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



class CameraViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate{
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var plusLabel: UILabel!
    @IBOutlet weak var minusLabel: UILabel!
    @IBOutlet weak var zoomSlider: UISlider!
    @IBOutlet weak var ledImage: UIImageView!
    @IBOutlet weak var informationLabel: UILabel!
    @IBOutlet weak var arView: ARSCNView!
    var latestPrediction : String = "…" // a variable containing the latest CoreML prediction
    
    @IBOutlet weak var debugTextView: UITextView!
    
    let streamPort = 8080
    
    //812 * 375
    //1920 * 1080
    let rationX: Double = 812.0/1920.0
    let rationY: Double = 375.0/1080.0
    let cloudChaserServerUrl = "http://65.49.81.103:8080/ws"
    let ip = IPChecker.getIP()
    let context = CIContext(options: nil)
    var clients = [Int: StreamingSession]()
    var serverSocket: GCDAsyncSocket?
    var previousOrientation = UIDeviceOrientation.unknown
    var ipIsDisplayed = false
    var ipAddress = ""
    var count = 0
    var tmpBox: Box!
    var inception: inceptionDetect!
    

    
    static var imagOrientation: UIImageOrientation = UIImageOrientation.up
    
    var chaseClient: CloudChaserClient!
    
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
            print("other")
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Intialize AR World Tracking
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
        
        // Intialize Socket
        print("Client's IP \(String(describing: self.ip))")
        informationLabel.text = self.ip! + ":" + String(streamPort)
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
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
//        arView.showsStatistics = true
        
        NotificationCenter.default.addObserver(forName: .UIDeviceOrientationDidChange,
                                               object: nil,
                                               queue: .main,
                                               using: didRotate)
        //        beginSession()
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapGesture(_:)))
        singleTap.numberOfTapsRequired = 1
        arView.addGestureRecognizer(singleTap)
        inception = inceptionDetect(view: self)
    }
    
    
    
    

    
    
    @objc func singleTapGesture(_ sender : UITapGestureRecognizer) {
        var loc = sender.location(in: arView)
        print(loc.x, loc.y)
        guard let nodePosition = hitWorldPoint(x: loc.x, y: loc.y) else {return}
        
        
//        let node : SCNNode = createNewBubbleParentNode("lol")
//        arView.scene.rootNode.addChildNode(node)
//        node.position = nodePosition
        
        tmpBox = Box()
        tmpBox.position = nodePosition
        tmpBox.move(side: .right, to: 0.1)
        tmpBox.move(side: .top, to: 0.1)
        tmpBox.move(side: .front, to: 0.1)

        arView.scene.rootNode.addChildNode(tmpBox)
        
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
        
        if count == 3{
            DispatchQueue.global(qos: .background).async {
                let currentImg = frame.capturedImage
                let sourceImage = CIImage(cvImageBuffer: currentImg, options: nil)
                guard let tempImage = self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return }
                let uiimage = UIImage(cgImage: tempImage, scale: 0.5, orientation: CameraViewController.imagOrientation)
                
                //                let imageToSend = UIImageJPEGRepresentation(self.resizeImage(image: uiimage), 0)
                let imageToSend = UIImageJPEGRepresentation(uiimage, 0)
                
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
        
        
        
        // Indciation Client status
        //        if self.clients.isEmpty {
        //            DispatchQueue.main.async(execute: {
        //                self.ledImage.image = UIImage(named: "led_gray")
        //            })
        //        }
        
        // Update curr Objects label
        if let cClient = chaseClient {
            if let objs = cClient.currOjbectsArray{
                
                var currObj = ""
                for obj in objs{
                    currObj.append(obj.objectName!)
                    currObj.append("\n")
//                    print(obj.top, obj.bottom, obj.left, obj.right)
                    
                    if  let boxNode  = arView.scene.rootNode.childNode(withName: obj.objectName!, recursively: false){
//                        print("Now update")
                    } else {
                        if obj.objectName == "b'keyboard" {
                            let y: CGFloat = CGFloat(rationY) * CGFloat((obj.top! + obj.bottom!))/2
                            let x: CGFloat = CGFloat(rationX) * CGFloat((obj.left! + obj.right!))/2
                         
                            guard var nodePosition = hitWorldPoint(x: y, y: x) else {return}
//                            print(y, x)
//                            print(arView.bounds.midX, arView.bounds.midY)
//                            let length = CGFloat(obj.top! - obj.bottom!)/4000
//                            let width = CGFloat(obj.left! - obj.right!)/4000
//                            print(length, width)
//                            nodePosition.x = nodePosition.x - 0.1
//                            nodePosition.y = nodePosition.y - 0.1
//                            nodePosition.z = nodePosition.z + 0.1
                            
//                            obj.box.position = nodePosition
                            
//                            obj.box.move(side: .right, to: Float(length))
//                            obj.box.move(side: .top, to: 0.1)
//                            obj.box.move(side: .front, to: Float(width))
                            
                            obj.label.position = nodePosition
                            arView.scene.rootNode.addChildNode(obj.label)
                        }
                        
                        
                    }
                    
                }
                                debugTextView.text = currObj
            }
        }
        
 
    }
    
    
    
    
    @IBAction func btn_Connect(_ sender: UIButton) {
        // Initialize Streaming Session
        chaseClient = CloudChaserClient(serverUrl: cloudChaserServerUrl, phoneUrl: "http://\(self.ip!):8080" )
        chaseClient.connect()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        arView.session.pause()
    }
    
    
}


// MARK: - GCDAsyncSocketDelegate

extension CameraViewController: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("New client from IP \(newSocket.connectedHost ?? "unknown")")
        guard let clientId = newSocket.connectedAddress?.hashValue else { return }
        
        let newClient = StreamingSession(id: clientId, client: newSocket, queue: self.clientQueue)
        self.clients[clientId] = newClient
        newClient.startStreaming()
        
        DispatchQueue.main.async(execute: {
            self.ledImage.image = UIImage(named: "led_red")
        })
    }
    
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
