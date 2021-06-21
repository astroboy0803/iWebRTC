//
//  ViewController.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/6/20.
//

import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    @IBAction private func showRTC(_ sender: UIButton) {
        let rtcVC = RTCViewController()
        rtcVC.modalPresentationStyle = .overFullScreen
        self.present(rtcVC, animated: true, completion: nil)
    }
}

