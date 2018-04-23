//
//  CameraViewController+ARView.swift
//  CloudChaser
//
//  Created by Zen on 4/23/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

extension CameraViewController: ARSCNViewDelegate, ARSessionDelegate{
    
    
    func initalizeAR() {
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        // Start the view's AR session with a configuration that uses the rear camera,
        // device position and orientation tracking, and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        
        if #available(iOS 11.3, *) {
            configuration.planeDetection = [.horizontal, .vertical]
        } else {
            // Fallback on earlier versions
        }
        
        arView.session.run(configuration)
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        arView.session.delegate = self
        
    }
}
