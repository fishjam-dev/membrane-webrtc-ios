import WebRTC

/// Utility wrapper around a local `RTCVideoTrack` also managing an instance of `VideoCapturer`
public class LocalVideoTrack: VideoTrack, LocalTrack {
    private let videoSource: RTCVideoSource
    internal var capturer: VideoCapturer?
    private let track: RTCVideoTrack
    
    public enum Capturer {
        case camera, file
    }
    
    internal override init() {
        let source = ConnectionManager.createVideoSource()
        
        self.videoSource = source
        self.track = ConnectionManager.createVideoTrack(source: source)
        
        super.init()
        
        self.capturer = self.createCapturer(videoSource: source)
    }
    
    public static func create(for capturer: Capturer) -> LocalVideoTrack {
        switch capturer {
        case .camera:
            return LocalCameraVideoTrack()
        case .file:
            return LocalFileVideoTrack()
        }
    }
    
    internal func createCapturer(videoSource: RTCVideoSource) -> VideoCapturer {
        fatalError("Basic LocalVideoTrack does not provide a default capturer")
    }
    
    public func start() {
        self.capturer?.startCapture()
    }
    
    public func stop() {
        self.capturer?.stopCapture()
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

public class LocalCameraVideoTrack: LocalVideoTrack {
    override internal func createCapturer(videoSource: RTCVideoSource) -> VideoCapturer {
        return CameraCapturer(videoSource)
    }
    
    public func switchCamera() {
        guard let capturer = self.capturer as? CameraCapturer else {
            return
        }
        
        capturer.switchCamera()
    }
}

public class LocalFileVideoTrack: LocalVideoTrack {
    override internal func createCapturer(videoSource: RTCVideoSource) -> VideoCapturer {
        return FileCapturer(videoSource)
    }
}
