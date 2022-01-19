import Foundation
import SwiftUI
import WebRTC


final class AppController: ObservableObject {
    public static let shared = AppController()
    
    @Published private(set) var localVideoFeed: RTCVideoTrack?
    
    @Published private(set) var client: MembraneRTC?
    
    private init() {

    }

    public func connect() {
        self.client = MembraneRTC(delegate: self, eventTransport: self, config: RTCConfiguration())
    }
}

extension AppController: MembraneRTCDelegate {
    /// Callback invoked when the client has been let into the room.
    func onJoinSuccess(peerID: String, peersInRoom: Array<Peer>) {
        debugPrint("onJoinSuccess")
    }

    /// Callback invoked when client has been denied access to enter the room. 
    func onJoinError(metadata: Any) {
        debugPrint("onJoinError")
    }

    /// Callback invoked a track is ready to be played. 
    func onTrackReady(ctx: TrackContext) {
        debugPrint("onTrackReady")
    }

    /// Callback invoked a peer already present in a room adds a new track. 
    func onTrackAdded(ctx: TrackContext) {
        debugPrint("onTrackAdded")
    }
    
    /// Callback invoked when a track will no longer receive any data. 
    func onTrackRemoved(ctx: TrackContext) {
        debugPrint("onTrackRemoved")
    }

    /// Callback invoked when track's metadata gets updated 
    func onTrackUpdated(ctx: TrackContext) {
        debugPrint("onTrackUpdated")
    }
    
    /// Callback invoked when a new peer joins the room. 
    func onPeerJoined(peer: Peer) {
        debugPrint("onPeerJoined")
        
    }

    /// Callback invoked when a peer leaves the room. 
    func onPeerLeft(peer: Peer) {
        debugPrint("onPeerLeft")
    }
    
    /// Callback invoked when peer's metadata gets updated. 
    func onPeerUpdated(peer: Peer) {
        debugPrint("onPeerUpdated")
    }
    
    /// Callback invoked when a connection errors happens.
    func onConnectionError(message: String) {
        debugPrint("onConnectionError")
    }
}

// FIXME: this is temporary just to launch the application
extension AppController: EventTransport {
    func receiveEvent(data: Data) -> Event? {
        return nil
    }

    func sendEvent(event: Event) {
        print("Application sending the signalling event")
    }
}
