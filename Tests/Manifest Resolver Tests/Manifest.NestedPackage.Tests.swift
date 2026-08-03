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

        // MARK: - invalidateStaleResolution(consumerPackageRoot:lintPackagePath:)
        //
        // `<consumerRoot>/Lint` is reused, unmodified, across every
        // `dispatch(at:arguments:)` call for a given consumer. A
        // `branch:`-tracked dependency's pin in `Package.resolved` only
        // advances on an explicit `swift package update` or when no
        // lockfile is present — a bare `swift run` keeps whatever revision
        // was resolved the first time, forever. Left unguarded, a stale
        // local `Lint/Package.resolved` (a rebased branch, an old CI
        // artifact) silently freezes every subsequent dispatch at that
        // revision with legitimate-looking output. This mirrors the fix
        // landed for swift-linter's eval path as
        // swift-foundations/swift-linter#25.

        @Test
        func `A stale Package_resolved is removed before dispatch`() throws {
            let root = try Self.makeTemporaryRoot(key: "invalidateRemovesStaleResolvedManifest")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            try File.System.Create.Directory.create(at: lintDirectory, createIntermediates: true)
            let resolvedManifestPath = lintDirectory / "Package.resolved"
            try File(resolvedManifestPath).write.atomic(
                "{ \"pins\": [ \"stale-revision\" ] }"
            )
            #expect(File(resolvedManifestPath).stat.exists)

            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )

            #expect(!File(resolvedManifestPath).stat.exists)
        }

        /// `Package.resolved` alone is NOT sufficient: SwiftPM's build
        /// system separately caches the resolved dependency graph in
        /// `.build/workspace-state.json` and restores `Package.resolved`
        /// FROM that cache when only the lockfile is missing — the same
        /// empirical finding behind swift-foundations/swift-linter#25's
        /// fix for the eval path.
        @Test
        func `A stale cached workspace-state is also removed`() throws {
            let root = try Self.makeTemporaryRoot(key: "invalidateRemovesStaleWorkspaceState")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            let buildDirectory = lintDirectory / ".build"
            try File.System.Create.Directory.create(at: buildDirectory, createIntermediates: true)
            let resolvedManifestPath = lintDirectory / "Package.resolved"
            let workspaceStatePath = buildDirectory / "workspace-state.json"
            try File(resolvedManifestPath).write.atomic("{ \"pins\": [ \"stale-revision\" ] }")
            try File(workspaceStatePath).write.atomic(
                "{ \"object\": { \"pins\": [ \"stale-revision\" ] } }"
            )
            #expect(File(workspaceStatePath).stat.exists)

            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )

            #expect(!File(resolvedManifestPath).stat.exists)
            #expect(!File(workspaceStatePath).stat.exists)
        }

        /// Only the two known resolution-state files go — compiled object
        /// files and module caches survive, so an unchanged dependency
        /// graph still benefits from SwiftPM's incremental build.
        @Test
        func `Invalidation leaves the rest of the build cache untouched`() throws {
            let root = try Self.makeTemporaryRoot(key: "invalidatePreservesObjectCache")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            let buildDirectory = lintDirectory / ".build"
            try File.System.Create.Directory.create(at: buildDirectory, createIntermediates: true)
            try File(lintDirectory / "Package.resolved").write.atomic("{ }")
            try File(buildDirectory / "workspace-state.json").write.atomic("{ }")
            let unrelatedArtifact = buildDirectory / "build.db"
            try File(unrelatedArtifact).write.atomic("unrelated compiled-artifact cache\n")

            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )

            #expect(File(unrelatedArtifact).stat.exists)
        }

        /// Neither `Lint/` nor any of its ancestors exist yet — the exact
        /// shape of a consumer's very first dispatch.
        @Test
        func `First-ever dispatch has no resolution state to remove, and is not an error`() throws {
            let root = try Self.makeTemporaryRoot(key: "invalidateFirstEverDispatch")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"

            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )
        }

        @Test
        func `Invalidation is idempotent across repeated calls`() throws {
            let root = try Self.makeTemporaryRoot(key: "invalidateIsIdempotent")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            let buildDirectory = lintDirectory / ".build"
            try File.System.Create.Directory.create(at: buildDirectory, createIntermediates: true)
            try File(lintDirectory / "Package.resolved").write.atomic("{ }")
            try File(buildDirectory / "workspace-state.json").write.atomic("{ }")

            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )
            try Manifest.NestedPackage.invalidateStaleResolution(
                consumerPackageRoot: root.string,
                lintPackagePath: lintDirectory.string
            )

            #expect(!File(lintDirectory / "Package.resolved").stat.exists)
            #expect(!File(buildDirectory / "workspace-state.json").stat.exists)
        }

        /// End-to-end proof at the `dispatch(at:arguments:)` boundary
        /// itself: a stale `Lint/Package.resolved` planted before dispatch
        /// does not survive the call, regardless of whether the dispatched
        /// `swift run` invocation succeeds. `dispatch` always spawns
        /// `swift run`, which fails fast here (no real `Lint` executable
        /// target exists in the fixture) — that failure is expected and
        /// irrelevant; invalidation runs unconditionally before the spawn
        /// attempt, so the stale pin is gone either way.
        @Test
        func `dispatch clears a stale Package_resolved before spawning`() throws {
            let root = try Self.makeTemporaryRoot(key: "dispatchClearsStalePin")
            defer { try? File.System.Delete.delete(at: root, recursive: true) }

            let lintDirectory = root / "Lint"
            let buildDirectory = lintDirectory / ".build"
            try File.System.Create.Directory.create(at: buildDirectory, createIntermediates: true)
            let resolvedManifestPath = lintDirectory / "Package.resolved"
            let workspaceStatePath = buildDirectory / "workspace-state.json"
            try File(resolvedManifestPath).write.atomic("{ \"pins\": [ \"stale-revision\" ] }")
            try File(workspaceStatePath).write.atomic(
                "{ \"object\": { \"pins\": [ \"stale-revision\" ] } }"
            )

            _ = try? Manifest.NestedPackage.dispatch(at: root.string, arguments: [])

            #expect(!File(resolvedManifestPath).stat.exists)
            #expect(!File(workspaceStatePath).stat.exists)
        }
    }
}
