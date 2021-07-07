//
//  iTesting.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/6/27.
//

import Foundation
import WebRTC

internal protocol CustomRenderBufferDelegate: AnyObject {
    func capture(cvPixelBuffer: CVPixelBuffer)
}

internal final class CustomRTCMTLVideoView: RTCMTLVideoView {

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

    private var frameCount: CMTimeValue = .zero

    private var timeScale: CMTimeScale = 60

    private let videoSettings: [String: Any]

    private let assetWriter: AVAssetWriter

    private let cameraInput: AVAssetWriterInput

    private let cameraInputAdaptor: AVAssetWriterInputPixelBufferAdaptor

    private var isRecord: Bool = false

    private weak var renderDelegate: CustomRenderBufferDelegate?

    private let docURL = {
        try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }()

    override init(frame: CGRect) {

        let fileURL = self.docURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        self.assetWriter = try! .init(outputURL: fileURL, fileType: .mp4)

        self.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: UIScreen.main.bounds.size.width * recordingQua.rawValue,
            AVVideoHeightKey: UIScreen.main.bounds.size.height * recordingQua.rawValue
        ]

        self.cameraInput = .init(mediaType: .video, outputSettings: self.videoSettings)
        self.cameraInput.transform = .init(rotationAngle: .pi)

        self.assetWriter.add(self.cameraInput)
        self.cameraInputAdaptor = .init(assetWriterInput: self.cameraInput, sourcePixelBufferAttributes: self.videoSettings)

        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal final func startRecording() {
        guard !self.isRecord else {
            return
        }
        print("videoView start \(Date())")
        self.frameCount = .zero
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: .zero)
        self.isRecord = true
    }

    internal final func stopRecording() {
        guard self.isRecord else {
            return
        }
        self.isRecord = false
        self.cameraInput.markAsFinished()
        self.assetWriter.finishWriting {
            print("videoView done \(Date())")
        }
    }

    override func renderFrame(_ frame: RTCVideoFrame?) {
        if self.isRecord, let frame = frame, let rtcCVPixelBuffer = frame.buffer as? RTCCVPixelBuffer {
            self.renderDelegate?.capture(cvPixelBuffer: rtcCVPixelBuffer.pixelBuffer)
            self.saveVideo(cvPixelBuffer: rtcCVPixelBuffer.pixelBuffer)
        }
        super.renderFrame(frame)
    }

    private func saveVideo(cvPixelBuffer: CVPixelBuffer) {
        // source: https://github.com/lhuanyu/ARScreenRecorder/blob/master/ARKitInteraction/ARScreenRecorder.swift
        self.saveQueue.async {
            print("\(self.frameCount).savevideo")
            if self.cameraInput.isReadyForMoreMediaData {
                self.cameraInputAdaptor.append(cvPixelBuffer, withPresentationTime: .init(value: self.frameCount, timescale: self.timeScale))
                self.frameCount += 1
            }
        }
    }

    /// frame to image and save
    /// - Parameter cvPixelBuffer: CVPixelBuffer
    private func saveImage(cvPixelBuffer: CVPixelBuffer) {
        // source: https://groups.google.com/g/discuss-webrtc/c/ULGIodbbLvM
        // source: https://stackoverflow.com/questions/8072208/how-to-turn-a-cvpixelbuffer-into-a-uiimage
        self.saveQueue.async {
            let ciImg = CIImage(cvImageBuffer: cvPixelBuffer)
            let tempContext = CIContext(options: nil)
            if let cgImgRef = tempContext.createCGImage(ciImg, from: .init(x: .zero, y: .zero, width: CVPixelBufferGetWidth(cvPixelBuffer), height: CVPixelBufferGetHeight(cvPixelBuffer))) {
                let uiImg = UIImage(cgImage: cgImgRef)
                let fileURL = self.docURL
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                try? uiImg.pngData()?.write(to: fileURL)
            }
        }
    }
}
