import AppKit
import TaskPaneCore

/// A fresh, exact-member AX read supplied by WindowService's serial worker.
struct WindowOverlapLiveState {
    let bounds: CGRect
    let isStandard: Bool
    let isMinimized: Bool
    let isFullscreen: Bool
    let isResizable: Bool

    var canResize: Bool { isStandard && !isMinimized && !isFullscreen && isResizable }
}

/// Opt-in overlap avoidance. The injected accessors own AX identity, membership,
/// current-geometry and capability verification; this type owns restoration.
@MainActor
final class WindowOverlapService {
    typealias ReadState = (WindowEntry) async -> WindowOverlapLiveState?
    /// entry, desired bounds, expected current bounds. Return observed bounds
    /// only after the setter and readback succeed on the same verified member.
    typealias SetFrame = (WindowEntry, CGRect, CGRect) async -> CGRect?

    private struct SavedFrame {
        let entry: WindowEntry
        let original: CGRect
        let applied: CGRect
        let requested: CGRect
        var pendingReadback = false
    }

    private struct Input {
        let enabled: Bool
        let windows: [WindowEntry]
        let reservations: [WindowOverlapReservation]
    }

    private let readState: ReadState
    private let setFrame: SetFrame
    private var saved: [UInt32: SavedFrame] = [:]
    private var userOverrides: [UInt32: CGRect] = [:]
    private var latest = Input(enabled: false, windows: [], reservations: [])
    private var revision: UInt64 = 0
    private var processedRevision: UInt64 = 0
    private var task: Task<Void, Never>?
    private var stopped = false
    private var restorationDeadline: TimeInterval?

    init(readState: @escaping ReadState, setFrame: @escaping SetFrame) {
        self.readState = readState
        self.setFrame = setFrame
    }

    func update(enabled: Bool, windows: [WindowEntry], reservations: [WindowOverlapReservation]) {
        guard !stopped else { return }
        latest = Input(enabled: enabled, windows: windows, reservations: reservations)
        revision &+= 1
        schedule()
    }

    /// Await this before stopping WindowService so its verified AX worker remains
    /// available for restoration. User-adjusted or no-longer-verifiable windows
    /// are deliberately left alone.
    func stop() async {
        stopped = true
        restorationDeadline = ProcessInfo.processInfo.systemUptime + 5
        latest = Input(enabled: false, windows: latest.windows, reservations: [])
        revision &+= 1
        schedule()
        await task?.value
        // A transient failure before mutation has no future inventory refresh at
        // quit. Retry twice within a fixed deadline, using the same fresh-member
        // and pre-write-geometry guards. User changes remain untouched.
        for _ in 0..<2 where !saved.isEmpty {
            guard ProcessInfo.processInfo.systemUptime < (restorationDeadline ?? 0) else { break }
            revision &+= 1
            schedule()
            await task?.value
        }
    }

    private func schedule() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            while self.processedRevision != self.revision {
                let currentRevision = self.revision
                let input = self.latest
                await self.apply(input, revision: currentRevision)
                self.processedRevision = currentRevision
            }
            self.task = nil
        }
    }

    private func apply(_ input: Input, revision expectedRevision: UInt64) async {
        let live = Dictionary(input.windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if !input.enabled { userOverrides = [:] }
        var userChanged = Set<UInt32>()
        for token in Array(saved.keys) {
            if let restorationDeadline, ProcessInfo.processInfo.systemUptime >= restorationDeadline { return }
            guard revision == expectedRevision, var record = saved[token] else { return }
            // A row can disappear during a transient metadata failure while its
            // exact AX member is retained. Revalidate the stored session instead
            // of treating an absent presentation row as confirmed closure.
            let entry = live[token] ?? record.entry
            guard entry.pid == record.entry.pid, let state = await readState(entry) else { continue }
            guard revision == expectedRevision else { return }
            if record.pendingReadback {
                if WindowOverlapGeometry.approximatelyEqual(state.bounds, record.original) {
                    saved.removeValue(forKey: token)
                    continue
                }
                if WindowOverlapGeometry.approximatelyEqual(state.bounds, record.requested) {
                    record = SavedFrame(entry: entry, original: record.original, applied: state.bounds, requested: record.requested)
                } else if WindowOverlapGeometry.approximatelyEqual(state.bounds, record.applied) {
                    // A failed write left the pre-write geometry untouched. Keep
                    // the original and permit a later restore/resize attempt.
                    record = SavedFrame(entry: entry, original: record.original, applied: state.bounds, requested: .zero)
                } else {
                    // Unknown partial writes or user geometry edits cannot be
                    // safely attributed. Retain provenance without overwriting.
                    continue
                }
                saved[token] = record
            }
            guard WindowOverlapGeometry.approximatelyEqual(state.bounds, record.applied) else {
                // The user/app moved or resized it. Never restore over that edit.
                saved.removeValue(forKey: token)
                userChanged.insert(token)
                userOverrides[token] = state.bounds
                continue
            }
            guard state.canResize else { continue }
            let adjusted = input.enabled
                ? WindowOverlapGeometry.avoidingOverlap(frame: record.original, reservations: input.reservations)
                : nil
            let target = adjusted ?? record.original
            if WindowOverlapGeometry.approximatelyEqual(target, state.bounds) { continue }
            // Some apps enforce their own minimum sizes. Avoid retrying the
            // same unattainable request on every inventory refresh.
            if adjusted != nil, WindowOverlapGeometry.approximatelyEqual(target, record.requested) { continue }
            guard revision == expectedRevision else { return }
            saved[token] = SavedFrame(entry: entry, original: record.original, applied: state.bounds, requested: target, pendingReadback: true)
            if let observed = await setFrame(entry, target, state.bounds) {
                if adjusted == nil {
                    saved.removeValue(forKey: token)
                } else {
                    saved[token] = SavedFrame(entry: entry, original: record.original, applied: observed, requested: target)
                }
            }
        }
        guard input.enabled, revision == expectedRevision else { return }
        for entry in input.windows where saved[entry.id] == nil && !userChanged.contains(entry.id) && !entry.isDialog && !entry.isMinimized && entry.isOnScreen {
            guard revision == expectedRevision else { return }
            guard let state = await readState(entry), state.canResize else { continue }
            guard revision == expectedRevision else { return }
            if let userFrame = userOverrides[entry.id], WindowOverlapGeometry.approximatelyEqual(userFrame, state.bounds) {
                continue
            }
            userOverrides.removeValue(forKey: entry.id)
            guard let target = WindowOverlapGeometry.avoidingOverlap(frame: state.bounds, reservations: input.reservations) else { continue }
            saved[entry.id] = SavedFrame(entry: entry, original: state.bounds, applied: state.bounds, requested: target, pendingReadback: true)
            if let observed = await setFrame(entry, target, state.bounds) {
                saved[entry.id] = SavedFrame(entry: entry, original: state.bounds, applied: observed, requested: target)
            }
        }
    }
}
