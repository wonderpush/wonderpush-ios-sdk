// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WonderPush",
    defaultLocalization: "en",
    products: [
        .library(
            name: "WonderPush",
            targets: ["WonderPush"]),
        .library(
            name: "WonderPushExtension",
            targets: ["WonderPushExtension"]),
    ],
    targets: [
        .target(
            name: "WonderPushCommon"
        ),
        .target(
            name: "WonderPush",
            dependencies: ["WonderPushCommon"],
            path: "Sources/WonderPush",
            resources: [
              .process("Resources/close-with-transparency.png"),
              .process("Resources/close-with-transparency@2x.png"),
              .process("Resources/javascript/webViewBridgeJavascriptFileToInject.js")
            ],
            cSettings: [
              .headerSearchPath("InAppMessaging"),
              .headerSearchPath("Segmenter"),
              .headerSearchPath(".")
            ]
        ),
        .target(
            name: "WonderPushExtension",
            dependencies: ["WonderPushCommon"],
            path: "Sources/WonderPushExtension"
        ),
    ]
)

