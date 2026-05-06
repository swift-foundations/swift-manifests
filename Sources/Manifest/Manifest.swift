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

/// Generic Swift-DSL manifest loader.
///
/// `Manifest` lifts the Package.swift loader pattern into a reusable
/// primitive: parameterized over a manifest filename, a typed-value
/// name declared at file scope of that manifest, a JSON-serializable
/// output type, and the dependencies the manifest is compiled
/// against.
///
/// ## Usage
///
/// ```swift
/// // In a consumer's Lint.swift:
/// //   let manifest: LintManifest = LintManifest(...)
///
/// let manifest = try Manifest.load(
///     LintManifest.self,
///     from: packageRoot,
///     named: "Lint.swift",
///     valueName: "manifest",
///     dependencies: [
///         .init(path: "...", product: "Linter Primitives",
///               packageName: "swift-linter-primitives",
///               imports: ["Linter_Primitives"])
///     ]
/// )
/// ```
///
/// ## Architecture
///
/// `Manifest` sits at L3-Foundations alongside ``Process`` and
/// ``File.System``. It composes:
///
/// - ``Process`` — to spawn the swift driver subprocess
///   (Foundation-clean per ``swift-process``).
/// - ``JSON`` — to encode/decode the typed value as JSON across
///   the parent/child boundary.
/// - ``File.System`` — to materialize the temporary eval project
///   on disk and read back the captured output.
/// - ``Environment`` — to read `SWIFT_PATH` for toolchain selection
///   (falls back to `/usr/bin/env swift`).
///
/// ## Foundation-clean
///
/// Neither ``Manifest`` nor the auto-generated driver shim imports
/// Apple's `Foundation` framework. The shim uses
/// ``JSON/jsonString(pretty:sortKeys:)`` for serialization and
/// ``File.write.atomic(_:options:)`` for output — both Foundation-
/// independent.
public enum Manifest: Sendable {}
