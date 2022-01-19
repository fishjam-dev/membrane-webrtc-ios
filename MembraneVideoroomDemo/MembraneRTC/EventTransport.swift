//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation


public protocol EventTransport {
    // TODO: this should return non-nil event, leave it for now
    func receiveEvent(data: Data) -> Event?;
    func sendEvent(event: Event);
}
