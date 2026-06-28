// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkPrompt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MarkPrompt", targets: ["MarkPrompt"]),
        .executable(name: "ReaderFixtureSnapshotTool", targets: ["ReaderFixtureSnapshotTool"]),
        .library(name: "MarkPromptKit", targets: ["MarkPromptKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MarkPrompt",
            dependencies: ["MarkPromptKit"],
            path: "Sources/MarkPrompt",
            exclude: [
                "App/Info.plist",
                "Resources/AppIcon.iconset"
            ],
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/AppIconSource.png")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MarkPrompt/App/Info.plist"
                ])
            ]
        ),
        .target(
            name: "MarkPromptKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MarkPromptKit"
        ),
        .executableTarget(
            name: "ReaderFixtureSnapshotTool",
            dependencies: ["MarkPromptKit"],
            path: "Sources/ReaderFixtureSnapshotTool"
        ),
        .testTarget(
            name: "MarkdownCoreTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/MarkdownCoreTests"
        ),
        .testTarget(
            name: "PromptCoreTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/PromptCoreTests"
        ),
        .testTarget(
            name: "ModelTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/ModelTests"
        ),
        .testTarget(
            name: "AnchorCoreTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/AnchorCoreTests"
        ),
        .testTarget(
            name: "PersistenceCoreTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/PersistenceCoreTests"
        ),
        .testTarget(
            name: "AppStateTests",
            dependencies: ["MarkPromptKit"],
            path: "Tests/AppStateTests"
        )
    ]
)
