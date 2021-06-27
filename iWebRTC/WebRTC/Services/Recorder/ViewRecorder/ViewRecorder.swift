//
//  ViewRecorder.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/6/27.
//

import UIKit
import AVFoundation

// source: https://bradgayman.com/blog/recordingAView/

internal final class ViewRecorder {
    
    // The array of screenshot images that go become the video
    var images = [UIImage]()
    
    // Let's hook into when the screen will be refreshed
    var displayLink: CADisplayLink?
    
    // Called when we're done writing the video
    var completion: ((URL?) -> Void)?
    
    // The view we're actively recording
    var sourceView: UIView?
    
    // Called to start the recording with the view to be recorded and completion closure
    func startRecording(_ view: UIView, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        self.sourceView = view
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: RunLoop.main, forMode: .common)
    }
    
    // Called to stop recording and kick off writing of asset
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        writeToVideo()
    }
    
    // Called every screen refresh to capture current visual state of the view
    @objc private func tick(_ displayLink: CADisplayLink) {
        let render = UIGraphicsImageRenderer(size: sourceView?.bounds.size ?? .zero)
        let image = render.image { (ctx) in
            // Important to capture the presentation layer of the view for animation to be recorded
            sourceView?.layer.presentation()?.render(in: ctx.cgContext)
        }
        images.append(image)
    }
    
    // Would contain code for async writing of video
    private func writeToVideo() {
        let imgToVideo = ImageToVideo(videoSettings: ImageToVideo.videoSettings())
        imgToVideo.createMovieFrom(images: images) { url in
            print(url.absoluteString)
        }
    }
}
