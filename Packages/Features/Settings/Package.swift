// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaNavigation"),
    ],
    targets: [
        .target(name: "Settings", dependencies: ["VikunjaNavigation"]),
    ]
)
