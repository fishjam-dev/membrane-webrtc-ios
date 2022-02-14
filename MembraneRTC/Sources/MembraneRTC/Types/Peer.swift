public struct Peer: Codable {
    public var id: String
    public var metadata: Metadata
    public var trackIdToMetadata: [String: Metadata]?
    
    public init(id: String, metadata: Metadata, trackIdToMetadata: [String: Metadata]) {
        self.id = id
        self.metadata = metadata
        self.trackIdToMetadata = trackIdToMetadata
    }
}
