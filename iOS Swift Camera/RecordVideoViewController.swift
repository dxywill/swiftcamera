//
//  RecordVideoViewController.swift
//  iOS Swift Camera
//
//  Created by Jeffrey Berthiaume on 9/18/15.
//  Copyright © 2015 Jeffrey Berthiaume. All rights reserved.
//  Modified by Xinyi Ding on 11/24/17
//

import UIKit
import AVFoundation

class RecordVideoViewController: UIViewController {
  
  private var movieFileOutput:AVCaptureMovieFileOutput? = nil
  private var isRecording = false
  private var elapsedTime = 0.0
  private var elapsedTimer:Timer? = nil
  private var fileName:String? = nil
  
  
  @IBOutlet weak var videoPreviewView: UIView!
  @IBOutlet weak var btnStartRecording: UIButton!
  @IBOutlet weak var elapsedTimeLabel: UILabel!
  
    
    var session: AVCaptureSession? = nil
    var previewLayer: AVCaptureVideoPreviewLayer? = nil
    var videoDevice: AVCaptureDevice? = nil
  
  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  
  let maxSecondsForVideo = 15.0
  let captureFramesPerSecond = 30.0
  
 

    
    override func viewDidLoad() {
    super.viewDidLoad()
    
   // self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    
    //if videoDevice != nil {
      self.setupRecording()
    //}
  }
    
    
    @IBAction func toggleFlash(_ sender: UIButton) {
        
        sender.isSelected = !sender.isSelected
        if let device = self.videoDevice {
            if (device.hasTorch) {
                do {
                    try device.lockForConfiguration()
                } catch _ {
                    
                }
                if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                    device.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    do {
                        try device.setTorchModeOn(level: 0.2)
                    } catch _ {
                        
                    }
                }
                device.unlockForConfiguration()
            }
        }
    }
    
  
  func setupRecording () {
    if session != nil {
      session!.stopRunning()
      session = nil
    }
    
    btnStartRecording.setImage(UIImage(named: "ButtonRecord"), for: UIControlState())
    
    isRecording = false
    self.setupCaptureSession()
    elapsedTime = -0.5
    self.updateElapsedTime()
    
  }
  
  func setupCaptureSession () {
    
    session = AVCaptureSession()
    session?.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
    
    
    self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    
    do {
      let input = try AVCaptureDeviceInput(device: videoDevice!)
      
      session?.addInput(input)
      
    } catch {
      print ("video initialization error")
    }
    
    AVAudioSession.sharedInstance().requestRecordPermission { (granted: Bool) -> Void in
      if granted {
        let audioCaptureDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        do {
          let audioInput = try AVCaptureDeviceInput(device: audioCaptureDevice!)
          self.session?.addInput(audioInput)
        } catch {
          print ("audio initialization error")
        }
      }
    }
    
    let queue = DispatchQueue(label: "videoCaptureQueue", attributes: [])
    
    let output = AVCaptureVideoDataOutput ()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]
    output.setSampleBufferDelegate(self, queue: queue)
    session?.addOutput(output)
    
    previewLayer = AVCaptureVideoPreviewLayer (session: session!)
    previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    previewLayer?.frame = CGRect(x: 0, y: 0, width: videoPreviewView.frame.size.width, height: videoPreviewView.frame.size.height)
    
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    let currentOrientation = UIDevice.current.orientation
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    
    videoPreviewView.layer.addSublayer(previewLayer!)
    
    movieFileOutput = AVCaptureMovieFileOutput()
    
    let maxDuration = CMTimeMakeWithSeconds(maxSecondsForVideo, Int32(captureFramesPerSecond))
    movieFileOutput?.maxRecordedDuration = maxDuration
    
    movieFileOutput?.minFreeDiskSpaceLimit = 1024 * 1024
    
    if (session?.canAddOutput(movieFileOutput!) != nil) {
      session?.addOutput(movieFileOutput!)
    }
    
    var videoConnection:AVCaptureConnection? = nil
    for connection in (movieFileOutput?.connections)! {
      for port in (connection as AnyObject).inputPorts! {
        if (port as AnyObject).mediaType == AVMediaType.video {
          videoConnection = connection as? AVCaptureConnection
          break
        }
      }
      if videoConnection != nil {
        break
      }
    }
    
    videoConnection?.videoOrientation = AVCaptureVideoOrientation (ui: currentOrientation)
    session?.startRunning()
    
  }
  
  @objc func updateElapsedTime () {
    elapsedTime += 0.5
    let elapsedFromMax = maxSecondsForVideo - elapsedTime
    elapsedTimeLabel.text = "00:" + String(format: "%02d", Int(round(elapsedFromMax)))
    
    if elapsedTime >= maxSecondsForVideo {
      isRecording = true
      self.recordVideo(self.btnStartRecording)
    }
    
  }
  
  func generateThumbnailFromVideo () {
    let videoURL = URL(fileURLWithPath: (documentsURL.path + "/" + fileName! + ".mp4"))
    let thumbnailPath = documentsURL.path + "/" + fileName! + ".jpg"
    
    let asset = AVAsset(url: videoURL)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    let time = CMTimeMake(2, 1)
    
    do {
      let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
      let videoThumb = UIImage(cgImage: imageRef)
      let imgData = UIImageJPEGRepresentation(videoThumb, 0.8)
      
      FileManager.default.createFile(atPath: thumbnailPath, contents: imgData, attributes: nil)
    } catch let error as NSError {
      print("Image generation failed with error \(error)")
    }
  }
  
  @IBAction func recordVideo (_ btn : UIButton) {
    
    if !isRecording {
      isRecording = true
      
      elapsedTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(RecordVideoViewController.updateElapsedTime), userInfo: nil, repeats: true)
      
      btn.setImage(UIImage (named: "ButtonStop"), for: UIControlState())
      
      fileName = UUID ().uuidString
      let path = documentsURL.path + "/" + fileName! + ".mp4"
      let outputURL = URL(fileURLWithPath: path)
      
      movieFileOutput?.startRecording(to: outputURL, recordingDelegate: self)
      
    } else {
      isRecording = false
      
      elapsedTimer?.invalidate()
      movieFileOutput?.stopRecording()
      
    }
    
  }
  
  override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
    if fromInterfaceOrientation == UIInterfaceOrientation.landscapeLeft {
      previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
    } else {
      previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
    }
    
  }
  
}

extension AVCaptureVideoOrientation {
  var uiInterfaceOrientation: UIDeviceOrientation {
    get {
      switch self {
      case .landscapeLeft:        return .landscapeLeft
      case .landscapeRight:       return .landscapeRight
      case .portrait:             return .portrait
      case .portraitUpsideDown:   return .portraitUpsideDown
      }
    }
  }
  
  init(ui:UIDeviceOrientation) {
    switch ui {
    case .landscapeRight:       self = .landscapeRight
    case .landscapeLeft:        self = .landscapeLeft
    case .portrait:             self = .portrait
    case .portraitUpsideDown:   self = .portraitUpsideDown
    default:                    self = .portrait
    }
  }
}

extension RecordVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
  
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    print (outputFileURL);
    
    self.generateThumbnailFromVideo()
    
    self.dismiss(animated: true, completion: nil)
  }
  
}
