//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation
import WebRTC

public struct TrackContext {
    var track: RTCMediaStreamTrack?
    var stream: RTCMediaStream?
    
    let peer: Peer
    let trackId: String
    let metadata: Any
}
