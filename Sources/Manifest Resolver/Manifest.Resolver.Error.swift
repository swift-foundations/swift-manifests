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

public import URI_Standard

extension Manifest.Resolver {
    /// Errors raised during parent-chain resolution.
    ///
    /// All cases describe failures while walking the parent chain
    /// (fetching parent URLs, evaluating parent manifests, detecting
    /// cycles, hitting the depth cap). Failures while loading the
    /// CONSUMER's manifest are NOT thrown here — the resolver
    /// silently falls back to its `defaultConfiguration` closure for
    /// that case, matching the linter's pre-extraction behavior.
    public enum Error: Swift.Error, Sendable {
        /// A parent `URI` failed to fetch (curl non-zero exit, file
        /// read failure, manifest load failure, or write-temp failure
        /// with `exitCode: 0` indicating a downstream issue).
        /// `exitCode` is the curl exit code where applicable;
        /// `stderr` is best-effort context.
        case parentFetchFailed(url: URI, exitCode: Swift.Int32, stderr: Swift.String)

        /// A cycle was detected in the parent chain. `visited` is
        /// the parent-first traversal up to the cycle point;
        /// `at` is the URI whose revisit closed the cycle.
        case parentChainCycle(visited: [URI], at: URI)

        /// The parent chain exceeded the depth-16 sanity backstop
        /// without revisiting any URI — that is, not a cycle.
        case parentChainTooDeep(depth: Swift.Int)
    }
}
