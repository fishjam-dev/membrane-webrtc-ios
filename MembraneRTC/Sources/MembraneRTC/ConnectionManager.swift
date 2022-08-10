import WebRTC

// class for managing RTCPeerConnection responsible for managing its media sources and
// handling various kinds of notifications
internal class ConnectionManager {
    let factory: RTCPeerConnectionFactory
    
    init(encoder: Encoder) {
        RTCInitializeSSL()

        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = getEncoderFactory(from: encoder)
        
        let simulcastFactory = RTCVideoEncoderFactorySimulcast(primary: encoderFactory, fallback: RTCDefaultVideoEncoderFactory())

        self.factory = RTCPeerConnectionFactory(encoderFactory: simulcastFactory, decoderFactory: decoderFactory)
    }

    func createPeerConnection(_ configuration: RTCConfiguration, constraints: RTCMediaConstraints) -> RTCPeerConnection? {
        DispatchQueue.webRTC.sync {
            factory.peerConnection(with: configuration, constraints: constraints, delegate: nil)
        }
    }

    func createAudioSource(_ constraints: RTCMediaConstraints?) -> RTCAudioSource {
        DispatchQueue.webRTC.sync {
            factory.audioSource(with: constraints)
        }
    }

    func createAudioTrack(source: RTCAudioSource) -> RTCAudioTrack {
        DispatchQueue.webRTC.sync {
            factory.audioTrack(with: source, trackId: UUID().uuidString)
        }
    }

    func createVideoCapturer() -> RTCVideoCapturer {
        DispatchQueue.webRTC.sync { RTCVideoCapturer() }
    }

    func createVideoSource(forScreencast _: Bool = false) -> RTCVideoSource {
        DispatchQueue.webRTC.sync { factory.videoSource() }
    }

    func createVideoTrack(source: RTCVideoSource) -> RTCVideoTrack {
        DispatchQueue.webRTC.sync {
            factory.videoTrack(with: source, trackId: UUID().uuidString)
        }
    }
}

extension RTCPeerConnection {
    // currently `Membrane RTC Engine` can't handle track of diretion `sendRecv` therefore
    // we need to change all `sendRecv` to `sendOnly`.
    func enforceSendOnlyDirection() {
        self.transceivers.forEach { transceiver in
            if transceiver.direction == .sendRecv {
                transceiver.setDirection(.sendOnly, error: nil)
            }
        }
    }
}
