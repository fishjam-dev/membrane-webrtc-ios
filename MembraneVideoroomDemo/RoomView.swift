import SwiftUI

class RoomView: View {
    @ObservableObject var client: MembraneRTC

    var body: some View {
        if let track = client.localVideoTrack {
            SwiftUIVideoView(track.track, fit: .fill)
        } else {
            Text("Local video track is not available yet...")
        }
    }
}