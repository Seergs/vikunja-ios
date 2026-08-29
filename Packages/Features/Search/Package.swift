// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Search",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Search", targets: ["Search"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaCore"),
        .package(path: "../../VikunjaNavigation"),
        .package(path: "../../VikunjaDesignSystem"),
    ],
    targets: [
        .target(name: "Search", dependencies: ["VikunjaCore", "VikunjaNavigation", "VikunjaDesignSystem"]),
    ]
)
