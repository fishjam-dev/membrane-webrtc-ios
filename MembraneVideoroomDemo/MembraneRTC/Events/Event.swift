//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation

public typealias Payload = [String: Any?]

public protocol SendableEvent {
    func serialize() -> Payload;
}


public enum ReceivableEventType: String, Codable {
    case PeerAccepted = "peerAccepted"
    case PeerJoined = "peerJoined"
    case PeerLeft = "peerLeft"
    case PeerUpdated = "peerUpdated"
    case Custom = "custom"
    case OfferData = "offerData"
    case Candidate = "candidate"
    case TracksAdded = "tracksAdded"
    case TracksRemoved = "tracksRemoved"
    case TrackUpdated = "trackUpdated"
    case SdpAnswer = "sdpAnswer"
}

public protocol ReceivableEvent {
    var type: ReceivableEventType { get }
}

internal struct ReceivableEventBase: Decodable {
    let type: ReceivableEventType
}

public class Events {
    internal static func decodeEvent<T: Decodable>(from data: Data) -> T? {
        do {
            
         return try JSONDecoder().decode(T.self, from: data)
        } catch {
            sdkLogger.error("failed to decode an event: \(error)")
            return nil
        }
    }
    
    public static func deserialize(payload: Payload) -> ReceivableEvent? {
        guard let rawData = payload["data"] as? String else {
            sdkLogger.error("Failed to extract 'data' field from json payload: \(payload)")
            return nil
        }
        
        let data = rawData.data(using: .utf8)!
        
        guard let base: ReceivableEventBase = decodeEvent(from: data) else {
            sdkLogger.error("Failed to decode ReceivableEventBase")
            return nil
        }
        
        switch base.type {
        case .PeerAccepted:
            let event: PeerAcceptedEvent? = decodeEvent(from: data)
            
            return event
            
        case .PeerJoined:
            let event: PeerJoinedEvent? = decodeEvent(from: data)
            
            return event
            
        case .PeerLeft:
            let event: PeerLeftEvent? = decodeEvent(from: data)
            
            return event
            
        case .PeerUpdated:
            let event: PeerUpdateEvent? = decodeEvent(from: data)
            
            return event
            
        case .TracksAdded:
            let event: TracksAddedEvent? = decodeEvent(from: data)
            
            return event
            
        case .TracksRemoved:
            let event: TracksRemovedEvent? = decodeEvent(from: data)
            
            return event
            
        case .TrackUpdated:
            let event: TracksUpdatedEvent? = decodeEvent(from: data)
            
            return event
            
        case .Custom:
            guard let baseEvent: BaseCustomEvent = decodeEvent(from: data) else {
                return nil
            }
            
            switch baseEvent.data.type {
            case .OfferData:
                guard let event: CustomEvent<OfferDataEvent> = decodeEvent(from: data) else {
                    return nil
                }
                
                return event.data
                
            case .Candidate:
                guard let event: CustomEvent<RemoteCandidateEvent> = decodeEvent(from: data) else {
                    return nil
                }
                
                return event.data
                
            case .SdpAnswer:
                guard let event: CustomEvent<SdpAnswerEvent> = decodeEvent(from: data) else {
                    return nil
                }
                
                return event.data
                
            default:
                sdkLogger.warning("Unhandled custom event parsing for \(baseEvent.data.type)")
                
                return nil
            }
        default:
            return nil
        }
    }
    
    public static func joinEvent(metadata: Metadata) -> SendableEvent  {
        return JoinEvent(metadata: metadata)
    }
}

/*
 Sendable events
 */
struct JoinEvent: SendableEvent {
    let metadata: Metadata
    
    init(metadata: Metadata) {
        self.metadata = metadata
    }
    
    func serialize() -> Payload {
        return [
            "type": "join",
            "data": ["metadata": self.metadata]
        ]
    }
}

struct SdpOfferEvent: SendableEvent {
    let sdp: String
    let trackIdToTrackMetadata: [String: Metadata]
    let midToTrackId: [String: String]
    
    init(sdp: String, trackIdToTrackMetadata: [String: Metadata], midToTrackId: [String: String]) {
        self.sdp = sdp
        self.trackIdToTrackMetadata = trackIdToTrackMetadata
        self.midToTrackId = midToTrackId
    }
    
    func serialize() -> Payload {
        return [
            "type": "custom",
            "data": [
                "type": "sdpOffer",
                "data": [
                    "sdpOffer": [
                        "type": "offer",
                        "sdp": self.sdp
                    ],
                    "trackIdToTrackMetadata": self.trackIdToTrackMetadata,
                    "midToTrackId": self.midToTrackId
                ]
                
            ]
        ]
    }
}

struct LocalCandidateEvent: SendableEvent {
    let candidate: String
    let sdpMLineIndex: Int32
    
    init(candidate: String, sdpMLineIndex: Int32) {
        self.candidate = candidate
        self.sdpMLineIndex = sdpMLineIndex
    }
    
    func serialize() -> Payload {
        return [
            "type": "custom",
            "data": [
                "type": "candidate",
                "data": [
                    "candidate": self.candidate,
                    "sdpMLineIndex": self.sdpMLineIndex
                ]
                
            ]
        ]
    }
}

/*
 Receivable events
 */

struct PeerAcceptedEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let id: String
        let peersInRoom: Array<Peer>
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct PeerJoinedEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peer: Peer
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct PeerLeftEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peerId: String
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct PeerUpdateEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peerId: String
        let metadata: Metadata
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct OfferDataEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let iceTransportPolicy: String
        let integratedTurnServers: Array<String>
        let tracksTypes: [String: Int]
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct TracksAddedEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peerId: String
        let trackIdToMetadata: [String: Metadata]
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct TracksRemovedEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peerId: String
        let trackIds: Array<String>
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct TracksUpdatedEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let peerId: String
        let trackId: String
        let metadata: Metadata
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct SdpAnswerEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let type: String
        let sdp: String
        let midToTrackId: [String: String]
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct RemoteCandidateEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let candidate: String
        let sdpMLineIndex: Int32
        let sdpMid: String?
    }
    
    let type: ReceivableEventType
    let data: Data
}

// This is kinda strange as we can't dynamically decode json strings to structs
// e.g. to [String: Any] type
// Therefore we need to preform a 2-phase decoding, meaning that we need to extract types first
// and then based on them statically decode embedded events
struct BaseCustomEvent: ReceivableEvent, Codable {
    struct Data: Codable {
        let type: ReceivableEventType
    }
    
    let type: ReceivableEventType
    let data: Data
}

struct CustomEvent<EventType: ReceivableEvent & Codable>: ReceivableEvent, Codable {
    let type: ReceivableEventType
    let data: EventType
}

