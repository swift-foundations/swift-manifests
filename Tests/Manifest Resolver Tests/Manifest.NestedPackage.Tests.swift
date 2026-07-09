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

extension Manifest.NestedPackage {
    @Suite("Manifest.NestedPackage") struct Test {
        /// Detection MUST return `true` against the swift-tagged-primitives
        /// reference fixture — the consumer that the architecture cohort
        /// Phase A PoC authors a `Lint/` nested package for. This test
        /// pins the load-bearing detection invariant: when the consumer's
        /// `Lint/Package.swift` exists, swift-linter delegates the run to
        /// the nested package's executable; absence triggers the single-
        /// file Lint.swift fallback.
        @Test
        func `detect returns true for tagged-primitives Lint nested package`() {
            let consumerRoot = "/Users/coen/Developer/swift-primitives/swift-tagged-primitives"
            let detected = Manifest.NestedPackage.detect(at: consumerRoot)
            #expect(detected == true)
        }

        /// Detection MUST return `false` for any directory that lacks a
        /// `Lint/Package.swift`. This is the single-file-fallback gate —
        /// when no nested package exists, the resolver caller falls
        /// through to the existing single-file `Lint.swift` chain-
        /// resolution flow per ``Manifest/Resolver/resolve(consumerPackageRoot:filename:dependencies:defaultConfiguration:buildConfiguration:)``.
        @Test
        func `detect returns false for a directory without Lint nested package`() {
            // swift-manifests itself doesn't host a `Lint/` nested package;
            // it's an L3 foundation, not a linter consumer.
            let directoryWithoutNestedPackage = "/Users/coen/Developer/swift-foundations/swift-manifests"
            let detected = Manifest.NestedPackage.detect(at: directoryWithoutNestedPackage)
            #expect(detected == false)
        }

        /// Detection MUST return `false` when the consumer root path
        /// itself does not exist on the filesystem. Aligns with the
        /// resolver's existing "absent → single-file fallback"
        /// behavior.
        @Test
        func `detect returns false for a non-existent consumer root`() {
            let nonExistentRoot = "/nonexistent/path/that/should/not/exist"
            let detected = Manifest.NestedPackage.detect(at: nonExistentRoot)
            #expect(detected == false)
        }
    }
}
