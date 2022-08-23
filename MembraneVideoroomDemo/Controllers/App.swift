import Foundation
import MembraneRTC
import SwiftUI

final class AppController: ObservableObject {
    public static let shared = AppController()

    public private(set) var client: MembraneRTC?

    enum State {
        case awaiting, loading, connected, disconnected, error
    }

    @Published private(set) var state: State

    private init() {
        state = .awaiting
    }


    public func connect(room: String, displayName: String) {
        let engineUrl = Constants.rtcEngineUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        let transportUrl = "\(engineUrl)/socket"

        let client = MembraneRTC.connect(
            with: MembraneRTC.ConnectOptions(
                transport: PhoenixTransport(url: transportUrl, topic: "room:\(room)", params: [:]),
                config: .init(["displayName": displayName])
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
        if let client = client {
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

    func onJoinSuccess(peerID _: String, peersInRoom _: [Peer]) {}

    func onJoinError(metadata _: Any) {}

    func onTrackReady(ctx _: TrackContext) {}

    func onTrackAdded(ctx _: TrackContext) {}

    func onTrackRemoved(ctx _: TrackContext) {}

    func onTrackUpdated(ctx _: TrackContext) {}

    func onPeerJoined(peer _: Peer) {}

    func onPeerLeft(peer _: Peer) {}

    func onPeerUpdated(peer _: Peer) {}

    func onError(_: MembraneRTCError) {
        DispatchQueue.main.async {
            self.state = .error
        }
    }
}
