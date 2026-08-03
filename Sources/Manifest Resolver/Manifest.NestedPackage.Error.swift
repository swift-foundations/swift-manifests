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
    /// `spawnFailed` covers the `swift run --package-path
    /// <consumerRoot>/Lint Lint` invocation itself failing to start
    /// (binary not found, permission denied, fork failure, and
    /// similar). Subsequent run-time failures of the dispatched
    /// executable are surfaced via its exit code, not as a Swift
    /// error.
    ///
    /// `staleResolutionInvalidationFailed` covers the pre-dispatch
    /// removal of the consumer `Lint` package's own resolution state
    /// (`Package.resolved`, `.build/workspace-state.json`) failing for
    /// a reason other than the file already being absent — see
    /// ``Manifest/NestedPackage/invalidateStaleResolution(lintPackagePath:)``.
    public enum Error: Swift.Error, Swift.Sendable {
        case spawnFailed(
            consumerPackageRoot: Swift.String,
            description: Swift.String
        )
        case staleResolutionInvalidationFailed(
            consumerPackageRoot: Swift.String,
            description: Swift.String
        )
    }
}
