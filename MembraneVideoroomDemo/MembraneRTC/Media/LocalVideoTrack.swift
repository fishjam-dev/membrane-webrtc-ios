import WebRTC

public class LocalVideoTrack {
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
                fatalError("Not implemented")
        }
        
        self.track = ConnectionManager.createVideoTrack(source: self.videoSource)
    }
    
    func start() {
        self.capturer.startCapture()
    }
    
    func stop() {
        self.capturer.stopCapture()
    }
}

