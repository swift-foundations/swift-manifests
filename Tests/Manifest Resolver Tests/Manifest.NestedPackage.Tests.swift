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

@testable import Manifest_Resolver

extension Manifest.NestedPackage {
    @Suite struct Test {

        /// Creates an empty directory at a deterministic temporary path,
        /// clearing any stray left by a previous run.
        private static func makeTemporaryRoot(key: Swift.String) throws -> File.Path {
            let root = try File.Path.Temporary.deterministic(
                prefix: "swift-manifests-nested-package-test-",
                key: key,
                suffix: ""
            )
            try? File.System.Delete.delete(at: root, recursive: true)
            try File.System.Create.Directory.create(at: root, createIntermediates: true)
            return root
        }

        /// Detection MUST return `true` when the consumer hosts a
        /// `Lint/Package.swift`, and `false` when it does not — swift-linter
        /// delegates the run to the nested package's executable in the first
        /// case and falls through to the single-file `Lint.swift` path in the
        /// second.
        ///
        /// Both arms run against **one** directory that this test builds, so
        /// the assertions differ only in whether `Lint/Package.swift` exists.
        /// That is deliberate: a lone `#expect(detected == false)` is satisfied
        /// by any constantly-false implementation, and previously was — the
        /// negative arm used to point at a hardcoded path that did not exist on
        /// CI, so it passed for the wrong reason and would have kept passing if
        /// `detect` were replaced by `{ _ in false }`. Asserting the flip in a
        /// single test makes it discriminating in both directions: a constant
        /// `false` fails the second `#expect`, a constant `true` fails the
        /// first.
        @Test
        func `detect flips from false to true when Lint Package_swift appears`() throws {
            let root = try Self.makeTemporaryRoot(key: "detectFlipsWhenLintPackageAppears")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            // Negative arm — the root exists and is readable, but hosts no `Lint/`.
            #expect(Manifest.NestedPackage.detect(at: root.string) == false)

            // Positive arm — same root, now carrying `Lint/Package.swift`.
            let lintDirectory = root / "Lint"
            try File.System.Create.Directory.create(at: lintDirectory, createIntermediates: true)
            try File(lintDirectory / "Package.swift").write.atomic(
                "// swift-tools-version: 6.3.3\n"
            )

            #expect(Manifest.NestedPackage.detect(at: root.string) == true)
        }

        /// Detection MUST return `false` when a `Lint/` directory exists but
        /// contains no `Package.swift`. This is the case a path-existence check
        /// alone would get wrong, and it was not covered before.
        @Test
        func `detect returns false for a Lint directory without Package_swift`() throws {
            let root = try Self.makeTemporaryRoot(key: "detectLintDirectoryWithoutPackage")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            try File.System.Create.Directory.create(at: lintDirectory, createIntermediates: true)
            try File(lintDirectory / "README.md").write.atomic("not a manifest\n")

            #expect(Manifest.NestedPackage.detect(at: root.string) == false)
        }

        /// Detection MUST return `false` when the consumer root path itself
        /// does not exist on the filesystem. Aligns with the resolver's
        /// existing "absent → single-file fallback" behavior.
        ///
        /// Distinct from the negative arm above: there the directory exists and
        /// lacks a nested package, here nothing exists at all. Both must reach
        /// `false`, by different routes.
        @Test
        func `detect returns false for a non-existent consumer root`() {
            let nonExistentRoot = "/nonexistent/path/that/should/not/exist"
            let detected = Manifest.NestedPackage.detect(at: nonExistentRoot)
            #expect(detected == false)
        }
    }
}
