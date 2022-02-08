import WebRTC

/// `VideoCapturer` responsible for capturing device's camera.
class CameraCapturer: VideoCapturer {
    private let capturer: RTCCameraVideoCapturer
    
    init(_ delegate: RTCVideoCapturerDelegate) {
        self.capturer = RTCCameraVideoCapturer(delegate: delegate)
    }
    
    public func startCapture() {
        let devices = RTCCameraVideoCapturer.captureDevices()
        
        guard let frontCamera = devices.first(where: { $0.position == .front }) else {
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
            // FIXME: we need more graceful handling of errors than fatal one
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
            // FIXME: we need more graceful handling of errors than fatal one
            fatalError("unsported requested frame rate of (\(minFps) - \(maxFps)")
        }
        
        self.capturer.startCapture(with: frontCamera,
                                   format: selectedFormat,
                                   fps: fps)
    }
    
    public func stopCapture() {
        self.capturer.stopCapture()
    }
}
