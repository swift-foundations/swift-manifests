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

extension Manifest {
    /// Compile and run a Swift source file as a single-file consumer
    /// manifest, returning the spawned process's exit code.
    ///
    /// Materializes a temporary eval project at
    /// ``Configuration/evalRoot``, copies
    /// ``Configuration/consumerSourcePath`` into the eval target as
    /// `main.swift`, generates a `Package.swift` whose
    /// `executableTarget` links the consumer-supplied dependencies,
    /// then spawns `swift run --package-path <evalRoot>
    /// <executableName> <arguments>` via ``Process/Spawn`` with the
    /// parent process's stdio inherited.
    ///
    /// The dispatched executable IS the consumer's source as compiled.
    /// Its stdout/stderr stream through to the caller's terminal; the
    /// child's exit code is returned as ``dispatch(configuration:)``'s
    /// `Int32` return value.
    ///
    /// This abstraction captures the materialize → spawn → passthrough
    /// shape that is structurally identical across single-file
    /// consumer-manifest tools (linters, formatters, doc generators).
    /// Consumer-domain concerns — magic-comment detection,
    /// source-content extraction, parent-chain folding — stay with
    /// the consumer; ``Executable`` handles only the mechanics.
    ///
    /// Sibling pattern to ``Manifest/load(_:configuration:)``
    /// (JSON-decode-spawn) and ``Manifest/Resolver`` (parent-chain
    /// walker).
    public enum Executable: Swift.Sendable {}
}

extension Manifest.Executable {
    /// Materialize the eval project + spawn the compiled executable.
    ///
    /// Pipeline:
    /// 1. Render `Package.swift` under ``Configuration/evalRoot`` from
    ///    the supplied dependencies, executable-target shape,
    ///    platforms, and optional ecosystem `SwiftSetting` block.
    /// 2. Copy ``Configuration/consumerSourcePath`` to
    ///    `<evalRoot>/Sources/<executableName>/main.swift`.
    /// 3. Spawn `swift run --package-path <evalRoot>
    ///    <executableName> <arguments>` with inherited stdio and
    ///    optional environment overrides.
    /// 4. Return the spawned process's exit code as `Int32`.
    ///    Termination by signal `s` is encoded as `-s` so callers can
    ///    distinguish abnormal termination from a regular non-zero
    ///    exit.
    ///
    /// - Parameter configuration: the materialize-and-spawn parameters.
    /// - Returns: the spawned process's exit code.
    /// - Throws: ``Error`` on materialization failure, source-read
    ///   failure, or spawn failure.
    public static func dispatch(
        configuration: Configuration
    ) throws(Self.Error) -> Swift.Int32 {
        try Self.Materializer.materialize(configuration: configuration)

        let invocation: [Swift.String] =
            [
                "swift", "run", "--package-path", configuration.evalRoot.string,
                configuration.executableName,
            ]
            + configuration.arguments
        let spawnConfiguration = Process.Spawn.Configuration(
            executable: "/usr/bin/env",
            arguments: invocation,
            environment: configuration.environment
        )
        let status: Process.Status
        do throws(Process.Error) {
            status = try Process.Spawn.run(spawnConfiguration).status
        } catch {
            throw .spawnFailed(
                consumerPackageRoot: configuration.consumerPackageRoot,
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
