//
//  yoloObject.swift
//  StreamIt
//
//  Created by Zen on 4/16/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import SceneKit

class DetectedObject{
    
    static let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    let objectName: String?
    var left: Int?
    var right: Int?
    var top: Int?
    var bottom: Int?
    var confidence: Double?
    var box: Box!
    var label: SCNNode!
    
    init?(stringArray : Array<Substring>) {
        if stringArray.count > 5{
            objectName = String(stringArray[0])
            left = Int(String(stringArray[1]))
            right = Int(stringArray[2])
            top = Int(stringArray[3])
            bottom = Int(stringArray[4])
            
            let index = stringArray[6].index(stringArray[6].startIndex, offsetBy: 9)
            confidence = Double(stringArray[6][..<index])
            
            // Do not add value with conficne less than 50
            if confidence! < 60 {
                return nil
            }
            box = Box()
            box.name = objectName
            label = DetectedObject.createNewBubbleParentNode(objectName!)
            label.name = objectName
        } else {
            return nil
        }
        
    }
    
    func position() -> SCNVector3!{
        return label.position
    }
    
    func setPosition(_ pos: SCNVector3){
        label.position = pos
    }
    
    static func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
    
    
}
