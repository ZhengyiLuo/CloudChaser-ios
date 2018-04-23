//
//  CameraViewController.swift
//  StreamIt
//
//  Created by Thibault Wittemberg on 14/04/2016.
//  Copyright © 2016 Thibault Wittemberg. All rights reserved.
//

import UIKit
import AVFoundation
import CocoaAsyncSocket
import SceneKit
import ARKit



class CameraViewController: UIViewController,  UIGestureRecognizerDelegate{
    
    @IBOutlet weak var statusView: UITextView!
    @IBOutlet weak var ledImage: UIImageView!
    @IBOutlet weak var arView: ARSCNView!
    var objectsViewController: VirtualObjectSelectionViewController?
    
    @IBOutlet weak var debugTextView: UITextView!
    
    let streamPort = 8080
    
    let cloudChaserServerUrl = "http://65.49.81.103:8080/ws"
    //    let cloudChaserServerUrl = "http://158.130.62.103:8080/ws"
    let ip = IPChecker.getIP()
    let context = CIContext(options: nil)
    var clients = [Int: StreamingSession]()
    var serverSocket: GCDAsyncSocket?
    var previousOrientation = UIDeviceOrientation.unknown
    var ipIsDisplayed = false
    var ipAddress = ""
    var count = 0
    var tmpBox: Box!
    var inception: InceptionDetect!
    var clientStatus: ClientStatus!
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketWriteQueue = DispatchQueue(label: "SocketWriteQueue", attributes: .concurrent)
    let isDebugging = false
    var isResizing = true
    var chaseClient: CloudChaserClient!
    
    static var imagOrientation: UIImageOrientation = UIImageOrientation.up
    var didRotate: (Notification) -> Void = { notification in
        switch UIDevice.current.orientation {
        case .landscapeRight:
            imagOrientation = UIImageOrientation.down
        case .landscapeLeft:
            imagOrientation = UIImageOrientation.up
        case .portrait :
            imagOrientation = UIImageOrientation.right
        case .portraitUpsideDown:
            imagOrientation = UIImageOrientation.left
        default:
            return
            //            print("other")
            
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        statusView.text = "Initiazling"
        // Intialize AR World Tracking
        
        
        // Intialize Sockets
        initializeSockets()
        
        // Initialize AR
        initalizeAR()
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapGesture(_:)))
        singleTap.numberOfTapsRequired = 1
        arView.addGestureRecognizer(singleTap)
        statusView.text = "Running Local Detection"
        clientStatus = .noClient
        inception = InceptionDetect(view: self)
        debugTextView.isHidden = !isDebugging
    }
    
    @objc func singleTapGesture(_ sender : UITapGestureRecognizer) {
        
        if clientStatus == .noClient{
            guard let nodePosition = hitWorldPoint(x: arView.bounds.midX, y: arView.bounds.midY) else {return}
            
            let node : SCNNode = DetectedObject.createNewBubbleParentNode(inception.latestPrediction)
            node.position = nodePosition
            arView.scene.rootNode.addChildNode(node)
        }
        
        
        //        tmpBox = Box()
        //        tmpBox.position = nodePosition
        //        tmpBox.move(side: .right, to: 0.1)
        //        tmpBox.move(side: .top, to: 0.1)
        //        tmpBox.move(side: .front, to: 0.1)
        
        //        arView.scene.rootNode.addChildNode(tmpBox)
        
    }
    
    func hitWorldPoint(x: CGFloat, y: CGFloat) -> SCNVector3!{
        let screenCentre : CGPoint = CGPoint(x: x, y: y)
        
        let arHitTestResults : [ARHitTestResult] = arView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            
            return worldCoord
        }
        return nil
    }
    
    
    func resizeImage(image: UIImage) -> UIImage {
        if image.size.height >= 1024 && image.size.width >= 1024 {
            
            UIGraphicsBeginImageContext(CGSize(width:480, height:270))
            image.draw(in: CGRect(x:0, y:0, width:480, height:270))
            
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage!
        }
        return image
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession,didUpdate frame: ARFrame) {
        
        if clientStatus == .hasClient{
            if count == 3{
                DispatchQueue.global(qos: .background).async {
                    let currentImg = frame.capturedImage
                    let sourceImage = CIImage(cvImageBuffer: currentImg, options: nil)
                    guard let tempImage = self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return }
                    //                    let uiimage = UIImage(cgImage: tempImage, scale: 0.5, orientation: CameraViewController.imagOrientation)
                    let uiimage = UIImage(cgImage: tempImage)
                    var imageToSend:  Data? = nil
                    if self.isResizing{
                        imageToSend = UIImageJPEGRepresentation(self.resizeImage(image: uiimage), 0)
                    } else {
                        imageToSend = UIImageJPEGRepresentation(uiimage, 0)
                    }
                    
                    
                    
                    
                    for (key, client) in self.clients {
                        if client.connected {
                            client.dataToSend = (imageToSend as NSData?)?.copy() as? Data
                        } else {
                            self.clients.removeValue(forKey: key)
                        }
                    }
                }
                count = 0
            } else {
                count += 1
            }
        }
        
        
        
    }
    
    func connectToChase(){
        chaseClient = CloudChaserClient(serverUrl: cloudChaserServerUrl, phoneUrl: "http://\(self.ip!):8080", view: self)
        chaseClient.connect()
        clientStatus = .hasClient
        statusView.text = "Contacting Remote Server"
    }
    
    func disconnectToChase(){
        if clientStatus == .hasClient{
            if chaseClient.isConnected(){
                chaseClient.disconnect()
            }
            chaseClient = nil
            clientStatus = .noClient
            inception = InceptionDetect(view: self)
            statusView.text = "Running Local Detection"
        }
    }
    
    func reset(){
        arView.session.pause()
        
        arView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode() }
        
        if clientStatus == .hasClient{
            if chaseClient.isConnected(){
                chaseClient.disconnect()
            }
            chaseClient = nil
            clientStatus = .noClient
            inception = InceptionDetect(view: self)
            statusView.text = "Running Local Detection"
        }
        initalizeAR()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        arView.session.pause()
    }
    
    
}


// MARK: - GCDAsyncSocketDelegate


extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
