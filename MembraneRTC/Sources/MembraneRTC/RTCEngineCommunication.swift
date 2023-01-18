import Promises

internal class RTCEngineCommunication: EventTransportDelegate {
    let transport: EventTransport
    let engineListener: RTCEngineListener

    init(transport: EventTransport, engineListener: RTCEngineListener) {
        self.transport = transport
        self.engineListener = engineListener
    }

    func connect() -> Promise<Void> {
        return transport.connect(delegate: self)
    }

    func disconnect() {
        transport.disconnect()
    }

    func join(peerMetadata: Metadata) {
        transport.send(event: JoinEvent(metadata: peerMetadata))
    }

    func updatePeerMetadata(peerMetadata: Metadata) {
        transport.send(event: UpdatePeerMetadata(metadata: peerMetadata))
    }

    func updateTrackMetadata(trackId: String, trackMetadata: Metadata) {
        transport.send(event: UpdateTrackMetadata(trackId: trackId, trackMetadata: trackMetadata))
    }

    func setTargetTrackEncoding(trackId: String, encoding: TrackEncoding) {
        transport.send(event: SelectEncodingEvent(trackId: trackId, encoding: encoding.description))
    }

    func renegotiateTracks() {
        transport.send(event: RenegotiateTracksEvent())
    }

    func localCandidate(sdp: String, sdpMLineIndex: Int32) {
        transport.send(event: LocalCandidateEvent(candidate: sdp, sdpMLineIndex: sdpMLineIndex))
    }

    func sdpOffer(sdp: String, trackIdToTrackMetadata: [String: Metadata], midToTrackId: [String: String]) {
        transport.send(
            event: SdpOfferEvent(sdp: sdp, trackIdToTrackMetadata: trackIdToTrackMetadata, midToTrackId: midToTrackId))
    }

    func didReceive(event: ReceivableEvent) {
        switch event.type {
        case .PeerAccepted:
            let peerAccepted = event as! PeerAcceptedEvent
            engineListener.onPeerAccepted(peerId: peerAccepted.data.id, peersInRoom: peerAccepted.data.peersInRoom)
        case .PeerJoined:
            let peerJoined = event as! PeerJoinedEvent
            engineListener.onPeerJoined(peer: peerJoined.data.peer)
        case .PeerLeft:
            let peerLeft = event as! PeerLeftEvent
            engineListener.onPeerLeft(peerId: peerLeft.data.peerId)
        case .PeerUpdated:
            let peerUpdated = event as! PeerUpdateEvent
            engineListener.onPeerUpdated(peerId: peerUpdated.data.peerId, peerMetadata: peerUpdated.data.metadata)
        case .PeerRemoved:
            let peerRemoved = event as! PeerRemovedEvent
            engineListener.onRemoved(peerId: peerRemoved.data.peerId, reason: peerRemoved.data.reason)
        case .OfferData:
            let offerData = event as! OfferDataEvent
            engineListener.onOfferData(
                integratedTurnServers: offerData.data.integratedTurnServers, tracksTypes: offerData.data.tracksTypes)
        case .Candidate:
            let candidate = event as! RemoteCandidateEvent
            engineListener.onRemoteCandidate(
                candidate: candidate.data.candidate, sdpMLineIndex: candidate.data.sdpMLineIndex,
                sdpMid: candidate.data.sdpMid)
        case .TracksAdded:
            let tracksAdded = event as! TracksAddedEvent
            engineListener.onTracksAdded(
                peerId: tracksAdded.data.peerId, trackIdToMetadata: tracksAdded.data.trackIdToMetadata)
        case .TracksRemoved:
            let tracksRemoved = event as! TracksRemovedEvent
            engineListener.onTracksRemoved(peerId: tracksRemoved.data.peerId, trackIds: tracksRemoved.data.trackIds)
        case .TrackUpdated:
            let tracksUpdated = event as! TracksUpdatedEvent
            engineListener.onTrackUpdated(
                peerId: tracksUpdated.data.peerId, trackId: tracksUpdated.data.trackId,
                metadata: tracksUpdated.data.metadata)
        case .SdpAnswer:
            let sdpAnswer = event as! SdpAnswerEvent
            engineListener.onSdpAnswer(
                type: sdpAnswer.data.type, sdp: sdpAnswer.data.sdp, midToTrackId: sdpAnswer.data.midToTrackId)
        case .EncodingSwitched:
            let encodingSwitched = event as! EncodingSwitchedEvent
            engineListener.onTrackEncodingChanged(
                peerId: encodingSwitched.data.peerId, trackId: encodingSwitched.data.trackId,
                encoding: encodingSwitched.data.encoding, encodingReason: encodingSwitched.data.reason)
        case .VadNotification:
            let vadNotification = event as! VadNotificationEvent
            engineListener.onVadNotification(trackId: vadNotification.data.trackId, status: vadNotification.data.status)
        case .BandwidthEstimation:
            let bandwidthEstimation = event as! BandwidthEstimationEvent
            engineListener.onBandwidthEstimation(estimation: Int(bandwidthEstimation.data.estimation))
        default:
            sdkLogger.error("Failed to handle ReceivableEvent of type \(event.type)")
            return
        }
    }

    func didReceive(error: EventTransportError) {
        engineListener.onError(error: error)
    }
}
