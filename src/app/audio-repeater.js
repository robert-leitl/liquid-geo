import * as Tone from 'tone';

export class AudioRepeater {

    MAX_RECORD_LENGTH = 5; // seconds
    FFT_BUFFER_SIZE = 256;

    isRecording = false;
    isRecordingTimeoutId = null;

    MIN_DB = -100;

    constructor(recordBtnElm, playbackBtnElm, isDev = false, pane = null) {
        this.isDev = isDev;
        this.pane = pane;
        this.recordBtnElm = recordBtnElm;
        this.recordBtnLabelElm = recordBtnElm.querySelector('label');
        this.playbackBtnElm = playbackBtnElm;
        this.playbackBtnLabelElm = playbackBtnElm.querySelector('label');
        this.playbackBtnElm.setAttribute('disabled', true);

        this.init();
    }

    init() {
        this.recordBtnLabelElm.innerHTML = 'RECORD';
        this.playbackBtnLabelElm.innerHTML = 'PLAY';
        this.playbackBtnElm.setAttribute('disabled', true);

        this.recordBtnElm.addEventListener('click', () => this.onRecordButtonClicked());
        this.playbackBtnElm.addEventListener('click', () => this.onPlaybackButtonClicked());
    }

    initAudio() {
        this.audioContext = new AudioContext();
        Tone.setContext(this.audioContext);

        this.gain = this.audioContext.createGain();

        this.analyser = this.audioContext.createAnalyser();
        this.analyser.fftSize = this.FFT_BUFFER_SIZE;
        this.analyser.minDecibels = -90;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.buffer = new Uint8Array(this.bufferLength);
        this.smoothedBuffer1 = new Float32Array(this.bufferLength);
        this.smoothedBuffer2 = new Float32Array(this.bufferLength);
        this.buffer.fill(0);
        this.smoothedBuffer1.fill(0);
        this.smoothedBuffer2.fill(0);
        // calculate the frequency bin bandwidth
        this.freqBandwidth = (this.audioContext.sampleRate / 2) / this.bufferLength;

        this.dist = new Tone.Distortion(0.3);
        this.pitchShift = new Tone.PitchShift(-2);
        this.reverb = new Tone.Reverb(3);

        Tone.connect(this.dist, this.pitchShift);
        Tone.connect(this.pitchShift, this.reverb);
        this.reverb.toDestination();
    }

    startPlayback() {
        this.audio.currentTime = 0;
        this.audio.play();
    }

    pausePlayback() {
        this.audio.pause();
    }

    onPlaybackButtonClicked() {
        this.startPlayback();
    }

    async onRecordButtonClicked() {
        if (!this.audioContext) this.initAudio();

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

        this.recordBtnElm.classList.add('is-recording');
        this.playbackBtnElm.setAttribute('disabled', true);
        this.recordBtnLabelElm.innerHTML = 'STOP';
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

                this.source = this.audioContext.createMediaElementSource(this.audio);
                Tone.connect(this.source, this.dist);
                Tone.connect(this.source, this.analyser);
            });
        }
        this.mediaRecorder.start();

        this.isRecordingTimeoutId = setTimeout(() => this.stopRecording(), this.MAX_RECORD_LENGTH * 1000);
    }

    stopRecording() {
        this.recordBtnElm.classList.remove('is-recording');
        this.playbackBtnElm.removeAttribute('disabled');
        this.isRecording = false;
        this.recordBtnLabelElm.innerHTML = 'RECORD';
        clearTimeout(this.isRecordingTimeoutId);
        this.mediaRecorder.stop();
    }

    getSpectrum(){
        if (this.audioContext) {
            if (this.audio && !this.audio.paused) {
                this.analyser.getByteFrequencyData( this.buffer );
            } else {
                this.buffer.fill(0);
            }

            if (this.buffer) {
                for(let i=0; i<this.buffer.length; ++i) {
                    let targetValue = this.buffer[i] / 255;
                    /*let targetValue = this.buffer[i];
                    targetValue = targetValue === -Infinity ? this.MIN_DB : targetValue;
                    targetValue = targetValue / this.MIN_DB;
                    targetValue = Math.max(0, 1 - targetValue);*/

                    this.smoothedBuffer1[i] += (targetValue - this.smoothedBuffer1[i]) / 10;
                    this.smoothedBuffer2[i] += (this.smoothedBuffer1[i] - this.smoothedBuffer2[i]) / 5;
                }
            }
        }

        return this.buffer;
    }
}