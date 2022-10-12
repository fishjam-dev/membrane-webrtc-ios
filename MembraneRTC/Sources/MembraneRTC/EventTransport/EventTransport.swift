import Foundation
import Promises

public enum EventTransportError: Error {
    /// Thrown when user is not authorized to join the session
    case unauthorized

    /// Thrown when transport fails to connect
    case connectionError

    /// Thrown when  the transport encountered unknown/unspecified error
    case unexpected(reason: String)
}

extension EventTransportError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unauthorized:
            return "User is unauthorized to use the transport"
        case .connectionError:
            return "Failed to connect with the remote side"
        case .unexpected(let reason):
            return "Encountered unexpected error: \(reason)"
        }
    }
}

/// Protocol defining a behaviour of an events' transport used for exchaning messages
/// between client and the server.
///
///  An implementation of such transport should take an `EventTransportDelegate` as its argument
///  and pass received and parsed messages directly to the delegate.
public protocol EventTransport {
    func connect(delegate: EventTransportDelegate) -> Promise<Void>
    func disconnect()
    func send(event: SendableEvent)
}

/// Protocol for a delegate listening for messages received by the `EventTransport`
public protocol EventTransportDelegate: AnyObject {
    func didReceive(event: ReceivableEvent)
    func didReceive(error: EventTransportError)
}
