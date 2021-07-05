//
//  VideoCapturerProxy.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/7/5.
//

import Foundation
import WebRTC

internal final class VideoCapturerProxy: NSObject {
    
    private enum recordingQuality: CGFloat {
        case lowest = 0.3
        case low = 0.5
        case normal = 0.8
        case good = 1.0
        case better = 1.3
        case high = 1.5
        case best = 2.0
    }
    
    private let recordingQua: recordingQuality = .normal
    
    private let saveQueue: DispatchQueue = .init(label: "_SaveQueue\(UUID().uuidString)")
    
    private let outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
        
    private let assetWriter: AVAssetWriter
        
    private let cameraInput: AVAssetWriterInput
            
    private var isRecord: Bool = false
    
    private let docURL = {
        try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }()
    
    init(capturer: RTCCameraVideoCapturer) {
        let videoOutput = capturer.captureSession
            .outputs
            .compactMap({ $0 as? AVCaptureVideoDataOutput })
            .last
        self.outputDelegate = videoOutput?.sampleBufferDelegate
        
        let fileURL = self.docURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        self.assetWriter = try! .init(outputURL: fileURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: UIScreen.main.bounds.size.width * recordingQua.rawValue,
            AVVideoHeightKey: UIScreen.main.bounds.size.height * recordingQua.rawValue
        ]
        self.cameraInput = .init(mediaType: .video, outputSettings: videoSettings)
        self.cameraInput.transform = .init(rotationAngle: .pi)
        self.cameraInput.expectsMediaDataInRealTime = true
        self.assetWriter.add(self.cameraInput)
        
        super.init()        
        videoOutput?.setSampleBufferDelegate(self, queue: saveQueue)
    }
    
    internal final func startRecrod() {
        guard !self.isRecord else {
            return
        }
        print("capture start \(Date())")
        self.isRecord = true
    }
    
    internal final func stopRecrod() {
        guard self.isRecord else {
            return
        }
        self.isRecord = false
        self.assetWriter.finishWriting {
            print("capture done \(Date())")
        }
    }
}

extension VideoCapturerProxy: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.outputDelegate?.captureOutput?(output, didDrop: sampleBuffer, from: connection)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.outputDelegate?.captureOutput?(output, didOutput: sampleBuffer, from: connection)
        
        guard
            self.isRecord
        else {
            return
        }
        if self.assetWriter.status == .unknown {
            self.assetWriter.startWriting()
            self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
        if self.assetWriter.status == .writing, self.cameraInput.isReadyForMoreMediaData {
            self.cameraInput.append(sampleBuffer)
        }
    }
}
