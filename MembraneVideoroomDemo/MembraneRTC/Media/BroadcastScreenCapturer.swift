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


// TODO: add a timer in case:
// - no frames arrive and no finished notification has been announced
// - no started notification arrived before starting the capture


// TODO: add delegates specifically for that delegate so that we can better control what happens with the screen boradcast
class BroadcastScreenCapturer: RTCVideoCapturer, VideoCapturer {
    private let ipcServer: IPCServer
    
    private let source: RTCVideoSource
    
    init(_ source: RTCVideoSource) {
        self.source = source
        self.ipcServer = IPCServer()
        
        super.init()
        
        // TODO: we need some better way of finishing the broadcast, either from inside the application or from OS (system controlling the broadcast)
        self.ipcServer.onReceive = { [weak self] _, _, data in
            guard
                let self = self,
                let sample = try? BroadcastMessage(serializedData: data) else {
                return
            }
            
            switch sample.type {
            case .notification(let notification):
                switch notification {
                case .finished:
                    break
                case .started:
                    break
                default:
                    break
                }
                
            case .video(let video):
                let pixelBuffer = CVPixelBuffer.from(sample.buffer, width: Int(video.width), height: Int(video.height), pixelFormat: video.format)
                
                let rtpBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                
                let videoFrame = RTCVideoFrame(buffer: rtpBuffer, rotation: RTCVideoRotation._0, timeStampNs: Int64(sample.timestamp))
                
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
        // already started I guess?
    }
    
    public func stopCapture() {
        self.ipcServer.close()
        self.ipcServer.dispose()
        // no way to stop this I guess?
    }
}
