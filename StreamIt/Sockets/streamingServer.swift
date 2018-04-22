//
//  streamingServer.swift
//  StreamIt
//
//  Created by Zen on 4/22/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation

class StreamingServer{
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketWriteQueue = DispatchQueue(label: "SocketWriteQueue", attributes: .concurrent)
    
    
    
    
    
    
}
