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

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, GCDAsyncSocketDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var plusLabel: UILabel!
    @IBOutlet weak var minusLabel: UILabel!
    @IBOutlet weak var zoomSlider: UISlider!
    @IBOutlet weak var ledImage: UIImageView!
    @IBOutlet weak var informationLabel: UILabel!

    let ip = IPChecker.getIP()
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var captureDevice: AVCaptureDevice?
    let videoOutput = AVCaptureVideoDataOutput()
    var clients = [Int:StreamingSession]()
    var serverSocket: GCDAsyncSocket?
    var previousOrientation = UIDeviceOrientation.portrait
    var ipIsDisplayed = false
    var ipAddress = ""
    
    let serverQueue = DispatchQueue(label: "ServerQueue", attributes: [])
    let clientQueue = DispatchQueue(label: "ClientQueue", attributes: DispatchQueue.Attributes.concurrent)
    let socketWriteQueue = DispatchQueue(label: "SocketWriteQueue", attributes: DispatchQueue.Attributes.concurrent)
    
    // Méthode du Delegate
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Client has connected with IP \(newSocket.connectedHost ?? "unknown")")
        let clientId = newSocket.connectedAddress?.hashValue
        let newClient = StreamingSession(id: clientId!, client: newSocket, queue: self.clientQueue)
        self.clients[clientId!] = newClient
        newClient.startStreaming()
        
        DispatchQueue.main.async(execute: {
            self.ledImage.image = UIImage(named: "led_red")
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // on crée la socket de service
        // Le serveur tourne dans sa propre queue (les méthodes de délégate seront exécutées dans cette queue)
        // Les clients possèdent également leur propre queue dexécution
        print("Création du serveur sur l'IP \(String(describing: self.ip))")
        self.serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: self.serverQueue, socketQueue: self.socketWriteQueue)
        
        do {
            try self.serverSocket!.accept(onInterface: self.ip, port: 10001)
        } catch {
            print("Could not listen on port 10001 ...")
        }

        // Do any additional setup after loading the view.
        self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        let devices = AVCaptureDevice.devices()
        
        for device in devices{
            if ((device as AnyObject).hasMediaType(AVMediaType.video)){
                self.captureDevice = device as AVCaptureDevice
                if (captureDevice != nil) {
                    print("Capture Device Found")
                    beginSession()
                    break
                }
            }
        }

        if let ip = self.ip {
            ipAddress = "http://\(ip):10001"
        } else {
            ipAddress = "IP address not available"
        }

        self.cameraView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(CameraViewController.tapOnCameraView)))
    }

    @objc func tapOnCameraView () {

        UIView.animate(withDuration: 1, animations: { [unowned self] in
            if (self.ipIsDisplayed) {
                self.informationLabel.alpha = 0
            }
            else {
                self.informationLabel.alpha = 1
                self.informationLabel.text = self.ipAddress
            }

            self.ipIsDisplayed = !self.ipIsDisplayed
        })
    }

    @IBAction func zoomChanged(_ sender: UISlider, forEvent event: UIEvent) {
        do {
            try self.captureDevice!.lockForConfiguration()
            self.captureDevice?.videoZoomFactor = CGFloat(sender.value)
            self.captureDevice!.unlockForConfiguration()
        }catch {
            
        }
    }

    func beginSession () -> Void {
        do {
            try self.captureDevice!.lockForConfiguration()
            self.captureDevice!.focusMode = .continuousAutoFocus
            self.captureDevice!.unlockForConfiguration()
            if let maxZoom = self.captureDevice?.activeFormat.videoMaxZoomFactor {
                self.zoomSlider.maximumValue = Float(maxZoom) / 2
            }
            
            try self.captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            
            let bounds = self.view.bounds
            
            self.previewLayer?.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: bounds.height))
            self.previewLayer?.videoGravity = AVLayerVideoGravity.resize
            self.previewLayer?.position = CGPoint(x: bounds.midX, y: bounds.midY)
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AVSessionQueue", attributes: []))
            self.captureSession.addOutput(videoOutput)
            self.cameraView.layer.addSublayer(self.previewLayer!)
            
            //self.previewLayer?.frame = self.view.layer.frame
            self.captureSession.startRunning()
            
        } catch {
            print ("Begin session failed")
        }
        
    }
    
    let context = CIContext(options:nil);
    
    func rotateLabels (_ angle: CGFloat) {
        DispatchQueue.main.async(execute: {
            UIView.animate(withDuration: 0.5, animations: {
                self.minusLabel.transform = CGAffineTransform.identity.rotated(by: angle)
                self.plusLabel.transform = CGAffineTransform.identity.rotated(by: angle)
                self.zoomSlider.transform = CGAffineTransform.identity.rotated(by: CGFloat(0))
                self.informationLabel.transform = CGAffineTransform.identity.rotated(by: angle)
            })
        })
    }
    
    func switchLabels () {
        DispatchQueue.main.async(execute: {
            UIView.animate(withDuration: 0.5, animations: {
                let c1 = self.minusLabel.center
                let c2 = self.plusLabel.center
                
                let dx = c2.x - c1.x
                let dy = c2.y - c1.y
                
                
                self.minusLabel.transform = CGAffineTransform.identity.translatedBy(x: dx, y: dy)
                self.plusLabel.transform = CGAffineTransform.identity.translatedBy(x: -dx, y: -dy)
                
                self.minusLabel.transform = self.minusLabel.transform.rotated(by: CGFloat(-1/2 * Double.pi))
                self.plusLabel.transform = self.plusLabel.transform.rotated(by: CGFloat(-1/2 * Double.pi))
                
                
                self.zoomSlider.transform = CGAffineTransform.identity.rotated(by: CGFloat(Double.pi))
                
                self.informationLabel.transform = CGAffineTransform.identity.rotated(by: CGFloat(-1/2 * Double.pi))
                
            })
        })
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let currentOrientation = UIDevice.current.orientation
        if (currentOrientation != self.previousOrientation){
            
            switch (currentOrientation) {
            case .portrait:
                self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.portrait
                self.rotateLabels(0)
                break
            case .landscapeRight:
                self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                self.switchLabels()
                break
            case .landscapeLeft:
                self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
                self.rotateLabels(CGFloat(1/2*Double.pi))
                
                break
            case .portraitUpsideDown:
                self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
                self.rotateLabels(0)
                break
            default:
                self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.portrait
                self.rotateLabels(0)
                break
            }
            
            self.previousOrientation = currentOrientation
        }
        
        if (self.clients.count>0){
            
            let capture : CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            let sourceImage = CIImage(cvImageBuffer: capture, options: nil)
            let tempImage:CGImage = self.context.createCGImage(sourceImage, from: sourceImage.extent)!
            let image = UIImage(cgImage: tempImage);
            let imageToSend = UIImageJPEGRepresentation(image, 0);
            for (key, client) in self.clients {
                if (client.connected){
                    client.dataToSend = (imageToSend as NSData?)?.copy() as? Data
                }else{
                    self.clients.removeValue(forKey: key)
                }
            }
            
            if (self.clients.count==0){
                DispatchQueue.main.async(execute: {
                    self.ledImage.image = UIImage(named: "led_gray")
                })
            }
        }
        
    }
}