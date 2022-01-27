//
//  ContentView.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 17/01/2022.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject var appCtrl: AppController
    
    var body: some View {
        ZStack {
            Color.blue.darker(by: 0.5).ignoresSafeArea()
            if appCtrl.client != nil && !appCtrl.awaitingConnect {
                RoomView(appCtrl.client!)
            } else if (appCtrl.awaitingConnect) {
                ConnectView()
            }
        }.foregroundColor(Color.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
