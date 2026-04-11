// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WiserOne",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "WiserOneCore",
            targets: ["WiserOneCore"]
        ),
        .executable(
            name: "WiserOne",
            targets: ["WiserOne"]
        ),
    ],
    targets: [
        .target(
            name: "WiserOneCore",
            path: "sources/core"
        ),
        .executableTarget(
            name: "WiserOne",
            dependencies: ["WiserOneCore"],
            path: "sources",
            exclude: ["core"],
            resources: [
                .copy("assets.xcassets"),
                .process("resources")
            ]
        ),
        .testTarget(
            name: "WiserOneCoreTests",
            dependencies: ["WiserOneCore"],
            path: "tests/core-tests"
        ),
        .testTarget(
            name: "WiserOneUITests",
            dependencies: ["WiserOne"],
            path: "tests/ui-tests"
        )
    ]
)
