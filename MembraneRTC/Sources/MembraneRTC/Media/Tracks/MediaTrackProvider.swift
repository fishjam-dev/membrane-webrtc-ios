import WebRTC

internal protocol MediaTrackProvider {
    func rtcTrack() -> RTCMediaStreamTrack
}
