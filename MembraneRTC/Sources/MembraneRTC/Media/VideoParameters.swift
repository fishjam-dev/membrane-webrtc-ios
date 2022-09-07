/// A set of parameters representing a video feed.
///
///     - Parameters
///         - dimensions: Dimensions (width x height) of the captured video
///         - maxBandwidth: maximal bandwith the video track can use. Defaults to 0 which is unlimited.
///         - maxFps: maximal captured frames per second
///         - simulcastConfig: Simulcast configuration used for the video track
///
///  Contains a set of useful presets.
public struct VideoParameters {
    // 4:3 aspect ratio
    public static let presetQVGA43 = VideoParameters(
        dimensions: Dimensions(width: 240, height: 180),
        maxBandwidth: .BandwidthLimit(90),
        maxFps: 10
    )
    public static let presetVGA43 = VideoParameters(
        dimensions: Dimensions(width: 480, height: 360),
        maxBandwidth: .BandwidthLimit(225),
        maxFps: 20
    )
    public static let presetQHD43 = VideoParameters(
        dimensions: Dimensions(width: 720, height: 540),
        maxBandwidth: .BandwidthLimit(450),
        maxFps: 25
    )
    public static let presetHD43 = VideoParameters(
        dimensions: Dimensions(width: 960, height: 720),
        maxBandwidth: .BandwidthLimit(1_500),
        maxFps: 30
    )
    public static let presetFHD43 = VideoParameters(
        dimensions: Dimensions(width: 1440, height: 1080),
        maxBandwidth: .BandwidthLimit(2_800),
        maxFps: 30
    )

    // 16:9 aspect ratio
    public static let presetQVGA169 = VideoParameters(
        dimensions: Dimensions(width: 320, height: 180),
        maxBandwidth: .BandwidthLimit(120),
        maxFps: 10
    )
    public static let presetVGA169 = VideoParameters(
        dimensions: Dimensions(width: 640, height: 360),
        maxBandwidth: .BandwidthLimit(300),
        maxFps: 20
    )
    public static let presetQHD169 = VideoParameters(
        dimensions: Dimensions(width: 960, height: 540),
        maxBandwidth: .BandwidthLimit(600),
        maxFps: 25
    )
    public static let presetHD169 = VideoParameters(
        dimensions: Dimensions(width: 1280, height: 720),
        maxBandwidth: .BandwidthLimit(2_000),
        maxFps: 30
    )
    public static let presetFHD169 = VideoParameters(
        dimensions: Dimensions(width: 1920, height: 1080),
        maxBandwidth: .BandwidthLimit(3_000),
        maxFps: 30
    )

    // Screen share
    public static let presetScreenShareVGA = VideoParameters(
        dimensions: Dimensions(width: 640, height: 360),
        maxBandwidth: .BandwidthLimit(200),
        maxFps: 3
    )
    public static let presetScreenShareHD5 = VideoParameters(
        dimensions: Dimensions(width: 1280, height: 720),
        maxBandwidth: .BandwidthLimit(400),
        maxFps: 5
    )
    public static let presetScreenShareHD15 = VideoParameters(
        dimensions: Dimensions(width: 1280, height: 720),
        maxBandwidth: .BandwidthLimit(1_000),
        maxFps: 15
    )
    public static let presetScreenShareFHD15 = VideoParameters(
        dimensions: Dimensions(width: 1920, height: 1080),
        maxBandwidth: .BandwidthLimit(1_500),
        maxFps: 15
    )
    public static let presetScreenShareFHD30 = VideoParameters(
        dimensions: Dimensions(width: 1920, height: 1080),
        maxBandwidth: .BandwidthLimit(3_000),
        maxFps: 30
    )

    public static let presets43 = [
        presetQVGA43, presetVGA43, presetQHD43, presetHD43, presetFHD43,
    ]

    public static let presets169 = [
        presetQVGA169, presetVGA169, presetQHD169, presetHD169, presetFHD169,
    ]

    public static let presetsScreenShare = [
        presetScreenShareVGA,
        presetScreenShareHD5,
        presetScreenShareHD15,
        presetScreenShareFHD15,
        presetScreenShareFHD30,
    ]

    public let dimensions: Dimensions
    public let maxBandwidth: TrackBandwidthLimit
    public let maxFps: Int
    public let simulcastConfig: SimulcastConfig
    

    public init(dimensions: Dimensions, maxBandwidth: TrackBandwidthLimit = .BandwidthLimit(0), maxFps: Int = 30, simulcastConfig: SimulcastConfig = SimulcastConfig()) {
        self.dimensions = dimensions
        self.maxBandwidth = maxBandwidth
        self.maxFps = maxFps
        self.simulcastConfig = simulcastConfig
    }
}
