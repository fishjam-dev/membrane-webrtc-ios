import Foundation
import MembraneRTC
import SwiftUI

final class AppController: ObservableObject {
    public static let shared = AppController()

    public private(set) var client: MembraneRTC?
    public private(set) var transport: PhoenixTransport?
    public private(set) var displayName: String = ""

    enum State {
        case awaiting, loading, connected, disconnected, error
    }

    @Published private(set) var state: State
    @Published var errorMessage: String?

    private init() {
        state = .awaiting
    }

    public func connect(room: String, displayName: String) {
        self.displayName = displayName
        let engineUrl = Constants.getRtcEngineUrl().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let transportUrl = "\(engineUrl)/socket"

        let transport = PhoenixTransport(
            url: transportUrl, topic: "room:\(room)", params: [:], channelParams: ["isSimulcastOn": true])
        DispatchQueue.main.async {
            self.state = .loading
        }
        transport.connect(delegate: self).then {
            DispatchQueue.main.async {
                self.client = MembraneRTC.create(delegate: self)
                self.transport = transport
                self.state = .connected
            }
        }.catch { error in
            DispatchQueue.main.async {
                self.state = .error
            }
        }

    }

    public func disconnect() {
        DispatchQueue.main.async {
            guard let client = self.client else {
                return
            }

            self.transport?.disconnect()

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
    func onSendMediaEvent(event: SerializedMediaEvent) {
        transport?.send(event: event)
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
}

extension AppController: PhoenixTransportDelegate {
    func didReceive(error: PhoenixTransportError) {
        state = .error
    }

    func didReceive(event: SerializedMediaEvent) {
        self.client?.receiveMediaEvent(mediaEvent: event)
    }
}
