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

extension Manifest.NestedPackage {
    /// Errors raised by the nested-package dispatch path.
    ///
    /// `spawnFailed` is the single shape observed today — the
    /// `swift run --package-path <consumerRoot>/Lint Lint` invocation
    /// could not be started (binary not found, permission denied,
    /// fork failure, and similar). Subsequent run-time failures of the
    /// dispatched executable are surfaced via its exit code, not as
    /// a Swift error.
    public enum Error: Swift.Error, Swift.Sendable {
        case spawnFailed(
            consumerPackageRoot: Swift.String,
            description: Swift.String
        )
    }
}
