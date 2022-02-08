import Foundation
import Promises

public enum EventTransportError: Error {
    // Throw when user is not authorized
    case unauthorized

    // Throw when transport fails to connect
    case connectionError
    
    // Throw when you have no idea what happened...
    case unexpected(reason: String)
}

extension EventTransportError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unauthorized:
            return "User is unauthorized to use the transport"
        case .connectionError:
            return "Failed to connect with the remote side"
        case .unexpected(reason: let reason):
            return "Encountered unexpected error: \(reason)"
        }
    }
}


/// Protocol defining a behaviour of an events' transport used for exchaning messages
/// between client and the server.
public protocol EventTransport {
    func connect(delegate: EventTransportDelegate) -> Promise<Void>
    func disconnect()
    func send(event: SendableEvent)
}

public protocol EventTransportDelegate: AnyObject {
    func didReceive(event: ReceivableEvent)
    func didReceive(error: EventTransportError)
}
