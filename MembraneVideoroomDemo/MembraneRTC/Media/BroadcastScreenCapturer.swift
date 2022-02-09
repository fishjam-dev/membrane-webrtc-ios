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
    func paused();
    func resumed();
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
    
    internal let supportedPixelFormats = DispatchQueue.webRTC.sync { RTCCVPixelBuffer.supportedPixelFormats() }

    init(_ source: RTCVideoSource, delegate: BroadcastScreenCapturerDelegate? = nil) {
        self.source = source
        self.capturerDelegate = delegate
        self.ipcServer = IPCServer()
        
        super.init(delegate: source)
        
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
                
                // TODO: do the recalculation of dimensions so that we don't end up with encoder errors
                self.source.adaptOutputFormat(toWidth: (Int32)(video.width/2), height: (Int32)(video.height/2), fps: 15)
                
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
                
                
                // FIXME: somehow local Metal renderer for RTCVPixelBuffer does not render the video, the I420 somehow does
                // so keep it in that format as long as it works
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

extension OSType {
    // Get string representation of CVPixelFormatType
    func toString() -> String {
        let types = [
            kCVPixelFormatType_TwoComponent8: "kCVPixelFormatType_TwoComponent8",
            kCVPixelFormatType_TwoComponent32Float: "kCVPixelFormatType_TwoComponent32Float",
            kCVPixelFormatType_TwoComponent16Half: "kCVPixelFormatType_TwoComponent16Half",
            kCVPixelFormatType_TwoComponent16: "kCVPixelFormatType_TwoComponent16",
            kCVPixelFormatType_OneComponent8: "kCVPixelFormatType_OneComponent8",
            kCVPixelFormatType_OneComponent32Float: "kCVPixelFormatType_OneComponent32Float",
            kCVPixelFormatType_OneComponent16Half: "kCVPixelFormatType_OneComponent16Half",
            kCVPixelFormatType_OneComponent16: "kCVPixelFormatType_OneComponent16",
            kCVPixelFormatType_OneComponent12: "kCVPixelFormatType_OneComponent12",
            kCVPixelFormatType_OneComponent10: "kCVPixelFormatType_OneComponent10",
            kCVPixelFormatType_Lossy_422YpCbCr10PackedBiPlanarVideoRange: "kCVPixelFormatType_Lossy_422YpCbCr10PackedBiPlanarVideoRange",
            kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange",
            kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange",
            kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange: "kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange",
            kCVPixelFormatType_Lossy_32BGRA: "kCVPixelFormatType_Lossy_32BGRA",
            kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarVideoRange: "kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarVideoRange",
            kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange",
            kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarFullRange",
            kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarVideoRange: "kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarVideoRange",
            kCVPixelFormatType_Lossless_32BGRA: "kCVPixelFormatType_Lossless_32BGRA",
            kCVPixelFormatType_DisparityFloat32: "kCVPixelFormatType_DisparityFloat32",
            kCVPixelFormatType_DisparityFloat16: "kCVPixelFormatType_DisparityFloat16",
            kCVPixelFormatType_DepthFloat32: "kCVPixelFormatType_DepthFloat32",
            kCVPixelFormatType_DepthFloat16: "kCVPixelFormatType_DepthFloat16",
            kCVPixelFormatType_ARGB2101010LEPacked: "kCVPixelFormatType_ARGB2101010LEPacked",
            kCVPixelFormatType_8IndexedGray_WhiteIsZero: "kCVPixelFormatType_8IndexedGray_WhiteIsZero",
            kCVPixelFormatType_8Indexed: "kCVPixelFormatType_8Indexed",
            kCVPixelFormatType_64RGBALE: "kCVPixelFormatType_64RGBALE",
            kCVPixelFormatType_64RGBAHalf: "kCVPixelFormatType_64RGBAHalf",
            kCVPixelFormatType_64RGBA_DownscaledProResRAW: "kCVPixelFormatType_64RGBA_DownscaledProResRAW",
            kCVPixelFormatType_64ARGB: "kCVPixelFormatType_64ARGB",
            kCVPixelFormatType_4IndexedGray_WhiteIsZero: "kCVPixelFormatType_4IndexedGray_WhiteIsZero",
            kCVPixelFormatType_4Indexed: "kCVPixelFormatType_4Indexed",
            kCVPixelFormatType_48RGB: "kCVPixelFormatType_48RGB",
            kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange",
            kCVPixelFormatType_444YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_444YpCbCr8BiPlanarFullRange",
            kCVPixelFormatType_444YpCbCr8: "kCVPixelFormatType_444YpCbCr8",
            kCVPixelFormatType_444YpCbCr16VideoRange_16A_TriPlanar: "kCVPixelFormatType_444YpCbCr16VideoRange_16A_TriPlanar",
            kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange: "kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange",
            kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: "kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange",
            kCVPixelFormatType_444YpCbCr10BiPlanarFullRange: "kCVPixelFormatType_444YpCbCr10BiPlanarFullRange",
            kCVPixelFormatType_444YpCbCr10: "kCVPixelFormatType_444YpCbCr10",
            kCVPixelFormatType_4444YpCbCrA8R: "kCVPixelFormatType_4444YpCbCrA8R",
            kCVPixelFormatType_4444YpCbCrA8: "kCVPixelFormatType_4444YpCbCrA8",
            kCVPixelFormatType_4444AYpCbCr8: "kCVPixelFormatType_4444AYpCbCr8",
            kCVPixelFormatType_4444AYpCbCr16: "kCVPixelFormatType_4444AYpCbCr16",
            kCVPixelFormatType_422YpCbCr8FullRange: "kCVPixelFormatType_422YpCbCr8FullRange",
            kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange",
            kCVPixelFormatType_422YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_422YpCbCr8BiPlanarFullRange",
            kCVPixelFormatType_422YpCbCr8_yuvs: "kCVPixelFormatType_422YpCbCr8_yuvs",
            kCVPixelFormatType_422YpCbCr8: "kCVPixelFormatType_422YpCbCr8",
            kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange: "kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange",
            kCVPixelFormatType_422YpCbCr16: "kCVPixelFormatType_422YpCbCr16",
            kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange: "kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange",
            kCVPixelFormatType_422YpCbCr10BiPlanarFullRange: "kCVPixelFormatType_422YpCbCr10BiPlanarFullRange",
            kCVPixelFormatType_422YpCbCr10: "kCVPixelFormatType_422YpCbCr10",
            kCVPixelFormatType_422YpCbCr_4A_8BiPlanar: "kCVPixelFormatType_422YpCbCr_4A_8BiPlanar",
            kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar: "kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar",
            kCVPixelFormatType_420YpCbCr8PlanarFullRange: "kCVPixelFormatType_420YpCbCr8PlanarFullRange",
            kCVPixelFormatType_420YpCbCr8Planar: "kCVPixelFormatType_420YpCbCr8Planar",
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange",
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_420YpCbCr8BiPlanarFullRange",
            kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: "kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange",
            kCVPixelFormatType_420YpCbCr10BiPlanarFullRange: "kCVPixelFormatType_420YpCbCr10BiPlanarFullRange",
            kCVPixelFormatType_40ARGBLEWideGamutPremultiplied: "kCVPixelFormatType_40ARGBLEWideGamutPremultiplied",
            kCVPixelFormatType_40ARGBLEWideGamut: "kCVPixelFormatType_40ARGBLEWideGamut",
            kCVPixelFormatType_32RGBA: "kCVPixelFormatType_32RGBA",
            kCVPixelFormatType_32BGRA: "kCVPixelFormatType_32BGRA",
            kCVPixelFormatType_32ARGB: "kCVPixelFormatType_32ARGB",
            kCVPixelFormatType_32AlphaGray: "kCVPixelFormatType_32AlphaGray",
            kCVPixelFormatType_32ABGR: "kCVPixelFormatType_32ABGR",
            kCVPixelFormatType_30RGBLEPackedWideGamut: "kCVPixelFormatType_30RGBLEPackedWideGamut",
            kCVPixelFormatType_30RGB: "kCVPixelFormatType_30RGB",
            kCVPixelFormatType_2IndexedGray_WhiteIsZero: "kCVPixelFormatType_2IndexedGray_WhiteIsZero",
            kCVPixelFormatType_2Indexed: "kCVPixelFormatType_2Indexed",
            kCVPixelFormatType_24RGB: "kCVPixelFormatType_24RGB",
            kCVPixelFormatType_24BGR: "kCVPixelFormatType_24BGR",
            kCVPixelFormatType_1Monochrome: "kCVPixelFormatType_1Monochrome",
            kCVPixelFormatType_1IndexedGray_WhiteIsZero: "kCVPixelFormatType_1IndexedGray_WhiteIsZero",
            kCVPixelFormatType_16VersatileBayer: "kCVPixelFormatType_16VersatileBayer",
            kCVPixelFormatType_16LE565: "kCVPixelFormatType_16LE565",
            kCVPixelFormatType_16LE5551: "kCVPixelFormatType_16LE5551",
            kCVPixelFormatType_16LE555: "kCVPixelFormatType_16LE555",
            kCVPixelFormatType_16Gray: "kCVPixelFormatType_16Gray",
            kCVPixelFormatType_16BE565: "kCVPixelFormatType_16BE565",
            kCVPixelFormatType_16BE555: "kCVPixelFormatType_16BE555",
            kCVPixelFormatType_14Bayer_RGGB: "kCVPixelFormatType_14Bayer_RGGB",
            kCVPixelFormatType_14Bayer_GRBG: "kCVPixelFormatType_14Bayer_GRBG",
            kCVPixelFormatType_14Bayer_GBRG: "kCVPixelFormatType_14Bayer_GBRG",
            kCVPixelFormatType_14Bayer_BGGR: "kCVPixelFormatType_14Bayer_BGGR",
            kCVPixelFormatType_128RGBAFloat: "kCVPixelFormatType_128RGBAFloat"
        ]

        return types[self] ?? "Unknown type"
    }
}

