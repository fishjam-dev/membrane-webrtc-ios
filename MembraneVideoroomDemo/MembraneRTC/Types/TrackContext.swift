import Foundation
import WebRTC

public struct TrackContext {
    var track: RTCMediaStreamTrack?
    var stream: RTCMediaStream?
    
    let peer: Peer
    let trackId: String
    let metadata: Metadata
}
