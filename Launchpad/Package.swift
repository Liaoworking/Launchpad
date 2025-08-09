// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Launchpad",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Launchpad",
            targets: ["Launchpad"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Launchpad",
            path: ".",
            sources: [
                "LaunchpadApp.swift",
                "ContentView.swift", 
                "AppManager.swift",
                "DraggableAppGrid.swift",
                "SettingsView.swift",
                "WindowManager.swift"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
) 