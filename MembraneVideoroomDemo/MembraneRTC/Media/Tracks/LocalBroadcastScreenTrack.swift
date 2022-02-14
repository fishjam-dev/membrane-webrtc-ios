import WebRTC

public protocol LocalBroadcastScreenTrackDelegate: AnyObject {
    func started();
    func stopped();
    func paused();
    func resumed();
}

/// Utility wrapper around a local `RTCVideoTrack` also managing a `BroadcastScreenCapturer`.
public class LocalBroadcastScreenTrack: VideoTrack, LocalTrack, BroadcastScreenCapturerDelegate {
    
    private let videoSource: RTCVideoSource
    private let capturer: VideoCapturer
    private let track: RTCVideoTrack
    public weak var delegate: LocalBroadcastScreenTrackDelegate?
    
    
    internal init(delegate: LocalBroadcastScreenTrackDelegate? = nil) {
        self.videoSource = ConnectionManager.createVideoSource()
        self.track = ConnectionManager.createVideoTrack(source: self.videoSource)
        
        let capturer = BroadcastScreenCapturer(videoSource)
        self.capturer = capturer
        
        super.init()
        
        capturer.capturerDelegate = self
    }
    
    internal func started() {
        self.delegate?.started()
    }
    
    internal func stopped() {
        self.delegate?.stopped()
    }
    
    public func start() {
        self.capturer.startCapture()
    }
    
    public func stop() {
        self.capturer.stopCapture()
    }
    
    public func paused() {
        self.delegate?.paused()
    }
    
    public func resumed() {
        self.delegate?.resumed()
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

