import Foundation

import WebRTC

/// Scales the screensharing resolution to avoid potential RTC encoding errors which
/// ocasionally happened with higher resolutions
internal func scaleScreensharingResolution(_ dimensions: Dimensions) -> Dimensions {
    let maxSize: Float = 960.0
    
    // dimensions are smaller than the max size so return it
    if max(dimensions.height, dimensions.width) < Int32(maxSize) {
        return dimensions
    }
    
    var ratio: Float32 = 0.0
    
    if dimensions.height > dimensions.width {
        ratio = maxSize / Float(dimensions.height)
    } else {
        ratio = maxSize / Float(dimensions.width)
    }
    
    let height = Int32(ratio * Float(dimensions.height))
    let width = Int32(ratio * Float(dimensions.width))
    
    return Dimensions(width: width, height: height)
}

/// Utility for creating a `CVPixelBuffer` from raw bytes.
extension CVPixelBuffer {
    public static func from(_ data: Data, width: Int, height: Int, pixelFormat: OSType) -> CVPixelBuffer {
        data.withUnsafeBytes { buffer in
            var pixelBuffer: CVPixelBuffer!
            
            let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &pixelBuffer)
            guard result == kCVReturnSuccess else { fatalError() }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
            
            var source = buffer.baseAddress!
            
            for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
                let dest      = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
                let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
                let planeSize = height * bytesPerRow
                
                memcpy(dest, source, planeSize)
                source += planeSize
            }
            
            return pixelBuffer
        }
    }
}


internal protocol BroadcastScreenCapturerDelegate: AnyObject {
    func started();
    func stopped();
    func paused();
    func resumed();
}

/// `VideoCapturer` that is responsible for capturing media from a remote `Broadcast Extension` that sends samples
/// via `IPC` mechanism.
///
/// The capturer works in a `Server` mode, receiving appropriate notifications/samples from the extension that is working in a `Client` mode.
/// The expected behaviour is to start the capturer prior to starting the extension as the server is responsible for opening the `IPC` port first.
/// If the client starts before the server it will automatically close as the port will be closed.
///
/// The communication is performed by using `Proto Buffers` to gracefully handle serialization and deserialization of raw bytes sent via IPC port.
class BroadcastScreenCapturer: RTCVideoCapturer, VideoCapturer {
    public weak var capturerDelegate: BroadcastScreenCapturerDelegate?
    
    private let ipcServer: IPCServer
    private let source: RTCVideoSource
    private var started = false
    private var isReceivingSamples: Bool = false
    
    private var timeoutTimer: Timer?
    
    internal let supportedPixelFormats = DispatchQueue.webRTC.sync { RTCCVPixelBuffer.supportedPixelFormats() }

    init(_ source: RTCVideoSource, delegate: BroadcastScreenCapturerDelegate? = nil) {
        self.source = source
        self.capturerDelegate = delegate
        self.ipcServer = IPCServer()
        
        super.init(delegate: source)
        
        // check every 2 seconds if the screensharing is still active or crashed
        // this is needed as we can't know if the IPC Client stopped working or not, so at least
        // we can check that that we receiving some samples
        self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // NOTE: there is basically no way of telling if the user has still
            // an opened RPSystemBroadcastPickerView, but we can assume that if the application
            // is in inactive state then this is a case therefore ignore the timeoutTimer tick
            if UIApplication.shared.applicationState == .inactive {
                return
            }
            
            if !self.isReceivingSamples {
                self.capturerDelegate?.stopped()
                timer.invalidate()
                return
            }
            
            self.isReceivingSamples = false
        }
        
        self.ipcServer.onReceive = { [weak self] _, _, data in
            guard
                let self = self,
                let sample = try? BroadcastMessage(serializedData: data) else {
                    return
                }
            
            switch sample.type {
            case .notification(let notification):
                switch notification {
                case .started:
                    sdkLogger.info("BroadcastScreenCapturer has been started")
                    self.capturerDelegate?.started()
                    self.started = true
                case .finished:
                    sdkLogger.info("BroadcastScreenCapturer has been stopped")
                    self.capturerDelegate?.stopped()
                case .paused:
                    sdkLogger.info("BroadcastScreenCapturer has been paused")
                    self.capturerDelegate?.paused()
                case .resumed:
                    sdkLogger.info("BroadcastScreenCapturer has been resumed")
                    self.capturerDelegate?.resumed()
                default:
                    break
                }
                
            case .video(let video):
                if !self.started {
                    fatalError("Started receiving video samples without `started` notificcation...")
                }
                
                self.isReceivingSamples = true
                
                let dimensions = scaleScreensharingResolution(Dimensions(width: Int32(video.width), height: Int32(video.height)))
                self.source.adaptOutputFormat(toWidth: dimensions.width, height: dimensions.height, fps: 15)
                
                let pixelBuffer = CVPixelBuffer.from(sample.buffer, width: Int(video.width), height: Int(video.height), pixelFormat: video.format)
                let height = Int32(CVPixelBufferGetHeight(pixelBuffer))
                let width = Int32(CVPixelBufferGetWidth(pixelBuffer))
                
                let rtcBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer,
                                                           adaptedWidth: width,
                                                           adaptedHeight: height,
                                                           cropWidth: width,
                                                           cropHeight: height,
                                                           cropX: 0,
                                                           cropY: 0)
                
                var rotation: RTCVideoRotation = ._0
                
                switch video.rotation {
                case 90:
                    rotation = ._90
                case 180:
                    rotation = ._180
                case 270:
                    rotation = ._270
                default:
                    break
                }
                
                
                // NOTEe: somehow local Metal renderer for RTCVPixelBuffer does not render the video
                // the I420 somehow does so keep it in that format as long as it works
                let buffer = rtcBuffer.toI420()
                let videoFrame = RTCVideoFrame(buffer: buffer, rotation: rotation, timeStampNs: sample.timestamp)

                let delegate = source as RTCVideoCapturerDelegate

                delegate.capturer(self, didCapture: videoFrame)
                
            default:
                break
            }
        }
    }
    
    public func startCapture() {
        guard self.ipcServer.listen(for: "group.membrane.broadcast.ipc") else {
            fatalError("Failed to open IPC for screen broadcast")
        }
    }
    
    public func stopCapture() {
        self.ipcServer.close()
        self.ipcServer.dispose()
    }
}
