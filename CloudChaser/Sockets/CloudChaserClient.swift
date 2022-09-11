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
    var ratioX: Double
    var ratioY: Double
    var objectCache: SwiftlyLRU<String, SCNVector3>
    let CACHE_CAPACITY = 50
    
    init(serverUrl: String, phoneUrl: String, view: CameraViewController) {
        self.phoneUrl = phoneUrl
        self.objectCache = SwiftlyLRU(capacity: CACHE_CAPACITY)
        self.mainView = view
        chaseClientSocket = WebSocket(url: URL(string: serverUrl)!)
        currOjbectsDict = [:]
        
        if view.isResizing {
            self.ratioX = 812.0/480.0
            self.ratioY = 375.0/270.0
        } else {
            self.ratioX = 812.0/1920.0
            self.ratioY = 375.0/1080.0
        }
        
        chaseClientSocket.delegate = self
        
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
    
    func write(string: String) {
        chaseClientSocket.write(string: string)
    }
    
    func write(data: Data) {
        chaseClientSocket.write(data: data)
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
        
        //
        let y: CGFloat = 375 - CGFloat(ratioY) * CGFloat((yoloObj.top! + yoloObj.bottom!))/2
        let x: CGFloat = CGFloat(ratioX) * CGFloat((yoloObj.left! + yoloObj.right!))/2
        guard let objNodePos = mainView.hitWorldPoint(x: y, y: x) else {return}
        yoloObj.setPosition(objNodePos)
        
        if var objArray = currOjbectsDict[yoloObj.objectName!] {
            // now val is not nil and the Optional has been unwrapped, so use it
            var addObject = false
            
            // More than 20 objects, not a good sign
            print(objArray.count, yoloObj.objectName!)
            if objArray.count > 20 {
                print("Revmoing")
                while var node = mainView.arView.scene.rootNode.childNode(withName: yoloObj.objectName!, recursively: false){
                    node.removeFromParentNode()
                }
            }
            
            for object in objArray{
                
                if let coord = object.position(){
//                    print(coord.distance(objNodePos))
                    let distance = coord.distance(objNodePos)
                    let angle = coord.angle(objNodePos)
                    if distance > 1.5 && angle > 0.5{
                            addObject = true
                    } else{
                        
                        object.setPosition(objNodePos)
                    }
                }
            }
            if addObject{
                objectCache[yoloObj.objectName!] = yoloObj.position()
                objArray.append(yoloObj)
                mainView.arView.scene.rootNode.addChildNode(yoloObj.label)
            }
        } else {
            currOjbectsDict[yoloObj.objectName!] = [yoloObj]
            mainView.arView.scene.rootNode.addChildNode(yoloObj.label)
            
            objectCache[yoloObj.objectName!] = yoloObj.position()
        }
        
        for (key,value) in currOjbectsDict{
            if let obj = objectCache[key] {
                // So the object is sitll in the cache, good for you!
            } else {
                while var node = mainView.arView.scene.rootNode.childNode(withName: key, recursively: false){
                       node.removeFromParentNode()
                }
            }
        }
        
        
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("got some data: \(data.count)")
    }
    
    
    
    
    
}
