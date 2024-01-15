public struct Endpoint: Codable {
    public let id: String
    public let type: String
    public let metadata: Metadata
    public let trackIdToMetadata: [String: Metadata]?
    public let tracks: [String: TracksAddedEvent.Data.TrackData]?

    public init(id: String, type: String, metadata: Metadata?, trackIdToMetadata: [String: Metadata]?, tracks: [String: TracksAddedEvent.Data.TrackData]?) {
        self.id = id
        self.type = type
        self.metadata = metadata ?? Metadata()
        self.trackIdToMetadata = trackIdToMetadata
        self.tracks = tracks
    }

    public func with(
        id: String? = nil, type: String? = nil, metadata: Metadata? = nil, trackIdToMetadata: [String: Metadata]? = nil, tracks:  [String: TracksAddedEvent.Data.TrackData]?
    ) -> Self {
        return Endpoint(
            id: id ?? self.id,
            type: type ?? self.type,
            metadata: metadata ?? self.metadata,
            trackIdToMetadata: trackIdToMetadata ?? self.trackIdToMetadata,
            tracks: tracks ?? self.tracks
        )
    }

    public func withTrack(trackId: String, metadata: Metadata?) -> Self {
        var newTrackIdToMetadata = self.trackIdToMetadata
        newTrackIdToMetadata?[trackId] = metadata ?? Metadata()
        
        var newTracks = self.tracks
        let simulcastConfig = newTracks?[trackId]?.simulcastConfig
        newTracks?[trackId] = TracksAddedEvent.Data.TrackData(metadata: metadata ?? Metadata(), simulcastConfig: simulcastConfig)

        return Endpoint(id: self.id, type: self.type, metadata: self.metadata, trackIdToMetadata: newTrackIdToMetadata, tracks: newTracks)
    }

    public func withoutTrack(trackId: String) -> Self {
        var newTrackIdToMetadata = self.trackIdToMetadata
        newTrackIdToMetadata?.removeValue(forKey: trackId)
        
        var newTracks = self.tracks
        newTracks?.removeValue(forKey: trackId)

        return Endpoint(id: self.id, type: self.type, metadata: self.metadata, trackIdToMetadata: newTrackIdToMetadata, tracks: newTracks)
    }

    enum CodingKeys: String, CodingKey {
        case id, type, metadata, trackIdToMetadata, tracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.metadata = try container.decodeIfPresent(Metadata.self, forKey: .metadata) ?? Metadata()
        self.trackIdToMetadata = try container.decodeIfPresent([String: Metadata].self, forKey: .trackIdToMetadata)
        self.tracks = try container.decodeIfPresent([String: TracksAddedEvent.Data.TrackData].self, forKey: .tracks)
    }
}
