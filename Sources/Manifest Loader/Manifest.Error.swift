public import JSON
public import Manifest
public import Process

extension Manifest {

    public enum Error: Swift.Error, Sendable {

        case invalidInput(reason: Swift.String)

        case projectMaterialization(reason: Swift.String)

        case driverProcess(Process.Error)

        case driverNonZeroStatus(Process.Status)

        case outputCaptureFailed(reason: Swift.String)

        case decoding(JSON.Error)
    }
}
