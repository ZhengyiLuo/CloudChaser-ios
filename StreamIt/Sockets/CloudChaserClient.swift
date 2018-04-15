//
//  CloudChaserClient.swift
//  StreamIt
//
//  Created by Zen on 4/15/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import Starscream

class CloudChaserClient: WebSocketDelegate{
    
    var chaseClient :WebSocketClient!
    
    init(url: String) {
        chaseClient = WebSocket(url: URL(string: url)!)
        chaseClient.delegate = self
    }
    
    
    // Check if connection is valid
    func connect() -> Bool{
        chaseClient.connect()
        return true
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket is connected")
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("got some text: \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("got some data: \(data.count)")
    }
    
    
    
    
}
