public import File_System
public import Manifest

extension Manifest.Executable {

    public enum Error: Swift.Error, Swift.Sendable {

        case readFailed(path: File.Path, description: Swift.String)

        case materializationFailed(reason: Swift.String)

        case spawnFailed(consumerPackageRoot: File.Path, description: Swift.String)
    }
}
