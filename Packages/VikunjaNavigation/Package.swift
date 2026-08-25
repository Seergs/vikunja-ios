// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikunjaNavigation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VikunjaNavigation", targets: ["VikunjaNavigation"]),
    ],
    targets: [
        .target(name: "VikunjaNavigation"),
        .testTarget(name: "VikunjaNavigationTests", dependencies: ["VikunjaNavigation"]),
    ]
)
