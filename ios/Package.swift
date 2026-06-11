// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "tauri-plugin-liquid-glass",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "tauri-plugin-liquid-glass",
            type: .static,
            targets: ["tauri-plugin-liquid-glass"]),
    ],
    dependencies: [
        // Tauri runtime injected as a sibling local package by the Tauri CLI
        // when the consumer runs `tauri ios init` / `tauri ios dev`.
        .package(name: "Tauri", path: "../.tauri/tauri-api"),
    ],
    targets: [
        .target(
            name: "tauri-plugin-liquid-glass",
            dependencies: [
                .byName(name: "Tauri"),
            ],
            path: "Sources"),
    ]
)
