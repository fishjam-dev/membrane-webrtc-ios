public struct Endpoint: Codable {
    public let id: String
    public let type: String
    public let metadata: Metadata
    public let trackIdToMetadata: [String: Metadata]?

    public init(id: String, type: String, metadata: Metadata, trackIdToMetadata: [String: Metadata]?) {
        self.id = id
        self.type = type
        self.metadata = metadata
        self.trackIdToMetadata = trackIdToMetadata
    }

    public func with(
        id: String? = nil, type: String? = nil, metadata: Metadata? = nil, trackIdToMetadata: [String: Metadata]? = nil
    ) -> Self {
        return Endpoint(
            id: id ?? self.id,
            type: type ?? self.type,
            metadata: metadata ?? self.metadata,
            trackIdToMetadata: trackIdToMetadata ?? self.trackIdToMetadata
        )
    }

    public func withTrack(trackId: String, metadata: Metadata) -> Self {
        var newTrackIdToMetadata = self.trackIdToMetadata
        newTrackIdToMetadata?[trackId] = metadata

        return Endpoint(id: self.id, type: self.type, metadata: self.metadata, trackIdToMetadata: newTrackIdToMetadata)
    }

    public func withoutTrack(trackId: String) -> Self {
        var newTrackIdToMetadata = self.trackIdToMetadata
        newTrackIdToMetadata?.removeValue(forKey: trackId)

        return Endpoint(id: self.id, type: self.type, metadata: self.metadata, trackIdToMetadata: newTrackIdToMetadata)
    }

    enum CodingKeys: String, CodingKey {
        case id, type, metadata, trackIdToMetadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.metadata = try container.decode(Metadata.self, forKey: .metadata)
        self.trackIdToMetadata = try container.decodeIfPresent(
            [String: Metadata].self, forKey: .trackIdToMetadata)
    }
}
