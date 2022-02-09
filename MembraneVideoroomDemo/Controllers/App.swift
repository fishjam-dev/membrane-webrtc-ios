import Foundation
import SwiftUI
import WebRTC
import Promises


final class AppController: ObservableObject {
    public static let shared = AppController()
    
    public private(set) var client: MembraneRTC?
    
    enum State {
        case awaiting, loading, connected, disconnected, error
    }
    
    @Published private(set) var state: State
    
    private init() {
        self.state = .awaiting
    }
    
//    let localAddress = "http://192.168.83.11:4000"
    let localAddress = "http://192.168.83.228:4000"
    let remoteAddress = "https://dscout.membrane.work"
    
    public func connect(room: String, displayName: String) {
        let transportUrl = "\(localAddress)/socket"
        let transport = PhoenixEventTransport(url: transportUrl, topic: "room:\(room)")
        
        let client = MembraneRTC(
            eventTransport: transport,
            config: RTCConfiguration(),
            localParticipantInfo: ParticipantInfo(displayName: displayName)
        )
        
        client.add(delegate: self)
        client.connect()
        
        DispatchQueue.main.async {
            self.state = .loading
            self.client = client
            
        }
    }
    
    public func disconnect() {
        DispatchQueue.main.async {
            guard let client = self.client else {
                return
            }
            
            client.remove(delegate: self)
            
            client.disconnect()
            
            self.client = nil
            self.state = .disconnected
        }
    }
    
    public func reset() {
        if let client = self.client {
            client.remove(delegate: self)
            client.disconnect()
        }
        
        DispatchQueue.main.async {
            self.client = nil
            self.state = .awaiting
        }
    }
    
    deinit {
        self.client?.remove(delegate: self)
    }
}

extension AppController: MembraneRTCDelegate {
    func onConnected() {
        DispatchQueue.main.async {
            self.state = .connected
        }
    }
    /// Callback invoked when the client has been let into the room.
    func onJoinSuccess(peerID: String, peersInRoom: Array<Peer>) {
        sdkLogger.info("AppController joined successfully")
    }

    /// Callback invoked when client has been denied access to enter the room. 
    func onJoinError(metadata: Any) {
        sdkLogger.info("AppController failed to join: \(metadata)")
    }

    /// Callback invoked a track is ready to be played. 
    func onTrackReady(ctx: TrackContext) {
        sdkLogger.debug("AppController a track is ready: \(ctx.trackId)")
    }

    /// Callback invoked a peer already present in a room adds a new track. 
    func onTrackAdded(ctx: TrackContext) {
        sdkLogger.debug("AppController a track has been added: \(ctx.trackId)")
    }
    
    /// Callback invoked when a track will no longer receive any data. 
    func onTrackRemoved(ctx: TrackContext) {
        sdkLogger.debug("AppController a track has been removed: \(ctx.trackId)")
    }

    /// Callback invoked when track's metadata gets updated 
    func onTrackUpdated(ctx: TrackContext) {
        sdkLogger.debug("AppController a track has been updated: \(ctx.trackId)")
    }
    
    /// Callback invoked when a new peer joins the room. 
    func onPeerJoined(peer: Peer) {
        sdkLogger.debug("AppController a new peer has joined")
    }

    /// Callback invoked when a peer leaves the room. 
    func onPeerLeft(peer: Peer) {
        sdkLogger.debug("AppController a peer has left")
    }
    
    /// Callback invoked when peer's metadata gets updated. 
    func onPeerUpdated(peer: Peer) {
        sdkLogger.debug("AppController a peer has been updated")
    }
    
    /// Callback invoked when a connection errors happens.
    func onConnectionError(message: String) {
        DispatchQueue.main.async {
            self.state = .error
        }
        
        sdkLogger.debug("AppController encountered connection error..")
    }
}
