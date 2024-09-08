// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MikanSwift",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "MikanSwift",
            targets: ["MikanSwift"]),
    ],
    targets: [
        .target(
            name: "MikanSwift"),
        .testTarget(
            name: "MikanSwiftTests",
            dependencies: ["MikanSwift"]),
    ]
)
