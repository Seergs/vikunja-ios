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
        .package(path: "../VikunjaAuth"),
        .package(path: "../VikunjaDesignSystem"),
    ],
    targets: [
        .target(
            name: "VikunjaWidgetKit",
            dependencies: ["VikunjaCore", "VikunjaNetworking", "VikunjaAuth", "VikunjaDesignSystem"],
        ),
        .testTarget(name: "VikunjaWidgetKitTests", dependencies: ["VikunjaWidgetKit"]),
    ],
)
