// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskPane",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TaskPane", targets: ["TaskPane"])],
    targets: [
        .target(name: "TaskPaneCore"),
        .executableTarget(name: "TaskPane", dependencies: ["TaskPaneCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("SwiftUI"),
            .linkedFramework("ApplicationServices"), .linkedFramework("IOKit"),
            .linkedFramework("SystemConfiguration"), .linkedFramework("ScreenCaptureKit")
        ]),
        .testTarget(name: "TaskPaneCoreTests", dependencies: ["TaskPaneCore"])
    ],
    swiftLanguageVersions: [.v5]
)
