// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikuAuth",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "VikuAuth", targets: ["VikuAuth"]),
    ],
    dependencies: [
        .package(path: "../VikunjaCore"),
    ],
    targets: [
        .target(name: "VikuAuth", dependencies: ["VikunjaCore"]),
        .testTarget(name: "VikuAuthTests", dependencies: ["VikuAuth"]),
    ],
)
