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

// Manifests Test Support
//
// Re-exports `Manifest Loader`, `Manifest Resolver`, and the upstream
// `Manifest Primitives Test Support` for cross-package consumers.
// Test-factory extension inits and shared fixture types (e.g.,
// `Manifest.Resolver` mock builders, `NestedPackage` dispatch
// fixtures) will land here as the test corpus grows; the structural
// spine ([MOD-024]) lands first so consumers can wire against
// `import Manifests_Test_Support` from day one.
