//
//  ObservableRoom.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 26/01/2022.
//

import Foundation
import WebRTC



struct Participant {
    let id: String
    let displayName: String
    
    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

struct ParticipantVideo: Identifiable {
    let id: String
    let participant: Participant
    // TODO: this videotrack could be wrapped to limit imports of webrtc package
    let videoTrack: RTCVideoTrack
    let isScreensharing: Bool
    
    init(id: String, participant: Participant, videoTrack: RTCVideoTrack, isScreensharing: Bool = false) {
        self.id = id
        self.participant = participant
        self.videoTrack = videoTrack
        self.isScreensharing = isScreensharing
    }
}

class ObservableRoom: ObservableObject {
    weak var room: MembraneRTC?
    
    @Published var errorMessage: String?
    
    var primaryVideo: ParticipantVideo?
    
    var participants: [String: Participant]
    var participantVideos: Array<ParticipantVideo>
    var localParticipantId: String?
    
    
    init(_ room: MembraneRTC) {
        self.room = room
        self.participants = [:]
        self.participantVideos = []
        
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
        
        self.localParticipantId = peerID
        
        let localParticipant = Participant(id: peerID, displayName: "Me")
        
        let participants = peersInRoom.map { peer in
            Participant(id: peer.id, displayName: peer.metadata["displayName"] ?? "")
        }
        
        DispatchQueue.main.async {
            guard let track = room.localVideoTrack?.track else {
                fatalError("failed to setup local video")
            }
            
            self.primaryVideo = ParticipantVideo(id: track.trackId, participant: localParticipant, videoTrack: track)
            self.participants[localParticipant.id] = localParticipant
            participants.forEach { participant in self.participants[participant.id] = participant }
            
            self.objectWillChange.send()
        }
    }
    
    func onJoinError(metadata: Any) {
        self.errorMessage = "Failed to join a room"
    }
    
    func onTrackReady(ctx: TrackContext) {
        guard
            let participant = self.participants[ctx.peer.id],
            let videoTrack = ctx.track as? RTCVideoTrack,
            self.participantVideos.first(where: { $0.id == ctx.trackId }) == nil else {
            return
        }
        
        let isScreensharing = ctx.metadata["type"] == "screensharing"
        let video = ParticipantVideo(id: ctx.trackId, participant: participant, videoTrack: videoTrack, isScreensharing: isScreensharing)
        
        // switch the video to primary view in case of screen sharing or a new remote participant
        if isScreensharing || self.primaryVideo?.participant.id == self.localParticipantId {
            if self.primaryVideo != nil {
                self.participantVideos.insert(self.primaryVideo!, at: 0)
            }
            
            self.primaryVideo = video
        } else {
            self.participantVideos.append(video)
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func onTrackAdded(ctx: TrackContext) {
    }
    
    func onTrackRemoved(ctx: TrackContext) {
        print("CONTEXT", ctx)
        print("VIDEOS", self.participantVideos)
        
        guard let idx = self.participantVideos.firstIndex(where: { $0.id == ctx.trackId }) else {
            if self.primaryVideo?.id == ctx.trackId {
                DispatchQueue.main.async {
                    if self.participantVideos.count > 0 {
                        self.primaryVideo = self.participantVideos.removeFirst()
                    } else {
                        self.primaryVideo = nil
                    }
                    
                    self.objectWillChange.send()
                }
            }
            return
        }
        
        
        DispatchQueue.main.async {
            self.participantVideos.remove(at: idx)
            self.objectWillChange.send()
        }
    }
    
    func onTrackUpdated(ctx: TrackContext) {
    }
    
    func onPeerJoined(peer: Peer) {
        self.participants[peer.id] = Participant(id: peer.id, displayName: peer.metadata["displayName"] ?? "")
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func onPeerLeft(peer: Peer) {
        DispatchQueue.main.async {
            self.participants.removeValue(forKey: peer.id)
            self.objectWillChange.send()
        }
    }
    
    func onPeerUpdated(peer: Peer) {
    }
    
    func onConnectionError(message: String) {
    }
}
