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

public import File_System
public import Manifest_Primitives

extension Manifest.Executable {
    /// Errors raised by ``Manifest/Executable/dispatch(configuration:)``.
    ///
    /// The three shapes correspond to the three pipeline stages
    /// where failure can surface: reading the consumer's source
    /// file, materializing the eval project on disk, and spawning
    /// the `swift run` subprocess. Consumer-domain failures
    /// (magic-comment validation, source extraction, parent-chain
    /// resolution) are NOT reported here — they happen before
    /// ``Manifest/Executable/dispatch(configuration:)`` is invoked
    /// and surface through the consumer's own error type.
    public enum Error: Swift.Error, Swift.Sendable {
        /// The consumer's source file could not be read from disk.
        case readFailed(path: File.Path, description: Swift.String)

        /// Materializing the eval project on disk failed.
        ///
        /// Covers directory creation, atomic-write failures,
        /// invalid `executableName` (rejected at path-component
        /// validation), and `Package.swift` rendering errors.
        case materializationFailed(reason: Swift.String)

        /// Spawning the `swift run` subprocess failed before the
        /// child process began executing (binary not found,
        /// permission denied, fork failure, invalid argument
        /// encoding). Non-zero exit codes from a successfully-
        /// spawned child are returned through
        /// ``Manifest/Executable/dispatch(configuration:)``'s
        /// `Int32` return value, NOT through this error.
        case spawnFailed(consumerPackageRoot: File.Path, description: Swift.String)
    }
}
