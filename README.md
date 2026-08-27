# swift-manifests

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Swift-DSL manifest loader and chain resolver for tools that take their
configuration as a typed Swift value rather than YAML or JSON.
Compiles a consumer's manifest file (`Lint.swift`, `Format.swift`,
etc.) via SwiftPM, captures the declared typed value, and folds parent
manifests into a layered configuration.

## Quick Start

Loading a single manifest as a typed value:

```swift
import Manifest_Loader

let configuration = Manifest.Configuration(
    root: packageRoot,
    filename: "Lint.swift",
    binding: "manifest",
    dependencies: [
        Manifest.Dependency(
            path: "../swift-linter",
            name: "swift-linter",
            product: "Linter",
            imports: ["Linter"]
        )
    ]
)

let manifest = try Manifest.load(
    Lint.Manifest.self,
    configuration: configuration
)
```

`Manifest.load` materializes a temporary eval project at
`<root>/.swift-manifest/<filename>/`, runs `swift run --package-path`
against it, captures the declared typed value as JSON, and decodes it
back to the requested type. The consumer's manifest file MUST declare a
file-scope `let <binding>: Output` whose right-hand side is a
fully-formed value.

Resolving a manifest with a parent chain:

```swift
import Manifest_Resolver

let configuration = try Manifest.Resolver<Lint.Manifest, Lint.Configuration>
    .resolve(
        consumerPackageRoot: packageRoot,
        manifestFilename: "Lint.swift",
        dependencies: dependencies,
        defaultConfiguration: { .empty },
        buildConfiguration: { manifest, parent in
            Lint.Configuration(
                inheriting: parent,
                rules: { },
                excluded: manifest.excludedPaths.map { $0.description }
            )
        }
    )
```

The resolver scans the consumer's manifest for a leading
`// parent: <URL>` directive, walks the chain (cycle-tracked,
depth-capped, per-process fetch-memoized), and folds parent manifests
into a layered configuration via the consumer-supplied
`buildConfiguration` closure.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-manifests.git", branch: "main"),
]
```

> Pre-1.0: no version tags yet. APIs may change; pin a commit for reproducible builds.

```swift
.target(
    name: "YourTool",
    dependencies: [
        .product(name: "Manifest Loader", package: "swift-manifests"),
        .product(name: "Manifest Resolver", package: "swift-manifests"),
    ]
)
```

Depend on `Manifest Loader` alone if your tool only needs single-file
typed-value extraction. Add `Manifest Resolver` when you need the
parent-chain composition layer on top.

## Two products

| Product | What it does | When to use |
|---|---|---|
| `Manifest Loader` | Compiles one manifest file via SwiftPM and decodes its declared `let`-bound typed value | Tools that take a single config file with no inheritance story |
| `Manifest Resolver` | Adds parent-chain resolution on top of `Manifest Loader` — scans for `// parent:` directives, fetches each ancestor, folds parent-first into a layered configuration | Tools with shared canonical configurations distributed to many consumers |

The resolver re-exports the loader; consumers needing both can import
`Manifest Resolver` alone.

## `Manifest.Resolver<M, C>`

The resolver is generic over two types:

- **`M`** — the *manifest* type each layer in the chain decodes to. This
  is the `JSON.Serializable` value the consumer's manifest file
  declares (e.g., `Lint.Manifest`).
- **`C`** — the *configuration* type the resolver folds the chain into
  (e.g., `Lint.Configuration`). The consumer supplies the
  `buildConfiguration` closure that lifts an `M` plus the accumulated
  parent `C?` into the next layered `C`.

`M` is the wire-shape; `C` is the runtime shape. The split lets
consumers compose layered semantics — "later layer wins per rule",
union of excluded paths, accumulated severity overrides — without
forcing every parent's wire-shape to know about layering.

```swift
public static func resolve(
    consumerPackageRoot: Swift.String,
    manifestFilename: Swift.String,
    dependencies: [Manifest.Dependency],
    defaultConfiguration: () -> C,
    buildConfiguration: (M, C?) -> C
) throws(Manifest.Resolver.Error) -> C
```

Failure modes partition cleanly:

- **Consumer manifest absent / load failure** — silently returns
  `defaultConfiguration()`.
- **No parent directive** — returns
  `buildConfiguration(consumerManifest, nil)`.
- **Parent chain failure** (fetch, cycle, depth, eval) — throws
  `Manifest.Resolver.Error`. The caller decides whether to warn and
  fall back to consumer-only or to default.

## Nested-package shape

`Manifest.NestedPackage.detect(at:)` and
`.dispatch(at:arguments:)` provide a parallel discovery path for tools
where the consumer authors a nested SwiftPM package (e.g., a `Lint/`
directory containing its own `Package.swift` + executable target)
rather than a single file. Detection returns `true` when both the
nested directory and its `Package.swift` are accessible; `dispatch`
delegates execution to the nested package's executable via
`swift run --package-path`.

The single-file path on `Manifest.Resolver` is unchanged; nested-package
detection is additive. Tools detect first, dispatch when present, and
fall through to the resolver for single-file consumers.

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
