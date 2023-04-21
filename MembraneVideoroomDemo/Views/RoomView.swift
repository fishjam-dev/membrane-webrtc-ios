import Foundation
import MembraneRTC
import ReplayKit
import SwiftUI

#if os(iOS)
    @available(iOS 12, *)
    extension RPSystemBroadcastPickerView {
        public static func show(
            for preferredExtension: String? = nil, showsMicrophoneButton: Bool = false
        ) {
            let view = RPSystemBroadcastPickerView()
            view.preferredExtension = preferredExtension
            view.showsMicrophoneButton = showsMicrophoneButton
            let selector = NSSelectorFromString("buttonPressed:")
            if view.responds(to: selector) {
                view.perform(selector, with: nil)
            }
        }
    }
#endif

class OrientationReceiver: ObservableObject {
    @Published var orientation: UIDeviceOrientation

    init() {
        orientation = UIDevice.current.orientation
    }

    func update(newOrientation: UIDeviceOrientation) {
        // in case of faceUp ignore the orientation and leave the old one
        if newOrientation != .faceUp {
            orientation = newOrientation
        }
    }
}

struct RoomView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var appCtrl: AppController
    @ObservedObject var room: RoomController
    @ObservedObject var orientationReceiver: OrientationReceiver
    @State private var localDimensions: Dimensions?

    init(_ room: MembraneRTC) {
        orientationReceiver = OrientationReceiver()
        self.room = RoomController(room)
    }

    @ViewBuilder
    func simulcastButtons(
        simulcastConfig: SimulcastConfig, toggleEncoding: @escaping (_ encoding: TrackEncoding) -> Void
    ) -> some View {
        let encodings = [TrackEncoding.l, TrackEncoding.m, TrackEncoding.h]

        ForEach(encodings, id: \.self) { e in
            Button(
                action: {
                    toggleEncoding(e)
                },
                label: {
                    Text(e.description)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            )
            .background(Color.blue.darker())
            .cornerRadius(8)
            .opacity(simulcastConfig.activeEncodings.contains(e) ? 1 : 0.5)
        }
    }

    @ViewBuilder
    func simulcastControls() -> some View {
        VStack {
            HStack {
                Text("Video quality")
                    .font(.system(size: 12))

                simulcastButtons(
                    simulcastConfig: room.videoSimulcastConfig,
                    toggleEncoding: room.toggleVideoTrackEncoding(encoding:))
            }
        }
    }

    @ViewBuilder
    func participantsVideoViews(_ participantVideos: [ParticipantVideo], size: CGFloat) -> some View {
        ScrollView(.vertical) {
            VStack {
                ForEach(Array(stride(from: 0, to: participantVideos.count, by: 2)), id: \.self) { index in
                    HStack {
                        Spacer()
                        ParticipantVideoView(participantVideos[index], height: size, width: size)
                            .onTapGesture {
                                self.room.focus(video: participantVideos[index])
                            }
                        Spacer()

                        if index + 1 < participantVideos.count {
                            ParticipantVideoView(participantVideos[index + 1], height: size, width: size)
                                .onTapGesture {
                                    self.room.focus(video: participantVideos[index + 1])
                                }
                            Spacer()
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    func mediaControlButton(_ type: LocalTrackType, enabled: Bool) -> some View {
        let enabledLabel = type == .video ? "video.fill" : "mic.fill"
        let disabledLabel = type == .video ? "video.slash.fill" : "mic.slash.fill"

        Button(action: {
            self.room.toggleLocalTrack(type)
        }) {
            Image(systemName: enabled ? enabledLabel : disabledLabel)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(enabled ? Color.white : Color.red.darker())
        }
    }

    @ViewBuilder
    func cameraSwitchButton() -> some View {
        Button(
            action: {
                self.room.switchCameraPosition()
            },
            label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.white)
            })
    }

    @ViewBuilder
    func screensharingControlButton() -> some View {
        let label =
            room.isScreensharingEnabled ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"

        Button(action: {
            self.room.toggleLocalTrack(.screensharing)

            RPSystemBroadcastPickerView.show(for: Constants.screencastExtensionBundleId)
        }) {
            Image(systemName: label)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color.white)
        }
    }

    @ViewBuilder
    func controls() -> some View {
        HStack {
            Spacer()

            mediaControlButton(.audio, enabled: self.room.isMicEnabled)
            //                .padding(.trailing)

            mediaControlButton(.video, enabled: self.room.isCameraEnabled)
            //                .padding(.trailing)

            Button(action: {
                self.appCtrl.disconnect()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.red.darker())
            }  //.padding(.trailing)

            cameraSwitchButton()
            //.padding(.trailing)

            if #available(iOS 12, *) {
                screensharingControlButton()
                //.padding(.trailing)
            }

            Spacer()
        }.padding()
    }

    private func calculatePrimaryFrameHeight(geometry: GeometryProxy) -> CGFloat {
        if orientationReceiver.orientation.isLandscape {
            return geometry.size.height * 0.9 - 20
        } else {
            return 200 * 16 / 9
        }
    }

    private func calculatePrimaryFrameWidth(geometry: GeometryProxy) -> CGFloat {
        if orientationReceiver.orientation.isLandscape {
            return geometry.size.width * 0.67 - 20
        } else {
            return 200
        }
    }

    private func calculateSecondaryFrameSize(geometry: GeometryProxy) -> CGFloat {
        if orientationReceiver.orientation.isLandscape {
            return geometry.size.height * 0.5 - 20
        } else {
            return geometry.size.height * 0.25 - 40
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let videoFrameHeight = calculatePrimaryFrameHeight(geometry: geometry)
            let videoFrameWidth = calculatePrimaryFrameWidth(geometry: geometry)
            let participantVideoSize = calculateSecondaryFrameSize(geometry: geometry)
            VStack {
                ScrollView(.vertical) {
                    VStack {
                        Text("Membrane iOS Demo")
                            .bold()
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)

                        simulcastControls()

                        if let errorMessage = room.errorMessage {
                            Text(errorMessage).foregroundColor(.red)
                        } else {
                            AdaptiveStack(orientation: self.orientationReceiver.orientation) {
                                if let primaryVideo = room.primaryVideo {
                                    ParticipantVideoView(primaryVideo, height: videoFrameHeight, width: videoFrameWidth)
                                        .padding(.bottom)
                                } else {
                                    Text("Local video track is not available yet...").foregroundColor(.white)
                                }

                                VStack {
                                    participantsVideoViews(room.participantVideos, size: participantVideoSize)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                Spacer()
                controls()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                self.room.enableTrack(.video, enabled: false)
            case .active:
                self.room.enableTrack(.video, enabled: true)
            default:
                break
            }
        }
        .onRotate { newOrientation in
            DispatchQueue.main.async {
                self.orientationReceiver.update(newOrientation: newOrientation)
            }
        }
    }
}
