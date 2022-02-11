import WebRTC

/// Utility wrapper around a remote `RTCVideoTrack`
public class RemoteVideoTrack: VideoTrack, RemoteTrack {
    public let track: RTCVideoTrack
    
    init(track: RTCVideoTrack) {
        self.track = track
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
}
