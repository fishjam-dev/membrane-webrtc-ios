public enum TrackEncoding : Int, CustomStringConvertible {
    case l = 0
    case m
    case h
    
    public var description : String {
        switch self {
            case .l: return "l"
            case .m: return "m"
            case .h: return "h"
        }
      }
}

public struct SimulcastConfig {
    public var enabled: Bool
    public var activeEncodings: [TrackEncoding] = []
    
    public init(enabled: Bool, activeEncodings: [TrackEncoding] = []) {
        self.enabled = enabled
        self.activeEncodings = activeEncodings
    }
}
