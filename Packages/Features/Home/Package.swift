// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Home",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Home", targets: ["Home"]),
    ],
    targets: [
        .target(name: "Home"),
    ]
)
