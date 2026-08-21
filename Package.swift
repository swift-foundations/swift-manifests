// swift-tools-version: 6.4

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-manifests open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-manifests project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-manifests",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(name: "Manifest Loader", targets: ["Manifest Loader"]),
        .library(name: "Manifest Resolver", targets: ["Manifest Resolver"]),
        .library(name: "Manifest Executable", targets: ["Manifest Executable"]),
        .library(name: "Manifests Test Support", targets: ["Manifests Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-manifest-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-package-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-uri-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-strings.git", branch: "main"),
    ],
    targets: [
        // MARK: - Manifest Loader
        .target(
            name: "Manifest Loader",
            dependencies: [
                .product(name: "Manifest Primitives", package: "swift-manifest-primitives"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "Strings", package: "swift-strings"),
            ]
        ),

        // MARK: - Manifest Resolver
        .target(
            name: "Manifest Resolver",
            dependencies: [
                .product(name: "Manifest Primitives", package: "swift-manifest-primitives"),
                "Manifest Loader",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "URI Standard", package: "swift-uri-standard"),
            ]
        ),

        // MARK: - Manifest Executable
        .target(
            name: "Manifest Executable",
            dependencies: [
                .product(name: "Manifest Primitives", package: "swift-manifest-primitives"),
                .product(name: "Package Primitives", package: "swift-package-primitives"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Manifests Test Support",
            dependencies: [
                "Manifest Loader",
                "Manifest Resolver",
                .product(name: "Manifest Primitives Test Support", package: "swift-manifest-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Manifest Loader Tests",
            dependencies: [
                "Manifest Loader",
                "Manifests Test Support",
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .testTarget(
            name: "Manifest Resolver Tests",
            dependencies: [
                "Manifest Resolver",
                "Manifests Test Support",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "URI Standard", package: "swift-uri-standard"),
            ]
        ),
        .testTarget(
            name: "Manifest Executable Tests",
            dependencies: [
                "Manifest Executable",
                "Manifests Test Support",
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
