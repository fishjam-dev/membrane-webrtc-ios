//
//  PhoenixEventTransport.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 19/01/2022.
//

import Foundation
import SwiftPhoenixClient
import Promises

class PhoenixEventTransport: EventTransport {
    enum ConnectionState {
        case uninitialized, connecting, connected, closed, error
    }
    
    let topic: String
    
    let socket: Socket
    var channel: Channel?
    // TODO: this delegate should be a weak reference
    var delegate: EventTransportDelegate?
    var connectionState: ConnectionState = .uninitialized
    
    
    let queue = DispatchQueue(label: "membrane.rtc.transport", qos: .background)
    
    init(url: String, topic: String) {
        self.topic = topic
        
        self.socket = Socket(endPoint: url, transport: { URLSessionTransport(url: $0)})
    }
    
    func connect(delegate: EventTransportDelegate) -> Promise<Void> {
        return Promise(on: queue) { resolve, fail in
            guard case .uninitialized = self.connectionState else {
                debugPrint("Tried connecting on a socket with state", self.connectionState)
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
            
            self.channel!.on("mediaEvent", callback: { message in
                guard let event: ReceivableEvent = Events.deserialize(payload: message.payload) else {
                    return
                }
                
                self.delegate?.receiveEvent(event: event)
            })
        }
    }
    
    func sendEvent(event: SendableEvent) {
        guard socket.isConnected,
            let channel = self.channel else {
            debugPrint("Tried sending a message on closed socket")
            return
        }
        
        let data = try! JSONSerialization.data(withJSONObject: event.serialize(), options: JSONSerialization.WritingOptions())
        
        guard let dataPayload: String = String(data: data, encoding: .utf8) else {
            return
        }
        
        channel.push("mediaEvent", payload: ["data": dataPayload])
    }
}

extension PhoenixEventTransport {
    func onOpen() {
        self.connectionState = .connected
    }
    
    func onClose() {
        self.connectionState = .closed
    }
    
    func onError(_ error: Error) {
        self.connectionState = .closed
    }
}
