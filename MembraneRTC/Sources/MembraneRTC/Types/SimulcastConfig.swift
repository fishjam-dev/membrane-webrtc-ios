/// Enum describing possible track encodings.
/// `"h"` - original encoding
/// `"m"` - original encoding scaled down by 2
/// `"l"` - original encoding scaled down by 4
public enum TrackEncoding: Int, CustomStringConvertible {
    case l = 0
    case m
    case h

    public var description: String {
        switch self {
        case .l: return "l"
        case .m: return "m"
        case .h: return "h"
        }
    }

    static func fromString(_ s: String) -> TrackEncoding? {
        switch s {
        case "l":
            return .l
        case "m":
            return .m
        case "h":
            return .h
        default:
            return nil
        }
    }
}

/// Simulcast configuration.
///
/// At the moment, simulcast track is initialized in three versions - low, medium and high.
/// High resolution is the original track resolution, while medium and low resolutions
/// are the original track resolution scaled down by 2 and 4 respectively.
public struct SimulcastConfig {
    /**
     * Whether to simulcast track or not.
     */
    public var enabled: Bool
    /**
     * List of initially active encodings.
     *
     * Encoding that is not present in this list might still be
     * enabled using {@link enableTrackEncoding}.
     */
    public var activeEncodings: [TrackEncoding] = []

    public init(enabled: Bool = false, activeEncodings: [TrackEncoding] = []) {
        self.enabled = enabled
        self.activeEncodings = activeEncodings
    }
}
