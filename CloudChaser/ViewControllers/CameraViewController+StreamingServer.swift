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
    
    func initializeSockets() {
        // Intialize Socket
        print("Client's IP \(String(describing: self.ip))")
        self.serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: self.serverQueue, socketQueue: self.socketWriteQueue)
        
        do {
            try self.serverSocket?.accept(onInterface: self.ip, port: UInt16(streamPort))
        } catch {
            print("Could not start listening on port 8080 (\(error))")
        }
        
        
        if let ip = self.ip {
            ipAddress = "http://\(ip):8080"
        } else {
            ipAddress = "IP address not available"
        }
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
