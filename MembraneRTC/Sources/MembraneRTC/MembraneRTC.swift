import Foundation
import Logging
import WebRTC

internal var sdkLogger = Logger(label: "org.membrane.ios")
internal let pcLogPrefix = "[PeerConnection]"

/// MembraneRTC client.
///
/// The client is responsible for relaying MembraneRTC Engine specific messages through given reliable transport layer.
/// Once initialized, the client is responsbile for exchaning necessary messages via provided `EventTransport` and managing underlying
/// `RTCPeerConnection`. The goal of the client is to be as lean as possible, meaning that all activies regarding the session such as moderating
/// should be implemented by the user himself on top of the `MembraneRTC`.
///
/// The user's ability of interacting with the client is greatly liimited to the essential actions such as joining/leaving the session,
/// adding/removing local tracks and receiving information about remote peers and their tracks that can be played by the user.
///
/// User can request 3 different types of local tracks that will get forwareded to the server by the client:
/// - `LocalAudioTrack` - an audio track utilizing device's microphone
/// - `LocalVideoTrack` - a video track that can utilize device's camera or if necessay use video playback from a file (useful for testing with a simulator)
/// - `LocalBroadcastScreenTrack` - a screencast track taking advantage of `Broadcast Upload Extension` to record device's screen even if the app is minimized
///
/// It is recommended to request necessary audio and video tracks before joining the room but it does not mean it can't be done afterwards (in case of screencast)
///
/// Once the user received `onConnected` notification they can call the `join` method to initialize joining the session.
/// After receiving `onJoinSuccess` a user will receive notification about various peers joining/leaving the session, new tracks being published and ready for playback
/// or going inactive.
public class MembraneRTC: MulticastDelegate<MembraneRTCDelegate>, ObservableObject, RTCEngineListener,
    PeerConnectionListener
{
    enum State {
        case uninitialized
        case awaitingJoin
        case connected
        case disconnected
    }

    public struct ConnectOptions {
        let transport: EventTransport
        let config: Metadata
        let encoder: Encoder

        public init(transport: EventTransport, config: Metadata, encoder: Encoder = Encoder.DEFAULT) {
            self.transport = transport
            self.config = config
            self.encoder = encoder
        }
    }

    var state: State

    private var eventTransport: EventTransport

    private lazy var engineCommunication: RTCEngineCommunication = {
        return RTCEngineCommunication(transport: eventTransport, engineListener: self)
    }()

    // a common stream ID used for all non-screenshare and audio tracks
    private let localStreamId = UUID().uuidString

    // `RTCPeerConnection` config
    private var config: RTCConfiguration

    private var peerConnectionFactoryWrapper: PeerConnectionFactoryWrapper

    private var localTracks: [LocalTrack] = []

    private var localPeer = Peer(id: "", metadata: .init([:]), trackIdToMetadata: [:])

    // mapping from peer's id to itself
    private var remotePeers: [String: Peer] = [:]

    // mapping from remote track's id to its context
    private var trackContexts: [String: TrackContext] = [:]

    // receiver used for iOS screen broadcast
    private var broadcastScreenshareReceiver: ScreenBroadcastNotificationReceiver?

    private var encoder: Encoder

    private lazy var peerConnectionManager: PeerConnectionManager = {
        return PeerConnectionManager(
            config: self.config, peerConnectionFactory: self.peerConnectionFactoryWrapper, peerConnectionListener: self)
    }()

    internal init(
        eventTransport: EventTransport, config: RTCConfiguration, peerMetadata: Metadata,
        encoder: Encoder
    ) {
        // RTCSetMinDebugLogLevel(.error)
        sdkLogger.logLevel = .info

        state = .uninitialized

        self.eventTransport = eventTransport

        self.config = config

        // setup local peer
        localPeer = localPeer.with(metadata: peerMetadata)

        peerConnectionFactoryWrapper = PeerConnectionFactoryWrapper(encoder: encoder)

        self.encoder = encoder

        super.init()
    }

    /**
     Initializes the connection with the `Membrane RTC Engine` transport layer
     and sets up local audio and video track.

     Should not be confused with joining the actual room, which is a separate process.

     - Parameters:
        - with: Connection options, consists of an `EventTransport` instance that will be used for relaying media events, arbitrary `config` metadata used by `Membrane RTC Engine` for connection and `encoder` type
        - delegate: The delegate that will receive all notification emitted by `MembraneRTC` client

     -  Returns: `MembraneRTC` client instance in connecting state
     */
    public static func connect(with options: ConnectOptions, delegate: MembraneRTCDelegate)
        -> MembraneRTC
    {
        let client = MembraneRTC(
            eventTransport: options.transport, config: RTCConfiguration(), peerMetadata: options.config,
            encoder: options.encoder)

        client.add(delegate: delegate)
        client.connect()

        return client
    }

    // Default ICE server when no turn servers are specified
    private static func defaultIceServer() -> RTCIceServer {
        let iceUrl = "stun:stun.l.google.com:19302"

        return RTCIceServer(urlStrings: [iceUrl])
    }

    /// Initiaites join process once the client has successfully connected.
    ///
    /// Once completed either `onJoinSuccess` or `onJoinError` of client's delegate gets invovked.
    public func join() {
        guard state == .awaitingJoin else {
            return
        }

        engineCommunication.join(peerMetadata: localPeer.metadata)
    }

    /// Disconnects from the `Membrane RTC Engine` transport and closes the exisitng `RTCPeerConnection`
    ///
    /// Once the `disconnect` gets invoked the client can't be reused and user should create a new client instance instead.
    public func disconnect() {
        engineCommunication.disconnect()

        localTracks.forEach { track in
            track.stop()
        }

        peerConnectionManager.close()
    }

    /**
   Creates a new video track utilizing device's specified camera.

   The client assumes that app user already granted camera access permissions.

   - Parameters:
   - videoParameters: The parameters used for choosing the proper camera resolution, target framerate, bitrate and simulcast config
   - metadata: The metadata that will be sent to the `Membrane RTC Engine` for media negotiation
   - captureDeviceId: name of the chosen camera. Obtain devices using `LocalVideoTrack.getCaptureDevices` and an id using `uniqueID` property

   - Returns: `LocalCameraVideoTrack` instance that user then can use for things such as front / back camera switch.
   */
    public func createVideoTrack(videoParameters: VideoParameters, metadata: Metadata, captureDeviceId: String? = nil)
        -> LocalVideoTrack
    {
        let videoTrack = LocalVideoTrack.create(
            for: .camera, videoParameters: videoParameters, peerConnectionFactoryWrapper: peerConnectionFactoryWrapper)

        if state == .connected {
            peerConnectionManager.addTrack(track: videoTrack, localStreamId: localStreamId)
        }

        if let captureDeviceId = captureDeviceId, let videoTrack = videoTrack as? LocalCameraVideoTrack {
            videoTrack.switchCamera(deviceId: captureDeviceId)
        }

        videoTrack.start()

        localTracks.append(videoTrack)

        localPeer = localPeer.withTrack(trackId: videoTrack.rtcTrack().trackId, metadata: metadata)

        if state == .connected {
            engineCommunication.renegotiateTracks()
        }

        return videoTrack
    }

    /**
     Creates a new audio track utilizing device's microphone.

     The client assumes that app user already granted microphone access permissions.

     - Parameters:
        - metadata: The metadata that will be sent to the `Membrane RTC Engine` for media negotiation

     - Returns: `LocalAudioTrack` instance that user then can use for things such as front / back camera switch.
     */
    public func createAudioTrack(metadata: Metadata) -> LocalAudioTrack {
        let audioTrack = LocalAudioTrack(peerConnectionFactoryWrapper: peerConnectionFactoryWrapper)

        if state == .connected {
            peerConnectionManager.addTrack(track: audioTrack, localStreamId: localStreamId)
        }

        audioTrack.start()

        localTracks.append(audioTrack)

        localPeer = localPeer.withTrack(trackId: audioTrack.rtcTrack().trackId, metadata: metadata)

        if state == .connected {
            engineCommunication.renegotiateTracks()
        }

        return audioTrack
    }

    /**
     Creates a screencast track capturing the entire device's screen.

     The track starts listening for a media sent from a custom  `Broadcast Upload Extension`.  For more information
     please refer to `LocalBroadcastScreenTrack` for more information.

     The nature of upload extension is asynchronous due to the way that iOS handle broadcasting the screen. The app user
     may be hanging on start broadcast screen therefore there is no consistent synchronous way of telling if the broadcast started.

     - Parameters:
        - appGroup: The App Group identifier shared by the application  with a target `Broadcast Upload Extension`
        - videoParameters: The parameters used for limiting the screen capture resolution and target framerate, bitrate and simulcast config
        - metadata: The metadata that will be sent to the `Membrane RTC Engine` for media negotiation
        - onStart: The callback that will receive the screencast track called once the track becomes available
        - onStop: The callback that will be called once the track becomes unavailable
     */
    public func createScreencastTrack(
        appGroup: String, videoParameters: VideoParameters, metadata: Metadata,
        onStart: @escaping (_ track: LocalScreenBroadcastTrack) -> Void, onStop: @escaping () -> Void
    ) -> LocalScreenBroadcastTrack {
        let screensharingTrack = LocalScreenBroadcastTrack(
            appGroup: appGroup, videoParameters: videoParameters,
            peerConnectionFactoryWrapper: peerConnectionFactoryWrapper)
        localTracks.append(screensharingTrack)

        broadcastScreenshareReceiver = ScreenBroadcastNotificationReceiver(
            onStart: { [weak self, weak screensharingTrack] in
                guard let track = screensharingTrack else {
                    return
                }

                DispatchQueue.main.async {
                    self?.setupScreencastTrack(track: track, metadata: metadata)
                    onStart(track)
                }
            },
            onStop: { [weak self, weak screensharingTrack] in
                DispatchQueue.main.async {
                    if let track = screensharingTrack {
                        self?.removeTrack(trackId: track.rtcTrack().trackId)
                    }
                    onStop()
                }
            })

        screensharingTrack.delegate = broadcastScreenshareReceiver
        screensharingTrack.start()
        return screensharingTrack
    }

    /**
     Removes a local track with given `trackId`.

     - Parameters:
        - trackId: The id of the local track that should get stopped and removed from the client

     - Returns: Bool whether the track has been found and removed or not
     */
    @discardableResult
    public func removeTrack(trackId: String) -> Bool {
        guard let index = localTracks.firstIndex(where: { $0.rtcTrack().trackId == trackId }) else {
            return false
        }

        let track = localTracks.remove(at: index)
        track.stop()

        peerConnectionManager.removeTrack(trackId: trackId)

        localPeer = localPeer.withoutTrack(trackId: trackId)

        engineCommunication.renegotiateTracks()

        return true
    }

    /// Returns information about the current local peer
    public func currentPeer() -> Peer {
        return localPeer
    }

    /**
     * Enables track encoding so that it will be sent to the server.

        - Parameters:
           - trackId: an id of a local track
           - encoding: an encoding that will be enabled
     */
    public func enableTrackEncoding(trackId: String, encoding: TrackEncoding) {
        setTrackEncoding(trackId: trackId, encoding: encoding, enabled: true)
    }

    /**
     * Disables track encoding so that it will be no longer sent to the server.

         - Parameters:
            - trackId: an id of a local track
            - encoding: an encoding that will be disabled
     */
    public func disableTrackEncoding(trackId: String, encoding: TrackEncoding) {
        setTrackEncoding(trackId: trackId, encoding: encoding, enabled: false)
    }

    /**
     Updates the metadata for the current peer.

        - Parameters:
         - peerMetadata: Data about this peer that other peers will receive upon joining.

     If the metadata is different from what is already tracked in the room, the optional
     callback `onPeerUpdated` will be triggered for other peers in the room.
     */
    public func updatePeerMetadata(peerMetadata: Metadata) {
        engineCommunication.updatePeerMetadata(peerMetadata: peerMetadata)
        localPeer = localPeer.with(metadata: peerMetadata)
    }

    /**
     Updates the metadata for a specific track.

        - Parameters:
         - trackId: local track id of audio or video track
         - trackMetadata: Data about this track that other peers will receive upon joining.

     If the metadata is different from what is already tracked in the room, the optional
     callback `onTrackUpdated` will be triggered for other peers in the room.
     */
    public func updateTrackMetadata(trackId: String, trackMetadata: Metadata) {
        engineCommunication.updateTrackMetadata(trackId: trackId, trackMetadata: trackMetadata)
        localPeer = localPeer.withTrack(trackId: trackId, metadata: trackMetadata)
    }

    /**
      Updates maximum bandwidth for the track identified by trackId.
      This value directly translates to quality of the stream and, in case of video, to the amount of RTP packets being sent.
      In case trackId points at the simulcast track bandwidth is split between all of the variant streams proportionally to their resolution.

        - Parameters:
         - trackId: track id of a video track
         - bandwidth: bandwidth in kbps
     */
    public func setTrackBandwidth(trackId: String, bandwidth: BandwidthLimit) {
        peerConnectionManager.setTrackBandwidth(trackId: trackId, bandwidth: bandwidth)
    }

    /**
        Updates maximum bandwidth for the given simulcast encoding of the given track.

        - Parameters:
         - trackId: track id of a video track
         - encoding: rid of the encoding
         - bandwidth: bandwidth in kbps
     */
    public func setEncodingBandwidth(trackId: String, encoding: String, bandwidth: BandwidthLimit) {
        peerConnectionManager.setEncodingBandwidth(trackId: trackId, encoding: encoding, bandwidth: bandwidth)
    }

    internal func connect() {
        // initiate a transport connection
        engineCommunication.connect().then {
            self.notify {
                self.state = .awaitingJoin

                $0.onConnected()
            }
        }.catch { error in
            self.notify {
                $0.onError(.transport(error.localizedDescription))
            }
        }
    }

    /// Adds given broadcast track to the peer connection and forces track renegotiation.
    private func setupScreencastTrack(track: LocalScreenBroadcastTrack, metadata: Metadata) {
        let screencastStreamId = UUID().uuidString

        peerConnectionManager.addTrack(track: track, localStreamId: screencastStreamId)

        localPeer = localPeer.withTrack(trackId: track.rtcTrack().trackId, metadata: metadata)

        engineCommunication.renegotiateTracks()
    }

    /**
     Sets track encoding that server should send to the client library.

     The encoding will be sent whenever it is available.
     If choosen encoding is temporarily unavailable, some other encoding
     will be sent until choosen encoding becomes active again.

         - Parameters:
            - trackId: an id of a remote track
            - encoding: an encoding to receive
     */
    public func setTargetTrackEncoding(trackId: String, encoding: TrackEncoding) {
        engineCommunication.setTargetTrackEncoding(trackId: trackId, encoding: encoding)
    }

    private func setTrackEncoding(trackId: String, encoding: TrackEncoding, enabled: Bool) {
        peerConnectionManager.setTrackEncoding(trackId: trackId, encoding: encoding, enabled: enabled)
    }

    public func getStats() {
        print(peerConnectionManager.getStats())
    }

    /**
     Changes severity level of debug logs.

         - Parameters:
            - severity: enum value representing the logging severity
     */
    public func changeWebRTCLoggingSeverity(severity: RTCLoggingSeverity) {
        RTCSetMinDebugLogLevel(severity)
    }

    func onPeerAccepted(peerId: String, peersInRoom: [Peer]) {
        localPeer = localPeer.with(id: peerId)

        // initialize all present peers
        peersInRoom.forEach { peer in
            self.remotePeers[peer.id] = peer

            // initialize peer's track contexts
            peer.trackIdToMetadata?.forEach { trackId, metadata in
                let context = TrackContext(track: nil, peer: peer, trackId: trackId, metadata: metadata)

                self.trackContexts[trackId] = context

                self.notify {
                    $0.onTrackAdded(ctx: context)
                }
            }
        }

        notify {
            $0.onJoinSuccess(peerID: peerId, peersInRoom: peersInRoom)
        }
    }

    func onPeerDenied() {
        notify {
            $0.onJoinError(metadata: [:])
        }
    }

    func onPeerJoined(peer: Peer) {
        guard peer.id != localPeer.id else {
            return
        }

        remotePeers[peer.id] = peer

        notify {
            $0.onPeerJoined(peer: peer)
        }
    }

    func onPeerLeft(peerId: String) {
        guard let peer = remotePeers[peerId] else {
            sdkLogger.error("Failed to process PeerLeft event: Peer not found: \(peerId)")
            return
        }

        remotePeers.removeValue(forKey: peer.id)

        // for a leaving peer clear his track contexts
        if let trackIds = peer.trackIdToMetadata?.keys {
            let contexts = trackIds.compactMap { id in
                self.trackContexts[id]
            }

            trackIds.forEach { id in
                self.trackContexts.removeValue(forKey: id)
            }

            contexts.forEach { context in
                self.notify {
                    $0.onTrackRemoved(ctx: context)
                }
            }
        }

        notify {
            $0.onPeerLeft(peer: peer)
        }
    }

    func onPeerUpdated(peerId: String, peerMetadata: Metadata) {
        guard var peer = remotePeers[peerId] else {
            sdkLogger.error("Failed to process PeerUpdated event: Peer not found: \(peerId)")
            return
        }

        // update peer's metadata
        peer = peer.with(metadata: peerMetadata)

        remotePeers.updateValue(peer, forKey: peer.id)

        notify {
            $0.onPeerUpdated(peer: peer)
        }
    }

    func onOfferData(integratedTurnServers: [OfferDataEvent.TurnServer], tracksTypes: [String: Int]) {
        peerConnectionManager.getSdpOffer(
            integratedTurnServers: integratedTurnServers, tracksTypes: tracksTypes, localTracks: localTracks
        ) { sdp, midToTrackId, error in
            if let err = error {
                self.notify {
                    $0.onError(.rtc(err.localizedDescription))
                }
            }

            if let sdp = sdp, let midToTrackId = midToTrackId {
                self.engineCommunication.sdpOffer(
                    sdp: sdp, trackIdToTrackMetadata: self.localPeer.trackIdToMetadata ?? [:],
                    midToTrackId: midToTrackId)
            }

        }
    }

    func onSdpAnswer(type: String, sdp: String, midToTrackId: [String: String?]) {
        peerConnectionManager.onSdpAnswer(sdp: sdp, midToTrackId: midToTrackId, localTracks: localTracks)
    }

    func onRemoteCandidate(candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        let candidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

        peerConnectionManager.onRemoteCandidate(candidate: candidate)
    }

    func onTracksAdded(peerId: String, trackIdToMetadata: [String: Metadata]) {
        // ignore local participant
        guard localPeer.id != peerId else {
            return
        }

        guard var peer = remotePeers[peerId] else {
            sdkLogger.error("Failed to process TracksAdded event: Peer not found: \(peerId)")
            return
        }

        // update tracks of the remote peer
        peer = peer.with(trackIdToMetadata: trackIdToMetadata)
        remotePeers[peer.id] = peer

        // for each track create a corresponding track context
        peer.trackIdToMetadata?.forEach { trackId, metadata in
            let context = TrackContext(track: nil, peer: peer, trackId: trackId, metadata: metadata)

            self.trackContexts[trackId] = context

            self.notify {
                $0.onTrackAdded(ctx: context)
            }
        }
    }

    func onTracksRemoved(peerId: String, trackIds: [String]) {
        guard let _ = remotePeers[peerId] else {
            sdkLogger.error("Failed to process TracksRemoved event: Peer not found: \(peerId)")
            return
        }

        // for each track clear its context and notify delegates
        trackIds.forEach { id in
            guard let context = self.trackContexts[id] else {
                sdkLogger.error("Failed to process TracksRemoved event: Track not found: \(id)")
                return
            }

            self.trackContexts.removeValue(forKey: id)

            self.notify {
                $0.onTrackRemoved(ctx: context)
            }
        }
    }

    func onTrackUpdated(peerId: String, trackId: String, metadata: Metadata) {
        guard let context = self.trackContexts[trackId] else {
            sdkLogger.error("Failed to process TrackUpdated event: Track not found: \(trackId)")
            return
        }

        context.metadata = metadata

        notify {
            $0.onTrackUpdated(ctx: context)
        }
    }

    func onTrackEncodingChanged(peerId: String, trackId: String, encoding: String, encodingReason: String) {
        self.notify {
            $0.onTrackEncodingChanged(
                peerId: peerId, trackId: trackId,
                encoding: encoding)
        }
        if let trackEncoding = TrackEncoding.fromString(encoding),
            let trackContext = self.trackContexts[trackId],
            let encodingReasonEnum = EncodingReason(rawValue: encodingReason)
        {
            trackContext.setEncoding(encoding: trackEncoding, encodingReason: encodingReasonEnum)
        }
    }

    func onVadNotification(trackId: String, status: String) {
        if let vadStatus = VadStatus(rawValue: status),
            let trackContext = self.trackContexts[trackId]
        {
            trackContext.vadStatus = vadStatus
        }

    }

    func onBandwidthEstimation(estimation: Int) {
        self.notify {
            $0.onBandwidthEstimationChanged(estimation: estimation)
        }
    }

    func onRemoved(peerId: String, reason: String) {
        guard peerId == localPeer.id else {
            sdkLogger.error("Received onRemoved media event, but it does not refer to the local peer")
            return
        }

        notify {
            $0.onRemoved(reason: reason)
        }
    }

    func onError(error: EventTransportError) {
        notify {
            $0.onError(.transport(error.description))
        }
    }

    func onClose() {
        notify {
            $0.onError(.transport("Transport has been closed"))
        }
    }

    /// Sends the local ice candidate to the `Membrane RTC Engine` instance via transport layer.
    func onLocalIceCandidate(candidate: RTCIceCandidate) {
        engineCommunication.localCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex)
    }

    func onAddTrack(trackId: String, track: RTCMediaStreamTrack) {
        guard let trackContext = trackContexts[trackId]
        else {
            sdkLogger.error(
                "\(pcLogPrefix) started receiving on a transceiver without registered track context"
            )
            return
        }

        // assign given receiver to its track's context
        if let audioTrack = track as? RTCAudioTrack {
            trackContext.track = RemoteAudioTrack(track: audioTrack)
        }

        if let videoTrack = track as? RTCVideoTrack {
            trackContext.track = RemoteVideoTrack(track: videoTrack)
        }

        notify {
            $0.onTrackReady(ctx: trackContext)
        }
    }

    func onPeerConnectionStateChange(newState: RTCIceConnectionState) {
        switch newState {
        case .connected:
            state = .connected
        case .disconnected:
            state = .disconnected
        default:
            break
        }
    }
}

extension DispatchQueue {
    static let webRTC = DispatchQueue(label: "membrane.rtc.webRTC")
    static let sdk = DispatchQueue(label: "membrane.rtc.sdk")
}
