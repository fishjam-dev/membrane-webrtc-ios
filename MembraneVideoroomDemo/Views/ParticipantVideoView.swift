import MembraneRTC
import SwiftUI

struct ParticipantVideoView: View {
    @ObservedObject var participantVideo: ParticipantVideo

    let height: CGFloat
    let width: CGFloat

    @State private var layout: VideoView.Layout
    @State private var localDimensions: Dimensions?

    init(_ participantVideo: ParticipantVideo, height: CGFloat, width: CGFloat) {
        self.participantVideo = participantVideo
        self.height = height
        self.width = width
        layout = .fill

        guard let value = localDimensions else { return }

        selectLayout(width, height, value)
    }

    func selectLayout(_ width: CGFloat, _ height: CGFloat, _ dimensions: Dimensions) {
        guard width != height else {
            // fill the square
            layout = .fill
            return
        }

        if (height > width) == (dimensions.height > dimensions.width) {
            layout = .fill
        } else {
            layout = .fit
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SwiftUIVideoView(self.participantVideo.videoTrack, layout: self.layout, mirror: self.participantVideo.mirror, dimensions: $localDimensions)
                .onChange(of: localDimensions) { value in
                    guard let dimensions = value else { return }

                    selectLayout(width, height, dimensions)
                }
                .background(Color.blue.darker(by: 0.6))
                .frame(width: self.width, height: self.height, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 15))

            Text(self.participantVideo.participant.displayName + (self.participantVideo.isScreensharing ? " (presentation)" : ""))
                .font(.system(size: 20))
                .bold()
                .shadow(color: .black, radius: 1)
                .foregroundColor(Color.white)
                .padding(10)
                .frame(maxWidth: self.width - 10)
                .fixedSize()
        }
    }
}
