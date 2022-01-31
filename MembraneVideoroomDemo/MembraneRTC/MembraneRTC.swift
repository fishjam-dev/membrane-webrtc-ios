import Foundation
import WebRTC
import Logging

internal var sdkLogger = Logger(label: "org.membrane.ios")

// TODO: document anything for your owns sake...
public class MembraneRTC: MulticastDelegate<MembraneRTCDelegate>, ObservableObject {
    static let version = "0.1.0"
    
    enum State {
        case uninitialized
        case connected
        case disconnected
    }
    
    
    var state: State
    var transport: EventTransport
    
    // RTC related stuff
    var config: RTCConfiguration
    var connection: RTCPeerConnection?
    
    @Published public var localVideoTrack: LocalVideoTrack?
    @Published public var localScreensharingVideoTrack: LocalVideoTrack?
    @Published public var localAudioTrack: LocalAudioTrack?
    
    var localPeer = Peer(id: "", metadata: [:], trackIdToMetadata: [:])
    
    // mapping from peer's id to itself
    var remotePeers: [String: Peer] = [:]
    
    // mapping from remote track's id to its context
    var trackContexts: [String: TrackContext] = [:]
    
    // mapping from transceiver's mid to its remote track id
    var midToTrackId: [String: String] = [:]
    
    public init(eventTransport: EventTransport, config: RTCConfiguration) {
//        RTCSetMinDebugLogLevel(.error)
        sdkLogger.logLevel = .debug
        
        self.state = .uninitialized
        self.transport = eventTransport
        self.config = config
        
        super.init()
    }
    
    public func join(metadata: Metadata) {
        self.transport.sendEvent(event: Events.joinEvent(metadata: metadata))
    }
    
    public func connect() {
        // initiate a transport connection
        self.transport.connect(delegate: self).then {
            self.notify {
                $0.onConnected()
            }
        }.catch { error in
            self.notify {
                $0.onConnectionError(message: error.localizedDescription)
            }
        }
        
        let config = self.config
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.candidateNetworkPolicy = .all
        config.disableIPV6 = true
        config.tcpCandidatePolicy = .disabled
        config.iceTransportPolicy = .all
        
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        guard let peerConnection = ConnectionManager.createPeerConnection(config, constraints: constraints) else {
            fatalError("Failed to initialize new PeerConnection")
        }
        
        peerConnection.delegate = self
        self.connection = peerConnection
        
        self.setupMediaTracks()
        
        // sever does not accept sendRecv direction so change all local tracks to sendOnly
        peerConnection.transceivers.forEach { tc in
            if tc.direction == .sendRecv {
                tc.setDirection(.sendOnly, error: nil)
            }
        }
    }
    
    public func disconnect() {
        self.transport.disconnect()
        
        if let pc = self.connection {
            pc.close()
        }
    }
    
    // TODO: this is just a pure mock, refactor it once physical device becomes available
    public func startScreensharing() -> LocalVideoTrack? {
        guard let pc = self.connection else {
            return nil
        }
        
        let localStreamId = UUID().uuidString
        
        let screensharingTrack = LocalVideoTrack(capturer: .screensharing)
        screensharingTrack.start()
        
        pc.add(screensharingTrack.track, streamIds: [localStreamId])
        
        // TODO: decide if all of those functions should be run on the webRTC queue
        pc.transceivers.forEach { transceiver in
            if transceiver.direction == .sendRecv {
                transceiver.setDirection(.sendOnly, error: nil)
            }
        }
        
        self.transport.sendEvent(event: RenegotiateTracksEvent())
        self.localScreensharingVideoTrack = screensharingTrack
        
        // add track's metadata and set the type to screensharing to indicate it to other clients
        self.localPeer.trackIdToMetadata?[screensharingTrack.track.trackId] = ["type": "screensharing"]
        
        return screensharingTrack
    }
    
    public func stopScreensharing() {
        guard
            let pc = self.connection,
            let screensharing = self.localScreensharingVideoTrack else {
            return
        }
        
        // stop capturing the screen
        screensharing.stop()
        
        // remove screensharing's track from peer connection and trigger renegotiation
        if let sender = pc.senders.first(where: { sender in
            sender.track?.trackId == screensharing.track.trackId
        }) {
            pc.removeTrack(sender)
            screensharing.track.isEnabled = false
            
            self.localScreensharingVideoTrack = nil
            self.transport.sendEvent(event: RenegotiateTracksEvent())
        }
    }
    
    // sets up both local video and audio tracks
    private func setupMediaTracks() {
        guard let pc = self.connection else {
            return
        }
        
        let localStreamId = UUID().uuidString
        
        let videoTrack = LocalVideoTrack(capturer: .file)
        
        videoTrack.start()
        pc.add(videoTrack.track, streamIds: [localStreamId])
        
        self.localVideoTrack = videoTrack
        
        let audioTrack = LocalAudioTrack()
        audioTrack.start()
        pc.add(audioTrack.track, streamIds: [localStreamId])
        self.localAudioTrack = audioTrack
        
        self.localPeer.trackIdToMetadata = [
            videoTrack.track.trackId: [:],
            // for now the audio track does not relay any media as microphone does not work on a simulator
            audioTrack.track.trackId: [:]
        ]
    }
}

extension MembraneRTC: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        sdkLogger.info("peerConnection new stream added")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        sdkLogger.info("peerConnection stream has been removed")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let descriptions: [RTCSignalingState: String] = [
         .haveLocalOffer: "have local offer",
         .haveRemoteOffer: "have remote offer",
         .haveLocalPrAnswer: "have local pr answer",
         .haveRemotePrAnswer: "have remote pr answer",
         .stable: "stable",
         .closed: "closed",
        ]
        
        sdkLogger.debug("peerConnection changed signaling state to \(descriptions[stateChanged] ?? "unknown")")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        guard let trackId = self.midToTrackId[transceiver.mid],
            var trackContext = self.trackContexts[trackId] else {
                print("HEEEEEJO")
            sdkLogger.error("peerConnection started receiving on a transceiver with an unknown 'mid' parameter or without registered track context")
            return
        }
        
        // assign receiving track to given track's context
        trackContext.track = transceiver.receiver.track
        self.trackContexts[trackId] = trackContext
        
        self.notify {
            $0.onTrackReady(ctx: trackContext)
        }
        
        sdkLogger.debug("peerConnection started receiving on a transceiver with a mid: \(transceiver.mid) and id \(transceiver.receiver.track?.trackId ?? "" )")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection,
                               didAdd  receiver: RTCRtpReceiver, streams mediaStreams: Array<RTCMediaStream>) {
        sdkLogger.info("peerConnection new receiver has been added: \(receiver.receiverId)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove  rtpReceiver: RTCRtpReceiver) {
        sdkLogger.info("peerConnection receiver has been removed: \(rtpReceiver.receiverId)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChangeLocalCandidate  local: RTCIceCandidate, remoteCandidate remote: RTCIceCandidate, lastReceivedMs lastDataReceivedMs: Int32, changeReason reason: String) {
        sdkLogger.debug("peerConnection a local candidate has been changed due to: '\(reason)'\nlocal: \(local.sdp)\nremote: \(remote.sdp)")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        sdkLogger.debug("peerConnection should negotiate")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let descriptions: [RTCIceConnectionState: String] = [
            .new: "new",
            .checking: "checking",
            .connected: "connected",
            .closed: "closed",
            .completed: "completed",
            .disconnected: "disconnected",
            .failed: "failed",
            .count: "count",
        ]
        
        sdkLogger.debug("peerConnection new connection state: \(descriptions[newState] ?? "unknown")")
        
        switch newState {
        case .connected:
            self.state = .connected
        case .disconnected:
            self.state = .disconnected
        default:
            break
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let descriptions: [RTCIceGatheringState: String] = [
            .new: "new",
            .gathering: "gathering",
            .complete: "complete",
        ]
        
        sdkLogger.debug("peerConnection new ice gathering state: \(descriptions[newState] ?? "unknown")")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DispatchQueue.webRTC.async {
            self.onLocalCandidate(candidate)
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        sdkLogger.debug("peerConnection a list of candidates has been removed")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) { }
}

extension MembraneRTC: EventTransportDelegate {
    public func receiveEvent(event: ReceivableEvent) {
        switch event.type {
        case .PeerAccepted:
            let peerAccepted = event as! PeerAcceptedEvent
            
            self.localPeer.id = peerAccepted.data.id
            
            // initialize all present peers
            peerAccepted.data.peersInRoom.forEach { peer in
                self.remotePeers[peer.id] = peer
                
                // initialize peer's track contexts
                peer.trackIdToMetadata?.forEach { trackId, metadata in
                    let context = TrackContext(track: nil, stream: nil, peer: peer, trackId: trackId, metadata: metadata)
                    
                    self.trackContexts[trackId] = context
                    
                    self.notify {
                        $0.onTrackAdded(ctx: context)
                    }
                }
            }
            
            self.notify {
                $0.onJoinSuccess(peerID: peerAccepted.data.id, peersInRoom: peerAccepted.data.peersInRoom)
            }
            
        case .PeerJoined:
            let peerJoined = event as! PeerJoinedEvent
            
            guard peerJoined.data.peer.id != self.localPeer.id else {
                return
            }
            
            self.remotePeers[peerJoined.data.peer.id] = peerJoined.data.peer
            
            self.notify {
                $0.onPeerJoined(peer: peerJoined.data.peer)
            }
            
            
        case .PeerLeft:
            let peerLeft = event as! PeerLeftEvent
            
            guard let peer = remotePeers[peerLeft.data.peerId] else {
                return
            }
            
            remotePeers.removeValue(forKey: peer.id)
            
            // for a leaving peer clear his track contexts
            if let trackIdToMetadata = peer.trackIdToMetadata {
                let trackIds = Array(trackIdToMetadata.keys)
                
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
            
            self.notify {
                $0.onPeerLeft(peer: peer)
            }
            
        case .PeerUpdated:
            let peerUpdated = event as! PeerUpdateEvent
            
            // TODO: check if the mutibility breaks anything here
            guard var peer = remotePeers[peerUpdated.data.peerId] else {
                return
            }
            
            
            peer.metadata = peerUpdated.data.metadata
            remotePeers.updateValue(peer, forKey: peer.id)
            
            self.notify {
                $0.onPeerUpdated(peer: peer)
            }
            
        case .OfferData:
            let offerData = event as! OfferDataEvent
            
            DispatchQueue.webRTC.async {
                self.onOfferData(offerData)
            }
            
        case .SdpAnswer:
            let sdpAnswer = event as! SdpAnswerEvent
            
            DispatchQueue.webRTC.async {
                self.onSdpAnswer(sdpAnswer)
            }
            
            
        case .Candidate:
            let candidate = event as! RemoteCandidateEvent
            
            DispatchQueue.webRTC.async {
                self.onRemoteCandidate(candidate)
            }
            
        case .TracksAdded:
            let tracksAdded = event as! TracksAddedEvent
            
            // ignore local participant
            guard self.localPeer.id != tracksAdded.data.peerId else {
                return
            }
            
            guard var peer = self.remotePeers[tracksAdded.data.peerId] else {
                return
            }
            
            // update tracks for the peer
            peer.trackIdToMetadata = tracksAdded.data.trackIdToMetadata
            self.remotePeers[peer.id] = peer
            
            // for each track create a corresponding track context
            peer.trackIdToMetadata?.forEach { trackId, metadata in
                let context = TrackContext(track: nil, stream: nil, peer: peer, trackId: trackId, metadata: metadata)
                
                self.trackContexts[trackId] = context
                
                self.notify {
                    $0.onTrackAdded(ctx: context)
                }
            }
            
        case .TracksRemoved:
            let tracksRemoved = event as! TracksRemovedEvent
            
            guard let _ = self.remotePeers[tracksRemoved.data.peerId] else {
                return
            }
            
            // for each track clear its context and notify delegates
            tracksRemoved.data.trackIds.forEach { id in
                guard let context = self.trackContexts[id] else {
                    return
                }
                
                // TODO: there are more fields to clear than just the track context mate...
                self.trackContexts.removeValue(forKey: id)
                
                self.notify {
                    $0.onTrackRemoved(ctx: context)
                }
            }
        
        default:
            sdkLogger.error("Failed to handle ReceivableEvent of type \(event.type)")
            
            return
        }
    }
    
}

extension MembraneRTC {
    func onOfferData(_ offerData: OfferDataEvent) {
        guard let pc = self.connection else {
            return
        }
        
        self.addNecessaryTransceivers(offerData)
        
        if self.state == .connected {
            pc.restartIce()
        }
        
        // TODO: why do we event need constanits here if we passed them when creating a peer connection
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        pc.offer(for: constraints, completionHandler: { offer, error in
            guard let offer = offer else {
                return
            }
            
            pc.setLocalDescription(offer, completionHandler: { error in
                guard let err = error else {
                    self.transport.sendEvent(event: SdpOfferEvent(sdp: offer.sdp, trackIdToTrackMetadata: self.localPeer.trackIdToMetadata ?? [:], midToTrackId: self.getMidToTrackId()))
                    return
                }
                
                sdkLogger.error("error occured while setting a local description: \(err)")
            })
        })
    }
    
    private func addNecessaryTransceivers(_ offerData: OfferDataEvent) {
        guard let pc = self.connection else {
            return
        }
        
        let necessaryAudio = offerData.data.tracksTypes["audio"] ?? 0
        let necessaryVideo = offerData.data.tracksTypes["video"] ?? 0
        
        var lackingAudio: Int = necessaryAudio
        var lackingVideo: Int = necessaryVideo
        
        pc.transceivers.filter {
            $0.direction == .recvOnly
        }.forEach { transceiver in
            guard let track = transceiver.receiver.track else {
                return
            }
            
            switch track.kind {
            case "audio": lackingAudio -= 1
            case "video": lackingVideo -= 1
            default:
                break
                
            }
        }
        
        sdkLogger.debug("peerConnection adding \(lackingAudio) audio and \(lackingVideo) video lacking transceivers")
        
        for _ in 0..<lackingAudio {
            pc.addTransceiver(of: .audio)?.setDirection(.recvOnly, error: nil)
        }
        
        for _ in 0..<lackingVideo {
            pc.addTransceiver(of: .video)?.setDirection(.recvOnly, error: nil)
        }
    }
    
    private func getMidToTrackId() -> [String: String] {
        guard let pc = self.connection,
              let localTracksKeys = self.localPeer.trackIdToMetadata?.keys else {
            return [:]
        }
        
        let localTracks: Array<String> = Array(localTracksKeys)
        
        var mapping: [String: String] = [:]
        
        
        pc.transceivers.forEach { transceiver in
            guard let trackId: String = transceiver.sender.track?.trackId,
                  localTracks.contains(trackId) else {
                      return
              }
            mapping[transceiver.mid] = trackId
        }
        
        return mapping
        
    }
    
    func onSdpAnswer(_ sdpAnswer: SdpAnswerEvent) {
        guard let pc = self.connection else {
            return
        }
        
        self.midToTrackId = sdpAnswer.data.midToTrackId
        
        let description = RTCSessionDescription(type: .answer, sdp: sdpAnswer.data.sdp)
        
        pc.setRemoteDescription(description, completionHandler: { error in
            guard let err = error else {
                return
            }
            
            sdkLogger.error("error occured while trying to set a remote description \(err)")
        })
    }
    
    func onRemoteCandidate(_ remoteCandidate: RemoteCandidateEvent) {
        guard let pc = self.connection else {
            return
        }
        
        let candidate = RTCIceCandidate(sdp: remoteCandidate.data.candidate, sdpMLineIndex: remoteCandidate.data.sdpMLineIndex, sdpMid: remoteCandidate.data.sdpMid)
        
        pc.add(candidate, completionHandler: { error in
            guard let err = error else {
                return
            }
            
            sdkLogger.error("error occured  during remote ice candidate processing: \(err)")
        })
    }
    
    func onLocalCandidate(_ candidate: RTCIceCandidate) {
        self.transport.sendEvent(event: LocalCandidateEvent(candidate: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex))
    }
}

internal extension DispatchQueue {
    static let webRTC = DispatchQueue(label: "membrane.rtc.webRTC")
    static let sdk = DispatchQueue(label: "membrane.rtc.sdk")
}
