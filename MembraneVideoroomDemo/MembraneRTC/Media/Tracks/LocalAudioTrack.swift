import WebRTC

/// Utility wrapper around a local `RTCAudioTrack` managing a local audio session.
public class LocalAudioTrack: AudioTrack, LocalTrack {
    public let track: RTCAudioTrack
    
    private let config: RTCAudioSessionConfiguration
    
    internal override init() {
        let constraints: [String: String] = [
            "googEchoCancellation": "true",
            "googAutoGainControl":  "true",
            "googNoiseSuppression": "true",
            "googTypingNoiseDetection": "true",
            "googHighpassFilter": "true"
        ]
        
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: constraints)
        
        self.config = RTCAudioSessionConfiguration.webRTC()
        self.config.category = AVAudioSession.Category.playAndRecord.rawValue
        self.config.mode = AVAudioSession.Mode.videoChat.rawValue
        self.config.categoryOptions = AVAudioSession.CategoryOptions.duckOthers
        
        let audioSource = ConnectionManager.createAudioSource(audioConstraints)
        
        let track = ConnectionManager.createAudioTrack(source: audioSource)
        track.isEnabled = true
        
        self.track = track
    }
    
    public func start() {
        configure(setActive: true)
    }
    
    public func stop() {
        configure(setActive: false)
    }
    
    public func toggle() {
        self.track.isEnabled = !self.track.isEnabled
    }
    
    public func enabled() -> Bool {
        return self.track.isEnabled
    }
    
    override func rtcTrack() -> RTCMediaStreamTrack {
        return self.track
    }
    
    private func configure(setActive: Bool) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        defer { audioSession.unlockForConfiguration() }
        
        do {
            try audioSession.setConfiguration(self.config, active: setActive)
        } catch {
            sdkLogger.error("Failed to set configuration for audio session")
        }
    }
}
