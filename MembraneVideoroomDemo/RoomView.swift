import Foundation
import SwiftUI
import WebRTC
import ReplayKit

extension RTCVideoTrack: Identifiable { }

#if os(iOS)
@available(iOS 12, *)

extension RPSystemBroadcastPickerView {
    public static func show(for preferredExtension: String? = nil, showsMicrophoneButton: Bool = false) {
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
        self.orientation = UIDevice.current.orientation
    }
    
    func update(newOrientation: UIDeviceOrientation) {
        // in case of faceUp ignore the orientation and leave the old one
        if newOrientation != .faceUp {
            self.orientation = newOrientation
        }
    }
}

struct RoomView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var appCtrl: AppController
    @ObservedObject var orientationReceiver: OrientationReceiver
    @ObservedObject var room: ObservableRoom
    @State private var localDimensions: Dimensions?
    
    init(_ room: MembraneRTC) {
        self.orientationReceiver = OrientationReceiver()
        self.room = ObservableRoom(room)
    }
    
    @ViewBuilder
    func participantsVideoViews(_ participantVideos: Array<ParticipantVideo>, size: CGFloat) -> some View {
        ScrollView(self.orientationReceiver.orientation.isLandscape ? .vertical : .horizontal) {
            AdaptiveStack(orientation: self.orientationReceiver.orientation, naturalAlignment: false) {
                ForEach(participantVideos) { video in
                    ParticipantVideoView(video, fit: .fill, height: size, width: size)
                        .onTapGesture {
                            self.room.focus(video: video)
                        }
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
    func screensharingControlButton() -> some View {
        let label = self.room.isScreensharingEnabled ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
        
        Button(action: {
            self.room.toggleLocalTrack(.screensharing)
            
            RPSystemBroadcastPickerView.show(for: "com.dscout.MembraneVideoroomDemo.ScreenBroadcastExt")
        }) {
            Image(systemName: label)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color.white.darker())
        }
    }
    
    @ViewBuilder
    func controls() -> some View {
        HStack {
            Spacer()
            
            Button(action: {
                self.appCtrl.disconnect()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.red.darker())
            }.padding(.trailing)
            
            mediaControlButton(.audio, enabled: self.room.isMicEnabled)
                .padding(.trailing)
            
            mediaControlButton(.video, enabled: self.room.isCameraEnabled)
                .padding(.trailing)
            
            screensharingControlButton()
                .padding(.trailing)
            
            Spacer()
        }.padding()
    }
    
    private func calculatePrimaryFrameHeight(geometry: GeometryProxy) -> CGFloat {
        if self.orientationReceiver.orientation.isLandscape {
            return geometry.size.height * 0.9 - 20
        } else {
           return geometry.size.height * 0.70 - 20 - geometry.safeAreaInsets.top
        }
    }
    
    private func calculatePrimaryFrameWidth(geometry: GeometryProxy) -> CGFloat {
        if self.orientationReceiver.orientation.isLandscape {
            return geometry.size.width * 0.67 - 20
        } else {
            return geometry.size.width - 40
        }
    }
    
    private func calculateSecondaryFrameSize(geometry: GeometryProxy) -> CGFloat {
        if self.orientationReceiver.orientation.isLandscape {
            return geometry.size.height * 0.5 - 20
        } else {
            return geometry.size.height * 0.2 - 40
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let videoFrameHeight = calculatePrimaryFrameHeight(geometry: geometry)
            let videoFrameWidth = calculatePrimaryFrameWidth(geometry: geometry)
            let participantVideoSize = calculateSecondaryFrameSize(geometry: geometry)
            
            VStack {
                Text("Membrane iOS Demo")
                    .bold()
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                
                if let errorMessage = room.errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else {
                    AdaptiveStack(orientation: self.orientationReceiver.orientation) {
                        if let primaryVideo = room.primaryVideo {
                            ParticipantVideoView(primaryVideo, fit: .fit, height: videoFrameHeight, width: videoFrameWidth)
                                .padding(.bottom)
                        } else {
                            Text("Local video track is not available yet...").foregroundColor(.white)
                        }
                        
                        VStack {
                            participantsVideoViews(room.participantVideos, size: participantVideoSize)
                            Spacer()
                            controls()
                        }
                    }
                }
            }
            .padding(8)
            
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
