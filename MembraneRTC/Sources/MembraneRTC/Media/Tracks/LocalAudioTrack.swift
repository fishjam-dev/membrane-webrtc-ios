import WebRTC

/// Utility wrapper around a local `RTCAudioTrack` managing a local audio session.
public class LocalAudioTrack: AudioTrack, LocalTrack {
    public let track: RTCAudioTrack

    private let config: RTCAudioSessionConfiguration

    internal init(connectionManager: ConnectionManager) {
        let constraints: [String: String] = [
            "googEchoCancellation": "true",
            "googAutoGainControl": "true",
            "googNoiseSuppression": "true",
            "googTypingNoiseDetection": "true",
            "googHighpassFilter": "true",
        ]

        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: constraints)

        config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.mode = AVAudioSession.Mode.videoChat.rawValue
        config.categoryOptions = AVAudioSession.CategoryOptions.duckOthers

        let audioSource = connectionManager.createAudioSource(audioConstraints)

        let track = connectionManager.createAudioTrack(source: audioSource)
        track.isEnabled = true

        self.track = track
    }

    public func start() {
        configure(setActive: true)
    }

    public func stop() {
        configure(setActive: false)
    }

    public func enabled() -> Bool {
        return track.isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        track.isEnabled = enabled
    }

    override func rtcTrack() -> RTCMediaStreamTrack {
        return track
    }

    public func trackId() -> String {
        return track.trackId
    }

    private func configure(setActive: Bool) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        defer { audioSession.unlockForConfiguration() }

        do {
            try audioSession.setConfiguration(config, active: setActive)
        } catch {
            sdkLogger.error("Failed to set configuration for audio session")
        }
    }

    private func setMode(mode: String) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        defer { audioSession.unlockForConfiguration() }

        do {
            config.mode = mode
            try audioSession.setConfiguration(config)
        } catch {
            sdkLogger.error("Failed to set configuration for audio session")
        }
    }

    /// Sets AVAudioSession configuration mode to voice chat
    /// (https://developer.apple.com/documentation/avfaudio/avaudiosession/mode/1616455-voicechat)
    public func setVoiceChatMode() {
        setMode(mode: AVAudioSession.Mode.voiceChat.rawValue)
    }

    /// Sets AVAudioSession configuration mode to video chat
    /// (https://developer.apple.com/documentation/avfaudio/avaudiosession/mode/1616590-videochat)
    public func setVideoChatMode() {
        setMode(mode: AVAudioSession.Mode.videoChat.rawValue)
    }
}
