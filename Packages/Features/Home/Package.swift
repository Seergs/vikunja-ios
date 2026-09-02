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
        .package(path: "../../VikuNavigation"),
        .package(path: "../../VikuDesignSystem"),
    ],
    targets: [
        .target(name: "Home", dependencies: ["VikunjaCore", "VikuNavigation", "VikuDesignSystem"]),
        .testTarget(name: "HomeTests", dependencies: ["Home"]),
    ],
)
