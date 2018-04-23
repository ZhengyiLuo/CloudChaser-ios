//
//  CameraViewController+StreamingServer.swift
//  StreamIt
//
//  Created by Zen on 4/22/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import SceneKit
import ARKit

extension CameraViewController: GCDAsyncSocketDelegate {
    
    enum ClientStatus{
        case hasClient
        case noClient
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("New client from IP \(newSocket.connectedHost ?? "unknown")")
        guard let clientId = newSocket.connectedAddress?.hashValue else { return }
        
        let newClient = StreamingSession(id: clientId, client: newSocket, queue: self.clientQueue)
        self.clients[clientId] = newClient
        newClient.startStreaming()
        self.clientStatus = .hasClient
        DispatchQueue.main.async(execute: {
            self.ledImage.image = UIImage(named: "led_red")
        })
        DispatchQueue.main.async(execute: {
            self.statusView.text = "Client Connected, running Cloud Detection"
        })
        
    }
    
}
