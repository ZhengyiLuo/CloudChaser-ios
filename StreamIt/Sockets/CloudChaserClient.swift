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
    
    var chaseClientSocket :WebSocketClient!
    var phoneUrl: String!
    init(serverUrl: String, phoneUrl: String) {
        chaseClientSocket = WebSocket(url: URL(string: serverUrl)!)
        chaseClientSocket.delegate = self
        self.phoneUrl = phoneUrl
        
    }
    
    
    // Check if connection is valid
    func connect() -> Bool{
        chaseClientSocket.connect()
        return true
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket is connected")
        if let currentPhoneUrl = self.phoneUrl{
            chaseClientSocket.write(string: "Client URL|\(currentPhoneUrl)")
        }
        
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
