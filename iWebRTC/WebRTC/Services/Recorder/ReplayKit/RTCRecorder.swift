//
//  RTCRecorder.swift
//  CathayLifeATMI
//
//  Created by BruceHuang on 2021/6/19.
//

import AVKit
import Foundation
import ReplayKit

public class RTCRecorder {
    public enum recordingQuality: CGFloat {
        case lowest = 0.3
        case low = 0.5
        case normal = 0.8
        case good = 1.0
        case better = 1.3
        case high = 1.5
        case best = 2.0
    }

    public var recordingQua: recordingQuality = .normal

    private var assetWriter: AVAssetWriter

    private lazy var videoInput: AVAssetWriterInput = {
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: UIScreen.main.bounds.size.width * recordingQua.rawValue,
            AVVideoHeightKey: UIScreen.main.bounds.size.height * recordingQua.rawValue
            ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        return videoInput
    }()

    private lazy var audioInput: AVAssetWriterInput = {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000.0
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        return audioInput
    }()

    private lazy var micInput: AVAssetWriterInput = {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000.0
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        return audioInput
    }()

    private let recorder: RPScreenRecorder

    public init() {
        self.recorder = RPScreenRecorder.shared()
        self.recorder.isMicrophoneEnabled = true
        self.recorder.isCameraEnabled = true
        self.recorder.cameraPosition = .front

        self.assetWriter = try! AVAssetWriter(outputURL: ReplayFileUtil.filePath(), fileType:
            .mov)
        [videoInput, audioInput, micInput].forEach({
            guard assetWriter.canAdd($0) else {
                return
            }
            assetWriter.add($0)
        })
    }

    // MARK: Screen Recording
    func startRecording(recordingHandler: @escaping (Error?) -> Void) {
        ReplayFileUtil.deleteFile()
        self.recorder.startCapture(handler: { sample, bufferType, error in
            print(bufferType.rawValue)

            if let error = error {
                self.stopRecording { _ in
                }
                recordingHandler(error)
                return
            }

            if self.assetWriter.status == .failed {
                print("Error occured:\n\(String(describing: self.assetWriter.error))")
                recordingHandler(self.assetWriter.error)
                self.stopRecording { _ in

                }
                return
            }
            switch bufferType {
            case .video:
                self.handle(sampleBuffer: sample)
            case .audioApp:
                self.add(sampleBuffer: sample, to: self.audioInput)
            case .audioMic:
                self.add(sampleBuffer: sample, to: self.micInput)
            @unknown default:
                break
            }
        }) { error in
            recordingHandler(error)
        }
    }

    private func handle(sampleBuffer: CMSampleBuffer) {
        if self.assetWriter.status == .unknown {
            self.assetWriter.startWriting()
            self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            return
        }
        if self.assetWriter.status == .writing && self.videoInput.isReadyForMoreMediaData {
            self.videoInput.append(sampleBuffer)
        }
    }

    private func add(sampleBuffer: CMSampleBuffer, to writerInput: AVAssetWriterInput) {
        guard writerInput.isReadyForMoreMediaData else {
            return
        }
        writerInput.append(sampleBuffer)
    }

    internal final func stopRecording(handler: @escaping (Error?) -> Void) {
        self.recorder.stopCapture { [weak self] error in
            handler(error)
            guard let self = self else {
                return
            }
            self.assetWriter.finishWriting {
                print("recording down")
                let fileURL = ReplayFileUtil.filePath()
                guard let sourceData = try? Data(contentsOf: fileURL) else {
                    return
                }
                print("screen record count = \(sourceData.count)")
            }
        }
    }
}

public class ReplayFileUtil {

    public class func filePath() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let soundFileURL = documentsPath.appendingPathComponent("screenRecording.mp4")
        return URL(fileURLWithPath: soundFileURL)
    }

    public class func deleteFile() {
        let filemanager = FileManager.default

        // document
        guard let folder = filemanager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

//        // cache
//        guard let folder = filemanager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
//            return
//        }

        let destinationPath = folder.appendingPathComponent("screenRecording.mp4").path
        do {
            try filemanager.removeItem(atPath: destinationPath)
            print("Local path removed successfully")
        } catch let error as NSError {
            print("------Error", error.debugDescription)
        }
    }

    public class func isRecordingAvailible() -> Bool {
        let manager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let destinationPath = documentsPath.appendingPathComponent("screenRecording.mp4")
        if manager.fileExists(atPath: destinationPath) {
            print("The file exists!")
            return true
        } else {
            return false
        }
    }
}
