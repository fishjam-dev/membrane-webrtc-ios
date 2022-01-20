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
    
    
    // TODO: this should be a separate type to hide the RTCVideoTrack type
    @Published public var localVideoTrack: LocalVideoTrack?

    public init(delegate: MembraneRTCDelegate, eventTransport: EventTransport, config: RTCConfiguration) {
        self.transport = eventTransport;
        self.delegate = delegate;
        self.config = config;
        
        super.init()
        
        self.transport.connect(delegate: self).then {
            self.transport.sendEvent(event: Events.joinEvent())
        }
        
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
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

        let audioTrack = Self.createLocalAudioTrack()
        
        let videoTrack = LocalVideoTrack(capturer: .screensharing)

        // TODO: decide where this should start capturing...
        videoTrack.start()
        
        pc.add(audioTrack, streamIds: [localStreamId])
        pc.add(videoTrack.track, streamIds: [localStreamId])
        self.localVideoTrack = videoTrack
    }
}


// MARK: local media tracks
extension MembraneRTC {
    // TODO: this function should have a lot of options regarding noise cancellation ect.
    static func createLocalAudioTrack() -> RTCAudioTrack {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        let audioSource = ConnectionManager.createAudioSource(constraints)
        let audioTrack = ConnectionManager.createAudioTrack(source: audioSource)
        
        return audioTrack
    }
    
    static func createLocalScreensharingTrack() {
        fatalError("Not implemented")
    }
}

extension MembraneRTC: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection did add stream")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("peerConnection new connection state: \(newState)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        debugPrint("peerConnection new gathering state: \(newState)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        debugPrint("Peer connection generated new candidate: \(candidate)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection did remove candidate(s)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
    }
}

extension MembraneRTC: EventTransportDelegate {
    public func receiveEvent(event: ReceivableEvent) {
        debugPrint("Receiving event", event)
    }
    
}


// I have no idea yet what is ogoing on
internal extension DispatchQueue {
    static let webRTC = DispatchQueue(label: "membrane.rtc.webRTC")
    static let sdk = DispatchQueue(label: "membrane.rtc.sdk")
}
