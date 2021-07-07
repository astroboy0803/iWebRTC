//
//  VideoCapturerProxy.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/7/5.
//

import Foundation
import WebRTC
import ReplayKit

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

    private weak var videoDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?

    private let assetWriter: AVAssetWriter

    private let cameraInput: AVAssetWriterInput

    private let audioInput: AVAssetWriterInput

    private let audioSession: AVCaptureSession

    private var isRecord: Bool = false

    private let docURL = {
        try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }()

    override init() {
        let fileURL = self.docURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        debugPrint(fileURL)
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

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000.0
        ]

        // audio input
        self.audioInput = .init(mediaType: .audio, outputSettings: audioSettings)
        self.audioInput.expectsMediaDataInRealTime = true
        self.assetWriter.add(self.audioInput)

        self.audioSession = .init()
        let audioOutput: AVCaptureAudioDataOutput = .init()
        if let audioDevice = AVCaptureDevice.default(for: .audio),
            let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            self.audioSession.addInput(audioInput)
        }

        super.init()

        self.audioSession.addOutput(audioOutput)
        audioOutput.setSampleBufferDelegate(self, queue: saveQueue)
    }

    internal final func setup(source capturer: RTCCameraVideoCapturer) {
        // source: https://stackoverflow.com/questions/33857572/quickblox-how-to-save-a-qbrtccameracapture-to-a-file
        let videoOutput = capturer.captureSession
            .outputs
            .compactMap({ $0 as? AVCaptureVideoDataOutput })
            .last
        self.videoDelegate = videoOutput?.sampleBufferDelegate
        videoOutput?.setSampleBufferDelegate(self, queue: saveQueue)
        self.audioSession.startRunning()
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
        self.cameraInput.markAsFinished()
        self.audioInput.markAsFinished()
        self.assetWriter.finishWriting {
            print("capture done \(Date())")
        }
    }
}

extension VideoCapturerProxy: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    final func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.videoDelegate?.captureOutput?(output, didDrop: sampleBuffer, from: connection)
    }

    final func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let isVideo = output is AVCaptureVideoDataOutput
        if isVideo {
            self.videoDelegate?.captureOutput?(output, didOutput: sampleBuffer, from: connection)
        }

        guard
            self.isRecord
        else {
            return
        }
        // source: https://stackoverflow.com/questions/20330174/avcapture-capturing-and-getting-framebuffer-at-60-fps-in-ios-7
        // source: https://stackoverflow.com/questions/44135223/record-video-with-avassetwriter-first-frames-are-black

        if self.assetWriter.status == .unknown {
            self.assetWriter.startWriting()
            self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            return
        }
        if self.assetWriter.status == .writing {
            let input = isVideo ? self.cameraInput : self.audioInput
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
}
