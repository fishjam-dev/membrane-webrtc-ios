import WebRTC

class CameraCapturer: VideoCapturer {
    private let capturer: RTCCameraVideoCapturer
    
    init(_ delegate: RTCVideoCapturerDelegate) {
        self.capturer = RTCCameraVideoCapturer(delegate: delegate)
    }
    
    public func startCapture() {
        guard
           let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
        
           // choose highest res
           let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
               let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
               let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
               return width1 < width2
           }).last,
        
           // choose highest fps
           let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
           return
        }

        self.capturer.startCapture(with: frontCamera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
    }
    
    public func stopCapture() {
        self.capturer.stopCapture()
    }
}
