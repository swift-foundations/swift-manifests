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
public import Package_Primitives
public import SPM_Standard

extension Manifest.Executable {
    /// Parameters for ``Manifest/Executable/dispatch(configuration:)``.
    ///
    /// The materialize-and-spawn pipeline reads the fields in this
    /// order: directory layout (``consumerPackageRoot``,
    /// ``consumerSourcePath``, ``evalRoot``, ``executableName``);
    /// generated-Package.swift content (``dependencies``,
    /// ``platforms``, ``swiftLanguageModes``, ``ecosystemSettings``,
    /// ``toolsVersion``); spawn parameters (``arguments``,
    /// ``environment``).
    public struct Configuration: Swift.Sendable {
        /// The consumer package's root directory.
        ///
        /// Used to compute the relative prefix that rewrites the
        /// consumer's `.package(path:)` declarations so they resolve
        /// from the materialized `Package.swift`'s vantage. The
        /// generic requires ``evalRoot`` to be a descendant of this
        /// root; non-descendant configurations fall back to `.`
        /// (consumer's own directory) defensively.
        public let consumerPackageRoot: File.Path

        /// The consumer-authored source file copied into the eval
        /// target as `main.swift`.
        ///
        /// Typically `<consumerPackageRoot>/<filename>`, such as
        /// `<root>/Lint.swift`. The file is read once; its bytes
        /// become the materialized eval target's entry point.
        public let consumerSourcePath: File.Path

        /// The materialized eval project's root directory.
        ///
        /// Conventional location is a gitignored cache directory
        /// under the consumer's root, such as
        /// `<consumerPackageRoot>/.swift-lint/eval/`. MUST be a
        /// descendant of ``consumerPackageRoot``.
        public let evalRoot: File.Path

        /// The name of the executable target in the materialized
        /// `Package.swift` and the spawn invocation `swift run
        /// --package-path <evalRoot> <executableName>`.
        ///
        /// Also names the `Sources/<executableName>/` directory that
        /// holds `main.swift`. Constrained to a valid SwiftPM
        /// target-name shape (path-component validation rejects
        /// names containing `/` or `NUL`).
        public let executableName: Swift.String

        /// Consumer-extracted dependencies to fold into the eval
        /// target's `Package.swift`.
        public let dependencies: [Package.Dependency]

        /// Platform declarations rendered inside the generated
        /// `Package(platforms:)` array.
        ///
        /// Each entry is a raw PackageDescription token like
        /// `".macOS(.v27)"`. The generic emits them verbatim;
        /// validation is consumer-side.
        public let platforms: [Swift.String]

        /// `swiftLanguageModes` tokens rendered into the generated
        /// `Package(swiftLanguageModes:)` array.
        ///
        /// Each entry is a raw PackageDescription token like `".v6"`.
        public let swiftLanguageModes: [Swift.String]

        /// Optional `SwiftSetting` block appended to the generated
        /// `Package.swift` after the `Package` literal.
        ///
        /// When non-nil and non-empty, the generic emits a trailing
        /// for-loop applying these settings to every non-system /
        /// non-binary / non-plugin / non-macro target. Each entry is
        /// a raw `SwiftSetting` constructor expression like
        /// `".enableUpcomingFeature(\"ExistentialAny\")"`. When nil
        /// or empty, no trailing block is rendered.
        public let ecosystemSettings: [Swift.String]?

        /// Arguments forwarded to the spawned executable.
        ///
        /// Passed verbatim after `swift run --package-path
        /// <evalRoot> <executableName>` on the spawn command line.
        public let arguments: [Swift.String]

        /// Environment dictionary for the spawned process.
        ///
        /// `nil` (default) inherits the parent's environment.
        /// Non-`nil` replaces the parent's environment with the
        /// given dictionary — consumers wanting to add a variable
        /// to the inherited environment should snapshot the
        /// parent's environment first and amend the snapshot.
        public let environment: [Swift.String: Swift.String]?

        /// SwiftPM tools-version rendered into the generated
        /// `// swift-tools-version: ...` directive.
        ///
        /// Raw token like `"6.3.1"`. Consumer responsibility to
        /// supply a tools-version supported by the spawning Swift
        /// toolchain.
        public let toolsVersion: Swift.String

        public init(
            consumerPackageRoot: File.Path,
            consumerSourcePath: File.Path,
            evalRoot: File.Path,
            executableName: Swift.String,
            dependencies: [Package.Dependency],
            platforms: [Swift.String],
            swiftLanguageModes: [Swift.String],
            ecosystemSettings: [Swift.String]? = nil,
            arguments: [Swift.String] = [],
            environment: [Swift.String: Swift.String]? = nil,
            toolsVersion: Swift.String
        ) {
            self.consumerPackageRoot = consumerPackageRoot
            self.consumerSourcePath = consumerSourcePath
            self.evalRoot = evalRoot
            self.executableName = executableName
            self.dependencies = dependencies
            self.platforms = platforms
            self.swiftLanguageModes = swiftLanguageModes
            self.ecosystemSettings = ecosystemSettings
            self.arguments = arguments
            self.environment = environment
            self.toolsVersion = toolsVersion
        }
    }
}
