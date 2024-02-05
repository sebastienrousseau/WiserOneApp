// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WiserOne",
    targets: [
        .executableTarget(
            name: "WiserOne",
            path: "Sources",
            resources: [
                .copy("Assets.xcassets"),
                .copy("WiserOne.entitlements"),
                .process("Resources/01-quotes.json"),
                .process("Resources/02-quotes.json"),
                .process("Resources/logo.svg")
            ]
        )
    ]
)
