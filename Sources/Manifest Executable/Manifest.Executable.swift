internal import File_System
public import Manifest
internal import Process

extension Manifest {

    public enum Executable: Swift.Sendable {}
}

extension Manifest.Executable {

    public static func dispatch(
        configuration: Configuration
    ) throws(Self.Error) -> Swift.Int32 {
        try Self.Materializer.materialize(configuration: configuration)

        let invocation: [Swift.String] =
            [
                "swift", "run", "--package-path", configuration.evalRoot.string,
                configuration.executableName,
            ]
            + configuration.arguments
        let spawnConfiguration = Process.Spawn.Configuration(
            executable: "/usr/bin/env",
            arguments: invocation,
            environment: configuration.environment
        )
        let status: Process.Status
        do throws(Process.Error) {
            status = try Process.Spawn.run(spawnConfiguration).status
        } catch {
            throw .spawnFailed(
                consumerPackageRoot: configuration.consumerPackageRoot,
                description: "\(error)"
            )
        }
        switch status {
        case .exited(let code): return code
        case .signaled(let s): return -s
        case .stopped(let s): return -s
        }
    }
}
