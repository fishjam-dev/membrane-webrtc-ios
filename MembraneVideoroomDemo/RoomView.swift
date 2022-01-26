import Foundation
import SwiftUI
import WebRTC

extension RTCVideoTrack: Identifiable {
}

struct RoomView: View {
    @ObservedObject var room: ObservableRoom
    
    @State private var localDimensions: Dimensions?
    
    init(_ room: MembraneRTC) {
        self.room = ObservableRoom(room)
    }
    
    
    @ViewBuilder
    func participantsList(_ participants: Array<Participant>) -> some View {
        let participantNames = participants.map {
            $0.displayName
        }.joined(separator: ", ")
        
        if participants.count > 0 {
             HStack {
                Text("Participants: ").bold()
                Text(participantNames)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
             EmptyView()
        }
    }
    
    @ViewBuilder
    func participantsVideoViews(_ participants: Array<Participant>, width: CGFloat, height: CGFloat) -> some View {
        let videoTracks = participants.compactMap { $0.videoTrack }
        
        ForEach(videoTracks) { track in
            SwiftUIVideoView(track, fit: .fill, dimensions: $localDimensions)
                .background(Color.blue.darker())
                .frame(width: width, height: height, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue.darker(by: 0.4), lineWidth: 2)
                )
                .padding(10)
        }
        
    }

    var body: some View {
        GeometryReader { geometry in
            // width minus potential padding
            let videoFrameWidth = geometry.size.width * 0.5 - 20
            // video height assumed that we are dealing with 9/16 minus potential padding
            let videoFrameHeight = (videoFrameWidth) * (16.0 / 9.0) - 20
            
            VStack {
                Text("Membrane iOS Demo")
                    .bold()
                    .font(.system(size: 20))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                
                if let track = room.localVideoTrack {
                    SwiftUIVideoView(track.track, fit: .fill, dimensions: $localDimensions)
                        .background(Color.blue.darker())
                        .frame(width: videoFrameWidth, height: videoFrameHeight, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.blue.darker(by: 0.4), lineWidth: 2)
                        )
                        .padding(10)
                    
                    participantsVideoViews(room.participants, width: videoFrameWidth, height: videoFrameHeight)
                } else {
                    Text("Local video track is not available yet...").foregroundColor(.white)
                }
                
                if let errorMessage = room.errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                Spacer()
                
                participantsList(room.participants)
            }
            .padding(8)
        }
    }
}
