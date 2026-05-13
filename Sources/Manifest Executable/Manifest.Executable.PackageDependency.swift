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

public import Manifest_Primitives
public import Package_Primitives

extension Manifest.Executable {
    /// A SwiftPM package dependency the materialized eval target
    /// links against.
    ///
    /// Each value renders one `.package(...)` clause in the
    /// generated `Package.swift` and one
    /// `.product(name:package:)` entry per product on the eval
    /// target's `dependencies` list.
    ///
    /// Path-form deps are rewritten by the materializer to be
    /// relative to the eval `Package.swift`'s location; URL-form
    /// deps pass through verbatim.
    public struct PackageDependency: Swift.Sendable, Swift.Hashable {
        /// The SwiftPM package source shape.
        public enum Source: Swift.Sendable, Swift.Hashable {
            /// Path-form: `.package(path: "...")`. Resolved relative
            /// to the consumer's package root by convention; the
            /// materializer rewrites the path so the generated
            /// `Package.swift` resolves it from the eval project's
            /// vantage. Self-reference shortcuts (`"."` or the
            /// empty string) collapse to the consumer's own root.
            case path(Swift.String)

            /// URL-form with `from:` version anchor:
            /// `.package(url: "...", from: "X.Y.Z")`.
            case urlFrom(url: Swift.String, from: Swift.String)

            /// URL-form with half-open range:
            /// `.package(url: "...", "lower"..<"upper")`.
            case urlRange(url: Swift.String, lower: Swift.String, upper: Swift.String)
        }

        /// The dependency's source.
        public let source: Source

        /// Typed SwiftPM package name (the dep's `Package(name:)`
        /// field).
        ///
        /// Used by the materializer to emit
        /// `.product(name:package:)` entries with the typed package
        /// identity preserved.
        public let name: Package.Name

        /// Typed product names to depend on from this package.
        ///
        /// The materializer emits one `.product(name:package:)`
        /// entry per product on the eval target's `dependencies`
        /// list.
        public let products: [Product.Name]

        public init(source: Source, name: Package.Name, products: [Product.Name]) {
            self.source = source
            self.name = name
            self.products = products
        }
    }
}
