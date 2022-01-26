//
//  ObservableRoom.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 26/01/2022.
//

import Foundation
import WebRTC


struct Participant: Identifiable {
    let id: String
    let displayName: String
    
    // TODO: this should be better wrapped so that we minimize webrtc imports
    var videoTrack: RTCVideoTrack?
    
    init(id: String, displayName: String, videoTrack: RTCVideoTrack? = nil) {
        self.id = id
        self.displayName = displayName
        self.videoTrack = videoTrack
    }
}

class ObservableRoom: ObservableObject {
    weak var room: MembraneRTC?
    
    @Published var localVideoTrack: LocalVideoTrack?
    @Published var errorMessage: String?
    
    var participants: Array<Participant>
    
    
    init(_ room: MembraneRTC) {
        self.participants = []
        self.room = room
        
        room.add(delegate: self)
        
        // TODO: room probably should have other states indicating that it is awaiting a join
        // for now we know that we need to trigger join here but it is not a must
        room.join(metadata: ["displayName": "I am the king!"])
    }
}

extension ObservableRoom: MembraneRTCDelegate {
    func onConnected() {
    }
    
    func onJoinSuccess(peerID: String, peersInRoom: Array<Peer>) {
        guard let room = self.room else {
            return
        }
        
        let participants = peersInRoom.map { peer in
            Participant(id: peer.id, displayName: peer.metadata["displayName"] ?? "")
        }
        
        DispatchQueue.main.async {
            self.localVideoTrack = room.localVideoTrack
            self.participants += participants
        }
    }
    
    func onJoinError(metadata: Any) {
        self.errorMessage = "Failed to join a room"
    }
    
    func onTrackReady(ctx: TrackContext) {
    }
    
    func onTrackAdded(ctx: TrackContext) {
    }
    
    func onTrackRemoved(ctx: TrackContext) {
    }
    
    func onTrackUpdated(ctx: TrackContext) {
    }
    
    func onPeerJoined(peer: Peer) {
        self.participants.append(Participant(id: peer.id, displayName: peer.metadata["displayName"] ?? ""))
        
        print(self.participants)
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func onPeerLeft(peer: Peer) {
        self.participants = self.participants.filter {
            $0.id != peer.id
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func onPeerUpdated(peer: Peer) {
    }
    
    func onConnectionError(message: String) {
    }
}
