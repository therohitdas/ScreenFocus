// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
    name: "ScreenFocus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ScreenFocus", targets: ["ScreenFocus"])
    ],
    targets: [
        .executableTarget(
            name: "ScreenFocus",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "ScreenFocusTests",
            dependencies: ["ScreenFocus"]
        )
    ]
)
