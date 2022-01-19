//
//  FileCapturer.swift.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 18/01/2022.
//

import SwiftUI
import WebRTC
import MembraneRTC

class FileCapturer: VideoCapturer {
    private let capturer: RTCFileVideoCapturer
    
    init(_ delegate: RTCVideoCapturerDelegate) {
        self.capturer = RTCFileVideoCapturer(delegate: delegate)
    }
    
    public func startCapture() {
        if let _ = Bundle.main.path(forResource: "video.mp4", ofType: nil) {
            self.capturer.startCapturing(fromFileNamed: "video.mp4") { err in
                print("Error while capturing from file", err)
            }

        } else {
            fatalError("Fatal when capturing video from file")
        }
    }
    
    public func stopCapture() {
        self.capturer.stopCapture()
    }
}
