import Foundation

/// Presentation identity only. Session window IDs must never be persisted or
/// substituted for the Accessibility identity used to control a window.
public struct WindowArrangementItem: Equatable {
    public let id: String
    public let applicationKey: String

    public init(id: String, applicationKey: String) {
        self.id = id
        self.applicationKey = applicationKey
    }
}

public enum WindowArrangement {
    /// Keeps the caller's base order for new windows and, optionally, makes each
    /// app's windows adjacent without combining or discarding any buttons.
    public static func ordered(items: [WindowArrangementItem], manualOrder: [String], groupAdjacent: Bool) -> [String] {
        var seen = Set<String>()
        let uniqueItems = items.filter { seen.insert($0.id).inserted }
        let ids = reconciled(manualOrder, liveIDs: uniqueItems.map(\.id))
        guard groupAdjacent else { return ids }

        let applicationKeys = Dictionary(uniqueKeysWithValues: uniqueItems.map { ($0.id, $0.applicationKey) })
        var applications: [String] = []
        var groups: [String: [String]] = [:]
        for id in ids {
            guard let application = applicationKeys[id] else { continue }
            if groups[application] == nil { applications.append(application) }
            groups[application, default: []].append(id)
        }
        return applications.flatMap { groups[$0] ?? [] }
    }

    /// Prunes closed IDs, removes duplicates, and appends newly verified IDs.
    /// The caller supplies all live identities, including temporarily hidden ones.
    public static func reconciled(_ order: [String], liveIDs: [String]) -> [String] {
        let live = Set(liveIDs)
        var seen = Set<String>()
        return (order + liveIDs).filter { live.contains($0) && seen.insert($0).inserted }
    }

    /// Moves one window; nil means the end. Unknown targets and no-op drops do
    /// not change state. No application keys or window titles identify this move.
    public static func moving(_ id: String, before target: String?, currentOrder: [String]) -> [String]? {
        var seen = Set<String>()
        let current = currentOrder.filter { seen.insert($0).inserted }
        guard current.contains(id), target != id,
              target.map({ current.contains($0) }) ?? true else { return nil }
        var updated = current.filter { $0 != id }
        if let target, let index = updated.firstIndex(of: target) { updated.insert(id, at: index) }
        else { updated.append(id) }
        return updated == current ? nil : updated
    }

    /// Starts a filtered drag from the displayed order while retaining other
    /// live windows. Hidden windows are preserved, never accepted as drop targets.
    public static func moving(_ id: String, before target: String?, currentOrder: [String],
                              retainedOrder: [String], liveIDs: [String]) -> [String]? {
        let live = Set(liveIDs)
        var seen = Set<String>()
        let visible = currentOrder.filter { live.contains($0) && seen.insert($0).inserted }
        let visibleIDs = Set(visible)
        guard visibleIDs.contains(id), target != id,
              target.map({ visibleIDs.contains($0) }) ?? true else { return nil }
        let base = reconciled(retainedOrder, liveIDs: liveIDs)
        var displayed = visible.makeIterator()
        let merged = base.map { visibleIDs.contains($0) ? displayed.next() ?? $0 : $0 }
        return moving(id, before: target, currentOrder: merged)
    }

    /// Moves an app's complete supplied block atomically, preserving its current
    /// internal order. Explicit hidden source IDs move with their app; unrelated
    /// hidden IDs remain in relative order. No window identity is invented.
    public static func movingBlock(_ ids: [String], before target: String?, currentOrder: [String],
                                   retainedOrder: [String], liveIDs: [String]) -> [String]? {
        let live = Set(liveIDs)
        let sources = Set(ids)
        var seen = Set<String>()
        let visible = currentOrder.filter { live.contains($0) && seen.insert($0).inserted }
        let visibleIDs = Set(visible)
        guard !sources.isEmpty, sources.isSubset(of: live), !sources.isDisjoint(with: visibleIDs),
              target.map({ visibleIDs.contains($0) && !sources.contains($0) }) ?? true else { return nil }
        let base = reconciled(retainedOrder, liveIDs: liveIDs)
        var displayed = visible.makeIterator()
        let merged = base.map { visibleIDs.contains($0) ? displayed.next() ?? $0 : $0 }
        let block = merged.filter { sources.contains($0) }
        var updated = merged.filter { !sources.contains($0) }
        if let target, let index = updated.firstIndex(of: target) { updated.insert(contentsOf: block, at: index) }
        else { updated.append(contentsOf: block) }
        return updated == merged ? nil : updated
    }
}
