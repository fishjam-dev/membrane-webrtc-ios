//
//  MembraneVideoroomDemoApp.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 17/01/2022.
//

import SwiftUI


@main
struct MembraneVideoroomDemoApp: App {
    @StateObject private var appState = AppController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .navigationTitle("Membrane Videoroom Demo")
        }
    }
}
