//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation


public protocol EventTransport {
    func receiveEvent(data: Data) -> Event;
    func sendEvent(event: Event);
}
