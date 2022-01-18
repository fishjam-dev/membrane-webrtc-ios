import Foundation
import WebRTC

public class MembraneRTC: ObservableObject {
    // TODO: this should have a better documentation
    
    static let version = "0.1.0"
    
    
    var transport: EventTransport
    var delegate: MembraneRTCDelegate
    var config: RTCConfiguration
    
    var connection: RTCPeerConnection?
    
    // TODO: this should be a separate type to hide the RTCVideoTrack type
    @Published public var localVideoTrack: LocalVideoTrack?
    
    public static func connect() {
        print("Connecting...");
    }

    public init(delegate: MembraneRTCDelegate, eventTransport: EventTransport, config: RTCConfiguration) {
        self.transport = eventTransport;
        self.delegate = delegate;
        self.config = config;
        
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherCOntinually
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        guard let peerConnection = ConnectionManager.createPeerConnection(config, constraints: constraints) else {
            fatalError(message: "Failed to initialize new PeerConnection")
        }
        
        self.connection = peerConnection
        self.connection.delegate = self
        
        self.setupMediaTrack()
    }
    
    private func setupMediaTracks() {
        let localStreamId = UUID().uuidString

        let audioTrack = self.createLocalAudioTrack()
        self.localVideoTrack = self.createLocalVideoTrack()

        // TODO: decide where this should start capturing...
        self.localVideoTrack.startCapture()
        
        self.connection.add(audioTrack, streamIds: [localStreamId])
        self.connection.add(self.localVideoTrack.track, streamIds: [localStreamId])
    }
}


// MARK: local media tracks
extension MembraneRTC {
    // TODO: this function should have a lot of options regarding noise cancellation ect.
    static func createLocalAudioTrack() -> RTCAudioTrack {
        let constraints = RTCMediaConstraints(mandatoryConstrains: nil, optionalConstraints: nil)

        let audioSource = ConnectionManager.createAudioSource(with: constraints)
        let audioTrack = ConnectionManager.createAudioTrack(source: audioSource)
        
        return audioTrack
    }
    
    static func createLocalScreensharingTrack() {
        print("hehe")
    }
}

extension MembraneRTC: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection did add stream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("peerConnection new connection state: \(newState)")
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        debugPrint("peerConnection new gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection did remove candidate(s)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
        self.remoteDataChannel = dataChannel
    }
}

extension MembraneRTC {
    
}


// I have no idea yet what is ogoing on
internal extension DispatchQueue {
    static let webRTC = DispatchQueue(label: "membrane.rtc.webRTC")
    static let sdk = DispatchQueue(label: "membrane.rtc.sdk")
}
