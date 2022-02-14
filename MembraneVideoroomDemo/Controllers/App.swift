import Foundation
import SwiftUI
import MembraneRTC


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
    
    let localAddress = "http://192.168.83.89:4000"
    let remoteAddress = "https://dscout.membrane.work"
    
    public func connect(room: String, displayName: String) {
        let transportUrl = "\(localAddress)/socket"
        
        let client = MembraneRTC.connect(
            with: MembraneRTC.ConnectOptions(
                transport: PhoenixTransport(url: transportUrl, topic: "room:\(room)"),
                config: ["displayName": displayName]
            ),
            delegate: self
        )
        
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
    func onJoinSuccess(peerID: String, peersInRoom: Array<Peer>) { }
    
    func onJoinError(metadata: Any) { }
    
    func onTrackReady(ctx: TrackContext) { }
    
    func onTrackAdded(ctx: TrackContext) { }
    
    func onTrackRemoved(ctx: TrackContext) { }
    
    func onTrackUpdated(ctx: TrackContext) { }
    
    func onPeerJoined(peer: Peer) { }
    
    func onPeerLeft(peer: Peer) { }
    
    func onPeerUpdated(peer: Peer) { }
    
    func onError(_ error: MembraneRTCError) {
        DispatchQueue.main.async {
            self.state = .error
        }
    }
}
