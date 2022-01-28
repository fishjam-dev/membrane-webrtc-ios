//
//  AdaptiveStack.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 28/01/2022.
//

import SwiftUI

struct AdaptiveStack<Content: View>: View {
    let orientation: UIDeviceOrientation
    let content: () -> Content
    let naturalAlignment: Bool
    
    init(orientation: UIDeviceOrientation, naturalAlignment: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.orientation = orientation
        self.naturalAlignment = naturalAlignment
        self.content = content
    }
    
    var body: some View {
        Group {
            if orientation.isLandscape {
                if naturalAlignment {
                    HStack(content: content)
                } else {
                    VStack(content: content)
                }
            } else {
                if naturalAlignment {
                    VStack(content: content)
                } else {
                    HStack(content: content)
                }
            }
        }
    }
}
