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
            Color.blue.ignoresSafeArea()
            
            if let room = appCtrl.room {
                RoomView(room)
            } else {
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
