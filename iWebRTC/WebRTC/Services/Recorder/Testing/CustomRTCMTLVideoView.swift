//
//  iTesting.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/6/27.
//

import Foundation
import WebRTC

internal final class CustomRTCMTLVideoView: RTCMTLVideoView {
    
    private let saveQueue: DispatchQueue = .init(label: "_SaveQueue\(UUID().uuidString)")
    
    private lazy var docURL: URL = {
        return try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }()
    
    private var isRecord: Bool = false
    
    internal final func startRecording() {
        self.isRecord = true
    }
    
    internal final func stopRecording() {
        self.isRecord = false
    }
    
    override func renderFrame(_ frame: RTCVideoFrame?) {
        if self.isRecord, let frame = frame {
            // source: https://groups.google.com/g/discuss-webrtc/c/ULGIodbbLvM
            let rtcCVPixelBuffer = frame.buffer as? RTCCVPixelBuffer
            if let cvPixelBuffer = rtcCVPixelBuffer?.pixelBuffer {
                self.saveQueue.async {
                    let ciImg = CIImage(cvImageBuffer: cvPixelBuffer)
                    let tempContext = CIContext(options: nil)
                    if let cgImgRef = tempContext.createCGImage(ciImg, from: .init(x: .zero, y: .zero, width: CVPixelBufferGetWidth(cvPixelBuffer), height: CVPixelBufferGetHeight(cvPixelBuffer))) {
                        let uiImg = UIImage(cgImage: cgImgRef)
                        let fileURL = self.docURL
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("png")
                        debugPrint(fileURL.absoluteString)
                        try? uiImg.pngData()?.write(to: fileURL)
                    }
                }
            }
            
        }
        super.renderFrame(frame)
    }
    
}
