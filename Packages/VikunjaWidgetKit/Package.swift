// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikunjaWidgetKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VikunjaWidgetKit", targets: ["VikunjaWidgetKit"]),
    ],
    dependencies: [
        .package(path: "../VikunjaCore"),
        .package(path: "../VikunjaNetworking"),
        .package(path: "../VikuAuth"),
        .package(path: "../VikuDesignSystem"),
        .package(path: "../VikuNavigation"),
    ],
    targets: [
        .target(
            name: "VikunjaWidgetKit",
            dependencies: ["VikunjaCore", "VikunjaNetworking", "VikuAuth", "VikuDesignSystem", "VikuNavigation"],
        ),
        .testTarget(name: "VikunjaWidgetKitTests", dependencies: ["VikunjaWidgetKit"]),
    ],
)
