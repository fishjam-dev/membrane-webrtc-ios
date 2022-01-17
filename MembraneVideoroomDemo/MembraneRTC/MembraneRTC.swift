import Foundation
import WebRTC

public class MembraneRTC: ObservableObject {
    // TODO: this should have a better documentation
    
    static let version = "0.1.0"
    
    
    var transport: EventTransport
    var delegate: MembraneRTCDelegate
    var config: RTCConfiguration
    
    var connection: RTCPeerConnection?
    var localVideoTrack: RTCVideoTrack?
    
    var localVideoCapturer: RTCVideoCapturer?

    // TODO: this should be a separate type to hide the RTCVideoTrack type
    @Published public var localVideoFeed: RTCVideoTrack?
    
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
        
        self.connection.add(audioTrack, streamIds: [localStreamId])
        self.connection.add(self.localVideoTrack, streamIds: [localStreamId])
    }
    
    // this function is responsible for capturing starting video capture and attaching it to a renderer
    public func startCapturingLocalVideo(renderer: RTCVideoRenderer) {
        guard let capturer = self.localVideoCapturer as? RTCCameraVideoCapturer else {
            return
        }

        guard
           let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
        
           // choose highest res
           let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
               let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
               let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
               return width1 < width2
           }).last,
        
           // choose highest fps
           let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
           return
        }

        capturer.startCapture(with: frontCamera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
        
        self.localVideoTrack?.add(renderer)
        
        // this should trigger the UI change when somebody listens for room changes...
        self.localVideoFeed = self.localVideoTrack
        

        // FIXME: I have no idea if this is event possible or if it will work to be honest...
        return self.localVideoFeed
        
    }
    
    // func addTrack(track: RTCMediaStreamTrack, stream: RTCMediaStream, trackMetadata: Dictionary<String, Any>) -> String {
    //     if let pc = connection {
    //         pc.add(track, streamIds: [stream.streamId]);
            
    //         pc.transceivers.forEach { transceiver in
    //             // in case any of transceivers' directions are of 'sendrecv' change them to 'sendonly'
    //             var error: NSError?;
    //             transceiver.setDirection(transceiver.direction == RTCRtpTransceiverDirection.sendRecv ? RTCRtpTransceiverDirection.sendOnly : transceiver.direction, error: &error);
    //             // TODO: maybe do something with the error
    //         }
            
    //     }
    //     return ""
    // }
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
    
    static func createLocalVideoTrack() -> RTCVideoTrack {
        let videoSource = ConnectionManager.createVideoSource()

        #if targetEnvironment(simulator)
            // TODO: read how this event works
            // videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
            self.localVideoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #else
            self.localVideoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        let videoTrack = ConnectionManager.videoTrack(with: self.localVideoCapturer)

        return videoTrack
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
