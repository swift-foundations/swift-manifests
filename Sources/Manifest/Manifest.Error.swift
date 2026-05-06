// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-manifest open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-manifest project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import JSON
public import Process

extension Manifest {
    /// Errors raised during manifest evaluation.
    ///
    /// Each case carries domain-specific context so callers can
    /// distinguish failure modes without parsing strings.
    public enum Error: Swift.Error, Sendable {
        /// The package root or manifest filename failed validation
        /// (interior NUL, missing manifest file, etc.). The wrapped
        /// `reason` describes the specific issue.
        case invalidInput(reason: Swift.String)

        /// Materializing the eval project on disk failed.
        case projectMaterialization(reason: Swift.String)

        /// Spawning or running the driver subprocess failed.
        case driverProcess(Process.Error)

        /// The driver subprocess exited with a non-zero status,
        /// indicating a compile failure or a runtime error inside
        /// the manifest itself.
        case driverNonZeroStatus(Process.Status)

        /// Reading the captured output file failed (file not
        /// produced, permission, etc.). The wrapped `reason`
        /// describes the specific issue.
        case outputCaptureFailed(reason: Swift.String)

        /// Decoding the captured output as JSON, or as the requested
        /// `Output` type via ``JSON.Serializable/deserialize(_:)``,
        /// failed.
        case decoding(JSON.Error)
    }
}
