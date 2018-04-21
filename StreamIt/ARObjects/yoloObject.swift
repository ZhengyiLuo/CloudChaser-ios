//
//  yoloObject.swift
//  StreamIt
//
//  Created by Zen on 4/16/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import SceneKit

class YoloObject{
    
    let worldCoord : SCNVector3?
    let objectName: String?
    var left: Int?
    var right: Int?
    var top: Int?
    var bottom: Int?
    var confidence: Double?
//    var box: Box!
    var boxNode2D: SCNNode!
    
    init?(stringArray : Array<Substring>) {
        if stringArray.count > 5{
            objectName = String(stringArray[0])
            left = Int(String(stringArray[1]))
            right = Int(stringArray[2])
            top = Int(stringArray[3])
            bottom = Int(stringArray[4])
            confidence = Double(stringArray[6])
            worldCoord = nil
//            box = Box()
            let box2D = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
            boxNode2D = SCNNode(geometry: box2D)
            boxNode2D.position = SCNVector3(0,0,-0.5)
        } else {
            return nil
        }
        
    }
    
    
    
    
}
