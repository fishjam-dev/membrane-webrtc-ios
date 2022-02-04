//
//  BroadcastScreenCapturer.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 03/02/2022.
//

import Foundation

import SwiftUI
import WebRTC

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

// TODO: add delegates specifically for that delegate so that we can better control what happens with the screen boradcast
class BroadcastScreenCapturer: RTCVideoCapturer, VideoCapturer {
    public weak var capturerDelegate: BroadcastScreenCapturerDelegate?
    
    private let ipcServer: IPCServer
    private let source: RTCVideoSource
    
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
                case .finished:
                    sdkLogger.info("BroadcastScreenCapturer has been stopped")
                    self.capturerDelegate?.stopped()
                default:
                    break
                }
                
            case .video(let video):
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
