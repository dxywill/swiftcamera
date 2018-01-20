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
    
    private var elapsedTime = 0.0
    private var elapsedTimer:Timer? = nil
    
    @IBOutlet weak var flashButton: UIButton!
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    
    
    private var session: AVCaptureSession? = nil
    private var previewLayer: AVCaptureVideoPreviewLayer? = nil
    private var videoDevice: AVCaptureDevice? = nil
    
    private var videoOutputFullFileName: String?
    private var videoTimeStampLog: URL!
    private var videoWriterInput: AVAssetWriterInput?
    private var videoWriter: AVAssetWriter?
    private var frameCount = 0
    
    var itr = "iter1"
    private var participantID = 0
    private var captureMode = 1
    private var maxFPS = 240.0
    private var videoDimension = "1280x 720"
    private var videoFormat = "420v"
    private var bitrate = 1280 * 720 * 1000
    
    private var videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey: 1280 * 720 * 1000]
        ] as [String : Any]
    
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
        print("iter is \(itr)")
        let userDefault = UserDefaults.standard
        self.participantID = userDefault.integer(forKey: "participantID")
        self.setupRecording()
        self.flashButton.sendActions(for: .touchUpInside)
    }
    
    func setupRecording () {
        self.initVariables()
        if session != nil {
            session!.stopRunning()
            session = nil
        }
        isRecordingVideo = false
        elapsedTime = -1.0
        self.setupCaptureSession()
        self.updateElapsedTime()
        
    }
    
    func initVariables() {
        switch captureMode {
        case 1:
            self.maxFPS = 240
            self.videoDimension = "1280x 720"
            self.videoFormat = "420f"
            self.bitrate = 1280 * 720 * 1000
            self.videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720,
                AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey: self.bitrate]
                ] as [String : Any]
            break
        case 2:
            self.maxFPS = 120
            self.videoDimension = "1920x1080"
            self.videoFormat = "420f"
            self.bitrate = 1920 * 1080 * 1000
            self.videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                //AVVideoProfileLevelKey: AVVideoProfileLevelH264High41, //use the best？
                AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey: self.bitrate]
                ] as [String : Any]
            break
        case 3:
            self.maxFPS = 30
            self.videoDimension = "3840x2160"
            self.videoFormat = "420f"
            self.bitrate = 3840 * 2160 * 1000
            self.videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 3840,
                AVVideoHeightKey: 2160,
                //AVVideoProfileLevelKey: AVVideoProfileLevelH264High41, //use the best？
                AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey: self.bitrate]
                ] as [String : Any]
            break
        default:
            break
        }
    }
    func setupCaptureSession () {
        
        session = AVCaptureSession()
        //Configure the resolution, Preset seems not working if we have set the device activeFormat below
        //session?.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160   // 4k
        //session?.sessionPreset = AVCaptureSession.Preset.hd1920x1080    // 1080P
        //session?.sessionPreset = AVCaptureSession.Preset.hd1280x720    // 720P
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
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    @IBAction func recordRaw(_ sender: UIButton) {
        
        print(self.lastSampleTime.seconds)
        print(self.frameCount)
        
        elapsedTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(RecordVideoViewController.updateElapsedTime), userInfo: nil, repeats: true)
        self.isRecordingVideo = true
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        self.videoOutputFullFileName = documentsPath + "/\(self.participantID)_\(self.videoDimension)_\(self.videoFormat)_\(self.itr).mov"
        self.videoTimeStampLog = getDocumentsDirectory().appendingPathComponent("/\(self.participantID)_\(self.videoDimension)_\(self.videoFormat)_\(self.itr).log")
        
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var startTime = formatter.string(from: timestamp)
        startTime = startTime + "\n"
        
        
        if let outputStream = OutputStream(url: videoTimeStampLog, append: true) {
            outputStream.open()
            let bytesWritten = outputStream.write(startTime, maxLength: startTime.count)
            if bytesWritten < 0 { print("write failure") }
            outputStream.close()
        } else {
            print("Unable to open file")
        }
        
//        do {
//            try startTime.write(to: videoTimeStampLog, atomically: true, encoding: String.Encoding.utf8)
//        } catch {
//            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
//        }
        
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
        
        //
        // if we use nil, which means output uncompressed RGB, the file size is huge, 720p, 3 sconds 500MB and the fps is low around 10fps, also use mov
        // so we need to use h264 or h265(hevc), supersingly, h264 also can get 240fps, which conflicts the doc, saying need to use hevc
        //self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: nil)
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: self.videoSettings)
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
        elapsedTimer?.invalidate()
        
        self.videoWriterInput!.markAsFinished()
        self.videoWriter!.finishWriting {
            
            if self.videoWriter!.status == AVAssetWriterStatus.completed {
                print("DEBUG:::The videoWriter status is completed")
                
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: self.videoOutputFullFileName!) {
                    print("DEBUG:::The file: \(self.videoOutputFullFileName!) has been save into documents folder, and is ready to be moved to camera roll")
                } else {
                    print("ERROR:::The file: \(self.videoOutputFullFileName!) not exists, so cannot move this file camera roll")
                }
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
            }
        }
        let userDefault = UserDefaults.standard
        userDefault.set(true, forKey: self.itr)
        dismiss(animated: true, completion: nil)
        
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var endTime = formatter.string(from: timestamp)
        endTime = endTime + "\n"
        
        
        if let outputStream = OutputStream(url: self.videoTimeStampLog, append: true) {
            outputStream.open()
            let bytesWritten = outputStream.write(endTime, maxLength: endTime.count)
            if bytesWritten < 0 { print("write failure") }
            outputStream.close()
        } else {
            print("Unable to open file")
        }
    }
    
    @objc func updateElapsedTime () {
        elapsedTime += 1.0
        elapsedTimeLabel.text = "00:" + String(format: "%02d", Int(round(elapsedTime)))
    }
    
    func setFPS(desiredFrameRate:Double){
        if let device = self.videoDevice{
            
            device.unlockForConfiguration()
            for vFormat in device.formats {
                
                var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
                let description = vFormat.description
                let frameRates = ranges[0]
                
                if (frameRates.maxFrameRate == self.maxFPS) && (description.range(of: self.videoDimension) != nil) && (description.range(of: self.videoFormat) != nil) {
                    
                    do {
                        try device.lockForConfiguration()
                    } catch _ {
                        
                    }
                    device.activeFormat = vFormat as AVCaptureDevice.Format
                    device.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    device.activeVideoMaxFrameDuration = frameRates.minFrameDuration //Always set to use the maximum frame rate
                    device.unlockForConfiguration()
                }
            }
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

