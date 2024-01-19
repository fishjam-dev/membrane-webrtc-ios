public struct TrackData: Codable{
    let metadata: Metadata
    let simulcastConfig: SimulcastConfig?
    
    public init (metadata : Metadata, simulcastConfig : SimulcastConfig? = nil) {
        self.metadata = metadata
        self.simulcastConfig = simulcastConfig
    }
}
