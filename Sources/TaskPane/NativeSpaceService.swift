import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

struct NativeSpaceSnapshot {
    /// A nil topology means the query was unavailable or malformed. "Main" is
    /// preserved when macOS groups displays into one shared Space stack.
    let currentSpacesByDisplayUUID: [String: UInt64]?
    let activeSpaceIDs: Set<UInt64>?
    let spacesByDisplayUUID: [String: [UInt64]]?
    let userSpaceIDs: Set<UInt64>?
    /// A missing key means unknown, never evidence that a window has no Space.
    let membershipsByWindowID: [CGWindowID: [UInt64]]
}

/// Read-only, worker-confined adapter for optional private APIs. No Space or
/// window assignment/activation/mutation functions are resolved here.
/// C ABIs and Copy ownership were checked against these primary sources:
/// https://github.com/asmvik/yabai/blob/master/src/misc/extern.h
/// https://github.com/asmvik/yabai/blob/master/src/window.c
/// https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h
/// https://github.com/NUIKit/CGSInternal/blob/master/CGSConnection.h
/// Dictionary keys and the "Main" topology boundary are independently used by:
/// https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/spaces/spaces.lua
/// https://github.com/lwouis/alt-tab-macos/blob/master/src/macos/api-wrappers/SkyLight.framework.swift
final class NativeSpaceReader {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyManagedSpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyWindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias DisplayCurrentSpace = @convention(c) (Int32, CFString) -> UInt64
    // Exact AXError (signed 32-bit) ABI:
    // https://github.com/lwouis/alt-tab-macos/blob/master/src/macos/api-wrappers/ApplicationServices.HIServices.framework.swift
    private typealias AXWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> Int32

    private let handles: [UnsafeMutableRawPointer]
    private let mainConnection: MainConnection?
    private let copyManagedSpaces: CopyManagedSpaces?
    private let copyWindowSpaces: CopyWindowSpaces?
    private let displayCurrentSpace: DisplayCurrentSpace?
    private let axWindowID: AXWindowID?

    init() {
        let paths = [
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
        ]
        let loadedHandles = paths.compactMap { dlopen($0, RTLD_LAZY | RTLD_LOCAL) }
        handles = loadedHandles
        func symbol(_ names: [String]) -> UnsafeMutableRawPointer? {
            for name in names {
                for handle in loadedHandles {
                    if let pointer = dlsym(handle, name) { return pointer }
                }
            }
            return nil
        }
        mainConnection = symbol(["CGSMainConnectionID", "SLSMainConnectionID"]).map { unsafeBitCast($0, to: MainConnection.self) }
        copyManagedSpaces = symbol(["CGSCopyManagedDisplaySpaces", "SLSCopyManagedDisplaySpaces"]).map { unsafeBitCast($0, to: CopyManagedSpaces.self) }
        copyWindowSpaces = symbol(["CGSCopySpacesForWindows", "SLSCopySpacesForWindows"]).map { unsafeBitCast($0, to: CopyWindowSpaces.self) }
        displayCurrentSpace = symbol(["CGSManagedDisplayGetCurrentSpace", "SLSManagedDisplayGetCurrentSpace"]).map { unsafeBitCast($0, to: DisplayCurrentSpace.self) }
        axWindowID = symbol(["_AXUIElementGetWindow"]).map { unsafeBitCast($0, to: AXWindowID.self) }
    }

    deinit { for handle in handles.reversed() { dlclose(handle) } }

    /// This bridge supplies metadata only. AX session identity and normal AX
    /// ownership checks must remain the authority for window actions.
    func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let axWindowID else { return nil }
        var identifier: CGWindowID = kCGNullWindowID
        guard axWindowID(element, &identifier) == AXError.success.rawValue,
              identifier != kCGNullWindowID else { return nil }
        return identifier
    }

    func snapshot(windowIDs: [CGWindowID]) -> NativeSpaceSnapshot {
        guard let mainConnection else { return unavailable }
        let connection = mainConnection()
        guard connection != 0 else { return unavailable }
        let topology = readTopology(connection: connection)
        var memberships: [CGWindowID: [UInt64]] = [:]
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        if let copyWindowSpaces {
            for identifier in Set(windowIDs).sorted().prefix(512) where identifier != kCGNullWindowID {
                guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                // Selector 0x7 is the all-spaces mask in both CGSInternal and
                // yabai's C usage. Query separately to retain attribution.
                let windows = [NSNumber(value: identifier)] as CFArray
                guard let copied = copyWindowSpaces(connection, 0x7, windows),
                      let values = copied.takeRetainedValue() as? [NSNumber], !values.isEmpty else { continue }
                let ids = values.compactMap(Self.spaceID)
                guard ids.count == values.count else { continue }
                memberships[identifier] = Array(Set(ids)).sorted()
            }
        }
        return NativeSpaceSnapshot(currentSpacesByDisplayUUID: topology?.current,
                                   activeSpaceIDs: topology.map { Set($0.current.values) },
                                   spacesByDisplayUUID: topology?.all,
                                   userSpaceIDs: topology?.user,
                                   membershipsByWindowID: memberships)
    }

    private var unavailable: NativeSpaceSnapshot {
        NativeSpaceSnapshot(currentSpacesByDisplayUUID: nil, activeSpaceIDs: nil,
                            spacesByDisplayUUID: nil, userSpaceIDs: nil, membershipsByWindowID: [:])
    }

    private func readTopology(connection: Int32) -> (current: [String: UInt64], all: [String: [UInt64]], user: Set<UInt64>)? {
        guard let copyManagedSpaces, let copied = copyManagedSpaces(connection),
              let displays = copied.takeRetainedValue() as? [[String: Any]],
              !displays.isEmpty, displays.count <= 64 else { return nil }
        var current: [String: UInt64] = [:]
        var all: [String: [UInt64]] = [:]
        var user = Set<UInt64>()
        for display in displays {
            guard let name = display["Display Identifier"] as? String,
                  (name == "Main" || UUID(uuidString: name) != nil),
                  all[name] == nil,
                  let spaces = display["Spaces"] as? [[String: Any]],
                  !spaces.isEmpty, spaces.count <= 1024 else { return nil }
            var ids: [UInt64] = []
            for space in spaces {
                guard let id = Self.spaceID(space["id64"] ?? space["ManagedSpaceID"]),
                      let type = space["type"] as? NSNumber,
                      CFGetTypeID(type) != CFBooleanGetTypeID(),
                      type.doubleValue.isFinite,
                      type.doubleValue.rounded() == type.doubleValue else { return nil }
                ids.append(id)
                if type.intValue == 0 { user.insert(id) }
            }
            guard Set(ids).count == ids.count else { return nil }
            let currentRecord = display["Current Space"] as? [String: Any]
            var selected = Self.spaceID(currentRecord?["id64"] ?? currentRecord?["ManagedSpaceID"])
            // "Main" is not a display UUID. Its dictionary value is the only
            // topology authority when separate display Spaces are disabled.
            if selected == nil, name != "Main", let displayCurrentSpace {
                let queried = displayCurrentSpace(connection, name as CFString)
                if queried != 0 { selected = queried }
            }
            guard let selected, ids.contains(selected) else { return nil }
            all[name] = ids
            current[name] = selected
        }
        return (current, all, user)
    }

    private static func spaceID(_ value: Any?) -> UInt64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              let identifier = UInt64(number.stringValue), identifier != 0 else { return nil }
        return identifier
    }
}
