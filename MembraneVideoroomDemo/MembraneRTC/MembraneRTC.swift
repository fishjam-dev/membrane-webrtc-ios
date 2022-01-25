import Foundation
import WebRTC
import Logging

internal var sdkLogger = Logger(label: "org.membrane.ios")

public class MembraneRTC: NSObject, ObservableObject {
    // TODO: this should have a better documentation
    
    
    enum State {
        case uninitialized
        case connected
        case disconnected
    }
    
    static let version = "0.1.0"
    
    
    var state: State
    var transport: EventTransport
    // TODO: this delegate should be a weak reference
    var delegate: MembraneRTCDelegate
    var config: RTCConfiguration
    
    var connection: RTCPeerConnection?
    var localPeer = Peer(id: "", metadata: [:], trackIdToMetadata: [:])
    
    
    // TODO: this should be a separate type to hide the RTCVideoTrack type
    @Published public var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    
    public init(delegate: MembraneRTCDelegate, eventTransport: EventTransport, config: RTCConfiguration) {
        RTCSetMinDebugLogLevel(.error)
        sdkLogger.logLevel = .debug
        
        self.state = .uninitialized
        self.transport = eventTransport;
        self.delegate = delegate;
        self.config = config;
        
        super.init()
        
        self.transport.connect(delegate: self).then {
            self.delegate.onConnected()
        }
        
        let config = RTCConfiguration()
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
            // somehow audio track is not yet working on simulator, and wont be, microphone has to be handled differently...
            audioTrack.track.trackId: [:]
        ]
    }
    
    public func join(metadata: Metadata) {
        self.transport.sendEvent(event: Events.joinEvent(metadata: metadata))
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
        sdkLogger.debug("peerConnection started receiving on a transceiver with a mid: \(transceiver.mid)")
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
            self.delegate.onJoinSuccess(peerID: peerAccepted.data.id, peersInRoom: peerAccepted.data.peersInRoom)
            
        case .PeerJoined:
            let peerJoined = event as! PeerJoinedEvent
            guard peerJoined.data.peer.id != self.localPeer.id else {
                return
            }
            
            self.delegate.onPeerJoined(peer: peerJoined.data.peer)
            
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
        
        for _ in 0..<lackingAudio {
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
