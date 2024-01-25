public struct TrackData: Codable{
    public let metadata: Metadata
    public let simulcastConfig: SimulcastConfig?
    
    public init (metadata : Metadata, simulcastConfig : SimulcastConfig? = nil) {
        self.metadata = metadata
        self.simulcastConfig = simulcastConfig
    }
    
    func copyWith(metadata: Metadata? = nil, simulcastConfig: SimulcastConfig? = nil) -> TrackData {
        return TrackData(
            metadata: metadata ?? self.metadata,
            simulcastConfig: simulcastConfig ?? self.simulcastConfig
        )
    }
}
