// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tasks",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Tasks", targets: ["Tasks"]),
    ],
    dependencies: [
        .package(path: "../../VikunjaCore"),
        .package(path: "../../VikunjaDesignSystem"),
    ],
    targets: [
        .target(name: "Tasks", dependencies: ["VikunjaCore", "VikunjaDesignSystem"]),
        .testTarget(name: "TasksTests", dependencies: ["Tasks"]),
    ],
)
