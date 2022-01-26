import Foundation
import SwiftUI
import WebRTC
import Promises


final class AppController: ObservableObject {
    public static let shared = AppController()
    
    public private(set) var client: MembraneRTC?
    
    @Published private(set) var awaitingConnect: Bool
    
    private init() {
        self.awaitingConnect = true
    }

    public func connect() {
        let client = MembraneRTC(eventTransport: PhoenixEventTransport(url: "http://localhost:4000/socket", topic: "room:test"), config: RTCConfiguration())
        client.add(delegate: self)
        client.connect()
        
        self.client = client
    }
    
    deinit {
        self.client?.remove(delegate: self)
    }
}

extension AppController: MembraneRTCDelegate {
    func onConnected() {
        DispatchQueue.main.async {
            self.awaitingConnect = false
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
        sdkLogger.debug("AppController encountered connection error..")
    }
}
