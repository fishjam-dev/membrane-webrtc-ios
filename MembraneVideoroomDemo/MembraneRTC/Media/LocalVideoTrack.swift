



public class LocalVideoTrack {
    private let videoSource: RTCVideoSource
    public internal(set) let capturer: VideoCapturer
    public internal(set) let track: RTCVideoTrack
    
    enum Capturer {
        case camera, screensharing
    }
    
    internal init(capturer: Capturer) {
        self.videoSource = ConnectionManager.createVideoSource()

        self.capturer = { 
            switch capturer {
                case .camera:
                  return CameraCapture(delegate: self.videoSource)
                case .screensharing:
                    fatalError(message: "Not implemented")
            }
        }()
        
        self.track = ConnectionManager.videoTrack(with: self.capturer)
    }
    
    func start() {
        self.capturer.startCapture()
    }
    
    func stop() {
        self.capturer.stopCapture()
    }
}

