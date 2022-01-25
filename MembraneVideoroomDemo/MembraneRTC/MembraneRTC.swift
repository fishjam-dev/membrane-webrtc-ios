import Foundation
import WebRTC

public class MembraneRTC: NSObject, ObservableObject {
    // TODO: this should have a better documentation
    
    static let version = "0.1.0"
    
    
    var transport: EventTransport
    // TODO: this delegate should be a weak reference
    var delegate: MembraneRTCDelegate
    var config: RTCConfiguration
    
    var connection: RTCPeerConnection?
    var localPeer = Peer(id: "", metadata: [:], trackIdToMetadata: [:])
    
    var started: Bool
    
    
    // TODO: this should be a separate type to hide the RTCVideoTrack type
    @Published public var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?

    public init(delegate: MembraneRTCDelegate, eventTransport: EventTransport, config: RTCConfiguration) {
        RTCSetMinDebugLogLevel(.error)
        
        self.transport = eventTransport;
        self.delegate = delegate;
        self.config = config;
        self.started = false
        
        
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
//        pc.add(audioTrack.track, streamIds: [localStreamId])
        self.localAudioTrack = audioTrack
        
        
        print("Video track", videoTrack.track.trackId)
        print("Audio track", audioTrack.track.trackId)
        
        self.localPeer.trackIdToMetadata = [
            videoTrack.track.trackId: [:],
            // somehow audio track is not yet working on simulator...
            //            audioTrack.track.trackId: [:]
        ]
        
        // TODO: remove me, just for testing...
        pc.transceivers
            .compactMap { return $0.sender.track as? RTCAudioTrack }
                   .forEach { $0.isEnabled = true }
        
        pc.transceivers
            .compactMap { return $0.sender.track as? RTCVideoTrack }
                   .forEach { $0.isEnabled = true }
    }
    
    public func join(metadata: Metadata) {
        self.transport.sendEvent(event: Events.joinEvent(metadata: metadata))
    }
}

extension MembraneRTC: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        fatalError("called didAdd stream when only a unified-plan is supported")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        fatalError("called didRemove stream when only a unified-plan is supported")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("peerConnection new signaling state: \(stateChanged)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        print("peerConnection started receiving on transceiver", transceiver)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection,
                               didAdd  receiver: RTCRtpReceiver, streams mediaStreams: Array<RTCMediaStream>) {
        print("peerConnection added new receiver", receiver, "for streams", mediaStreams)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove  rtpReceiver: RTCRtpReceiver) {
        print("peerConnection removed a receiver")
        
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChangeLocalCandidate  local: RTCIceCandidate, remoteCandidate remote: RTCIceCandidate, lastReceivedMs lastDataReceivedMs: Int32, changeReason reason: String) {
        print("peerConnection local candidate has changed due to \(local.debugDescription), \(remote.debugDescription), \(reason)")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("peerConnection should negotiate")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        var stateName: String?
        
        
        switch newState {
        case .new:
            stateName = "new"
        case .checking:
            stateName = "checking"
        case .connected:
            stateName = "connected"
        case .closed:
            stateName = "closed"
        case .completed:
            stateName = "completed"
        case .disconnected:
            stateName = "disconnected"
        case .failed:
            stateName = "failed"
        case .count:
            stateName = "count"
        default:
            stateName = "unknown"
            
        }
        print("peerConnection new connection state: ", stateName!)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("peerConnection new gathering state: \(newState)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DispatchQueue.webRTC.async {
            self.onLocalCandidate(candidate)
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("peerConnection did remove candidate(s)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("peerConnection did open data channel")
    }
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
            print(event.type)
            return
        }
    }
    
}

extension MembraneRTC {
    
    func onOfferData(_ offerData: OfferDataEvent) {
        guard let pc = self.connection,
            started == false else {
            return
        }
        
        self.started = true
        
        // TODO: why do we event need constanits here if we passed them when creating a peer connection
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        // TODO: handle incoming track, the code below assumes that we just send the tracks without receiving any
        // for all outgoing transceivers we need to change direction to 'sendOnly'
        pc.transceivers.forEach { tc in
            if tc.direction == .sendRecv {
                tc.setDirection(.sendOnly, error: nil)
            }
        }
        
        
        pc.offer(for: constraints, completionHandler: { offer, error in
            guard let offer = offer else {
                return
            }
            
            pc.setLocalDescription(offer, completionHandler: { error in
                guard let err = error else {
                    self.transport.sendEvent(event: SdpOfferEvent(sdp: offer.sdp, trackIdToTrackMetadata: self.localPeer.trackIdToMetadata ?? [:], midToTrackId: self.getMidToTrackId()))
                    return
                }
                
                print("Error while setting local description", err)
            })
            
        })
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
            
            print("Failed to set remote description", err)
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
            
            print("Error while processing remote ice candidate", err)
        })
    }
    
    func onLocalCandidate(_ candidate: RTCIceCandidate) {
        self.transport.sendEvent(event: LocalCandidateEvent(candidate: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex))
    }
}


// I have no idea yet what is ogoing on
internal extension DispatchQueue {
    static let webRTC = DispatchQueue(label: "membrane.rtc.webRTC")
    static let sdk = DispatchQueue(label: "membrane.rtc.sdk")
}
