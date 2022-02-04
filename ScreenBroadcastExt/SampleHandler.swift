//
//  SampleHandler.swift
//  MembraneVideoroomDemoScreensharing
//
//  Created by Jakub Perzylo on 03/02/2022.
//

import Foundation
import ReplayKit
import WebRTC
import os.log

let logger = OSLog(subsystem: "com.dscout.MembraneVideoroomDemo.ScreenBroadcastExt", category: "Broadcaster")

class SampleHandler: RPBroadcastSampleHandler {
    
    override public init() {}
    
    var ipcClient: IPCCLient?

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        self.ipcClient = IPCCLient()
        
        guard let connected = self.ipcClient?.connect(with: "group.membrane.broadcast.ipc"), connected else {
            os_log("failed to connect with ipc server", log: logger, type: .debug)
            super.finishBroadcastWithError(NSError(domain: "", code: 0, userInfo: nil))
            return
        }
        
        let message = BroadcastMessage.with {
            $0.notification = .started
        }
        
        guard let protoData = try? message.serializedData() else { return }
        
        ipcClient?.send(protoData, messageId: 1)
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        let message = BroadcastMessage.with {
            $0.notification = .finished
        }
        
        guard let protoData = try? message.serializedData() else { return }
        
        ipcClient?.send(protoData, messageId: 1)
    }
    
    // TODO: for now we only support video, skip all audio for app and mic
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        
        switch sampleBufferType {
        case .video:
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            var rotation: RTCVideoRotation?
            if #available(macOS 11.0, *) {
                // Check rotation tags. Extensions see these tags, but `RPScreenRecorder` does not appear to set them.
                // On iOS 12.0 and 13.0 rotation tags (other than up) are set by extensions.
                if let sampleOrientation = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil),
                   let coreSampleOrientation = sampleOrientation.uint32Value {
                    rotation = CGImagePropertyOrientation(rawValue: coreSampleOrientation)?.toRTCRotation()
                }
            }

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let timestampNs = UInt64(CMTimeGetSeconds(timestamp) * Double(NSEC_PER_SEC))

            let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)

            let message = BroadcastMessage.with {
                $0.buffer = Data(pixelBuffer: buffer)
                $0.timestamp = timestampNs
                $0.video = .with({
                    $0.format = pixelFormat
                    $0.rotation = UInt32(rotation?.rawValue ?? 0)
                    $0.width = UInt32(CVPixelBufferGetWidth(buffer))
                    $0.height = UInt32(CVPixelBufferGetHeight(buffer))
                })
            }

            guard let protoData = try? message.serializedData() else { return }
            ipcClient?.send(protoData, messageId: 1)
            
        default:
            break
        }
    }
}

extension Data {
    public init(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [.readOnly])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, [.readOnly]) }

        // Calculate sum of planes' size
        var totalSize = 0
        for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
            let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            let planeSize   = height * bytesPerRow
            totalSize += planeSize
        }

        guard let rawFrame = malloc(totalSize) else { fatalError() }
        var dest = rawFrame

        for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
            let source      = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
            let height      = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            let planeSize   = height * bytesPerRow

            memcpy(dest, source, planeSize)
            dest += planeSize
        }

        self.init(bytesNoCopy: rawFrame, count: totalSize, deallocator: .free)
    }
}

extension CGImagePropertyOrientation {
    public func toRTCRotation() -> RTCVideoRotation {
        switch self {
        case .up, .upMirrored, .down, .downMirrored: return ._0
        case .left, .leftMirrored: return ._90
        case .right, .rightMirrored: return ._270
        default: return ._0
        }
    }
}
