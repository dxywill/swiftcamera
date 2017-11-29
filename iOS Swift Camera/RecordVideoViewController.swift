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
    
    private var isRecording = false
    //private var elapsedTime = 0.0
    //private var elapsedTimer:Timer? = nil
    //private var fileName:String? = nil
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    
    
    private var session: AVCaptureSession? = nil
    private var previewLayer: AVCaptureVideoPreviewLayer? = nil
    private var videoDevice: AVCaptureDevice? = nil
    
    //New added
    private var videoOutputFullFileName: String?
    private var videoWriterInput: AVAssetWriterInput?
    private var videoWriter: AVAssetWriter?
    private var frameCount = 0
    private var bitrate = 1280 * 720 * 1000
    
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
    
    func setupRecording () {
        if session != nil {
            session!.stopRunning()
            session = nil
        }
        isRecordingVideo = false
        self.setupCaptureSession()
        self.updateElapsedTime()
        
    }
    
    func setupCaptureSession () {
        
        session = AVCaptureSession()
        //Configure the resolution, Preset seems not working if we have set the device activeFormat below
        //session?.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160   // 4k
        //session?.sessionPreset = AVCaptureSession.Preset.hd1920x1080    // 1080P
        session?.sessionPreset = AVCaptureSession.Preset.hd1280x720    // 720P
        //session?.sessionPreset =  AVCaptureSession.Preset.high
        
        self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice!)
            session?.addInput(input)
        } catch {
            print ("video initialization error")
        }
        
        //Configure the device afer adding to the session!
        self.setFPS(desiredFrameRate: 240)
        
        let queue = DispatchQueue(label: "videoCaptureQueue", attributes: [])
        let output = AVCaptureVideoDataOutput ()
        output.alwaysDiscardsLateVideoFrames = true
        
        //if we use BGRA for 4K, the fps is only 5, 420v for about 20fps, format[30] has 420v ecoding, so if we choose format[30], its not necessary to
        // set the coding here? However, it seems overwritting the 420f in the format[31]
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)] //Uncomperessed RGB
        //output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)] //420v
        
        
        output.setSampleBufferDelegate(self, queue: queue)
        session?.addOutput(output)
        
        previewLayer = AVCaptureVideoPreviewLayer (session: session!)
        previewLayer?.frame = self.videoPreviewView.frame
        videoPreviewView.layer.addSublayer(previewLayer!)
        
        session?.startRunning()
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
        
        self.isRecordingVideo = true
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        self.videoOutputFullFileName = documentsPath + "/test_camera_capture_video.mov"
        
        if self.videoOutputFullFileName == nil {
            print("Error:The video output file name is nil")
            return
        }
        
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
        
        //Configure output video settings, this should not impact the capture fps right? only affects the output file
        // SEEMS HEVC (h265) is not supported ?
        // https://developer.apple.com/documentation/avfoundation/avassetwriterinput/1385912-initwithmediatype
        
        let videoCompressionPropertys = [AVVideoAverageBitRateKey: self.videoPreviewView.bounds.width * self.videoPreviewView.bounds.height * 10.1]
//
//        let videoSettings: [String: AnyObject] = [
//                AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
//                AVVideoWidthKey: self.videoPreviewView.bounds.width as AnyObject,
//                AVVideoHeightKey: self.videoPreviewView.bounds.height as AnyObject,
//                AVVideoCompressionPropertiesKey:videoCompressionPropertys as AnyObject
//            ]
//
        //let videoCompressionPropertys = [AVVideoAverageBitRateKey: self.videoPreviewView.bounds.width * self.videoPreviewView.bounds.height * 10.1]
        
// 720p
        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High41, //use the best？
            AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey: self.bitrate]
            ] as [String : Any]

        
//1080p
//        let videoSettings = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey: 1920,
//            AVVideoHeightKey: 1080
//            ] as [String : Any]
        
        
        //4k
//        let videoSettings = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey: 3840,
//            AVVideoHeightKey: 2160
//            ] as [String : Any]
//
        // if we use nil, which means output uncompressed RGB, the file size is huge, 720p, 3 sconds 500MB and the fps is low around 10fps, also use mov
        // so we need to use h264 or h265(hevc), supersingly, h264 also can get 240fps, which conflicts the doc, saying need to use hevc
        //self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: nil)
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        self.videoWriterInput!.expectsMediaDataInRealTime = true
        
        do {
            self.videoWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: self.videoOutputFullFileName!), fileType: AVFileType.mov) // change this using hevc?
        } catch let error as NSError {
            print("ERROR:::::>>>>>>>>>>>>>Cannot init videoWriter, error:\(error.localizedDescription)")
        }
        
        if self.videoWriter!.canAdd(self.videoWriterInput!) {
            self.videoWriter!.add(self.videoWriterInput!)
        } else {
            print("ERROR:::Cannot add videoWriterInput into videoWriter")
        }
        
        
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
                } else {
                    print("ERROR:::The file: \(self.videoOutputFullFileName) not exists, so cannot move this file camera roll")
                }
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
            }
        }
    }
    
    func updateElapsedTime () {
    }
    
    func setFPS(desiredFrameRate:Double){
        if let device = self.videoDevice{
//
//            device.unlockForConfiguration()
//            // 1
//            for vFormat in device.formats {
//
//                // 2
//                var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
//                let frameRates = ranges[0]
//
//                // 3
//                if frameRates.maxFrameRate == 240 {
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
//        }
        
        
        //debuging
        // 1
            
        //let vFormat = device.formats[24] // 1080p 420v, 120fps
        //   let vFormat = device.formats[25] // 1080p 420f
        
        //let vFormat = device.formats[30] // 4k 420v
        //let vFormat = device.formats[31] // 4k 420f
        
        let vFormat = device.formats[18] // 720p 420f, 240fps
        
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
        device.activeVideoMaxFrameDuration = frameRates.minFrameDuration // Always use the maximum framerate
        device.unlockForConfiguration()
        
    }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Here we can collect the frames, and process them.
        self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
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
        }
    }
}

