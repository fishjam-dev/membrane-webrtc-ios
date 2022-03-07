import WebRTC

public protocol LocalBroadcastScreenTrackDelegate: AnyObject {
    func started()
    func stopped()
    func paused()
    func resumed()
}

/// Utility wrapper around a local `RTCVideoTrack` also managing a `BroadcastScreenCapturer`.
public class LocalBroadcastScreenTrack: VideoTrack, LocalTrack, BroadcastScreenCapturerDelegate {
    private let videoSource: RTCVideoSource
    private let capturer: VideoCapturer
    private let track: RTCVideoTrack
    public weak var delegate: LocalBroadcastScreenTrackDelegate?

    internal init(appGroup: String, videoParameters: VideoParameters, delegate _: LocalBroadcastScreenTrackDelegate? = nil) {
        videoSource = ConnectionManager.createVideoSource()
        track = ConnectionManager.createVideoTrack(source: videoSource)

        let capturer = BroadcastScreenCapturer(videoSource, appGroup: appGroup, videoParameters: videoParameters)
        self.capturer = capturer

        super.init()

        capturer.capturerDelegate = self
    }

    internal func started() {
        delegate?.started()
    }

    internal func stopped() {
        delegate?.stopped()
    }

    public func start() {
        capturer.startCapture()
    }

    public func stop() {
        capturer.stopCapture()
    }

    public func paused() {
        delegate?.paused()
    }

    public func resumed() {
        delegate?.resumed()
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
