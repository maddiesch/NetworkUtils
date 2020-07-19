// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkUtils",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "NetworkUtils", targets: ["NetworkUtils"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "NetworkUtils", dependencies: []),
        .testTarget(name: "NetworkUtilsTests", dependencies: ["NetworkUtils"]),
    ]
)
