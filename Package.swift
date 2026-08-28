// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CherryPanel",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CherryPanel",
            targets: ["CherryPanel"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CherryPanel",
            dependencies: [],
            path: "CherryPanel",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CherryPanelWidget",
            dependencies: ["CherryPanel"],
            path: "WidgetExtension"
        ),
        .testTarget(
            name: "CherryPanelTests",
            dependencies: ["CherryPanel"],
            path: "Tests"
        ),
    ]
)