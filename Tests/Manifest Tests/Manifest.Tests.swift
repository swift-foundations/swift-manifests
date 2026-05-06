// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-manifest open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-manifest project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import Manifest

@Suite("Manifest API surface")
struct ManifestAPITests {
    @Test("Configuration constructs with all parameters")
    func configurationConstructs() {
        let config = Manifest.Configuration(
            packageRoot: "/tmp/example",
            filename: "Lint.swift",
            valueName: "manifest",
            dependencies: [
                Manifest.Dependency(
                    path: "/tmp/some-package",
                    packageName: "some-package",
                    product: "Some Product",
                    imports: ["Some_Product"]
                )
            ]
        )
        #expect(config.packageRoot == "/tmp/example")
        #expect(config.filename == "Lint.swift")
        #expect(config.valueName == "manifest")
        #expect(config.dependencies.count == 1)
        #expect(config.toolchain == nil)
    }

    @Test("Configuration accepts an explicit toolchain override")
    func configurationToolchain() {
        let config = Manifest.Configuration(
            packageRoot: "/tmp/example",
            filename: "Lint.swift",
            valueName: "manifest",
            dependencies: [],
            toolchain: "/usr/bin/swift"
        )
        #expect(config.toolchain == "/usr/bin/swift")
    }
}
