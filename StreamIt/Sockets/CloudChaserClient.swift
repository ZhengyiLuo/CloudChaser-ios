//
//  CloudChaserClient.swift
//  StreamIt
//
//  Created by Zen on 4/15/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import Starscream
import SceneKit

class CloudChaserClient: WebSocketDelegate{
    
    var chaseClientSocket :WebSocketClient!
    var phoneUrl: String!
    var currOjbectsDict: [String: [DetectedObject]]!
    var mainView: CameraViewController!
    //812 * 375
    //1920 * 1080
    let rationX: Double = 812.0/1920.0
    let rationY: Double = 375.0/1080.0
    var objectCache: SwiftlyLRU<String, SCNVector3>?
    let CACHE_CAPACITY = 50
    
    init(serverUrl: String, phoneUrl: String, view: CameraViewController) {
        chaseClientSocket = WebSocket(url: URL(string: serverUrl)!)
        chaseClientSocket.delegate = self
        self.phoneUrl = phoneUrl
        currOjbectsDict = [:]
        self.mainView = view
        self.objectCache = SwiftlyLRU(capacity: CACHE_CAPACITY)
    }
    
    
    func connect(){
        chaseClientSocket.connect()
    }
    
    func isConnected() -> Bool{
        return chaseClientSocket.isConnected
    }
    
    func disconnect(){
        chaseClientSocket.disconnect()
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
        //        print("got some text: \(text)")
        let strArray = text.split(separator: ",")
        
        guard var yoloObj = DetectedObject(stringArray: strArray) else {return}
        
        let y: CGFloat = CGFloat(rationY) * CGFloat((yoloObj.top! + yoloObj.bottom!))/2
        let x: CGFloat = CGFloat(rationX) * CGFloat((yoloObj.left! + yoloObj.right!))/2
        guard var objNodePos = mainView.hitWorldPoint(x: y, y: x) else {return}
        yoloObj.setPosition(objNodePos)
        
        if var objArray = currOjbectsDict[yoloObj.objectName!] {
            // now val is not nil and the Optional has been unwrapped, so use it
            var addObject = false
            for object in objArray{
                
                if let coord = object.position(){
//                    print(coord.distance(objNodePos))
                    var distance = coord.distance(objNodePos)
                    var angle = coord.angle(objNodePos)
                    if distance > 1.5 && angle > 0.5{
                            addObject = true
                    } else if distance > 0.5 && angle > 0.2 {
                        object.setPosition(objNodePos)
                    }
                }
            }
            if addObject{
                objArray.append(yoloObj)
                mainView.arView.scene.rootNode.addChildNode(yoloObj.label)
            }
        } else {
            currOjbectsDict[yoloObj.objectName!] = [yoloObj]
            mainView.arView.scene.rootNode.addChildNode(yoloObj.label)
        }
        
        
        
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("got some data: \(data.count)")
    }
    
    
    
    
    
}
