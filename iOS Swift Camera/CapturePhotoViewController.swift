//
//  CapturePhotoViewController.swift
//  msrmedia
//
//  Created by Jeffrey Berthiaume on 9/11/15.
//  Copyright © 2015 Amherst, Inc. All rights reserved.
//

import UIKit
import AVFoundation

class CapturePhotoViewController: UIViewController {
  
  var captureDevice : AVCaptureDevice?
  let captureSession = AVCaptureSession()
  var stillImageOutput: AVCaptureStillImageOutput?
  var streamLayer : AVCaptureVideoPreviewLayer?
  
  var scale:CGFloat = 0.0
  
  var delegate:CapturePhotoDelegate! = nil
  
  @IBOutlet weak var streamView: UIView!
  @IBOutlet weak var flashButton: UIButton!
  @IBOutlet weak var previewImage: UIImageView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view, typically from a nib.
    captureSession.sessionPreset = AVCaptureSession.Preset.high
    
    //captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    
    let devices = AVCaptureDevice.devices()
    
    // Loop through all the capture devices on this phone
    for device in devices {
      // Make sure this particular device supports video
      if ((device as AnyObject).hasMediaType(AVMediaType.video)) {
        // Finally check the position and confirm we've got the back camera
        if((device as AnyObject).position == AVCaptureDevice.Position.back) {
          captureDevice = device as? AVCaptureDevice
          if captureDevice != nil {
            print("Capture device found")
          }
        }
      }
    }
    
    if (captureDevice != nil) {
      
      beginSession()
      
      if !(captureDevice!.hasTorch) {
        flashButton.isHidden = true
      } else {
        flashButton.isSelected = false
      }
      
    }
    
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    streamLayer?.frame = (streamView?.bounds)!
  }
  
  func beginSession() {
    
    let err : NSError? = nil
    do {
      try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))
    } catch {
      // nil
    }
    
    if err != nil {
      print("error: \(err?.localizedDescription)")
    }
    
    streamLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    streamView?.layer.addSublayer(streamLayer!)
    streamLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    
    stillImageOutput = AVCaptureStillImageOutput()
    stillImageOutput?.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
    
    captureSession.addOutput(stillImageOutput!)
    
    captureSession.startRunning()
  }
  
  func toggleFlash(_ on : Bool) {
    if captureDevice!.hasTorch {
      do {
        try captureDevice!.lockForConfiguration()
        if on == false {
          captureDevice!.torchMode = AVCaptureDevice.TorchMode.off
        } else {
          try captureDevice!.setTorchModeOn(level: 1.0)
        }
        captureDevice!.unlockForConfiguration()
      } catch {
        print ("error with camera flash")
      }
    }
  }
  
  @IBAction func toggleFlashButton (_ btn : UIButton) {
    btn.isSelected = !btn.isSelected
  }
  
  @IBAction func pinchGestureRecognized(_ gestureRecognizer: UIPinchGestureRecognizer) {
    if gestureRecognizer.state == UIGestureRecognizerState.began {
      scale = gestureRecognizer.scale
    }
    
    if gestureRecognizer.state == UIGestureRecognizerState.began ||
      gestureRecognizer.state == UIGestureRecognizerState.changed {
        
        let currentScale = (streamLayer?.value(forKeyPath: "transform.scale") as AnyObject).floatValue.CGFloatValue
        var newScale = 1 - (scale - gestureRecognizer.scale);
        newScale = min(newScale, 2.0 / currentScale)
        newScale = max(newScale, 1.0 / currentScale)
        
        let transform = (streamLayer?.affineTransform())!.scaledBy (x: newScale, y: newScale)
        streamLayer?.setAffineTransform(transform)
        
        scale = gestureRecognizer.scale
        
    }
    
  }
  
  func cropToZoom (_ img : UIImage) -> UIImage {
    let currentScale = (streamLayer?.value(forKeyPath: "transform.scale") as AnyObject).floatValue.CGFloatValue
    if currentScale == 1.0 {
      return img
    }
    
    let newW = img.size.width / currentScale
    let newH = img.size.height / currentScale
    let newX1 = (img.size.width / 2) - (newW / 2)
    let newY1 = (img.size.height / 2) - (newH / 2)
    
    let rect = CGRect( x: -newX1, y: -newY1, width: img.size.width, height: img.size.height)
    
    UIGraphicsBeginImageContextWithOptions(CGSize(width: newW, height: newH), true, 1.0)
    img.draw(in: rect)
    
    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return result!
  }
  
  func takePhoto () {
    
    if let videoConnection = stillImageOutput!.connection(with: AVMediaType.video) {
      videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
      stillImageOutput?.captureStillImageAsynchronously(from: videoConnection, completionHandler: {(sampleBuffer, error) in
        if (sampleBuffer != nil) {
          let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!)
          let dataProvider = CGDataProvider(data: imageData as! CFData)
          let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true,intent: CGColorRenderingIntent.defaultIntent)
          
          let image = UIImage(cgImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.right)
          self.previewImage.image = self.cropToZoom(image)
          
          self.delegate!.didTakePhoto(self.cropToZoom(image))
          
          self.scale = 0.0
          self.streamLayer?.setAffineTransform(CGAffineTransform.identity)
          
          self.toggleFlash(false)
          
        }
      })
    }
    
  }
  
  @IBAction func capturePhoto (_ sender: UIButton) {
    
    if (captureDevice != nil) {
      self.toggleFlash(flashButton.isSelected)
      
      let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
      DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
        self.takePhoto()
        self.dismiss(animated: true, completion: { })
      })
    } else {
      self.delegate!.didTakePhoto(UIImage(named: "LargeIcon")!)
      
      self.dismiss(animated: true, completion: { })
    }
    
  }
  
}

protocol CapturePhotoDelegate {
  func didTakePhoto (_ img : UIImage)
}

extension Float {
  var CGFloatValue: CGFloat {
    get {
      return CGFloat(self)
    }
  }
}
