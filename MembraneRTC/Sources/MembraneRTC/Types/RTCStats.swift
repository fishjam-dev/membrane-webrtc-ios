public struct QualityLimitationDurations {
    public let bandwidth: Double
    public let cpu: Double
    public let none: Double
    public let other: Double

    public init(bandwidth: Double, cpu: Double, none: Double, other: Double) {
        self.bandwidth = bandwidth
        self.cpu = cpu
        self.none = none
        self.other = other
    }
}

public protocol RTCStats {}

public struct RTCOutboundStats: RTCStats {
    public let kind: String
    public let rid: String
    public let bytesSent: Int
    public let targetBitrate: Double
    public let packetsSent: Int
    public let framesEncoded: Int
    public let framesPerSecond: Double
    public let frameWidthHeightRatio: Double
    public let qualityLimitationDurations: QualityLimitationDurations?

    public init(
        kind: String = "", rid: String = "", bytesSent: Int = 0, targetBitrate: Double = 0.0, packetsSent: Int = 0,
        framesEncoded: Int = 0, framesPerSecond: Double = 0.0, frameWidthHeightRatio: Double = 0.0,
        qualityLimitationDurations: QualityLimitationDurations? = nil
    ) {
        self.kind = kind
        self.rid = rid
        self.bytesSent = bytesSent
        self.targetBitrate = targetBitrate
        self.packetsSent = packetsSent
        self.framesEncoded = framesEncoded
        self.framesPerSecond = framesPerSecond
        self.frameWidthHeightRatio = frameWidthHeightRatio
        self.qualityLimitationDurations = qualityLimitationDurations
    }
}

public struct RTCInboundStats: RTCStats {
    public let kind: String
    public let jitter: Double
    public let packetsLost: Int
    public let packetsReceived: Int
    public let bytesReceived: Int
    public let framesReceived: Int
    public let frameWidth: Int
    public let frameHeight: Int
    public let framesPerSecond: Double
    public let framesDropped: Int

    public init(
        kind: String = "", jitter: Double = 0.0, packetsLost: Int = 0, packetsReceived: Int = 0, bytesReceived: Int = 0,
        framesReceived: Int = 0, frameWidth: Int = 0, frameHeight: Int = 0, framesPerSecond: Double = 0.0,
        framesDropped: Int = 0
    ) {
        self.kind = kind
        self.jitter = jitter
        self.packetsLost = packetsLost
        self.packetsReceived = packetsReceived
        self.bytesReceived = bytesReceived
        self.framesReceived = framesReceived
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.framesPerSecond = framesPerSecond
        self.framesDropped = framesDropped
    }
}
