/// Delegate responsible for receiving notification from `MembraneRTC` client.
public protocol MembraneRTCDelegate {
    /// Callback invoked when client has successfully connected via transport layer.
    func onConnected() -> Void

    /// Callback invoked when the client has been approved to participate in session.
    func onJoinSuccess(peerID: String, peersInRoom: [Peer]) -> Void

    /// Callback invoked when client has been denied access to enter the room.
    func onJoinError(metadata: Any) -> Void

    /// Callback invoked a track is ready to be played.
    func onTrackReady(ctx: TrackContext) -> Void

    /// Callback invoked a peer already present in a room adds a new track.
    func onTrackAdded(ctx: TrackContext) -> Void

    /// Callback invoked when a track will no longer receive any data and should get removed.
    func onTrackRemoved(ctx: TrackContext) -> Void

    /// Callback invoked when track's metadata gets updated.
    func onTrackUpdated(ctx: TrackContext) -> Void

    /// Callback invoked when a new peer joins the room.
    func onPeerJoined(peer: Peer) -> Void

    /// Callback invoked when a peer leaves the room.
    ///
    /// When a peer with active track leaves the room, `onTrackRemoved` will be called for all their tracks beforehand.
    func onPeerLeft(peer: Peer) -> Void

    /// Callback invoked when peer's metadata gets updated.
    func onPeerUpdated(peer: Peer) -> Void

    /// Callback invoked when an errors happens.
    ///
    /// For more information about the error type please refere to `MembraneRTCError`.
    func onError(_ error: MembraneRTCError) -> Void
}
