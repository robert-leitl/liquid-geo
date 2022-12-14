import { concatAll, take, count, debounceTime, delay, filter, forkJoin, from, fromEvent, map, scan, withLatestFrom, of, switchMap, tap, distinctUntilChanged } from 'rxjs';
import { Sketch } from './sketch';
import { Pane } from 'tweakpane';
import * as modernizr from './utils/modernizr';
import { AudioRepeater } from './audio-repeater';

const queryString = window.location.search;
const urlParams = new URLSearchParams(queryString);
const hasDebugParam = urlParams.get('debug');
const isDev = import.meta.env.MODE === 'development';
let sketch;
let audioRepeater;
let pane;

if (isDev) {
    import('https://greggman.github.io/webgl-lint/webgl-lint.js');
}

if (hasDebugParam || isDev) {
    pane = new Pane({ title: 'Settings', expanded: isDev });
}

const resize = () => {
    // explicitly set the width and height to compensate for missing dvh and dvw support
    document.body.style.width = `${document.documentElement.clientWidth}px`;
    document.body.style.height = `${document.documentElement.clientHeight}px`;

    if (sketch) {
        sketch.resize();
    }
}

// add a debounced resize listener
fromEvent(window, 'resize').pipe(debounceTime(100)).subscribe(() => resize());

// resize initially on load
fromEvent(window, 'load').pipe(take(1)).subscribe(() => resize());

// INIT APP
const canvasElm = document.querySelector('canvas');
const recordBtnElm = document.querySelector('#record-button');
const playbackBtnElm = document.querySelector('#playback-button');
audioRepeater = new AudioRepeater(recordBtnElm, playbackBtnElm, isDev, pane);
sketch = new Sketch(canvasElm, audioRepeater, (instance) => instance.run(), isDev, pane);
resize();
