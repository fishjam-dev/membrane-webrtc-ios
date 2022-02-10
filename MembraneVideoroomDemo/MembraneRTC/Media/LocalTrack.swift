import WebRTC

public protocol LocalTrack {
    func start();
    func stop();
    func toggle();
    func rtcTrack() -> RTCMediaStreamTrack;
}

public enum LocalTrackType {
    case audio, video, screensharing
}
