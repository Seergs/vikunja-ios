// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikunjaDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VikunjaDesignSystem", targets: ["VikunjaDesignSystem"]),
    ],
    targets: [
        .target(name: "VikunjaDesignSystem"),
        .testTarget(name: "VikunjaDesignSystemTests", dependencies: ["VikunjaDesignSystem"]),
    ]
)
