//
//  AudioRecorder.swift
//  iWebRTC
//
//  Created by BruceHuang on 2021/7/5.
//

import Foundation
import AVFoundation
import AudioUnit

// call setupAudioSessionForRecording() during controlling view load
// call startRecording() to start recording in a later UI call

// source: https://gist.github.com/hotpaw2/ba815fc23b5d642705f2b1dedfaf0107/1193de873b813a3f74d7ff4deba11d159c9edf43
// source: https://gist.github.com/leonid-s-usov/dcd674b0a8baf96123cac6c4e08e3e0c
final class AudioRecorder: NSObject {

    var audioUnit: AudioUnit?
    var micPermission: Bool =  false
    var sessionActive: Bool =  false
    var isRecording: Bool =  false

    // default audio sample rate
    var sampleRate: Double = 44100.0

    // lock-free circular fifo/buffer size
    let circBuffSize: Int = 32768

    // for incoming samples
    var circBuffer: [Float] = .init(repeating: .zero, count: 32768)

    var circInIdx: Int = .zero
    var audioLevel: Float = .zero

    // guess of device hardware sample rate
    private var hwSRate: Double = 48000.0

    private var micPermissionDispatchToken: Int = .zero

    // for restart from audio interruption notification
    private var interrupted: Bool = false
    func startRecording() {
        if isRecording { return }

        startAudioSession()
        if sessionActive {
            startAudioUnit()
        }
    }

    var numberOfChannels: Int = 2

    private let outputBus: UInt32 = .zero
    private let inputBus: UInt32 = 1

    private var gTmp0: Int = .zero

    func startAudioUnit() {
        var err: OSStatus = noErr

        if self.audioUnit == nil {
            setupAudioUnit()         // setup once
        }
        guard
            let au = self.audioUnit
        else {
            return
        }

        err = AudioUnitInitialize(au)
        gTmp0 = Int(err)
        if err != noErr {
            return
        }

        // start
        err = AudioOutputUnitStart(au)
        gTmp0 = Int(err)
        if err == noErr {
            isRecording = true
        }
    }

    func startAudioSession() {
        if sessionActive == false {
            // set and activate Audio Session
            do {

                let audioSession = AVAudioSession.sharedInstance()

                if micPermission == false {
                    if micPermissionDispatchToken == 0 {
                        micPermissionDispatchToken = 1
                        audioSession.requestRecordPermission({(granted: Bool) -> Void in
                            if granted {
                                self.micPermission = true
                                return
                                // check for this flag and call from UI loop if needed
                            } else {
                                self.gTmp0 += 1
                                // dispatch in main/UI thread an alert
                                //   informing that mic permission is not switched on
                            }
                        })
                    }
                }
                if micPermission == false { return }

                try audioSession.setCategory(.record)
                // choose 44100 or 48000 based on hardware rate
                // sampleRate = 44100.0
                var preferredIOBufferDuration = 0.0058      // 5.8 milliseconds = 256 samples
                hwSRate = audioSession.sampleRate           // get native hardware rate
                if hwSRate == 48000.0 { sampleRate = 48000.0 }  // set session to hardware rate
                if hwSRate == 48000.0 { preferredIOBufferDuration = 0.0053 }
                let desiredSampleRate = sampleRate
                try audioSession.setPreferredSampleRate(desiredSampleRate)
                try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)

                NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: nil,
                    queue: nil,
                    using: myAudioSessionInterruptionHandler )

                try audioSession.setActive(true)
                sessionActive = true
            } catch /* let error as NSError */ {
                // handle error here
            }
        }
    }

    private func setupAudioUnit() {

        var componentDesc: AudioComponentDescription = .init(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: UInt32(0),
            componentFlagsMask: UInt32(0)
        )

        var osErr: OSStatus = noErr

        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)

        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit

        guard
            let au = self.audioUnit
        else {
            return
        }

        // Enable I/O for input.
        var one_ui32: UInt32 = 1

        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))

        // Set format to 32-bit Floats, linear PCM
        let nc = 2  // 2 channel stereo
        var streamFormatDesc: AudioStreamBasicDescription = .init(
            mSampleRate: Double(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: ( kAudioFormatFlagsNativeFloatPacked ),
            mBytesPerPacket: UInt32(nc * MemoryLayout<UInt32>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(nc * MemoryLayout<UInt32>.size),
            mChannelsPerFrame: UInt32(nc),
            mBitsPerChannel: UInt32(8 * (MemoryLayout<UInt32>.size)),
            mReserved: UInt32(0)
        )

        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        // Ask CoreAudio to allocate buffers for us on render.
        //   Is this true by default?
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        gTmp0 = Int(osErr)
    }

    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        _ ) -> OSStatus in

        let audioObject = unsafeBitCast(inRefCon, to: AudioRecorder.self)
        var err: OSStatus = noErr

        // set mData to nil, AudioUnitRender() should be allocating buffers
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(2),
                mDataByteSize: 16,
                mData: nil))

        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }

        audioObject.processMicrophoneBuffer( inputDataList: &bufferList,
                                             frameCount: UInt32(frameCount) )

        return 0
    }

    func processMicrophoneBuffer(   // process RemoteIO Buffer from mic input
        inputDataList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: UInt32 ) {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers: AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)

        // Microphone Input Analysis
        // let data      = UnsafePointer<Int16>(mBuffers.mData)
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            var sum: Float = 0.0
            var j = self.circInIdx
            let m = self.circBuffSize
            for i in 0..<(count/2) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
                self.circBuffer[j    ] = x
                self.circBuffer[j + 1] = y
                j += 2 ; if j >= m { j = 0 }                // into circular buffer
                sum += x * x + y * y
            }
            self.circInIdx = j              // circular index will always be less than size
            // measuredMicVol_1 = sqrt( Float(sum) / Float(count) ) // scaled volume
            if sum > 0.0 && count > 0 {
                let tmp = 5.0 * (logf(sum / Float(count)) + 20.0)
                let r: Float = 0.2
                audioLevel = r * tmp + (1.0 - r) * audioLevel
            }
        }
    }

    func stopRecording() {
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }

    func myAudioSessionInterruptionHandler(notification: Notification) {
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let interuptionVal = AVAudioSession.InterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue )
            if interuptionVal == AVAudioSession.InterruptionType.began {
                if isRecording {
                    stopRecording()
                    isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        sessionActive = false
                    } catch {
                    }
                    interrupted = true
                }
            } else if interuptionVal == AVAudioSession.InterruptionType.ended {
                if interrupted {
                    // potentially restart here
                }
            }
        }
    }

}

// end of class RecordAudio
