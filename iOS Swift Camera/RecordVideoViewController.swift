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

class RecordVideoViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
    
    
    //New added
    var videoOutputFullFileName: String?
    var videoWriterInput: AVAssetWriterInput?
    var videoWriter: AVAssetWriter?
    var frameCount = 0
    
    lazy var isRecordingVideo: Bool = {
        let isRecordingVideo = false
        return isRecordingVideo
    }()
    
    lazy var lastSampleTime: CMTime = {
        let lastSampleTime = kCMTimeZero
        return lastSampleTime
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupRecording()
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
    
    @IBAction func recordRaw(_ sender: UIButton) {
        
        print(self.lastSampleTime.seconds)
        print(self.frameCount)
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        self.videoOutputFullFileName = documentsPath + "/test_camera_capture_video.mov"
        
        if self.videoOutputFullFileName == nil {
            print("Error:The video output file name is nil")
            return
        }
        
        self.isRecordingVideo = true
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: self.videoOutputFullFileName!) {
            print("WARN:::The file: \(self.videoOutputFullFileName!) exists, will delete the existing file")
            do {
                try fileManager.removeItem(atPath: self.videoOutputFullFileName!)
            } catch let error as NSError {
                print("WARN:::Cannot delete existing file: \(self.videoOutputFullFileName!), error: \(error.debugDescription)")
            }
            
        } else {
            print("DEBUG:::The file \(self.videoOutputFullFileName!) not exists")
        }
        
        
        // AVVideoAverageBitRateKey is for pecifying a key to access the average bit rate (as bits per second) used in encoding.
        // This video shoule be video size * a float number, and here 10.1 is equal to AVCaptureSessionPresetHigh.
        let videoCompressionPropertys = [
            AVVideoAverageBitRateKey: self.videoPreviewView.bounds.width * self.videoPreviewView.bounds.height * 10.1
        ]
        
        let videoSettings: [String: AnyObject] = [
            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
            AVVideoWidthKey: self.videoPreviewView.bounds.width as AnyObject,
            AVVideoHeightKey: self.videoPreviewView.bounds.height as AnyObject,
            AVVideoCompressionPropertiesKey:videoCompressionPropertys as AnyObject
        ]
        
//        let videoSettings: [String: AnyObject] = [
//            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
//            AVVideoWidthKey: self.videoPreviewView.bounds.width as AnyObject,
//            AVVideoHeightKey: self.videoPreviewView.bounds.height as AnyObject
//        ]
        
        //self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: nil)
        self.videoWriterInput!.expectsMediaDataInRealTime = true
        
        
        //        let sourcePixelBufferAttributes = [
        //            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA),
        //            kCVPixelBufferWidthKey as String: NSNumber(int: Int32(self.cameraView.bounds.width)),
        //            kCVPixelBufferHeightKey as String: NSNumber(int: Int32(self.cameraView.bounds.height))
        //        ]
        //
        //        self.videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        //            assetWriterInput: self.videoWriterInput,
        //            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        //        )
        
        do {
            self.videoWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: self.videoOutputFullFileName!), fileType: AVFileType.mov)
        } catch let error as NSError {
            print("ERROR:::::>>>>>>>>>>>>>Cannot init videoWriter, error:\(error.localizedDescription)")
        }
        
        
//        if self.videoWriter!.canAdd(self.videoWriterInput!) {
//            self.videoWriter!.add(self.videoWriterInput!)
//        } else {
//            print("ERROR:::Cannot add videoWriterInput into videoWriter")
//        }
        
        self.videoWriter!.add(self.videoWriterInput!)
        
        
        if self.videoWriter!.status != AVAssetWriterStatus.writing {
            
            print("DEBUG::::::::::::::::The videoWriter status is not writing, and will start writing the video.")
            
            let hasStartedWriting = self.videoWriter!.startWriting()
            if hasStartedWriting {
                self.videoWriter!.startSession(atSourceTime: self.lastSampleTime)
                print("DEBUG:::Have started writting on videoWriter, session at source time: \(self.lastSampleTime)")
            } else {
                print("WARN:::Fail to start writing on videoWriter")
            }
            
            
            
        } else {
            print("WARN:::The videoWriter.status is writting now, so cannot start writing action on videoWriter")
        }
    }
    
    @IBAction func stopRecordRaw(_ sender: UIButton) {
        
        print(self.lastSampleTime.seconds)
        print(self.frameCount)
        self.isRecordingVideo = false
        
        self.videoWriterInput!.markAsFinished()
        self.videoWriter!.finishWriting {
            
            if self.videoWriter!.status == AVAssetWriterStatus.completed {
                print("DEBUG:::The videoWriter status is completed")
                
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: self.videoOutputFullFileName!) {
                    print("DEBUG:::The file: \(self.videoOutputFullFileName) has been save into documents folder, and is ready to be moved to camera roll")
//                    PHPhotoLibrary.shared().performChanges({
//                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: self.videoOutputFullFileName!))
//                    }) { completed, error in
//                        if completed {
//                            print("Video \(self.videoOutputFullFileName) has been moved to camera roll")
//                        }
//
//                        if error != nil {
//                            print ("ERROR:::Cannot move the video \(self.videoOutputFullFileName) to camera roll, error: \(error!.localizedDescription)")
//                        }
//                    }
                } else {
                    print("ERROR:::The file: \(self.videoOutputFullFileName) not exists, so cannot move this file camera roll")
                }
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
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
        //Configure the resolution
        //session?.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160 // 4k
        session?.sessionPreset = AVCaptureSession.Preset.hd1920x1080    // 1080P
        //session?.sessionPreset = AVCaptureSession.Preset.hd1280x720    // 720P
       // session?.sessionPreset =  AVCaptureSession.Preset.high
        
        self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice!)
            
            session?.addInput(input)
            
        } catch {
            print ("video initialization error")
        }
        
        //After adding?????
        self.setFPS(desiredFrameRate: 20)
        
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
        //output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)] //Uncomperessed RGB
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)] //420v
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
        
        // wtf? can not add  two output?
//        if (session?.canAddOutput(movieFileOutput!) != nil) {
//            session?.addOutput(movieFileOutput!)
//        }
        
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
    
    func setFPS(desiredFrameRate:Double){
        if let device = self.videoDevice{
//            do {
//                try device.lockForConfiguration()
//            } catch _ {
//            }
//
//            // set to 120FPS
//            let format = device.activeFormat
//            let time:CMTime = CMTimeMake(1, Int32(desiredFrameRate))
//
//            for range in format.videoSupportedFrameRateRanges {
//                if range.minFrameRate <= (desiredFrameRate + 0.0001) && range.maxFrameRate >= (desiredFrameRate - 0.0001) {
//                    device.activeVideoMaxFrameDuration = time
//                    device.activeVideoMinFrameDuration = time
//                    print("Changed FPS to \(desiredFrameRate)")
//                    break
//                }
//
//            }
//            device.unlockForConfiguration()
            
//            // 1
//            for vFormat in device.formats {
//                print("blabla")
//                // 2
//                var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
//                let frameRates = ranges[0]
//
//                // 3
//                if frameRates.maxFrameRate == 60 {
//
//                    // 4
//                    do {
//                        try device.lockForConfiguration()
//                    } catch _ {
//
//                    }
//                    device.activeFormat = vFormat as AVCaptureDevice.Format
//                    device.activeVideoMinFrameDuration = frameRates.minFrameDuration
//                    device.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
//                    device.unlockForConfiguration()
//                }
//            }
            
            //debuging
            // 1
            
            let vFormat = device.formats[24]

                // 2
                var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
                let frameRates = ranges[0]
            
                var description = vFormat.formatDescription

                // 3


                    // 4
                    do {
                        try device.lockForConfiguration()
                    } catch _ {

                    }
                    device.activeFormat = vFormat as AVCaptureDevice.Format
                    device.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    device.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                    device.unlockForConfiguration()
            
        }
    }
    
    
    func generateThumbnailFromVideo () {
        let videoURL = URL(fileURLWithPath: (documentsURL.path + "/" + fileName! + ".mov"))
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
        
//        if !isRecording {
//            isRecording = true
//
//            elapsedTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(RecordVideoViewController.updateElapsedTime), userInfo: nil, repeats: true)
//
//            btn.setImage(UIImage (named: "ButtonStop"), for: UIControlState())
//
//            fileName = UUID ().uuidString
//            let path = documentsURL.path + "/" + fileName! + ".mov"
//            let outputURL = URL(fileURLWithPath: path)
//
//            movieFileOutput?.startRecording(to: outputURL, recordingDelegate: self)
//
//        } else {
//            isRecording = false
//
//            elapsedTimer?.invalidate()
//            movieFileOutput?.stopRecording()
//
//        }
        
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if fromInterfaceOrientation == UIInterfaceOrientation.landscapeLeft {
            previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        } else {
            previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        }
        
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Here we can collect the frames, and process them.
        //let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        print(self.lastSampleTime)
        self.frameCount = self.frameCount + 1
        
        
        // Append the sampleBuffer into videoWriterInput
        if self.isRecordingVideo {
            if let writerInput = self.videoWriterInput {
                if writerInput.isReadyForMoreMediaData {
                    if self.videoWriter!.status == AVAssetWriterStatus.writing {
                        let whetherAppendSampleBuffer = self.videoWriterInput!.append(sampleBuffer)
                        
                        print(">>>>>>>>>>>>>The time::: \(self.lastSampleTime.value)/\(self.lastSampleTime.timescale)")
                        
                        if whetherAppendSampleBuffer {
                            print("DEBUG::: Append sample buffer successfully")
                        } else {
                            print("WARN::: Append sample buffer failed")
                        }
                    } else {
                        print("WARN:::The videoWriter status is not writing")
                    }
                }
                
            } else {
                print("WARN:::Cannot append sample buffer into videoWriterInput")
            }
            //            let fps: Int32 = 30
            //            let frameDuration = CMTimeMake(1, fps)
            //            let lastFrameTime = CMTimeMake(self.frameCounter, fps)
            //            let presentationTime = self.frameCounter == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
            //
            //            if self.videoWriterInputPixelBufferAdaptor.assetWriterInput.readyForMoreMediaData {
            //                let whetherPixelBufferAppendedtoAdaptor = self.videoWriterInputPixelBufferAdaptor.appendPixelBuffer(pixelBuffer!, withPresentationTime: presentationTime)
            //
            //                if whetherPixelBufferAppendedtoAdaptor {
            //                    print("DEBUG:::PixelBuffer appended adaptor successfully")
            //                } else {
            //                    print("WARN:::PixelBuffer appended adapotr failed")
            //                }
            //
            //
            //                self.frameCounter += 1
            //
            //                print("DEBUG:::The current frame counter = \(self.frameCounter)")
            //            } else {
            //                print("WARN:::The assetWriterInput is not ready")
            //            }
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

