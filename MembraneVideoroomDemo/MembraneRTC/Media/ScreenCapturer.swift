//
//  ScreenCapturer.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 20/01/2022.
//

import Foundation
import WebRTC
import ReplayKit


// NOTE: this may not work with a simulator though...
class ScreenCapturer: RTCVideoCapturer, VideoCapturer {
    let screenRecorder: RPScreenRecorder
    let source: RTCVideoSource
    
    init(_ source: RTCVideoSource) {
        self.screenRecorder = RPScreenRecorder.shared()
        self.source = source
        
        super.init()
        
        guard self.screenRecorder.isAvailable else {
            sdkLogger.error("Screen recording is not available")
            return
        }
    }
    
    // TODO: this is available since iOS 11, make sure that you add a special warning or if statement here...
    func startCapture() {
        self.screenRecorder.startCapture(handler: { sampleBuffer, bufferType, error in
            // capture video only
            if bufferType == RPSampleBufferType.video {
                self.handleSourceBuffer(buffer: sampleBuffer, type: bufferType)
            }
            
        }, completionHandler: {
            error in sdkLogger.error("Encountered error while capturing screen: \(error?.localizedDescription)")
        })
    }
         
    private func handleSourceBuffer(buffer: CMSampleBuffer, type: RPSampleBufferType) {
        if (CMSampleBufferGetNumSamples(buffer) != 1 || !CMSampleBufferIsValid(buffer) ||
            !CMSampleBufferDataIsReady(buffer)) {
            return;
        }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // TODO: why is this so random? strange resolution and really low FPS
        self.source.adaptOutputFormat(toWidth: (Int32)(width/3), height: (Int32)(height/3), fps: 8)
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        
        let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(buffer))) * Int64(NSEC_PER_SEC)
        
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStampNs)
        
        let delegate = self.source as RTCVideoCapturerDelegate
        
        delegate.capturer(self, didCapture: videoFrame)
    }
    
    func stopCapture() {
            self.screenRecorder.stopCapture()
    }
}
