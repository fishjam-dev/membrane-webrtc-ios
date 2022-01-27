//
//  ParticipantVideoView.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 27/01/2022.
//

import SwiftUI

struct ParticipantVideoView: View {
    let participantVideo: ParticipantVideo
    let height: CGFloat
    let width: CGFloat
    
    @State private var localDimensions: Dimensions?
    
    init(_ participantVideo: ParticipantVideo, height: CGFloat, width: CGFloat) {
        self.participantVideo = participantVideo
        self.height = height
        self.width = width
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SwiftUIVideoView(self.participantVideo.videoTrack, fit: .fill, dimensions: $localDimensions)
                .background(Color.blue.darker(by: 0.6))
                .frame(width: self.width, height: self.height, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            
            Text(self.participantVideo.participant.displayName)
                .font(.system(size: 20))
                .bold()
                .shadow(color: .black, radius: 1)
                .foregroundColor(Color.white)
                .padding(10)
        }
    }
}
