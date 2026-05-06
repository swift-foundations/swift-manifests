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

extension Manifest {
    /// A package dependency that the manifest's driver shim
    /// compiles against.
    ///
    /// Each dependency entry materializes into:
    ///
    ///   - a `.package(path: ...)` clause in the eval project's
    ///     `Package.swift`,
    ///   - a `.product(name:package:)` entry on the driver target's
    ///     `dependencies` list,
    ///   - one `import` statement per name in ``imports`` at the
    ///     top of the driver shim's `main.swift`.
    public struct Dependency: Sendable {
        /// Filesystem path to the package directory.
        ///
        /// Resolved relative to the eval project's `Package.swift`
        /// — typically a path like `"../../swift-primitives/..."`
        /// when the consumer is itself a swift-foundations package.
        public let path: Swift.String

        /// SwiftPM package name (the `name:` field of
        /// `Package.swift`).
        public let packageName: Swift.String

        /// Product name within the package.
        public let product: Swift.String

        /// Module names to emit `import` statements for in the
        /// driver shim. Spaces in product names become underscores
        /// in module names per Swift's normalization (e.g.,
        /// "Linter Primitives" → "Linter_Primitives").
        public let imports: [Swift.String]

        public init(
            path: Swift.String,
            packageName: Swift.String,
            product: Swift.String,
            imports: [Swift.String]
        ) {
            self.path = path
            self.packageName = packageName
            self.product = product
            self.imports = imports
        }
    }
}
