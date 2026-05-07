// swift-tools-version: 6.3.1

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
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "Manifest Loader", targets: ["Manifest Loader"]),
        .library(name: "Manifest Resolver", targets: ["Manifest Resolver"]),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-manifest-primitives"),
        .package(path: "../../swift-standards/swift-uri-standard"),
        .package(path: "../swift-environment"),
        .package(path: "../swift-file-system"),
        .package(path: "../swift-json"),
        .package(path: "../swift-process"),
        .package(path: "../swift-strings"),
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

        // MARK: - Tests
        .testTarget(
            name: "Manifest Loader Tests",
            dependencies: [
                "Manifest Loader",
            ]
        ),
        .testTarget(
            name: "Manifest Resolver Tests",
            dependencies: [
                "Manifest Resolver",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "URI Standard", package: "swift-uri-standard"),
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
