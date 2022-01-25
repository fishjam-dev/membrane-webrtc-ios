//
//  AudioSessionManager.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 24/01/2022.
//

import Foundation
import WebRTC


class AudioSessionManager {
    internal init() {
        
    }
    
    public static let sharedInstance = AudioSessionManager()
    
    public func configure(_ configuration: RTCAudioSessionConfiguration, setActive: Bool) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.lockForConfiguration()
        
        defer { audioSession.unlockForConfiguration() }
        
        do {
            try audioSession.setConfiguration(configuration, active: setActive)
        } catch {
            print("Failed to set configuration for an audio session")
        }
    }
}
