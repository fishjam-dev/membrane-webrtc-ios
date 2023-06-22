import MembraneRTC
import SwiftUI

struct Participant {
    let id: String
    let displayName: String
    var isAudioTrackActive: Bool
}

class ParticipantVideo: Identifiable, ObservableObject {
    let id: String
    let isScreensharing: Bool

    @Published var participant: Participant
    @Published var isActive: Bool
    @Published var videoTrack: VideoTrack?
    @Published var mirror: Bool
    @Published var vadStatus: VadStatus

    init(
        id: String, participant: Participant, videoTrack: VideoTrack? = nil, isScreensharing: Bool = false,
        isActive: Bool = false,
        mirror: Bool = false
    ) {
        self.id = id
        self.participant = participant
        self.videoTrack = videoTrack
        self.isScreensharing = isScreensharing
        self.isActive = isActive
        self.mirror = mirror
        self.vadStatus = VadStatus.silence
    }
}

class RoomController: ObservableObject {
    weak var room: MembraneRTC?

    var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    var localScreencastTrack: LocalScreenBroadcastTrack?

    @Published var errorMessage: String?
    @Published var isMicEnabled: Bool
    @Published var isCameraEnabled: Bool
    @Published var isScreensharingEnabled: Bool

    @Published var primaryVideo: ParticipantVideo?

    @Published var participants: [String: Participant]
    @Published var participantVideos: [ParticipantVideo]
    var localParticipantId: String?
    var localScreensharingVideoId: String?
    var isFrontCamera: Bool = true
    let displayName: String

    @Published var videoSimulcastConfig: SimulcastConfig = SimulcastConfig(
        enabled: true, activeEncodings: [TrackEncoding.l, TrackEncoding.m])
    @Published var screencastSimulcastConfig: SimulcastConfig = SimulcastConfig(
        enabled: false, activeEncodings: [])

    init(_ room: MembraneRTC, _ displayName: String) {
        self.room = room
        self.displayName = displayName
        participants = [:]
        participantVideos = []

        isMicEnabled = true
        isCameraEnabled = true
        isScreensharingEnabled = false

        room.add(delegate: self)

        self.room?.connect(metadata: .init(["displayName": displayName]))
    }

    func enableTrack(_ type: LocalTrackType, enabled: Bool) {
        switch type {
        case .video:
            if let track = localVideoTrack, track.enabled() != enabled {
                track.setEnabled(enabled)
            }

            isCameraEnabled = enabled
        case .audio:
            if let track = localAudioTrack, track.enabled() != enabled {
                track.setEnabled(enabled)
            }

            isMicEnabled = enabled
        default:
            break
        }
    }

    func switchCameraPosition() {
        guard let cameraTrack = localVideoTrack as? LocalCameraVideoTrack else {
            return
        }

        cameraTrack.switchCamera()
        isFrontCamera = !isFrontCamera

        guard let id = localParticipantId,
            let localVideo = findParticipantVideo(id: id)
        else {
            return
        }

        let localIsFrontCamera = isFrontCamera
        // HACK: there is a delay when we set the mirror and the camer actually switches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            localVideo.mirror = localIsFrontCamera
        }
    }

    func toggleLocalTrack(_ type: LocalTrackType) {
        guard let room = room,
            let localParticipantId = localParticipantId,
            let localParticipant = participants[localParticipantId]
        else {
            return
        }

        switch type {
        case .audio:
            isMicEnabled = !isMicEnabled
            localAudioTrack?.setEnabled(isMicEnabled)
            if let trackId = localAudioTrack?.trackId() {
                room.updateTrackMetadata(
                    trackId: trackId, trackMetadata: .init(["active": isMicEnabled, "type": "audio"]))
            }
            guard var p = participants[localParticipantId] else {
                return
            }
            let pv = findParticipantVideoByOwner(participantId: localParticipantId)

            p.isAudioTrackActive = isMicEnabled
            participants[localParticipantId] = p
            pv?.participant = p

        case .video:
            isCameraEnabled = !isCameraEnabled
            localVideoTrack?.setEnabled(isCameraEnabled)
            if let trackId = localVideoTrack?.trackId() {
                room.updateTrackMetadata(
                    trackId: trackId, trackMetadata: .init(["active": isCameraEnabled, "type": "camera"]))
            }
            let pv = findParticipantVideoByOwner(participantId: localParticipantId)

            pv?.isActive = isCameraEnabled

        case .screensharing:
            // if screensharing is enabled it must be closed by the Broadcast Extension, not by our application
            // the only thing we can do is to display stop recording button, which we already do
            guard isScreensharingEnabled == false else {
                return
            }

            let displayName = room.currentEndpoint().metadata["displayName"] ?? "UNKNOWN"

            let preset = VideoParameters.presetScreenShareHD15
            let videoParameters = VideoParameters(
                dimensions: preset.dimensions.flip(), maxBandwidth: preset.maxBandwidth,
                maxFps: preset.maxFps, simulcastConfig: screencastSimulcastConfig)

            localScreencastTrack = room.createScreencastTrack(
                appGroup: Constants.appGroup,
                videoParameters: videoParameters,
                metadata: .init(["user_id": displayName, "type": "screensharing"]),
                onStart: { [weak self] screencastTrack in
                    guard let self = self else {
                        return
                    }

                    self.localScreensharingVideoId = UUID().uuidString

                    let localParticipantScreensharing = ParticipantVideo(
                        id: self.localScreensharingVideoId!,
                        participant: localParticipant,
                        videoTrack: screencastTrack,
                        isScreensharing: true,
                        isActive: true
                    )

                    self.add(video: localParticipantScreensharing)

                    // once the screensharing has started we want to focus it
                    self.focus(video: localParticipantScreensharing)
                    self.isScreensharingEnabled = true
                },
                onStop: { [weak self] in
                    guard let self = self,
                        let localScreensharingId = self.localScreensharingVideoId,
                        let video = self.findParticipantVideo(id: localScreensharingId)
                    else {
                        return
                    }

                    self.remove(video: video)
                    self.isScreensharingEnabled = false
                })
        }
    }

    func focus(video: ParticipantVideo) {
        DispatchQueue.main.async {
            guard let idx = self.participantVideos.firstIndex(where: { $0.id == video.id }) else {
                return
            }

            self.participantVideos.remove(at: idx)

            // decide where to put current primary video (if one is set)
            if let primary = self.primaryVideo {
                // if either new video or old primary are local videos then we can insert at the beginning
                if video.participant.id == self.localParticipantId
                    || primary.participant.id == self.localParticipantId
                {
                    self.participantVideos.insert(primary, at: 0)
                } else {
                    let index = self.participantVideos.count > 0 ? 1 : 0
                    self.participantVideos.insert(primary, at: index)
                }
                if primary.participant.id != self.localParticipantId && primary.isScreensharing == false {
                    self.room?.setTargetTrackEncoding(trackId: primary.id, encoding: TrackEncoding.l)
                }
            }

            // set the current primary video
            self.primaryVideo = video

            if video.participant.id != self.localParticipantId && self.primaryVideo?.isScreensharing == false {
                self.room?.setTargetTrackEncoding(trackId: video.id, encoding: TrackEncoding.h)
            }
        }
    }

    // in case of local video being a primary one then sets the new video
    // as a primary and moves local video to regular participant videos
    //
    // otherwise simply appends to participant videos
    func add(video: ParticipantVideo) {
        DispatchQueue.main.async {
            guard self.findParticipantVideo(id: video.id) == nil else {
                print("RoomController tried to add already existing ParticipantVideo")
                return
            }

            if let primaryVideo = self.primaryVideo,
                primaryVideo.participant.id == self.localParticipantId
            {
                self.participantVideos.insert(primaryVideo, at: 0)
                self.primaryVideo = video

                return
            }

            self.participantVideos.append(video)
        }
    }

    func remove(video: ParticipantVideo) {
        DispatchQueue.main.async {
            if let primaryVideo = self.primaryVideo,
                primaryVideo.id == video.id
            {
                if self.participantVideos.count > 0 {
                    self.primaryVideo = self.participantVideos.removeFirst()
                } else {
                    self.primaryVideo = nil
                }
                return
            }

            guard let idx = self.participantVideos.firstIndex(where: { $0.id == video.id }) else {
                return
            }

            self.participantVideos.remove(at: idx)
        }
    }

    func findParticipantVideo(id: String) -> ParticipantVideo? {
        if let primaryVideo = primaryVideo,
            primaryVideo.id == id
        {
            return primaryVideo
        }

        return participantVideos.first(where: { $0.id == id })
    }

    func findParticipantVideoByOwner(participantId: String, isScreencast: Bool = false) -> ParticipantVideo? {
        if let primaryVideo = self.primaryVideo, primaryVideo.participant.id == participantId,
            primaryVideo.isScreensharing == isScreencast
        {
            return primaryVideo
        }
        return self.participantVideos.first(where: {
            $0.participant.id == participantId && $0.isScreensharing == isScreencast
        })
    }
}

extension RoomController: MembraneRTCDelegate {

    func onSendMediaEvent(event: SerializedMediaEvent) {}

    func onConnected(endpointId: String, otherEndpoints: [Endpoint]) {
        let localParticipant = Participant(id: endpointId, displayName: "Me", isAudioTrackActive: true)

        let participants = otherEndpoints.map { endpoint in
            Participant(
                id: endpoint.id, displayName: endpoint.metadata["displayName"] as? String ?? "",
                isAudioTrackActive: false)
        }

        let videoTrackMetadata =
            [
                "user_id": displayName, "active": true, "type": "camera",
            ] as [String: Any]
        let audioTrackMetadata =
            [
                "user_id": displayName, "active": true, "type": "audio",
            ] as [String: Any]

        let preset = VideoParameters.presetHD43
        let videoParameters = VideoParameters(
            dimensions: preset.dimensions.flip(),
            maxBandwidth: TrackBandwidthLimit.SimulcastBandwidthLimit(["l": 150, "m": 500, "h": 1500]),
            simulcastConfig: videoSimulcastConfig
        )

        localVideoTrack = room?.createVideoTrack(
            videoParameters: videoParameters, metadata: .init(videoTrackMetadata))
        localAudioTrack = room?.createAudioTrack(metadata: .init(audioTrackMetadata))

        localParticipantId = endpointId

        DispatchQueue.main.async {
            self.participantVideos = participants.map { p in
                ParticipantVideo(id: p.id, participant: p, videoTrack: nil, isActive: false)
            }

            guard let videoTrack = self.localVideoTrack else {
                fatalError("failed to setup local video")
            }

            self.primaryVideo = ParticipantVideo(
                id: localParticipant.id, participant: localParticipant, videoTrack: videoTrack,
                isActive: true, mirror: self.isFrontCamera)
            self.participants[localParticipant.id] = localParticipant
            participants.forEach { participant in self.participants[participant.id] = participant }
        }
    }

    func onConnectionError(metadata _: Any) {
        errorMessage = "Failed to connect"
    }

    func onTrackReady(ctx: TrackContext) {
        ctx.setOnVoiceActivityChangedListener { trackContext in
            if let participantVideo = self.participantVideos.first(where: {
                $0.participant.id == trackContext.endpoint.id
            }) {
                DispatchQueue.main.async {
                    participantVideo.vadStatus = trackContext.vadStatus
                }
            }
            if self.primaryVideo?.participant.id == trackContext.endpoint.id {
                DispatchQueue.main.async {
                    self.primaryVideo?.vadStatus = trackContext.vadStatus
                }
            }
        }

        guard var participant = participants[ctx.endpoint.id] else {
            return
        }

        guard let videoTrack = ctx.track as? VideoTrack else {
            DispatchQueue.main.async {
                participant.isAudioTrackActive = ctx.metadata["active"] as? Bool == true
                self.participants[ctx.endpoint.id] = participant
                let pv = self.findParticipantVideoByOwner(participantId: ctx.endpoint.id)
                pv?.participant = participant
            }

            return
        }

        // there can be a situation where we simply need to replace `videoTrack` for
        // already existing video, happens when dynamically adding new local track
        if let participantVideo = participantVideos.first(where: { $0.id == ctx.trackId }) {
            DispatchQueue.main.async {
                participantVideo.videoTrack = videoTrack
            }

            return
        }

        // track is seen for the first time so initialize the participant's video
        let isScreensharing = ctx.metadata["type"] as? String == "screensharing"
        let video = ParticipantVideo(
            id: ctx.trackId, participant: participant, videoTrack: videoTrack,
            isScreensharing: isScreensharing, isActive: ctx.metadata["active"] as? Bool == true || isScreensharing)

        guard let existingVideo = self.findParticipantVideoByOwner(participantId: ctx.endpoint.id) else {
            add(video: video)

            if isScreensharing {
                focus(video: video)
            }
            return
        }

        if isScreensharing {
            add(video: video)
            focus(video: video)
            return
        }

        guard let idx = self.participantVideos.firstIndex(where: { $0.id == existingVideo.id }) else {
            DispatchQueue.main.async {
                self.primaryVideo = video
            }
            return
        }
        DispatchQueue.main.async {
            self.participantVideos[idx] = video
        }

    }

    func onTrackAdded(ctx _: TrackContext) {}

    func onTrackRemoved(ctx: TrackContext) {
        if let primaryVideo = primaryVideo,
            primaryVideo.id == ctx.trackId
        {
            remove(video: primaryVideo)

            return
        }

        if let video = participantVideos.first(where: { $0.id == ctx.trackId }) {
            remove(video: video)
        }
    }

    func onTrackUpdated(ctx: TrackContext) {
        let isActive = ctx.metadata["active"] as? Bool ?? false

        if ctx.metadata["type"] as? String == "camera" {
            DispatchQueue.main.async {
                if ctx.endpoint.id == self.primaryVideo?.participant.id {
                    self.primaryVideo?.isActive = isActive
                } else {
                    self.participantVideos.first(where: { $0.participant.id == ctx.endpoint.id })?.isActive =
                        isActive
                }
            }
        } else {
            DispatchQueue.main.async {
                guard var p = self.participants[ctx.endpoint.id] else {
                    return
                }
                p.isAudioTrackActive = isActive
                self.participants[ctx.endpoint.id] = p
                if ctx.endpoint.id == self.primaryVideo?.participant.id {
                    self.primaryVideo?.participant = p
                } else {
                    self.participantVideos.first(where: { $0.participant.id == ctx.endpoint.id })?.participant = p
                }
            }

        }
    }

    func onEndpointAdded(endpoint: Endpoint) {
        self.participants[endpoint.id] = Participant(
            id: endpoint.id, displayName: endpoint.metadata["displayName"] as? String ?? "", isAudioTrackActive: false)
        let pv =
            ParticipantVideo(id: endpoint.id, participant: participants[endpoint.id]!, videoTrack: nil, isActive: false)
        add(video: pv)

    }

    func onEndpointRemoved(endpoint: Endpoint) {
        DispatchQueue.main.async {
            self.participants.removeValue(forKey: endpoint.id)
            self.participantVideos = self.participantVideos.filter({ $0.participant.id != endpoint.id })
            if self.primaryVideo?.participant.id == endpoint.id {
                self.primaryVideo = nil
            }
        }
    }

    func onEndpointUpdated(endpoint _: Endpoint) {}

    private func toggleTrackEncoding(
        simulcastConfig: SimulcastConfig, trackId: String, encoding: TrackEncoding
    ) -> SimulcastConfig {
        if simulcastConfig.activeEncodings.contains(encoding) {
            room?.disableTrackEncoding(trackId: trackId, encoding: encoding)
            return SimulcastConfig(
                enabled: true, activeEncodings: simulcastConfig.activeEncodings.filter({ $0 != encoding }))
        } else {
            room?.enableTrackEncoding(trackId: trackId, encoding: encoding)
            return SimulcastConfig(
                enabled: true, activeEncodings: simulcastConfig.activeEncodings + [encoding])
        }
    }

    func toggleVideoTrackEncoding(encoding: TrackEncoding) {
        guard let trackId = localVideoTrack?.trackId() else {
            return
        }
        videoSimulcastConfig = toggleTrackEncoding(
            simulcastConfig: videoSimulcastConfig, trackId: trackId, encoding: encoding)
    }

    func toggleScreencastTrackEncoding(encoding: TrackEncoding) {
        guard let trackId = localScreencastTrack?.trackId() else {
            return
        }
        screencastSimulcastConfig = toggleTrackEncoding(
            simulcastConfig: screencastSimulcastConfig, trackId: trackId, encoding: encoding)
    }
}
