//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation
import Promises

enum EventTransportError: Error {
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


public protocol EventTransport {
    func connect(delegate: EventTransportDelegate) -> Promise<Void>;
    func sendEvent(event: SendableEvent);
}

public protocol EventTransportDelegate {
    func receiveEvent(event: ReceivableEvent);
}
