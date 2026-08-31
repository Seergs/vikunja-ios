// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Home",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Home", targets: ["Home"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaCore"),
        .package(path: "../../VikunjaNavigation"),
        .package(path: "../../VikunjaDesignSystem"),
    ],
    targets: [
        .target(name: "Home", dependencies: ["VikunjaCore", "VikunjaNavigation", "VikunjaDesignSystem"]),
        .testTarget(name: "HomeTests", dependencies: ["Home"]),
    ],
)
