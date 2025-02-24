// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NextWaveShared",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "NextWaveShared",
            targets: ["NextWaveShared"]),
    ],
    targets: [
        .target(
            name: "NextWaveShared",
            dependencies: []),
    ]
) 