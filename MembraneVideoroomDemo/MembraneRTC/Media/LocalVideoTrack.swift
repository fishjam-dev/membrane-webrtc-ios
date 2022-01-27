import WebRTC

public class LocalVideoTrack: LocalTrack {
    private let videoSource: RTCVideoSource
    private let capturer: VideoCapturer
    public let track: RTCVideoTrack
    
    enum Capturer {
        case camera, screensharing, file
    }
    
    internal init(capturer: Capturer) {
        self.videoSource = ConnectionManager.createVideoSource()
        
        switch capturer {
            case .camera:
                self.capturer = CameraCapturer(self.videoSource)
            case .file:
                self.capturer = FileCapturer(self.videoSource)
            case .screensharing:
                self.capturer = ScreenCapturer(self.videoSource)
        }
        
        self.track = ConnectionManager.createVideoTrack(source: self.videoSource)
    }
    
    public func start() {
        self.capturer.startCapture()
    }
    
    public func stop() {
        self.capturer.stopCapture()
    }
    
    public func toggle() {
        self.track.isEnabled = !self.track.isEnabled
    }
}

