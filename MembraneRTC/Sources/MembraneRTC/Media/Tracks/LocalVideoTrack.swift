import WebRTC

/// Utility wrapper around a local `RTCVideoTrack` also managing an instance of `VideoCapturer`
public class LocalVideoTrack: VideoTrack, LocalTrack {
    internal let videoSource: RTCVideoSource
    internal var capturer: VideoCapturer?
    private let track: RTCVideoTrack
    internal var simulcastConfig: SimulcastConfig
    

    public enum Capturer {
        case camera, file
    }

    internal init(simulcastConfig: SimulcastConfig, connectionManager: ConnectionManager) {
        let source = connectionManager.createVideoSource()

        videoSource = source
        track = connectionManager.createVideoTrack(source: source)
        
        self.simulcastConfig = simulcastConfig

        super.init()

        capturer = createCapturer(videoSource: source)
    }

    static func create(for capturer: Capturer, videoParameters: VideoParameters, simulcastConfig: SimulcastConfig, connectionManager: ConnectionManager) -> LocalVideoTrack {
        switch capturer {
        case .camera:
            return LocalCameraVideoTrack(parameters: videoParameters, simulcastConfig: simulcastConfig, connectionManager: connectionManager)
        case .file:
            return LocalFileVideoTrack(simulcastConfig: simulcastConfig, connectionManager: connectionManager)
        }
    }
    
    /**
        Use this to create a local track for preview etc.
        For local track that is sent to the backend use `createVideoTrack` from MembraneRTC
     
         - Parameters:
            - videoParameters: The parameters used for choosing the proper camera resolution and target framerate
     */
    public static func create(videoParameters: VideoParameters) -> LocalVideoTrack {
        return create(for: .camera, videoParameters: videoParameters, simulcastConfig: SimulcastConfig(), connectionManager: ConnectionManager(encoder: .DEFAULT))
    }

    internal func createCapturer(videoSource _: RTCVideoSource) -> VideoCapturer {
        fatalError("Basic LocalVideoTrack does not provide a default capturer")
    }
    
    public var trackID: String { track.trackId }

    public func start() {
        capturer?.startCapture()
    }

    public func stop() {
        capturer?.stopCapture()
    }

    public func enabled() -> Bool {
        return track.isEnabled
    }
    
    public func setEnabled(_ enabled: Bool) {
        track.isEnabled = enabled
    }
    
    public func trackId() -> String {
        return track.trackId
    }

    override func rtcTrack() -> RTCMediaStreamTrack {
        return track
    }
}

public class LocalCameraVideoTrack: LocalVideoTrack {
    private let videoParameters: VideoParameters
    
    init(parameters: VideoParameters, simulcastConfig: SimulcastConfig, connectionManager: ConnectionManager) {
        self.videoParameters = parameters
        super.init(simulcastConfig: simulcastConfig, connectionManager: connectionManager)
    }
    
    override internal func createCapturer(videoSource: RTCVideoSource) -> VideoCapturer {
        return CameraCapturer(videoParameters: videoParameters, delegate: videoSource)
    }

    public func switchCamera() {
        guard let capturer = capturer as? CameraCapturer else {
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
