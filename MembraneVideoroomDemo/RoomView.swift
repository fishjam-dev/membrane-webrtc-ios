import Foundation
import SwiftUI
import WebRTC

extension RTCVideoTrack: Identifiable {
}

struct RoomView: View {
    @EnvironmentObject var appCtrl: AppController
    @ObservedObject var room: ObservableRoom
    
    @State private var localDimensions: Dimensions?
    
    init(_ room: MembraneRTC) {
        self.room = ObservableRoom(room)
    }
    
    @ViewBuilder
    func participantsVideoViews(_ participantVideos: Array<ParticipantVideo>, size: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(participantVideos) { video in
                    // FIXME: this local dimensions should be kept separately inside some ParticipantVideoView or something...
                    ParticipantVideoView(video, height: size, width: size)
                        .onTapGesture {
                            self.room.focus(video: video)
                        }
//                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func mediaControlButton(_ type: ObservableRoom.LocalTrackType, enabled: Bool) -> some View {
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

    var body: some View {
        GeometryReader { geometry in
            // width minus potential padding
            let videoFrameHeight = geometry.size.height * 0.70 - 20 - geometry.safeAreaInsets.top
            // video height assumed that we are dealing with 9/16 minus potential padding
            let videoFrameWidth = geometry.size.width - 40
            
            VStack {
                Text("Membrane iOS Demo")
                    .bold()
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                
                if let primaryVideo = room.primaryVideo {
                    ParticipantVideoView(primaryVideo, height: videoFrameHeight, width: videoFrameWidth)
                        .padding(.bottom)
                    
                    participantsVideoViews(room.participantVideos, size: geometry.size.height * 0.2 - 20)
                } else {
                    Text("Local video track is not available yet...").foregroundColor(.white)
                }
                
                if let errorMessage = room.errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                
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
                    
                    
                    Spacer()
                }
                    .padding()
            }
            .padding(8)
        }
    }
}
