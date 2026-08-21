import File_System
import Testing

@testable import Manifest_Loader

extension Manifest {
    @Suite struct Test {
        @Suite(.serialized) struct Integration {}
    }
}

extension Manifest.Test.Integration {

    #if !os(Windows)
        @Test
        func `driver shim round-trips Int through swift run subprocess`() throws {
            let testFilePath: Swift.String = #filePath
            let manifestPackageRoot = Self._directoryAncestor(of: testFilePath, levels: 3)
            let foundationsRoot = Self._directoryAncestor(of: manifestPackageRoot, levels: 1)

            guard
                let jsonPackagePath = Self._firstReadableDirectory([
                    manifestPackageRoot + "/.build/checkouts/swift-json",
                    foundationsRoot + "/swift-json",
                ]),
                let fileSystemPackagePath = Self._firstReadableDirectory([
                    manifestPackageRoot + "/.build/checkouts/swift-file-system",
                    foundationsRoot + "/swift-file-system",
                ])
            else {

                Issue.record(
                    """
                    Could not locate the swift-json / swift-file-system checkouts. \
                    Looked under \(manifestPackageRoot)/.build/checkouts and \
                    \(foundationsRoot). Run `swift build` once so SwiftPM resolves \
                    dependencies, or clone the packages as siblings.
                    """
                )
                return
            }

            let fixtureRoot = "/tmp/swift-manifest-e2e-\(Swift.UInt64.random(in: .min ... .max))"
            try Manifest._createDirectoryRecursive(at: fixtureRoot)

            try Manifest._writeAtomic(
                "let manifest: Int = 42\n",
                to: fixtureRoot + "/Lint.swift"
            )

            let result = try Manifest.load(
                Int.self,
                from: fixtureRoot,
                named: "Lint.swift",
                binding: "manifest",
                dependencies: [
                    Manifest.Dependency(
                        path: jsonPackagePath,
                        name: "swift-json",
                        product: "JSON",
                        imports: []
                    ),
                    Manifest.Dependency(
                        path: fileSystemPackagePath,
                        name: "swift-file-system",
                        product: "File System",
                        imports: []
                    ),
                ]
            )

            #expect(result == 42)
        }
    #endif

    private static func _firstReadableDirectory(
        _ candidates: [Swift.String]
    ) -> Swift.String? {
        for candidate in candidates {
            guard let directory = try? File.Directory(validating: candidate) else { continue }
            guard (try? directory.entries()) != nil else { continue }
            return candidate
        }
        return nil
    }

    private static func _directoryAncestor(
        of path: Swift.String,
        levels: Int
    ) -> Swift.String {
        var current = path
        for _ in 0..<levels {
            guard let lastSlash = current.lastIndex(of: "/") else { return current }
            current = Swift.String(current[..<lastSlash])
        }
        return current
    }
}
