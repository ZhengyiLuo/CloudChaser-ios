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
    
    let cloudChaserServerUrl = "http://192.168.0.121:8080/ws"
    
    let ip = IPChecker.getIP()
    let context = CIContext(options: nil)
    var clients = [Int: StreamingSession]()
    var serverSocket: GCDAsyncSocket?
    var previousOrientation = UIDeviceOrientation.unknown
    var ipIsDisplayed = false
    var ipAddress = ""
    var count = 0
    var tmpBox: Box!
//    var inception: InceptionDetect!
    var clientStatus: ClientStatus!
    var fps = 5
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: .concurrent)
    let socketWriteQueue = DispatchQueue(label: "SocketWriteQueue", attributes: .concurrent)
    let isDebugging = false
    var isResizing = false
    var sending = true
    var chaseClient: CloudChaserClient!
    var objPosition: SCNVector3!
    
    static var imagOrientation: UIImage.Orientation = UIImage.Orientation.up
    var didRotate: (Notification) -> Void = { notification in
        switch UIDevice.current.orientation {
        case .landscapeRight:
            imagOrientation = UIImage.Orientation.down
        case .landscapeLeft:
            imagOrientation = UIImage.Orientation.up
        case .portrait :
            imagOrientation = UIImage.Orientation.right
        case .portraitUpsideDown:
            imagOrientation = UIImage.Orientation.left
        default:
            return
            //            print("other")
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    
                    self._setupCaptureSession()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            _setupCaptureSession()
        }
    }

    public var _captureSession: AVCaptureSession?
    public var _videoOutput: AVCaptureVideoDataOutput?
    public var _assetWriter: AVAssetWriter?
    public var _assetWriterInput: AVAssetWriterInput?
    public var _adpater: AVAssetWriterInputPixelBufferAdaptor?
    public var _filename = ""
    public var _time: Double = 0
    public func _setupCaptureSession() {
//        print("!!!!!!!!!!!")
        
//        let session = AVCaptureSession()
//        session.sessionPreset = .hd1920x1080
//
//        guard
//            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
//            let input = try? AVCaptureDeviceInput(device: device),
//            session.canAddInput(input) else { return }
//
//        session.beginConfiguration()
//        session.addInput(input)
//        session.commitConfiguration()
//
//        let output = AVCaptureVideoDataOutput()
//        guard session.canAddOutput(output) else { return }
//        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.yusuke024.video"))
//        session.beginConfiguration()
//        session.addOutput(output)
//        session.commitConfiguration()
//
//        DispatchQueue.main.async {
//            let previewView = _PreviewView()
//            previewView.videoPreviewLayer.session = session
//            previewView.frame = self.view.bounds
//            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//            self.view.insertSubview(previewView, at: 0)
//        }

//        session.startRunning()
//        _videoOutput = output
//        _captureSession = session
    }

    public enum _CaptureState {
        case idle, start, capturing, end
    }
    public var _captureState = _CaptureState.idle
    @IBAction func capture(_ sender: Any) {
        switch _captureState {
        case .idle:
            _captureState = .start
        case .capturing:
            _captureState = .end
        default:
            break
        }
    }
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        statusView.text = "Initiazling"
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
//        statusView.text = "Running Local Detection"
        clientStatus = .noClient
//        inception = InceptionDetect(view: self)
        debugTextView.isHidden = !isDebugging
    }
    
    @objc func singleTapGesture(_ sender : UITapGestureRecognizer) {
        
            arView.scene.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
            guard let nodePosition = hitWorldPoint(x: arView.bounds.midX, y: arView.bounds.midY) else {return}
            let node : SCNNode = DetectedObject.createNewBubbleParentNode("Object")
            node.position = nodePosition
            arView.scene.rootNode.addChildNode(node)
            objPosition = nodePosition
            


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
    
    func saveImage(image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent("fileName.png")!)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    @IBAction func btnStart(_ sender: UIButton) {
        
//        connectToChase()
        
    }
    
    
    @IBAction func btnStop(_ sender: UIButton) {
        stop()
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession,didUpdate frame: ARFrame) {
        var sendJson : [String: String] = [:]
        
        
//        if clientStatus == .hasClient && self.sending{
//
//            let currentTransform = frame.camera.transform
//            let floatArray = (0..<4).flatMap { x in (0..<4).map { y in currentTransform[x][y] } }
//            let stringArray = floatArray.map { String($0) }
//            let tranformString = stringArray.joined(separator: " ")
//            let now = Date()
//            let formatter = DateFormatter()
//            formatter.timeZone = TimeZone.current
//            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
//            let dateString = formatter.string(from: now)
////            print(dateString)
//
//            sendJson["camPose"] = tranformString
//            sendJson["timeStamp"] = dateString
//            if self.objPosition != nil{
//                sendJson["objPose"] = [self.objPosition.x, self.objPosition.y, self.objPosition.z].map{String($0)}.joined(separator: " ")
//            }
//            do{
//                let jsonData = try JSONSerialization.data(withJSONObject: sendJson, options: .prettyPrinted)
//                let jsonString = String(data: jsonData, encoding: .utf8)!
//                let currentImg = frame.capturedImage
//                let sourceImage = CIImage(cvImageBuffer: currentImg, options: nil)
//                guard let tempImage = self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return }
//                let uiimage = UIImage(cgImage: tempImage)
//                var imageToSend:  Data? = nil
//                if self.isResizing{
//                    imageToSend = UIImageJPEGRepresentation(self.resizeImage(image: uiimage), 0)
//                } else {
//                    imageToSend = UIImageJPEGRepresentation(uiimage, 0)
//                }
//
//                DispatchQueue.global(qos: .background).async {
//                    self.chaseClient.write(string: jsonString)
//                    self.chaseClient.write(data: (imageToSend as? NSData)! as! Data)
//
//                    }
//
//            } catch{
//                print(error.localizedDescription)
//            }
//        }
        
            let currentTransform = frame.camera.transform
            let floatArray = (0..<4).flatMap { x in (0..<4).map { y in currentTransform[x][y] } }
            let stringArray = floatArray.map { String($0) }
            let tranformString = stringArray.joined(separator: " ")
            let now = Date()
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
            let dateString = formatter.string(from: now)
//            print(dateString)

//            sendJson["camPose"] = tranformString
//            sendJson["timeStamp"] = dateString
//            if self.objPosition != nil{
//                sendJson["objPose"] = [self.objPosition.x, self.objPosition.y, self.objPosition.z].map{String($0)}.joined(separator: " ")
//            }
//            do{
//                let jsonData = try JSONSerialization.data(withJSONObject: sendJson, options: .prettyPrinted)
//                let jsonString = String(data: jsonData, encoding: .utf8)!
                let currentImg = frame.capturedImage
                let sourceImage = CIImage(cvImageBuffer: currentImg, options: nil)
        
//                guard let tempImage = self.context.createCGImage(sourceImage, from: sourceImage.extent) else { return }
//                let uiimage = UIImage(cgImage: tempImage)
//                var imageToSend:  Data? = nil
//                if self.isResizing{
//                    imageToSend = UIImageJPEGRepresentation(self.resizeImage(image: uiimage), 0)
//                } else {
//                    imageToSend = UIImageJPEGRepresentation(uiimage, 0)
//                }
//
//                DispatchQueue.global(qos: .background).async {
//                    self.chaseClient.write(string: jsonString)
//                    self.chaseClient.write(data: (imageToSend as? NSData)! as! Data)
//
//                    }
        
    }
    
    func stop() {
        print("stop session")
//        DispatchQueue.global(qos: .background).async {
//            self.chaseClient.write(string: "close")
//        }
//
//        self.sending = false
//        let generator = UINotificationFeedbackGenerator()
//        generator.notificationOccurred(.success)
        
    }
    
    func connectToChase(){
        chaseClient = CloudChaserClient(serverUrl: cloudChaserServerUrl, phoneUrl: "http://\(self.ip!):8080", view: self)
        chaseClient.connect()
        clientStatus = .hasClient
//        statusView.text = "Contacting Remote Server"
        self.sending = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func disconnectToChase(){
        if clientStatus == .hasClient{
            if chaseClient.isConnected(){
                chaseClient.disconnect()
            }
            chaseClient = nil
            clientStatus = .noClient
//            inception = InceptionDetect(view: self)
//            statusView.text = "Running Local Detection"
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
//            inception = InceptionDetect(view: self)
//            statusView.text = "Running Local Detection"
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
    func withTraits(traits:UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}



public class _PreviewView: UIView {
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
