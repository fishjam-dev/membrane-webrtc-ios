import WebRTC

/// `VideoCapturer` responsible for capturing device's camera.
class CameraCapturer: VideoCapturer {
    private let videoParameters: VideoParameters
    private let capturer: RTCCameraVideoCapturer
    private var isFront: Bool = true

    init(videoParameters: VideoParameters, delegate: RTCVideoCapturerDelegate) {
        self.videoParameters = videoParameters
        self.capturer = RTCCameraVideoCapturer(delegate: delegate)
    }

    public func startCapture() {
        if isFront {
            startCapturing(for: .front)
        } else {
            startCapturing(for: .back)
        }
    }

    public func stopCapture() {
        capturer.stopCapture()
    }

    public func switchCamera() {
        stopCapture()

        isFront = !isFront

        startCapture()
    }

    internal func startCapturing(for position: AVCaptureDevice.Position) {
        let devices = RTCCameraVideoCapturer.captureDevices()

        guard let frontCamera = devices.first(where: { $0.position == position }) else {
            return
        }

        let formats: [AVCaptureDevice.Format] = RTCCameraVideoCapturer.supportedFormats(
            for: frontCamera)

        let (targetWidth, targetHeight) = (
            videoParameters.dimensions.width,
            videoParameters.dimensions.height
        )

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

        let fps = videoParameters.maxFps

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

        capturer.startCapture(
            with: frontCamera,
            format: selectedFormat,
            fps: fps)
    }
}
