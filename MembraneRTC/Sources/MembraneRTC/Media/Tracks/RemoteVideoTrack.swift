import WebRTC

/// Utility wrapper around a remote `RTCVideoTrack`
public class RemoteVideoTrack: VideoTrack, RemoteTrack {
    public let track: RTCVideoTrack

    init(track: RTCVideoTrack) {
        self.track = track
    }

    public func toggle() {
        track.isEnabled = !track.isEnabled
    }

    public func enabled() -> Bool {
        return track.isEnabled
    }

    override func rtcTrack() -> RTCMediaStreamTrack {
        return track
    }
}
