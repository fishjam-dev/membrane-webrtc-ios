import Foundation
import WebRTC

public struct TrackContext {
    var track: RemoteTrack?
    
    let peer: Peer
    let trackId: String
    let metadata: Metadata
}
