//
//  RTCViewController.swift
//  CathayLifeATMI
//
//  Created by BruceHuang on 2021/6/18.
//

import UIKit
import WebRTC

internal final class RTCViewController: UIViewController {

    private let backButton: UIButton = {
        let button = UIButton()
        button.setTitle("返回", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .selected)
        button.layer.cornerRadius = 15
        return button
    }()

    private let offerButton: UIButton = {
        let button = UIButton()
        button.setTitle("Offer", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .selected)
        button.layer.cornerRadius = 15
        return button
    }()

    private let answerButton: UIButton = {
        let button = UIButton()
        button.setTitle("Answer", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .selected)
        button.layer.cornerRadius = 15
        return button
    }()

    private let recordButton: UIButton = {
        let button = UIButton()
        button.setTitle("錄影", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .selected)
        button.layer.cornerRadius = 15
        return button
    }()

    private let doneButton: UIButton = {
        let button = UIButton()
        button.setTitle("完成", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .selected)
        button.layer.cornerRadius = 15
        return button
    }()

    private let customerView: CustomRTCMTLVideoView = {
        let view = CustomRTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFit
        return view
    }()

    private let saleView: RTCMTLVideoView = {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFit
        return view
    }()

    private let config = Config.default
    private let webRTCClient: WebRTCClient
    private let signalClient: SignalingClient
    private let recorder: RTCRecorder
    private let viewRecorder: ViewRecorder
    private var isRetry: Bool = true

    init() {
        self.viewRecorder = .init()
        self.recorder = .init()
        self.recorder.recordingQua = .good
//        self.recorder.onRecordingError = {
//            ReplayFileUtil.deleteFile()
//        }

        self.webRTCClient = .init(iceServers: self.config.webRTCIceServers)

        // iOS 13 has native websocket support. For iOS 12 or lower we will use 3rd party library.
        let signalURL = self.config.signalingServerUrl
        let webSocketProvider: WebSocketProvider
        if #available(iOS 13.0, *) {
            webSocketProvider = NativeWebSocket(url: signalURL)
        } else {
            webSocketProvider = StarscreamWebSocket(url: signalURL)
        }

        self.signalClient = .init(webSocket: webSocketProvider)

        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        self.isRetry = false
        self.signalClient.disconnect()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupLayout()
        self.setupTargets()

        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
        self.signalClient.connect()

        self.webRTCClient.startCaptureLocalVideo(renderer: self.saleView)
        self.webRTCClient.renderRemoteVideo(to: self.customerView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

// MARK: - Setup
extension RTCViewController {
    // MARK: 設定畫面layout
    private func setupLayout() {
        // TODO: for test
        self.view.backgroundColor = .systemYellow
        self.customerView.backgroundColor = .black
        self.saleView.backgroundColor = .red

        let spacing: CGFloat = 5

        let menuWidth: CGFloat = 100
        let menuHeigth: CGFloat = 50

        [self.backButton, self.offerButton, self.answerButton, self.recordButton, self.doneButton, self.customerView, self.saleView].forEach({
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        })

        NSLayoutConstraint.activate([
            self.backButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.backButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 5),
            self.backButton.widthAnchor.constraint(equalToConstant: menuWidth),
            self.backButton.heightAnchor.constraint(equalToConstant: menuHeigth),

            self.offerButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.offerButton.leadingAnchor.constraint(equalTo: self.backButton.trailingAnchor, constant: 5),
            self.offerButton.widthAnchor.constraint(equalToConstant: menuWidth),
            self.offerButton.heightAnchor.constraint(equalToConstant: menuHeigth),

            self.answerButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.answerButton.leadingAnchor.constraint(equalTo: self.offerButton.trailingAnchor, constant: 5),
            self.answerButton.widthAnchor.constraint(equalToConstant: menuWidth),
            self.answerButton.heightAnchor.constraint(equalToConstant: menuHeigth),

            self.recordButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.recordButton.leadingAnchor.constraint(equalTo: self.answerButton.trailingAnchor, constant: 5),
            self.recordButton.widthAnchor.constraint(equalToConstant: menuWidth),
            self.recordButton.heightAnchor.constraint(equalToConstant: menuHeigth),

            self.doneButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.doneButton.leadingAnchor.constraint(equalTo: self.recordButton.trailingAnchor, constant: 5),
            self.doneButton.widthAnchor.constraint(equalToConstant: menuWidth),
            self.doneButton.heightAnchor.constraint(equalToConstant: menuHeigth),

            self.customerView.topAnchor.constraint(equalTo: self.backButton.bottomAnchor, constant: spacing),
            self.customerView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0 - spacing),
            self.customerView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            self.customerView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),

            self.saleView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: spacing),
            self.saleView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            self.saleView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.3),
            self.saleView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.25)
        ])
    }

    // MARK: 設定事件
    private func setupTargets() {
        self.backButton.addTarget(self, action: #selector(self.doClose(_:)), for: .touchUpInside)
        self.offerButton.addTarget(self, action: #selector(self.doOffer(_:)), for: .touchUpInside)
        self.answerButton.addTarget(self, action: #selector(self.doAnswer(_:)), for: .touchUpInside)
        self.recordButton.addTarget(self, action: #selector(self.doRecord(_:)), for: .touchUpInside)
        self.doneButton.addTarget(self, action: #selector(self.doDone(_:)), for: .touchUpInside)
    }

    // MARK: 離開
    @objc
    private func doClose(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: offer sdp
    @objc
    private func doOffer(_ sender: UIButton) {
        print("offering...")
        self.webRTCClient.offer { sdp in
            self.signalClient.send(sdp: sdp)
        }
    }

    // MARK: answer sdp
    @objc
    private func doAnswer(_ sender: UIButton) {
        print("answer...")
        self.webRTCClient.answer { localSdp in
            self.signalClient.send(sdp: localSdp)
        }
    }

    // MARK: 錄影
    @objc
    private func doRecord(_ sender: UIButton) {
//        self.recorder.startRecording { _ in
//
//        }
        
//        self.recordButton.isEnabled = false
//        self.viewRecorder.startRecording(self.saleView) { _ in
//
//        }
        
        self.customerView.startRecording()
    }

    // MARK: 結束
    @objc
    private func doDone(_ sender: UIButton) {
        self.customerView.stopRecording()
        
//        self.viewRecorder.stop()
//        self.recordButton.isEnabled = true
        
//        self.recorder.stopRecording { _ in
//
//        }
    }
}

// MARK: - WebRTCClientDelegate
extension RTCViewController: WebRTCClientDelegate {
    final func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        self.signalClient.send(candidate: candidate)
    }

    final func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print("WebRTC Status: \(state.description.capitalized)")

        guard self.isRetry else {
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            debugPrint("Trying to reconnect to signaling server...")
            self.signalClient.connect()
        }
    }

    final func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {

    }
}

// MARK: - SignalClientDelegate
extension RTCViewController: SignalClientDelegate {
    final func signalClientDidConnect(_ signalClient: SignalingClient) {
        print("Signaling Server Connected")
    }

    final func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        print("Signaling Server Disconnected")
    }

    final func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("Signaling Server receive remote sdp")
        self.webRTCClient.set(remoteSdp: sdp) { error in
            print("set sdp done, error = \(error?.localizedDescription ?? "")")
        }
    }

    final func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        print("Signaling Server receive Candidate")
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            print("set Candidate done, error = \(error?.localizedDescription ?? "")")
        }
    }
}
