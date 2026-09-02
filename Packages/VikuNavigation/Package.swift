// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VikuNavigation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VikuNavigation", targets: ["VikuNavigation"]),
    ],
    targets: [
        .target(name: "VikuNavigation"),
        .testTarget(name: "VikuNavigationTests", dependencies: ["VikuNavigation"]),
    ],
)
