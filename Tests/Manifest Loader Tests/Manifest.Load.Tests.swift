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

@testable import Manifest_Loader

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Manifest {
    @Suite struct Test {
        @Suite(.serialized) struct Integration {}
    }
}

extension Manifest.Test.Integration {

    /// End-to-end exercise of the auto-generated driver shim. Materializes
    /// a real eval project on disk, spawns `swift run` against it, and
    /// asserts the JSON-serialized `Output` round-trips through the
    /// subprocess.
    ///
    /// Why: Swift 6.x rejects `@main` in a module that contains top-level
    /// code; a file literally named `main.swift` is implicitly top-level
    /// by filename. The shim emits `@main` on `enum __SwiftManifestDriver`,
    /// so its filename MUST NOT be `main.swift`. Without this test the
    /// failure mode is invisible until a downstream consumer hits the
    /// shim path; a unit test on `Configuration` cannot catch it.
    @Test
    func `driver shim round-trips Int through swift run subprocess`() throws {
        let testFilePath: Swift.String = #filePath
        let manifestPackageRoot = Self._directoryAncestor(of: testFilePath, levels: 3)
        let foundationsRoot = Self._directoryAncestor(of: manifestPackageRoot, levels: 1)

        let fixtureRoot = "/tmp/swift-manifest-e2e-\(getpid())"
        try Manifest._createDirectoryRecursive(at: fixtureRoot)

        try Manifest._writeAtomic(
            "let manifest: Int = 42\n",
            to: fixtureRoot + "/Lint.swift"
        )

        let result = try Manifest.load(
            Int.self,
            from: fixtureRoot,
            named: "Lint.swift",
            binding: "manifest",
            dependencies: [
                Manifest.Dependency(
                    path: foundationsRoot + "/swift-json",
                    name: "swift-json",
                    product: "JSON",
                    imports: []
                ),
                Manifest.Dependency(
                    path: foundationsRoot + "/swift-file-system",
                    name: "swift-file-system",
                    product: "File System",
                    imports: []
                ),
            ]
        )

        #expect(result == 42)
    }

    private static func _directoryAncestor(
        of path: Swift.String,
        levels: Int
    ) -> Swift.String {
        var current = path
        for _ in 0..<levels {
            guard let lastSlash = current.lastIndex(of: "/") else { return current }
            current = Swift.String(current[..<lastSlash])
        }
        return current
    }
}
