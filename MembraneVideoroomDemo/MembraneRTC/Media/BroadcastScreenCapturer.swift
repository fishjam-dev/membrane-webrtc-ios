import Foundation

import WebRTC

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
}

// TODO: add a timer in case:
// - no frames arrive and no finished notification has been announced
// - no started notification arrived before starting the capture

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
    
    init(_ source: RTCVideoSource, delegate: BroadcastScreenCapturerDelegate? = nil) {
        self.source = source
        self.capturerDelegate = delegate
        self.ipcServer = IPCServer()
        
        super.init()
        
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
                default:
                    break
                }
                
            case .video(let video):
                if !self.started {
                    fatalError("Started receiving video samples without `started` notificcation...")
                }
                
                // TODO: do the recalculation of dimensions so that we don't end up with encoder errors
                self.source.adaptOutputFormat(toWidth: (Int32)(video.width/2), height: (Int32)(video.height/2), fps: 15)
                
                let pixelBuffer = CVPixelBuffer.from(sample.buffer, width: Int(video.width), height: Int(video.height), pixelFormat: video.format)
                
                let rtpBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                
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
                
                let videoFrame = RTCVideoFrame(buffer: rtpBuffer, rotation: rotation, timeStampNs: Int64(sample.timestamp))
                
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
