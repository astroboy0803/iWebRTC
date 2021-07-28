const video = document.querySelector('video');

const constraints = {
    audio: true,
    video: {
        width: { min: 1280 },
        height: { min: 720 }
    }
};

function handleSuccess(stream) {
    const mediaStreamTracks = stream.getTracks();
    console.log(mediaStreamTracks);

    // 方便可以在瀏覽器console
    window.stream = stream;

    video.srcObject = stream;
}

function handleError(error) {
    console.log('navigator.MediaDevices.getUserMedia error: ', error.message, error.name);
}

function onCapture() {
    navigator.mediaDevices
        .getUserMedia(constraints)
        .then(handleSuccess)
        .catch(handleError);
}

function stopCapture() {
    if (window.stream) {
        const videoStreams = window.stream.getVideoTracks()
        videoStreams.forEach(stream => {
            stream.stop() // 停止所有media stream
            //stream.enabled = false // 裝置還是接受資訊，但不渲染在畫面上(不接受)
        });

        // 釋放資源
        video.src = video.srcObject = null;
    }
}

const screenshotButton = document.querySelector('#screenshot-button');
const img = document.querySelector('#screenshot img');
const canvas = document.querySelector('canvas');
const filterSelector = document.querySelector("#filter");

screenshotButton.onclick = video.onclick = function () {
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.className = filterSelector.value;
    // 渲染
    canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
    // 轉成image data
    img.src = canvas.toDataURL('image/png');

    filterSelector.onchange = function () {
        video.className = filterSelector.value;
    }
};
