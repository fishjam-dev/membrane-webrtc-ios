//
//  LocalBroadcastScreenTrack.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 04/02/2022.
//

import Foundation
import WebRTC

public protocol LocalBroadcastScreenTrackDelegate: AnyObject {
    func started();
    func stopped();
}

public class LocalBroadcastScreenTrack: LocalTrack, BroadcastScreenCapturerDelegate {
    private let videoSource: RTCVideoSource
    private let capturer: VideoCapturer
    private let track: RTCVideoTrack
    public weak var delegate: LocalBroadcastScreenTrackDelegate?
    
    
    internal init(delegate: LocalBroadcastScreenTrackDelegate? = nil) {
        self.videoSource = ConnectionManager.createVideoSource()
        self.track = ConnectionManager.createVideoTrack(source: self.videoSource)
        
        let capturer = BroadcastScreenCapturer(videoSource)
        self.capturer = capturer
        
        capturer.capturerDelegate = self
    }
    
    internal func started() {
        self.delegate?.started()
    }
    
    internal func stopped() {
        self.delegate?.stopped()
    }
    
    public func start() {
        self.capturer.startCapture()
    }
    
    public func stop() {
        self.capturer.stopCapture()
    }
    
    public func toggle() {
        self.track.isEnabled = !self.track.isEnabled
    }
    
    public func rtcTrack() -> RTCMediaStreamTrack {
        return self.track
    }
}

