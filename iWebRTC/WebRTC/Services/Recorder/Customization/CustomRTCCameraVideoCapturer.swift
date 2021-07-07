//
//  CustomRTCCameraVideoCapturer.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/7/7.
//

import Foundation
import WebRTC

internal final class CustomRTCCameraVideoCapturer: RTCCameraVideoCapturer {
    
    private var capturerProxy: VideoCapturerProxy
    
    override init(delegate: RTCVideoCapturerDelegate) {
        self.capturerProxy = .init()
        super.init(delegate: delegate)
    }
    
    override final func startCapture(with device: AVCaptureDevice, format: AVCaptureDevice.Format, fps: Int) {
        self.startCapture(with: device, format: format, fps: fps, completionHandler: nil)
    }
    
    override final func startCapture(with device: AVCaptureDevice, format: AVCaptureDevice.Format, fps: Int, completionHandler: ((Error?) -> Void)? = nil) {
        self.capturerProxy.setup(source: self)
        super.startCapture(with: device, format: format, fps: fps) { error in
            completionHandler?(error)
        }
    }
    
    internal final func startRecord() {
        self.capturerProxy.startRecrod()
    }
    
    internal final func stopRecord() {
        self.capturerProxy.stopRecrod()
    }
}
