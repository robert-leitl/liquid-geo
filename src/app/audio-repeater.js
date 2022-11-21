export class AudioRepeater {

    MAX_RECORD_LENGTH = 5; // seconds
    FFT_BUFFER_SIZE = 512;

    isRecording = false;
    isRecordingTimeoutId = null;

    constructor(recordBtnElm, playbackBtnElm, isDev = false, pane = null) {
        this.isDev = isDev;
        this.pane = pane;
        this.recordBtnElm = recordBtnElm;
        this.playbackBtnElm = playbackBtnElm;

        this.init();
    }

    init() {
        this.audioContext = new AudioContext();

        this.gain = this.audioContext.createGain();
        this.gain.connect(this.audioContext.destination);

        this.analyser = this.audioContext.createAnalyser();
        this.analyser.fftSize = this.FFT_BUFFER_SIZE;
        this.analyser.minDecibels = -90;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.buffer = new Uint8Array(this.bufferLength);
        // calculate the frequency bin bandwidth
        this.freqBandwidth = (this.audioContext.sampleRate / 2) / this.bufferLength;

        this.analyser.connect(this.gain);

        this.recordBtnElm.innerHTML = 'START REC';
        this.playbackBtnElm.innerHTML = 'PLAY';
        this.playbackBtnElm.setAttribute('disabled', true);

        this.recordBtnElm.addEventListener('click', () => this.onRecordButtonClicked());
        this.playbackBtnElm.addEventListener('click', () => this.onPlaybackButtonClicked());
    }

    startPlayback() {
        this.playbackBtnElm.innerHTML = 'PAUSE';
        this.audio.play();
    }

    pausePlayback() {
        this.playbackBtnElm.innerHTML = 'PLAY';
        this.audio.pause();
    }

    onPlaybackButtonClicked() {
        if (this.audio.paused) {
            this.startPlayback();
        } else {
            this.pausePlayback();
        }
    }

    async onRecordButtonClicked() {
        if (this.isRecording) {
            this.stopRecording();
        } else {
            await this.startRecording();
        }
    }
    
    async startRecording() {
        if (this.audio) {
            this.audio.pause();
        }

        this.playbackBtnElm.setAttribute('disabled', true);
        this.recordBtnElm.innerHTML = 'STOP REC';
        this.isRecording = true;
        this.audioChunks = [];

        if (!this.mediaRecorder) {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            this.mediaRecorder = new MediaRecorder(stream);

            this.mediaRecorder.addEventListener("dataavailable", event => {
                this.audioChunks.push(event.data);
            });

            this.mediaRecorder.addEventListener("stop", () => {
                this.audioBlob = new Blob(this.audioChunks, { type: "audio/mpeg" });
                this.audioUrl = URL.createObjectURL(this.audioBlob);
                this.audio = new Audio(this.audioUrl);
                this.audio.loop = true;

                this.source = this.audioContext.createMediaElementSource(this.audio);
                this.source.connect(this.analyser);
            });
        }
        this.mediaRecorder.start();

        this.isRecordingTimeoutId = setTimeout(() => this.stopRecording(), this.MAX_RECORD_LENGTH * 1000);
    }

    stopRecording() {
        this.playbackBtnElm.removeAttribute('disabled');
        this.isRecording = false;
        this.recordBtnElm.innerHTML = 'START REC';
        clearTimeout(this.isRecordingTimeoutId);
        this.mediaRecorder.stop();
    }

    getSpectrum(){
        if (this.audio && !this.audio.paused) {
            this.analyser.getByteFrequencyData( this.buffer );
        } else {
            this.buffer.fill(0);
        }

        return this.buffer;
    }
}