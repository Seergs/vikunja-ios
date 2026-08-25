// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Projects",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Projects", targets: ["Projects"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaNavigation"),
    ],
    targets: [
        .target(name: "Projects", dependencies: ["VikunjaNavigation"]),
    ]
)
