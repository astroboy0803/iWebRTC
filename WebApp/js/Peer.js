"use strict";

const startButton = document.getElementById("startButton");
const callButton = document.getElementById("callButton");
const hangupButton = document.getElementById("hangupButton");
callButton.disabled = true;
hangupButton.disabled = true;
startButton.addEventListener("click", start);
callButton.addEventListener("click", call);
hangupButton.addEventListener("click", hangup);

let startTime;
const localVideo = document.getElementById("localVideo");
const remoteVideo = document.getElementById("remoteVideo");

localVideo.addEventListener("loadedmetadata", function () {
    console.log(
        `Local video videoWidth: ${this.videoWidth}px,  videoHeight: ${this.videoHeight}px`
    );
});

remoteVideo.addEventListener("loadedmetadata", function () {
    console.log(
        `Remote video videoWidth: ${this.videoWidth}px,  videoHeight: ${this.videoHeight}px`
    );
});

remoteVideo.addEventListener("resize", () => {
    console.log(
        `Remote video size changed to ${remoteVideo.videoWidth}x${remoteVideo.videoHeight}`
    );

    if (startTime) {
        const elapsedTime = window.performance.now() - startTime;
        console.log("Setup time: " + elapsedTime.toFixed(3) + "ms");
        startTime = null;
    }
});

let localStream;
let pc1;
let pc2;
const offerOptions = {
    offerToReceiveAudio: 1,
    offerToReceiveVideo: 1,
};

function getName(pc) {
    return pc === pc1 ? "pc1" : "pc2";
}

async function start() {
    console.log("Requesting local stream");
    startButton.disabled = true;
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: true,
        });
        console.log("Received local stream");
        const videoTracks = stream.getVideoTracks();
        const audioTracks = stream.getAudioTracks();
        if (videoTracks.length > 0) {
            console.log(`Using video device: ${videoTracks[0].label}`);
        }
        if (audioTracks.length > 0) {
            console.log(`Using audio device: ${audioTracks[0].label}`);
        }
        localVideo.srcObject = stream;
        localStream = stream;
        callButton.disabled = false;
    } catch (e) {
        alert(`getUserMedia() error: ${e.name}`);
    }
}

function getSelectedSdpSemantics() {
    const sdpSemanticsSelect = document.querySelector("#sdpSemantics");
    const option = sdpSemanticsSelect.options[sdpSemanticsSelect.selectedIndex];
    return option.value === "" ? {} : { sdpSemantics: option.value };
}

// MARK: Call
/**
 * pc1,pc2 => peer-to-peer connection流程
 * step1: 建立Local peer connection  => signalingState: "statable"
 * step1.5: 將stream track 與peer connection 透過addTrack()關聯起來，之後建立連結才能進行傳輸！
 * step2: local peer call createOffer methods to create RTCSessionDescription(SDP) => signalingState: "have-local-offer"
 * step3: setLocalDescription() is called 然後傳給remote peer
 * step4: remote peer 收到後透過setRemoteDescription() 建立description for local peer.
 * step5: 建立成功後local peer會觸發icecandidate event 就能將serialized candidate data 通過signaling channel交付給remote peer
 * step6: Remote peer 建立createAnswer 將自己的SDP 回傳給Local peer
 * step7: Local peer收到後透過setRemoteDescription() 建立description for remote peer
 * Ping ! p2p 完成
 */
async function call() {
    callButton.disabled = true;
    hangupButton.disabled = false;
    console.log("Starting call");
    startTime = window.performance.now();
    const configuration = {};
    console.log("RTCPeerConnection configuration:", configuration);
    pc1 = buildPeerConnection("pc1", configuration);
    pc2 = buildPeerConnection("pc2", configuration);
    pc2.ontrack = gotRemoteStream

    localStream.getTracks().forEach((track) => pc1.addTrack(track, localStream));
    console.log("Added local stream to pc1");

    try {
        console.log("pc1 createOffer start");
        const offer = await pc1.createOffer(offerOptions);
        await onCreateOfferSuccess(offer);
    } catch (e) {
        onCreateSessionDescriptionError(e);
    }
}

// MARK: Build PeerConnection
function buildPeerConnection(label, configuration) {
    const peer = new RTCPeerConnection(configuration);
    console.log(`Created peer connection object: ${label}`);
    /**
     *  when an RTCIceCandidate has been identified 
     *  and added to the local peer by a call to `RTCPeerConnection.setLocalDescription()`.
     *  言下之意： 當local peer有新的candidate建立時，要交付給remote peers
     */
    peer.onicecandidate = (e) => onIceCandidate(label, e);
    peer.oniceconnectionstatechange = (e) => onIceStateChange(label, e);

    return peer;
}

async function onIceCandidate(pc, event) {
    try {
        await getOtherPc(pc).addIceCandidate(event.candidate);
        onAddIceCandidateSuccess(pc);
    } catch (e) {
        onAddIceCandidateError(pc, e);
    }
    console.log(
        `${getName(pc)} ICE candidate:\n${event.candidate ? event.candidate.candidate : "(null)"
        }`
    );
}

function getOtherPc(pc) {    
    return pc === pc1 ? pc2 : pc1;
}

// print log
function onAddIceCandidateSuccess(pc) {
    console.log(`${getName(pc)} addIceCandidate success`);
}

// print log
function onAddIceCandidateError(pc, error) {
    console.log(
        `${getName(pc)} failed to add ICE Candidate: ${error.toString()}`
    );
}

// print log
function onIceStateChange(pc, event) {
    if (pc) {
        console.log(`${getName(pc)} ICE state: ${pc.iceConnectionState}`);
        console.log("ICE state change event: ", event);
    }
}

function gotRemoteStream(e) {
    if (remoteVideo.srcObject !== e.streams[0]) {
        remoteVideo.srcObject = e.streams[0];
        console.log("pc2 received remote stream");
    }
}

// print log
function onCreateSessionDescriptionError(error) {
    console.log(`Failed to create session description: ${error.toString()}`);
}

async function onCreateOfferSuccess(desc) {
    console.log(`Offer from localPeer\n`, desc);
    console.log("pc1 setLocalDescription start");
    try {
        await pc1.setLocalDescription(desc);
        onSetLocalSuccess(pc1);
    } catch (e) {
        onSetSessionDescriptionError();
    }
    console.log(pc1)
    console.log("pc2 setRemoteDescription start");
    try {
        await pc2.setRemoteDescription(desc);
        onSetRemoteSuccess(pc2);
    } catch (e) {
        onSetSessionDescriptionError();
    }

    console.log("pc2 createAnswer start");
    try {
        const answer = await pc2.createAnswer();
        await onCreateAnswerSuccess(answer);
    } catch (e) {
        onCreateSessionDescriptionError(e);
    }
}

// print log
function onSetLocalSuccess(pc) {
    console.log(`${getName(pc)} setLocalDescription complete`);
}

// print log
function onSetSessionDescriptionError(error) {
    console.log(`Failed to set session description: ${error.toString()}`);
}

// print log
function onSetRemoteSuccess(pc) {
    console.log(`${getName(pc)} setRemoteDescription complete`);
}

async function onCreateAnswerSuccess(desc) {
    console.log(`Answer from remotePeer:`, desc);
    console.log("pc2 setLocalDescription start");
    try {
        await pc2.setLocalDescription(desc);
        onSetLocalSuccess(pc2);
    } catch (e) {
        onSetSessionDescriptionError(e);
    }
    console.log("pc1 setRemoteDescription start");
    try {
        await pc1.setRemoteDescription(desc);
        onSetRemoteSuccess(pc1);
    } catch (e) {
        onSetSessionDescriptionError(e);
    }
}

// MARK: hangup
function hangup() {
    console.log("Ending call");
    pc1.close();
    pc2.close();
    pc1 = null;
    pc2 = null;
    hangupButton.disabled = true;
    callButton.disabled = false;
    startButton.disabled = false;
}

