// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikunjaAuth",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "VikunjaAuth", targets: ["VikunjaAuth"]),
    ],
    dependencies: [
        .package(path: "../VikunjaCore"),
    ],
    targets: [
        .target(name: "VikunjaAuth", dependencies: ["VikunjaCore"]),
        .testTarget(name: "VikunjaAuthTests", dependencies: ["VikunjaAuth"]),
    ],
)
