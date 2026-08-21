extension Manifest.NestedPackage {

    public enum Error: Swift.Error, Swift.Sendable {
        case spawnFailed(
            consumerPackageRoot: Swift.String,
            description: Swift.String
        )
        case staleResolutionInvalidationFailed(
            consumerPackageRoot: Swift.String,
            description: Swift.String
        )
    }
}
