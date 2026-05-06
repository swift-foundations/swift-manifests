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

import Testing
@testable import Manifest_Resolver

@Suite("Manifest.Resolver")
struct ManifestResolverTests {
    /// A minimal `C` shape for testing the resolver's fold semantics
    /// without depending on a real lint configuration type.
    struct Configuration: Sendable, Equatable {
        let value: Swift.Int
    }

    @Test("Non-existent package root falls back to defaultConfiguration")
    func nonExistentRootFallsBackToDefault() throws {
        let result = try Manifest.Resolver<Swift.Int, Configuration>.resolve(
            consumerPackageRoot: "/nonexistent/path/that/should/not/exist",
            manifestFilename: "Lint.swift",
            dependencies: [],
            defaultConfiguration: { Configuration(value: 999) },
            buildConfiguration: { manifest, _ in
                Configuration(value: manifest)
            }
        )
        #expect(result == Configuration(value: 999))
    }
}
