// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "tauri-plugin-system-components",
    platforms: [
        // UIButton.Configuration (used by the components overlay) needs 15.
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "tauri-plugin-system-components",
            type: .static,
            targets: ["tauri-plugin-system-components"]),
    ],
    dependencies: [
        // Tauri runtime injected as a sibling local package by the Tauri CLI
        // when the consumer runs `tauri ios init` / `tauri ios dev`.
        .package(name: "Tauri", path: "../.tauri/tauri-api"),
    ],
    targets: [
        .target(
            name: "tauri-plugin-system-components",
            dependencies: [
                .byName(name: "Tauri"),
            ],
            path: "Sources"),
    ]
)
