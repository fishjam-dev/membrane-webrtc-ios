import WebRTC

public protocol LocalTrack {
    func start();
    func stop();
    func toggle();
    func rtcTrack() -> RTCMediaStreamTrack;
}
