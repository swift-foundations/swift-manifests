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

internal import File_System
public import Manifest_Primitives
internal import Process

/// Detection + dispatch for the nested-package consumer manifest shape.
///
/// PoC of the Lint/ nested-package mechanism (architecture cohort
/// Phase A — `HANDOFF-architecture-poc-lint-nested-package.md`).
///
/// Single-file `Lint.swift` consumers continue to use the existing
/// chain-resolution path on `Manifest.Resolver`; nested-package
/// consumers (with a `Lint/` directory at the package root containing
/// its own `Package.swift` + executable target) are detected here
/// and the lint run is delegated to the consumer's `Lint` executable
/// via `swift run --package-path <consumerRoot>/Lint Lint <args>`.
///
/// The dispatch path is intentionally additive to the existing
/// resolver: ``Manifest/Resolver/resolve(consumerPackageRoot:filename:dependencies:defaultConfiguration:buildConfiguration:)``
/// is unchanged. Callers detect first via ``detect(at:)`` and, when
/// `true`, dispatch via ``dispatch(at:arguments:)``. When `false`,
/// they fall through to the existing single-file resolution flow.
extension Manifest {
    public enum NestedPackage: Swift.Sendable {}
}

extension Manifest.NestedPackage {
    /// Detect whether `<consumerPackageRoot>/Lint/Package.swift`
    /// exists at the consumer's package root.
    ///
    /// Returns `true` only when both the `Lint/` directory and a
    /// `Package.swift` file inside it are accessible. Any I/O
    /// failure (missing directory, unreadable filesystem) returns
    /// `false` — callers should treat absent detection as "consumer
    /// uses the single-file path."
    public static func detect(
        at consumerPackageRoot: Swift.String
    ) -> Swift.Bool {
        let lintDirectoryPath = consumerPackageRoot + "/Lint"
        let directory: File.Directory
        do throws(File.Path.Error) {
            directory = try File.Directory(validating: lintDirectoryPath)
        } catch {
            return false
        }
        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try directory.entries()
        } catch {
            return false
        }
        for entry in entries where Swift.String(entry.name) == "Package.swift" {
            return true
        }
        return false
    }

    /// Spawn `swift run --package-path <consumerPackageRoot>/Lint Lint
    /// <arguments>` and return the dispatched executable's exit code.
    ///
    /// Inherits the parent process's stdio so the dispatched
    /// executable's diagnostic output streams through to the caller's
    /// stdout/stderr in real time. The dispatched executable IS the
    /// linter binary for the consumer (linking engine + rule packs
    /// declared in its `Lint/Package.swift`), so its stdout is the
    /// authoritative diagnostic stream.
    ///
    /// Returns the dispatched process's exit code as an `Int32`. A
    /// terminating signal `s` is encoded as `-s` so callers can
    /// distinguish abnormal termination from a regular non-zero exit.
    public static func dispatch(
        at consumerPackageRoot: Swift.String,
        arguments: [Swift.String]
    ) throws(Self.Error) -> Swift.Int32 {
        let lintPackagePath = consumerPackageRoot + "/Lint"
        try Self.invalidateStaleResolution(
            consumerPackageRoot: consumerPackageRoot,
            lintPackagePath: lintPackagePath
        )
        let invocation: [Swift.String] =
            ["swift", "run", "--package-path", lintPackagePath, "Lint"] + arguments
        let configuration = Process.Spawn.Configuration(
            executable: "/usr/bin/env",
            arguments: invocation
        )
        let status: Process.Status
        do throws(Process.Error) {
            status = try Process.Spawn.run(configuration).status
        } catch {
            throw .spawnFailed(
                consumerPackageRoot: consumerPackageRoot,
                description: "\(error)"
            )
        }
        switch status {
        case .exited(let code): return code
        case .signaled(let s): return -s
        case .stopped(let s): return -s
        }
    }

    /// Remove a prior run's resolution state from the consumer's
    /// `Lint/` package, if any exists: `Package.resolved` AND
    /// SwiftPM's own `.build/workspace-state.json`.
    ///
    /// `<consumerRoot>/Lint` is the consumer's own committed package —
    /// unlike swift-linter's eval fallback (`.swift-lint/eval/`, a
    /// materialized scratch project), it is reused across every
    /// `dispatch(at:arguments:)` invocation in place, on the
    /// developer's or CI's machine. A branch-tracked dependency
    /// declared there (the engine, a rule pack) keeps whatever pin
    /// `Package.resolved` already holds — SwiftPM only advances a
    /// `branch:`-tracked pin on an explicit `swift package update` or
    /// when no lockfile is present, never on a bare `swift run`. Left
    /// alone, a `Lint/Package.resolved` generated once — by a stale
    /// local checkout, an old CI artifact, a rebased branch — freezes
    /// every subsequent dispatch at that revision indefinitely, with
    /// legitimate-looking output and no diagnostic that anything is
    /// wrong. This mirrors the fix landed for swift-linter's eval path
    /// as swift-foundations/swift-linter#25.
    ///
    /// Deleting `Package.resolved` alone is not sufficient: SwiftPM's
    /// build system separately caches the resolved dependency graph in
    /// `.build/workspace-state.json` and restores `Package.resolved`
    /// from that cache when only the lockfile is missing. Both must go
    /// for `swift run` to re-resolve for real. The rest of `.build`
    /// (compiled object files, module caches) is left untouched, so an
    /// unchanged dependency graph still benefits from SwiftPM's
    /// incremental build.
    ///
    /// Best-effort and idempotent: absence of either file (first-ever
    /// dispatch against this consumer) is the common case, not a
    /// failure.
    internal static func invalidateStaleResolution(
        consumerPackageRoot: Swift.String,
        lintPackagePath: Swift.String
    ) throws(Self.Error) {
        let staleStatePaths: [Swift.String] = [
            lintPackagePath + "/Package.resolved",
            lintPackagePath + "/.build/workspace-state.json",
        ]
        for path in staleStatePaths {
            let filePath: File.Path
            do throws(File.Path.Error) {
                filePath = try File.Path(path)
            } catch {
                throw .staleResolutionInvalidationFailed(
                    consumerPackageRoot: consumerPackageRoot,
                    description: "invalidate stale Lint resolution at \(path): \(error)"
                )
            }
            do throws(File.System.Delete.Error) {
                try File(filePath).delete.ifExists()
            } catch {
                throw .staleResolutionInvalidationFailed(
                    consumerPackageRoot: consumerPackageRoot,
                    description: "invalidate stale Lint resolution at \(path): \(error)"
                )
            }
        }
    }
}
