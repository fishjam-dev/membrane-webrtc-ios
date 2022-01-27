//
//  LocalAudioTrack.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 24/01/2022.
//

import Foundation
import WebRTC
import Promises
        
public class LocalAudioTrack: LocalTrack {
    public let track: RTCMediaStreamTrack
    
    private let config: RTCAudioSessionConfiguration
    
    internal init() {
        let constraints: [String: String] = [
            "googEchoCancellation": "false",
            "googAutoGainControl":  "false",
            "googNoiseSuppression": "false",
            "googTypingNoiseDetection": "false",
            "googHighpassFilter": "false"
        ]

        // let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: constraints)
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        self.config = RTCAudioSessionConfiguration()
        
        self.config.category = AVAudioSession.Category.playAndRecord.rawValue
        self.config.mode = AVAudioSession.Mode.videoChat.rawValue
        // self.config.categoryOptions = AVAudioSession.CategoryOptions.duckOthers
        
        let audioSource = ConnectionManager.createAudioSource(audioConstraints)
        // audioSource.volume = 100
        
        let track = ConnectionManager.createAudioTrack(source: audioSource)
        track.isEnabled = true
        
        self.track = track
    }

    public func start() {
        // TODO: this is just for testing purposes as this will change global settings while operating on local tracks
        // which should not change remote tracks...
        configure(setActive: true)
    }

    public func stop() {
        configure(setActive: false)
    }
    
    public func toggle() {
        self.track.isEnabled = !self.track.isEnabled
    }
    
    private func configure(setActive: Bool) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        defer { audioSession.unlockForConfiguration() }
        
        do {
            try audioSession.setCategory(self.config.category)
            try audioSession.setMode(self.config.mode)
            // try audioSession.setConfiguration(self.config, active: setActive)
        } catch {
            sdkLogger.error("Failed to set configuration for audio session")
        }
    }
}



