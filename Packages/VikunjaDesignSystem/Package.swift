// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikunjaDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VikunjaDesignSystem", targets: ["VikunjaDesignSystem"]),
    ],
    dependencies: [
        .package(path: "../VikunjaCore"),
    ],
    targets: [
        .target(name: "VikunjaDesignSystem", dependencies: ["VikunjaCore"]),
        .testTarget(name: "VikunjaDesignSystemTests", dependencies: ["VikunjaDesignSystem"]),
    ],
)
