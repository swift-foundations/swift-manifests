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

import File_System
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

        // Resolve each dependency from SwiftPM's own checkouts first, falling
        // back to a sibling working copy. The sibling layout alone — which is
        // all this test used to consider — exists only on a developer machine
        // that has cloned the whole ecosystem side by side. On CI the checkout
        // is `/__w/swift-manifests/swift-manifests`, so `foundationsRoot` is
        // `/__w/swift-manifests` and the sibling path is simply absent, which
        // failed the run with `the package at '.../swift-json' cannot be
        // accessed`. Both packages are declared dependencies of this one, so
        // `.build/checkouts` always has them wherever the tests actually run.
        guard
            let jsonPackagePath = Self._firstReadableDirectory([
                manifestPackageRoot + "/.build/checkouts/swift-json",
                foundationsRoot + "/swift-json",
            ]),
            let fileSystemPackagePath = Self._firstReadableDirectory([
                manifestPackageRoot + "/.build/checkouts/swift-file-system",
                foundationsRoot + "/swift-file-system",
            ])
        else {
            // Deliberately a recorded failure, not a skip: this test guards a
            // shim-filename constraint whose failure mode is otherwise
            // invisible, and silently dropping it in the environment that gates
            // merges is how the coverage would be lost without anyone noticing.
            Issue.record(
                """
                Could not locate the swift-json / swift-file-system checkouts. \
                Looked under \(manifestPackageRoot)/.build/checkouts and \
                \(foundationsRoot). Run `swift build` once so SwiftPM resolves \
                dependencies, or clone the packages as siblings.
                """
            )
            return
        }

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
                    path: jsonPackagePath,
                    name: "swift-json",
                    product: "JSON",
                    imports: []
                ),
                Manifest.Dependency(
                    path: fileSystemPackagePath,
                    name: "swift-file-system",
                    product: "File System",
                    imports: []
                ),
            ]
        )

        #expect(result == 42)
    }

    /// Returns the first candidate that names a directory whose contents can
    /// actually be listed, or `nil` when none can.
    ///
    /// Listing rather than merely validating the path: `File.Directory(validating:)`
    /// checks the spelling, not the filesystem, so a path that does not exist
    /// validates fine and would be reported as usable.
    private static func _firstReadableDirectory(
        _ candidates: [Swift.String]
    ) -> Swift.String? {
        for candidate in candidates {
            guard let directory = try? File.Directory(validating: candidate) else { continue }
            guard (try? directory.entries()) != nil else { continue }
            return candidate
        }
        return nil
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
