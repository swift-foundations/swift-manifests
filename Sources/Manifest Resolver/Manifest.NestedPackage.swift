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
        guard let directory = try? File.Directory(validating: lintDirectoryPath) else {
            return false
        }
        guard let entries = try? directory.entries() else {
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
}
