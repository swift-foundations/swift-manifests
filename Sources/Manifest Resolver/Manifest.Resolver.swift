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

internal import File_System
public import JSON
internal import Manifest_Loader
public import Manifest_Primitives
internal import Process
internal import URI_Standard

extension Manifest {
    /// Resolves a manifest's configuration by walking its parent
    /// chain.
    ///
    /// `Manifest.Resolver` is generic over the manifest type `M`
    /// (which `Manifest_Loader` deserializes from each parent's
    /// captured JSON) and the configuration type `C` (the runtime
    /// shape the consumer composes via `buildConfiguration`).
    ///
    /// The resolver:
    /// 1. Loads the consumer's manifest via ``Manifest_Loader/Manifest/load(_:configuration:)``.
    /// 2. Scans the manifest's source file for a leading
    ///    `// parent: <URL>` directive via
    ///    ``Manifest_Primitives/Manifest/Parent/scan(in:)``.
    /// 3. Walks the chain (cycle-tracked, depth-capped, per-process
    ///    fetch-memoized).
    /// 4. Folds parent manifests parent-first into a layered `C`,
    ///    then layers the consumer's manifest on top via
    ///    `buildConfiguration`.
    ///
    /// Failures are partitioned:
    /// - Consumer manifest absent / load failure → silently returns
    ///   `defaultConfiguration()`.
    /// - No parent directive → returns
    ///   `buildConfiguration(consumerManifest, nil)`.
    /// - Parent chain failure (fetch, cycle, depth, eval) → throws
    ///   ``Manifest/Resolver/Error``; the caller decides whether to
    ///   warn + fall back to consumer-only or to default.
    public enum Resolver<M: JSON.Serializable, C>: Swift.Sendable {}
}

extension Manifest.Resolver {
    /// Resolve the configuration for `consumerPackageRoot`.
    ///
    /// - Parameters:
    ///   - consumerPackageRoot: filesystem path to the package whose
    ///     manifest is being resolved.
    ///   - filename: the manifest's filename inside that
    ///     package root (e.g., `"Lint.swift"`).
    ///   - dependencies: the SwiftPM dependencies the manifest's
    ///     driver shim compiles against (passed verbatim to
    ///     ``Manifest_Loader/Manifest/load(_:configuration:)`` for
    ///     both consumer and parent evaluations).
    ///   - defaultConfiguration: the fallback when the consumer's
    ///     manifest is absent or fails to load.
    ///   - buildConfiguration: lifts a loaded `M` plus the
    ///     accumulated parent `C?` into the next layered `C`. Called
    ///     once per parent layer (parent-first), then once with the
    ///     consumer's manifest at the end.
    ///
    /// - Returns: a `C` constructed by folding the parent chain
    ///   parent-first then layering the consumer on top. When no
    ///   parent directive is present the result is
    ///   `buildConfiguration(consumerManifest, nil)`.
    ///
    /// - Throws: ``Manifest/Resolver/Error`` on parent-chain failure.
    public static func resolve(
        consumerPackageRoot: Swift.String,
        filename: Swift.String,
        dependencies: [Manifest.Dependency],
        defaultConfiguration: () -> C,
        buildConfiguration: (M, C?) -> C
    ) throws(Self.Error) -> C {
        // Step 1: load consumer manifest. Silent fall-back to defaults on any failure.
        let consumerManifest: M
        do {
            consumerManifest = try Manifest.load(
                M.self,
                from: consumerPackageRoot,
                named: filename,
                binding: "manifest",
                dependencies: dependencies
            )
        } catch {
            return defaultConfiguration()
        }

        // Step 2: scan the consumer's source for `// parent: <URL>`. Best-effort
        // read; absence of the source file is indistinguishable from absence of
        // a directive — both produce single-tier results.
        let consumerSource = readSource(
            at: consumerPackageRoot + "/" + filename
        )

        // Step 3: try to extract a parent URI from the source.
        guard
            let consumerSource,
            let firstParentURI = parseParent(in: consumerSource)
        else {
            return buildConfiguration(consumerManifest, nil)
        }

        // Step 4: walk the chain. Throws on cycle / depth / fetch / eval failure.
        let parentChain = try walk(
            startingAt: firstParentURI,
            filename: filename,
            dependencies: dependencies
        )

        // Step 5: fold parents (parent-first), layer consumer on top.
        var current: C? = nil
        for parentManifest in parentChain {
            current = buildConfiguration(parentManifest, current)
        }
        return buildConfiguration(consumerManifest, current)
    }
}

// MARK: - Source reading

extension Manifest.Resolver {
    /// Read a manifest source file's bytes as a UTF-8 string.
    /// Returns `nil` on any I/O failure — the caller treats absent
    /// content the same as absent parent directive.
    @inline(__always)
    private static func readSource(at path: Swift.String) -> Swift.String? {
        do {
            let filePath = try File.Path(path)
            let bytes: [Swift.UInt8] = try File(filePath).read.full {
                (span: Span<Swift.UInt8>) -> [Swift.UInt8] in
                var array: [Swift.UInt8] = []
                array.reserveCapacity(span.count)
                for i in 0..<span.count { array.append(span[i]) }
                return array
            }
            return Swift.String(decoding: bytes, as: UTF8.self)
        } catch {
            return nil
        }
    }

    /// Parse the first `// parent: <URL>` directive from `source`
    /// and convert the URL bytes to a typed `URI`. Validates the
    /// scheme prefix — only `http://`, `https://`, and `file://`
    /// are accepted.
    @inline(__always)
    private static func parseParent(
        in source: Swift.String
    ) -> URI? {
        guard let urlBytes = Manifest.Parent.scan(in: source) else {
            return nil
        }
        guard
            urlBytes.starts(with: schemePrefixHTTP)
            || urlBytes.starts(with: schemePrefixHTTPS)
            || urlBytes.starts(with: schemePrefixFile)
        else { return nil }
        let urlString = Swift.String(decoding: urlBytes, as: UTF8.self)
        return try? URI(urlString)
    }

}

// File-scope so the constants compile inside a generic extension —
// Swift forbids static stored properties on generic types.
private let schemePrefixHTTP:  [Swift.UInt8] = Swift.Array("http://".utf8)
private let schemePrefixHTTPS: [Swift.UInt8] = Swift.Array("https://".utf8)
private let schemePrefixFile:  [Swift.UInt8] = Swift.Array("file://".utf8)

// MARK: - Chain walk

extension Manifest.Resolver {
    /// Walk the parent chain starting at `rootURL`.
    ///
    /// Returns the chain in PARENT-FIRST order (root-most → tier
    /// closest to consumer). The consumer's own manifest is NOT
    /// part of this chain — the caller layers it on top.
    ///
    /// Cycle detection: visited URIs accumulate in a `Set<URI>` plus
    /// an order-preserving `[URI]` for diagnostics; revisit produces
    /// ``Manifest/Resolver/Error/parentChainCycle(visited:at:)``.
    /// Depth backstop at 16 produces
    /// ``Manifest/Resolver/Error/parentChainTooDeep(depth:)``.
    @inline(__always)
    internal static func walk(
        startingAt rootURL: URI,
        filename: Swift.String,
        dependencies: [Manifest.Dependency]
    ) throws(Self.Error) -> [M] {
        var visited: Set<URI> = []
        var visitedOrder: [URI] = []
        var memo: [URI: Swift.String] = [:]
        var chain: [M] = []
        var currentURI: URI? = rootURL
        var depth = 0

        while let uri = currentURI {
            if visited.contains(uri) {
                throw .parentChainCycle(visited: visitedOrder, at: uri)
            }
            visited.insert(uri)
            visitedOrder.append(uri)
            depth += 1
            if depth > 16 {
                throw .parentChainTooDeep(depth: depth)
            }
            let content = try fetch(uri, memo: &memo)
            let parentManifest = try evalParent(
                content: content,
                url: uri,
                filename: filename,
                dependencies: dependencies
            )
            chain.append(parentManifest)
            // Re-parse the same content for the next parent URI.
            if let nextBytes = Manifest.Parent.scan(in: content),
               nextBytes.starts(with: schemePrefixHTTP)
               || nextBytes.starts(with: schemePrefixHTTPS)
               || nextBytes.starts(with: schemePrefixFile)
            {
                let urlString = Swift.String(decoding: nextBytes, as: UTF8.self)
                currentURI = try? URI(urlString)
            } else {
                currentURI = nil
            }
        }

        chain.reverse()
        return chain
    }
}

// MARK: - URL fetch

extension Manifest.Resolver {
    /// Fetch the contents of a parent `URI`, memoizing within the
    /// passed-through dictionary.
    ///
    /// Two backends:
    /// - `file://<path>` — read the local file directly via
    ///   `File_System` using the URI's typed `path` accessor.
    /// - `http://`, `https://` — invoke `curl -fsSL <uri.value> -o
    ///   <temp>` via ``Process/Spawn/run(_:)``; read the temp file;
    ///   delete it.
    ///
    /// Memoization is per-process and keyed on the `URI`. Same URI
    /// fetched twice in one chain resolution = one curl invocation.
    @inline(__always)
    internal static func fetch(
        _ uri: URI,
        memo: inout [URI: Swift.String]
    ) throws(Self.Error) -> Swift.String {
        if let cached = memo[uri] {
            return cached
        }
        let content: Swift.String
        if uri.scheme?.value == "file" {
            content = try fetchFile(uri)
        } else {
            content = try fetchHTTP(uri)
        }
        memo[uri] = content
        return content
    }

    /// Read a `file://`-scheme `URI` by routing through the URI's
    /// typed `path` accessor (no manual scheme manipulation).
    @inline(__always)
    private static func fetchFile(
        _ uri: URI
    ) throws(Self.Error) -> Swift.String {
        guard let uriPath = uri.path else {
            throw .parentFetchFailed(
                url: uri,
                exitCode: -1,
                stderr: "URI has no path component"
            )
        }
        let pathString: Swift.String
        if uriPath.isAbsolute {
            pathString = "/" + uriPath.segments.joined(separator: "/")
        } else {
            pathString = uriPath.segments.joined(separator: "/")
        }
        do {
            let filePath = try File.Path(pathString)
            let bytes: [Swift.UInt8] = try File(filePath).read.full {
                (span: Span<Swift.UInt8>) -> [Swift.UInt8] in
                var array: [Swift.UInt8] = []
                array.reserveCapacity(span.count)
                for i in 0..<span.count { array.append(span[i]) }
                return array
            }
            return Swift.String(decoding: bytes, as: UTF8.self)
        } catch {
            throw .parentFetchFailed(url: uri, exitCode: -1, stderr: "\(error)")
        }
    }

    /// Fetch an `http://` or `https://` `URI` by spawning
    /// `curl -fsSL <uri.value> -o <temp>`, reading the temp file,
    /// then deleting it.
    @inline(__always)
    private static func fetchHTTP(
        _ uri: URI
    ) throws(Self.Error) -> Swift.String {
        let tempPath: File.Path
        do {
            tempPath = try File.Path.Temporary.deterministic(
                prefix: "swift-manifests-fetch-",
                key: uri.value,
                suffix: ".tmp"
            )
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: -1,
                stderr: "temp path: \(error)"
            )
        }

        let configuration = Process.Spawn.Configuration(
            executable: "/usr/bin/curl",
            arguments: ["-fsSL", uri.value, "-o", tempPath.description]
        )

        let status: Process.Status
        do {
            status = try Process.Spawn.run(configuration)
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: -1,
                stderr: "spawn: \(error)"
            )
        }

        guard case .exited(let code) = status, code == 0 else {
            let exitCode: Swift.Int32
            switch status {
            case .exited(let c): exitCode = c
            case .signaled(let s): exitCode = -s
            case .stopped(let s): exitCode = -s
            }
            throw .parentFetchFailed(
                url: uri,
                exitCode: exitCode,
                stderr: ""
            )
        }

        let content: Swift.String
        do {
            let bytes: [Swift.UInt8] = try File(tempPath).read.full {
                (span: Span<Swift.UInt8>) -> [Swift.UInt8] in
                var array: [Swift.UInt8] = []
                array.reserveCapacity(span.count)
                for i in 0..<span.count { array.append(span[i]) }
                return array
            }
            content = Swift.String(decoding: bytes, as: UTF8.self)
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: 0,
                stderr: "read temp: \(error)"
            )
        }

        // Best-effort cleanup; ignore errors.
        _ = try? Process.Spawn.run(
            Process.Spawn.Configuration(
                executable: "/bin/rm",
                arguments: ["-f", tempPath.description]
            )
        )

        return content
    }
}

// MARK: - Parent eval

extension Manifest.Resolver {
    /// Evaluate a fetched parent's manifest content as a typed `M`
    /// via ``Manifest_Loader/Manifest/load(_:configuration:)``.
    ///
    /// Materializes the content under
    /// `/tmp/swift-manifests-parent-eval-<sanitized-uri>/<filename>`,
    /// then invokes `Manifest.load` against that as a fresh package
    /// root. Each parent eval is a swift-build subprocess; only the
    /// FETCH step is memoized.
    @inline(__always)
    internal static func evalParent(
        content: Swift.String,
        url uri: URI,
        filename: Swift.String,
        dependencies: [Manifest.Dependency]
    ) throws(Self.Error) -> M {
        let tempDirectory: File.Path
        do {
            tempDirectory = try File.Path.Temporary.deterministic(
                prefix: "swift-manifests-parent-eval-",
                key: uri.value,
                suffix: ""
            )
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: 0,
                stderr: "temp dir: \(error)"
            )
        }
        let tempDirectoryString = tempDirectory.description
        let tempFilePathString = tempDirectoryString + "/" + filename

        // Best-effort mkdir -p; failure surfaces as the subsequent write failure.
        _ = try? Process.Spawn.run(
            Process.Spawn.Configuration(
                executable: "/bin/mkdir",
                arguments: ["-p", tempDirectoryString]
            )
        )

        do {
            let filePath = try File.Path(tempFilePathString)
            try File(filePath).write.atomic(content)
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: 0,
                stderr: "write temp \(filename): \(error)"
            )
        }

        do {
            return try Manifest.load(
                M.self,
                from: tempDirectoryString,
                named: filename,
                binding: "manifest",
                dependencies: dependencies
            )
        } catch {
            throw .parentFetchFailed(
                url: uri,
                exitCode: 0,
                stderr: "manifest.load: \(error)"
            )
        }
    }
}
