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

internal import Environment
internal import File_System
public import JSON
public import Manifest_Primitives
internal import Process
internal import Strings

extension Manifest {
    /// Compile and run a Swift-DSL manifest, returning the
    /// declared typed value as `Output`.
    ///
    /// Materializes a temporary eval project at
    /// `\(root)/.swift-manifest/\(filename)/` containing a
    /// generated `Package.swift`, a generated driver `Driver.swift`,
    /// and a copy of the consumer's manifest file. Invokes
    /// `swift run --package-path <eval>` via ``Process/Spawn`` and
    /// captures the JSON-serialized typed value from a known output
    /// path.
    ///
    /// Manifest contract: the consumer's file MUST declare a
    /// file-scope `let \(binding): Output` whose right-hand side
    /// is a fully-formed `Output` value.
    ///
    /// - Parameters:
    ///   - output: the typed-value type. Constraint:
    ///     ``JSON.Serializable``.
    ///   - configuration: ``Configuration`` describing manifest
    ///     location, target value name, and dependencies.
    /// - Returns: the typed value declared in the manifest.
    /// - Throws: ``Manifest/Error`` on materialization, driver,
    ///   or decoding failure.
    public static func load<Output: JSON.Serializable>(
        _ output: Output.Type,
        configuration: Configuration
    ) throws(Manifest.Error) -> Output {
        // 1. Validate inputs (existence + path-conversion fitness).
        let evalRoot = configuration.root
            + "/.swift-manifest/" + configuration.filename
        let outputPath = evalRoot + "/.output.json"
        let manifestSourcePath = configuration.root + "/" + configuration.filename

        // 2. Materialize the eval project on disk.
        try _materialize(
            evalRoot: evalRoot,
            outputPath: outputPath,
            manifestSourcePath: manifestSourcePath,
            configuration: configuration
        )

        // 3. Spawn the driver subprocess.
        try _runDriver(evalRoot: evalRoot, outputPath: outputPath, configuration: configuration)

        // 4. Read captured output.
        let captured: Swift.String = try _readCapturedOutput(at: outputPath)

        // 5. Decode JSON into Output.
        do throws(JSON.Error) {
            let json = try JSON.parse(captured)
            return try Output(json: json)
        } catch {
            throw .decoding(error)
        }
    }

    /// Convenience overload aggregating individual parameters.
    public static func load<Output: JSON.Serializable>(
        _ output: Output.Type,
        from root: Swift.String,
        named filename: Swift.String,
        binding: Swift.String,
        dependencies: [Dependency],
        toolchain: Swift.String? = nil
    ) throws(Manifest.Error) -> Output {
        try load(
            output,
            configuration: Configuration(
                root: root,
                filename: filename,
                binding: binding,
                dependencies: dependencies,
                toolchain: toolchain
            )
        )
    }
}

// MARK: - Materialization

extension Manifest {
    @usableFromInline
    internal static func _materialize(
        evalRoot: Swift.String,
        outputPath: Swift.String,
        manifestSourcePath: Swift.String,
        configuration: Configuration
    ) throws(Manifest.Error) {
        let driverDir = evalRoot + "/Sources/Driver"

        // Create directory tree.
        try _createDirectoryRecursive(at: driverDir)

        // Generate Package.swift.
        let packageSwift = _renderPackageSwift(
            evalRoot: evalRoot,
            configuration: configuration
        )
        try _writeAtomic(packageSwift, to: evalRoot + "/Package.swift")

        // Generate driver Driver.swift.
        //
        // The shim uses `@main` on `enum __SwiftManifestDriver`. Swift 6.x
        // rejects `@main` in a module that contains top-level code; a file
        // literally named `main.swift` is implicitly top-level by filename.
        // Writing the shim to `Driver.swift` keeps `@main` valid.
        let driverSwift = _renderDriverMain(
            binding: configuration.binding,
            imports: configuration.dependencies.flatMap(\.imports)
        )
        try _writeAtomic(driverSwift, to: driverDir + "/Driver.swift")

        // Copy the consumer's manifest into the driver target.
        let manifestBytes: Swift.String = try _readEntireFile(at: manifestSourcePath)
        try _writeAtomic(manifestBytes, to: driverDir + "/" + configuration.filename)
    }

    @usableFromInline
    internal static func _createDirectoryRecursive(at absolutePath: Swift.String)
        throws(Manifest.Error)
    {
        let path: File.Path
        do throws(Paths.Path.Error) {
            path = try File.Path(absolutePath)
        } catch {
            throw .projectMaterialization(reason: "invalid path \(absolutePath): \(error)")
        }
        do throws(File.System.Create.Directory.Error) {
            try File.Directory(path).create.recursive()
        } catch {
            throw .projectMaterialization(reason: "create directory \(absolutePath): \(error)")
        }
    }

    @usableFromInline
    internal static func _writeAtomic(
        _ contents: Swift.String,
        to absolutePath: Swift.String
    ) throws(Manifest.Error) {
        let path: File.Path
        do throws(Paths.Path.Error) {
            path = try File.Path(absolutePath)
        } catch {
            throw .projectMaterialization(reason: "invalid path \(absolutePath): \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try File(path).write.atomic(contents)
        } catch {
            throw .projectMaterialization(reason: "write \(absolutePath): \(error)")
        }
    }

    @usableFromInline
    internal static func _readEntireFile(at absolutePath: Swift.String)
        throws(Manifest.Error) -> Swift.String
    {
        let path: File.Path
        do throws(Paths.Path.Error) {
            path = try File.Path(absolutePath)
        } catch {
            throw .outputCaptureFailed(reason: "invalid path \(absolutePath): \(error)")
        }
        let bytes: [Byte]
        do throws(File.System.Read.Full.Error) {
            bytes = try File(path).read.full { (span: Span<Byte>) -> [Byte] in
                var array: [Byte] = []
                array.reserveCapacity(span.count)
                for i in 0..<span.count {
                    array.append(span[i])
                }
                return array
            }
        } catch {
            throw .outputCaptureFailed(reason: "read \(absolutePath): \(error)")
        }
        return Swift.String(decoding: bytes, as: UTF8.self)
    }

    @usableFromInline
    internal static func _readCapturedOutput(at absolutePath: Swift.String)
        throws(Manifest.Error) -> Swift.String
    {
        try _readEntireFile(at: absolutePath)
    }
}

// MARK: - Source Rendering

extension Manifest {
    @usableFromInline
    internal static func _renderPackageSwift(
        evalRoot: Swift.String,
        configuration: Configuration
    ) -> Swift.String {
        var lines: [Swift.String] = [
            "// swift-tools-version: 6.3.1",
            "// AUTO-GENERATED by swift-manifest. DO NOT EDIT.",
            "import PackageDescription",
            "",
            "let package = Package(",
            "    name: \"swift-manifest-driver\",",
            "    platforms: [",
            "        .macOS(.v26),",
            "        .iOS(.v26),",
            "        .tvOS(.v26),",
            "        .watchOS(.v26),",
            "        .visionOS(.v26)",
            "    ],",
            "    dependencies: ["
        ]

        for dep in configuration.dependencies {
            lines.append("        .package(path: \"\(dep.path)\"),")
        }

        lines.append(contentsOf: [
            "    ],",
            "    targets: [",
            "        .executableTarget(",
            "            name: \"Driver\",",
            "            dependencies: ["
        ])

        for dep in configuration.dependencies {
            lines.append(
                "                .product(name: \"\(dep.product)\", package: \"\(dep.name)\"),"
            )
        }

        lines.append(contentsOf: [
            "            ]",
            "        )",
            "    ],",
            "    swiftLanguageModes: [.v6]",
            ")",
            ""
        ])

        return lines.joined(separator: "\n")
    }

    @usableFromInline
    internal static func _renderDriverMain(
        binding: Swift.String,
        imports: [Swift.String]
    ) -> Swift.String {
        var lines: [Swift.String] = [
            "// AUTO-GENERATED by swift-manifest. DO NOT EDIT.",
            "import JSON",
            "import File_System"
        ]
        for module in imports {
            lines.append("import \(module)")
        }
        lines.append(contentsOf: [
            "",
            "@main",
            "enum __SwiftManifestDriver {",
            "    static func main() throws {",
            "        let outputPath = CommandLine.arguments[1]",
            "        let json = \(binding).jsonString()",
            "        let path = try File.Path(outputPath)",
            "        try File(path).write.atomic(json)",
            "    }",
            "}",
            ""
        ])
        return lines.joined(separator: "\n")
    }
}

// MARK: - Driver Spawn

extension Manifest {
    @usableFromInline
    internal static func _runDriver(
        evalRoot: Swift.String,
        outputPath: Swift.String,
        configuration: Configuration
    ) throws(Manifest.Error) {
        let executable: Swift.String
        let prefixArguments: [Swift.String]
        if let toolchain = configuration.toolchain {
            executable = toolchain
            prefixArguments = []
        } else {
            executable = "/usr/bin/env"
            prefixArguments = ["swift"]
        }

        let arguments: [Swift.String] =
            prefixArguments + [
                "run",
                "--package-path", evalRoot,
                "Driver",
                outputPath
            ]

        let status: Process.Status
        do throws(Process.Error) {
            status = try Process.Spawn.run(
                Process.Spawn.Configuration(
                    executable: executable,
                    arguments: arguments
                )
            ).status
        } catch {
            throw .driverProcess(error)
        }

        guard status == .exited(code: 0) else {
            throw .driverNonZeroStatus(status)
        }
    }
}
