import Foundation
import SwiftUI

struct RoomView: View {
    @ObservedObject var client: MembraneRTC

    var body: some View {
        VStack {
            Text("Welcome").foregroundColor(.white)
            
            if let track = client.localVideoTrack {
                SwiftUIVideoView(track.track, fit: .fill)
                    .border(Color.black)
            } else {
                Text("Local video track is not available yet...").foregroundColor(.white)
            }
            Text("Goodbye").foregroundColor(.white)
        }
        .padding(8)
    }
}
