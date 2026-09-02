// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Projects",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Projects", targets: ["Projects"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaCore"),
        .package(path: "../../VikuNavigation"),
        .package(path: "../../VikunjaDesignSystem"),
    ],
    targets: [
        .target(name: "Projects", dependencies: ["VikunjaCore", "VikuNavigation", "VikunjaDesignSystem"]),
        .testTarget(name: "ProjectsTests", dependencies: ["Projects"]),
    ],
)
