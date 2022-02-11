import Foundation
import SwiftPhoenixClient
import Promises

/// `EventTransport` implementation utilizing `Phoenix` socket and a channel.
class PhoenixTransport: EventTransport {
    enum ConnectionState {
        case uninitialized, connecting, connected, closed, error
    }
    
    /// Channel's topic
    let topic: String
    
    let socket: Socket
    var channel: Channel?
    var connectionState: ConnectionState = .uninitialized
    
    weak var delegate: EventTransportDelegate?
    
    
    let queue = DispatchQueue(label: "membrane.rtc.transport", qos: .background)
    
    init(url: String, topic: String) {
        self.topic = topic
        
        self.socket = Socket(endPoint: url, transport: { URLSessionTransport(url: $0)})
    }
    
    func connect(delegate: EventTransportDelegate) -> Promise<Void> {
        return Promise(on: queue) { resolve, fail in
            guard case .uninitialized = self.connectionState else {
                fail(EventTransportError.unexpected(reason: "Tried to connect on a pending socket"))
                return
            }
            
            self.connectionState = .connecting
            
            self.delegate = delegate
            
            self.socket.connect()
            
            self.socket.onOpen { self.onOpen() }
            self.socket.onClose { self.onClose() }
            self.socket.onError { error in self.onError(error) }
            
            let channel = self.socket.channel(self.topic)
            
            channel.join(timeout: 3.0)
                .receive("ok", callback: { message in
                    self.connectionState = .connected
                    resolve(())
                }).receive("error", callback: { message in
                    self.connectionState = .error
                    fail(EventTransportError.connectionError)
                })
            
            self.channel = channel
            
            /// listen for media events
            self.channel!.on("mediaEvent", callback: { message in
                guard let event: ReceivableEvent = Events.deserialize(payload: message.payload) else {
                    return
                }
                
                self.delegate?.didReceive(event: event)
            })
        }
    }
    
    func disconnect() {
        if let channel = self.channel {
            channel.leave()
            
            self.channel = nil
        }
        
        socket.disconnect()
        
        self.connectionState = .closed
    }
    
    func send(event: SendableEvent) {
        guard self.connectionState == .connected,
            let channel = self.channel else {
                sdkLogger.error("PhoenixEventTransport tried sending a message on a closed socket")
            return
        }
        
        let data = try! JSONSerialization.data(withJSONObject: event.serialize(), options: JSONSerialization.WritingOptions())
        
        guard let dataPayload: String = String(data: data, encoding: .utf8) else {
            return
        }
        
        channel.push("mediaEvent", payload: ["data": dataPayload])
    }
}

extension PhoenixTransport {
    func onOpen() {
        self.connectionState = .connected
    }
    
    func onClose() {
        self.connectionState = .closed
    }
    
    func onError(_ error: Error) {
        self.connectionState = .closed
        self.delegate?.didReceive(error: EventTransportError.connectionError)
    }
}
