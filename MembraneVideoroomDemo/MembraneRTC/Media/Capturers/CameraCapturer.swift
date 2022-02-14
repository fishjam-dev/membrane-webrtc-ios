import WebRTC

/// `VideoCapturer` responsible for capturing device's camera.
class CameraCapturer: VideoCapturer {
    private let capturer: RTCCameraVideoCapturer
    private var isFront: Bool = true
    
    init(_ delegate: RTCVideoCapturerDelegate) {
        self.capturer = RTCCameraVideoCapturer(delegate: delegate)
    }
    
    public func startCapture() {
        if isFront {
            self.startCapturing(for: .front)
        } else {
            self.startCapturing(for: .back)
        }
    }
    
    public func stopCapture() {
        self.capturer.stopCapture()
    }
    
    public func switchCamera() {
        self.stopCapture()
        
        self.isFront = !self.isFront
        
        self.startCapture()
    }
    
    internal func startCapturing(for position: AVCaptureDevice.Position) {
        let devices = RTCCameraVideoCapturer.captureDevices()
        
        guard let frontCamera = devices.first(where: { $0.position == position }) else {
            return
        }
        
        let formats: Array<AVCaptureDevice.Format> = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        
        let parameters = VideoParameters.presetHD169
        let (targetWidth, targetHeight) = (parameters.dimensions.width,
                                           parameters.dimensions.height)

        var currentDiff = Int32.max
        var selectedFormat: AVCaptureDevice.Format = formats[0]
        var selectedDimension: Dimensions?
        for format in formats {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            let diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
                selectedDimension = dimension
            }
        }
        
        guard let dimension = selectedDimension else {
            fatalError("Could not get dimensions for video capture")
        }
        
        sdkLogger.info("CameraCapturer selected dimensions of \(dimension)")

        let fps = parameters.encoding.maxFps

        // discover FPS limits
        var minFps = 60
        var maxFps = 0
        for fpsRange in selectedFormat.videoSupportedFrameRateRanges {
            minFps = min(minFps, Int(fpsRange.minFrameRate))
            maxFps = max(maxFps, Int(fpsRange.maxFrameRate))
        }
        if fps < minFps || fps > maxFps {
            fatalError("unsported requested frame rate of (\(minFps) - \(maxFps)")
        }
        
        self.capturer.startCapture(with: frontCamera,
                                   format: selectedFormat,
                                   fps: fps)
    }
}
