import SwiftUI

struct AppBadge: View {
    let bundleIdentifier: String?
    let enabled: Bool
    @ObservedObject private var badges = ApplicationBadgeService.shared
    var body: some View {
        if enabled, let bundleIdentifier, let label = badges.labelsByBundleIdentifier[bundleIdentifier] {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2).background(.red, in: Capsule())
                .accessibilityLabel("Notification badge: \(label)").allowsHitTesting(false)
        }
    }
}
