import WebRTC

// class for managing RTCPeerConnection responsible for managing its media sources and
// handling various kinds of notifications
internal class ConnectionManager {}

extension ConnectionManager {
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()

        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()

        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()

    static func createPeerConnection(_ configuration: RTCConfiguration, constraints: RTCMediaConstraints) -> RTCPeerConnection? {
        DispatchQueue.webRTC.sync {
            factory.peerConnection(with: configuration, constraints: constraints, delegate: nil)
        }
    }

    static func createAudioSource(_ constraints: RTCMediaConstraints?) -> RTCAudioSource {
        DispatchQueue.webRTC.sync {
            factory.audioSource(with: constraints)
        }
    }

    static func createAudioTrack(source: RTCAudioSource) -> RTCAudioTrack {
        DispatchQueue.webRTC.sync {
            factory.audioTrack(with: source, trackId: UUID().uuidString)
        }
    }

    static func createVideoCapturer() -> RTCVideoCapturer {
        DispatchQueue.webRTC.sync { RTCVideoCapturer() }
    }

    static func createVideoSource(forScreencast _: Bool = false) -> RTCVideoSource {
        DispatchQueue.webRTC.sync { factory.videoSource() }
    }

    static func createVideoTrack(source: RTCVideoSource) -> RTCVideoTrack {
        DispatchQueue.webRTC.sync {
            factory.videoTrack(with: source, trackId: UUID().uuidString)
        }
    }
}

extension RTCPeerConnection {
    func enforceSendOnlyDirection() {
        self.transceivers.forEach { transceiver in
            if transceiver.direction == .sendRecv {
                transceiver.setDirection(.sendOnly, error: nil)
            }
        }
    }
}
