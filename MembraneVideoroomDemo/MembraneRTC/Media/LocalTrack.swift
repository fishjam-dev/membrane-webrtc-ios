//
//  LocalTrack.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 24/01/2022.
//

import Foundation
import WebRTC

public protocol LocalTrack {
    func start();
    func stop();
    func toggle();
    func rtcTrack() -> RTCMediaStreamTrack;
}
