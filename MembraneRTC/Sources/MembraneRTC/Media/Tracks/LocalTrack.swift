public protocol LocalTrack {
    func start()
    func stop()
    func toggle()
    func enabled() -> Bool
}

public enum LocalTrackType {
    case audio, video, screensharing
}
