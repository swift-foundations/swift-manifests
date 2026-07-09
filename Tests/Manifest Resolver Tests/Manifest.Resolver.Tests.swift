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

import File_System
import Testing
import URI_Standard

@testable import Manifest_Resolver

@Suite("Manifest.Resolver")
struct ManifestResolverTests {
    /// A minimal `C` shape for testing the resolver's fold semantics
    /// without depending on a real lint configuration type.
    struct Configuration: Sendable, Equatable {
        let value: Swift.Int
    }

    @Test
    func `Non-existent package root falls back to defaultConfiguration`() throws {
        let result = try Manifest.Resolver<Swift.Int, Configuration>.resolve(
            consumerPackageRoot: "/nonexistent/path/that/should/not/exist",
            filename: "Lint.swift",
            dependencies: [],
            defaultConfiguration: { Configuration(value: 999) },
            buildConfiguration: { manifest, _ in
                Configuration(value: manifest)
            }
        )
        #expect(result == Configuration(value: 999))
    }

    // MARK: - fetch() — file:// scheme

    @Test
    func `fetch reads file:// URI content from an existing file`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "swift-manifests-resolver-test-",
            key: "fetchReadsFileURIContent",
            suffix: ".txt"
        )
        defer { try? File.System.Delete.delete(at: path) }
        let content = "// parent: file:///nowhere\nlet manifest: Int = 42\n"
        try File(path).write.atomic(content)

        let uri = try URI("file://" + path.description)
        var memo: [URI: Swift.String] = [:]
        let read = try Manifest.Resolver<Swift.Int, Configuration>.fetch(uri, memo: &memo)
        #expect(read == content)
    }

    @Test
    func `fetch throws parentFetchFailed for a non-existent file:// URI`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "swift-manifests-resolver-test-",
            key: "fetchThrowsForMissingFile-DOES-NOT-EXIST",
            suffix: ".txt"
        )
        // Best-effort cleanup in case a prior test run left a stray.
        try? File.System.Delete.delete(at: path)

        let uri = try URI("file://" + path.description)
        var memo: [URI: Swift.String] = [:]
        do throws(Manifest.Resolver<Swift.Int, Configuration>.Error) {
            _ = try Manifest.Resolver<Swift.Int, Configuration>.fetch(uri, memo: &memo)
            Issue.record("expected fetch to throw .parentFetchFailed for missing file://")
        } catch {
            switch error {
            case .parentFetchFailed(let url, _, _):
                #expect(url == uri)

            default:
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    @Test
    func `fetch memoizes successive calls for the same URI (per-process)`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "swift-manifests-resolver-test-",
            key: "fetchMemoizesSameURI",
            suffix: ".txt"
        )
        defer { try? File.System.Delete.delete(at: path) }
        let content = "let manifest: Int = 7\n"
        try File(path).write.atomic(content)

        let uri = try URI("file://" + path.description)
        var memo: [URI: Swift.String] = [:]

        // First fetch — populates memo.
        let first = try Manifest.Resolver<Swift.Int, Configuration>.fetch(uri, memo: &memo)
        #expect(first == content)
        #expect(memo[uri] == content)
        #expect(memo.count == 1)

        // Mutate the file on disk; a non-memoized re-read would observe
        // the new bytes.
        let mutated = "let manifest: Int = 99\n"
        try File(path).write.atomic(mutated)

        // Second fetch — must return memoized content, NOT the new bytes.
        let second = try Manifest.Resolver<Swift.Int, Configuration>.fetch(uri, memo: &memo)
        #expect(second == content)
        #expect(memo.count == 1)
    }
}
