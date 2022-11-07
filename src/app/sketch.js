import { vec2 } from "gl-matrix";
import { filter, fromEvent, merge, throwIfEmpty } from "rxjs";
import * as twgl from "twgl.js";

import drawVert from './shader/sph/draw.vert.glsl';
import drawFrag from './shader/sph/draw.frag.glsl';
import integrateVert from './shader/sph/integrate.vert.glsl';
import integrateFrag from './shader/sph/integrate.frag.glsl';
import pressureVert from './shader/sph/pressure.vert.glsl';
import pressureFrag from './shader/sph/pressure.frag.glsl';
import forceVert from './shader/sph/force.vert.glsl';
import forceFrag from './shader/sph/force.frag.glsl';
import indicesVert from './shader/sph/indices.vert.glsl';
import indicesFrag from './shader/sph/indices.frag.glsl';
import sortVert from './shader/sph/sort.vert.glsl';
import sortFrag from './shader/sph/sort.frag.glsl';
import offsetVert from './shader/sph/offset.vert.glsl';
import offsetFrag from './shader/sph/offset.frag.glsl';

export class Sketch {

    TARGET_FRAME_DURATION = 16;
    #time = 0; // total time
    #deltaTime = 0; // duration betweent the previous and the current animation frame
    #frames = 0; // total framecount according to the target frame duration
    // relative frames according to the target frame duration (1 = 60 fps)
    // gets smaller with higher framerates --> use to adapt animation timing
    #deltaFrames = 0;

    // particle constants
    NUM_PARTICLES = 500;

    // the domain scale factor compresses the field to make a dense particle area
    DOMAIN_SCALE_FACTOR = 4;

    simulationParams = {
        H: 1, // kernel radius
        MASS: 1, // particle mass
        REST_DENS: 1.8, // rest density
        GAS_CONST: 40, // gas constant
        VISC: 5.5, // viscosity constant

        // these are calculated from the above constants
        POLY6: 0,
        HSQ: 0,
        SPIKY_GRAD: 0,
        VISC_LAP: 0,

        PARTICLE_COUNT: 0,
        DOMAIN_SCALE: 0,

        STEPS: 0
    };

    pointerParams = {
        RADIUS: 3,
        STRENGTH: 6,
    }

    constructor(canvasElm, onInit = null, isDev = false, pane = null) {
        this.canvas = canvasElm;
        this.onInit = onInit;
        this.isDev = isDev;
        this.pane = pane;

        this.#init();
    }

    run(time = 0) {
        this.#deltaTime = Math.min(16, time - this.#time);
        this.#time = time;
        this.#deltaFrames = this.#deltaTime / this.TARGET_FRAME_DURATION;
        this.#frames += this.#deltaFrames;

        this.#animate(this.#deltaTime);
        this.#render();

        requestAnimationFrame((t) => this.run(t));
    }

    resize() {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        this.viewportSize = vec2.set(
            this.viewportSize,
            this.canvas.clientWidth,
            this.canvas.clientHeight
        );

        // the domain scale reflects the aspect ratio within the simulation
        this.domainScale = vec2.copy(vec2.create(), this.viewportSize);
        const maxSize = Math.max(this.domainScale[0], this.domainScale[1]) * 1.;
        this.domainScale[0] /= maxSize;
        this.domainScale[1] /= maxSize;
        vec2.scale(this.domainScale, this.domainScale, (this.textureSize * this.simulationParams.H) / this.DOMAIN_SCALE_FACTOR)
        this.simulationParams.DOMAIN_SCALE = this.domainScale;
        this.simulationParamsNeedUpdate = true;

        const needsResize = twgl.resizeCanvasToDisplaySize(this.canvas);

        if (needsResize) {
            gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
        }
    }

    #init() {
        this.gl = this.canvas.getContext('webgl2', { antialias: false, alpha: false });

        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        twgl.addExtensionsToContext(gl);

        this.viewportSize = vec2.fromValues(
            this.canvas.clientWidth,
            this.canvas.clientHeight
        );

        this.#initTextures();

        // Setup Programs
        this.drawPrg = twgl.createProgramInfo(gl, [drawVert, drawFrag]);
        this.integratePrg = twgl.createProgramInfo(gl, [integrateVert, integrateFrag]);
        this.pressurePrg = twgl.createProgramInfo(gl, [pressureVert, pressureFrag]);
        this.forcePrg = twgl.createProgramInfo(gl, [forceVert, forceFrag]);
        this.indicesPrg = twgl.createProgramInfo(gl, [indicesVert, indicesFrag]);
        this.sortPrg = twgl.createProgramInfo(gl, [sortVert, sortFrag]);
        this.offsetPrg = twgl.createProgramInfo(gl, [offsetVert, offsetFrag]);

        // Setup uinform blocks
        this.simulationParamsUBO = twgl.createUniformBlockInfo(gl, this.pressurePrg, 'u_SimulationParams');
        this.pointerParamsUBO = twgl.createUniformBlockInfo(gl, this.integratePrg, 'u_PointerParams');
        this.simulationParamsNeedUpdate = true;

        // Setup Meshes
        this.quadBufferInfo = twgl.createBufferInfoFromArrays(gl, { a_position: { numComponents: 2, data: [-1, -1, 3, -1, -1, 3] }});
        this.quadVAO = twgl.createVAOAndSetAttributes(gl, this.pressurePrg.attribSetters, this.quadBufferInfo.attribs, this.quadBufferInfo.indices);

        // Setup Framebuffers
        this.pressureFBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.densityPressure}], this.textureSize, this.textureSize);
        this.forceFBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.force}], this.textureSize, this.textureSize);
        this.inFBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.position1},{attachment: this.textures.velocity1}], this.textureSize, this.textureSize);
        this.outFBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.position2},{attachment: this.textures.velocity2}], this.textureSize, this.textureSize);
        this.indices1FBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.indices1}], this.textureSize, this.textureSize);
        this.indices2FBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.indices2}], this.textureSize, this.textureSize);
        this.offsetFBO = twgl.createFramebufferInfo(gl, [{attachment: this.textures.offset}], this.cellSideCount, this.cellSideCount);

        this.#initEvents();
        this.#updateSimulationParams();
        this.#initTweakpane();

        this.resize();
        
        if (this.onInit) this.onInit(this);
    }

    #initEvents() {
        this.isPointerDown = false;
        this.pointer = vec2.create();
        this.pointerLerp = vec2.create();
        this.pointerLerpPrev = vec2.create();
        this.pointerLerpDelta = vec2.create();

        fromEvent(this.canvas, 'pointerdown').subscribe((e) => {
            this.isPointerDown = true;
            this.pointer = this.#getNormalizedPointerCoords(e);
            vec2.copy(this.pointerLerp, this.pointer);
            vec2.copy(this.pointerLerpPrev, this.pointerLerp);
        });
        merge(
            fromEvent(this.canvas, 'pointerup'),
            fromEvent(this.canvas, 'pointerleave')
        ).subscribe(() => this.isPointerDown = false);
        fromEvent(this.canvas, 'pointermove').pipe(
            filter(() => this.isPointerDown)
        ).subscribe((e) => {
            this.pointer = this.#getNormalizedPointerCoords(e);
        });

        fromEvent(window.document, 'keyup').subscribe(() => this.debugKey = true);
    }

    #updateSimulationParams() {
        const sim = this.simulationParams
        sim.HSQ = sim.H * sim.H;
        sim.POLY6 = 315.0 / (64. * Math.PI * Math.pow(sim.H, 9.));
        sim.SPIKY_GRAD = -45.0 / (Math.PI * Math.pow(sim.H, 6.));
        sim.VISC_LAP = 45.0 / (Math.PI * Math.pow(sim.H, 5.));

        this.simulationParamsNeedUpdate = true;
    }

    #getNormalizedPointerCoords(e) {
        return vec2.fromValues(
            (e.clientX / this.viewportSize[0]) * 2. - 1, 
            (1 - (e.clientY / this.viewportSize[1])) * 2. - 1
        );
    }

    #initTextures() {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        // get a power of two texture size
        this.textureSize = 2**Math.ceil(Math.log2(Math.sqrt(this.NUM_PARTICLES)));

        // update the particle size to fill the texture space
        this.NUM_PARTICLES = this.textureSize * this.textureSize;
        this.simulationParams.PARTICLE_COUNT = this.NUM_PARTICLES;
        this.simulationParamsNeedUpdate = true;

        console.log('number of particles:', this.NUM_PARTICLES);

        // update the sort params
        this.logNumParticles = Math.log2(this.textureSize);
        this.totalSortSteps = ((this.logNumParticles + this.logNumParticles) * (this.logNumParticles + this.logNumParticles + 1)) / 2;

        // define the cell sizes
        this.cellSideCount = Math.max(1, Math.ceil((this.textureSize * this.simulationParams.H) / this.DOMAIN_SCALE_FACTOR));
        this.numCells = this.cellSideCount * this.cellSideCount;

        console.log('number of cells:', this.numCells);

        const initVelocities = new Float32Array(this.NUM_PARTICLES * 4);
        const initForces = new Float32Array(this.NUM_PARTICLES * 4);
        const initPositions = new Float32Array(this.NUM_PARTICLES * 4);

        for(let i=0; i<this.NUM_PARTICLES; ++i) {
            initVelocities[i * 4 + 0] = 0;
            initVelocities[i * 4 + 1] = 0;
            initPositions[i * 4 + 0] = Math.random() * 1.9 - .95;
            initPositions[i * 4 + 1] = Math.random() * 1.9 - .95;
        }

        // empty offset texture
        this.initialOffsetTextureData = new Uint16Array(this.numCells);
        this.initialOffsetTextureData.fill(Number.MAX_VALUE);

        const defaultOptions = {
            width: this.textureSize,
            height: this.textureSize,
            min: gl.NEAREST, 
            mag: gl.NEAREST,
            wrap: gl.REPEAT
        }

        const defaultVectorTexOptions = {
            ...defaultOptions,
            format: gl.RGBA,
            internalFormat: gl.RGBA32F, 
        }

        const defaultIndicesTexOptions = {
            ...defaultOptions,
            format: gl.RG_INTEGER,
            internalFormat: gl.RG16UI,
            wrap: gl.CLAMP_TO_EDGE
        }

        this.offsetTextureOptions = {
            ...defaultOptions,
            width: this.cellSideCount,
            height: this.cellSideCount,
            format: gl.RED_INTEGER,
            internalFormat: gl.R16UI,
            wrap: gl.CLAMP_TO_EDGE
        }

        this.textures = twgl.createTextures(gl, { 
            densityPressure: {
                ...defaultOptions,
                format: gl.RG, 
                internalFormat: gl.RG32F, 
                src: new Float32Array(this.NUM_PARTICLES * 2)
            },
            force: { ...defaultVectorTexOptions, src: [...initForces] },
            position1: { ...defaultVectorTexOptions, src: [...initPositions] },
            position2: { ...defaultVectorTexOptions, src: [...initPositions] },
            velocity1: { ...defaultVectorTexOptions, src: [...initVelocities] },
            velocity2: { ...defaultVectorTexOptions, src: [...initVelocities] },
            indices1: {
                ...defaultIndicesTexOptions,
                src: new Uint16Array(this.NUM_PARTICLES * 4)
            },
            indices2: {
                ...defaultIndicesTexOptions,
                src: new Uint16Array(this.NUM_PARTICLES * 4)
            },
            offset: {
                ...this.offsetTextureOptions,
                src: this.initialOffsetTextureData,
            }
        });

        this.currentPositionTexture = this.textures.position2;
        this.currentVelocityTexture = this.textures.velocity2;
    }

    #initTweakpane() {
        if (!this.pane) return;

        const sim = this.pane.addFolder({ title: 'Simulation' });
        sim.addInput(this.simulationParams, 'MASS', { min: 0.01, max: 5, });
        sim.addInput(this.simulationParams, 'REST_DENS', { min: 0.1, max: 5, });
        sim.addInput(this.simulationParams, 'GAS_CONST', { min: 10, max: 500, });
        sim.addInput(this.simulationParams, 'VISC', { min: 1, max: 20, });
        sim.addInput(this.simulationParams, 'STEPS', { min: 0, max: 6, step: 1 });

        const pointer = this.pane.addFolder({ title: 'Pointer' });
        pointer.addInput(this.pointerParams, 'RADIUS', { min: 0.1, max: 5, });
        pointer.addInput(this.pointerParams, 'STRENGTH', { min: 1, max: 35, });

        sim.on('change', () => this.#updateSimulationParams());
        pointer.on('change', () => this.pointerParamsNeedUpdate = true);
    }

    #updatePointer() {
        this.pointerLerp[0] += (this.pointer[0] - this.pointerLerp[0]) / 5;
        this.pointerLerp[1] += (this.pointer[1] - this.pointerLerp[1]) / 5;

        vec2.subtract(this.pointerLerpDelta, this.pointerLerp, this.pointerLerpPrev);
        vec2.copy(this.pointerLerpPrev, this.pointerLerp);
    }

    #simulate(deltaTime) {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        //this.#prepare();

        if (this.simulationParamsNeedUpdate) {
            twgl.setBlockUniforms(
                this.simulationParamsUBO,
                {
                    ...this.simulationParams,
                    CELL_TEX_SIZE: [this.cellSideCount, this.cellSideCount],
                    CELL_SIZE: this.simulationParams.H
                }
            );
            twgl.setUniformBlock(gl, this.pressurePrg, this.simulationParamsUBO);
            this.simulationParamsNeedUpdate = false;
        } else {
            twgl.bindUniformBlock(gl, this.pressurePrg, this.simulationParamsUBO);
        }


        // calculate density and pressure for every particle
        gl.useProgram(this.pressurePrg.program);
        twgl.bindFramebufferInfo(gl, this.pressureFBO);
        gl.bindVertexArray(this.quadVAO);
        twgl.setUniforms(this.pressurePrg, { 
            u_positionTexture: this.inFBO.attachments[0],
            u_indicesTexture: this.currentIndicesTexture,
            u_offsetTexture: this.textures.offset,
        });
        twgl.drawBufferInfo(gl, this.quadBufferInfo);


        // calculate pressure-, viscosity- and boundary forces for every particle
        gl.useProgram(this.forcePrg.program);
        twgl.bindFramebufferInfo(gl, this.forceFBO);
        twgl.setUniforms(this.forcePrg, { 
            u_densityPressureTexture: this.pressureFBO.attachments[0],
            u_positionTexture: this.inFBO.attachments[0], 
            u_velocityTexture: this.inFBO.attachments[1],
            u_indicesTexture: this.currentIndicesTexture,
            u_offsetTexture: this.textures.offset,
            u_cellTexSize: [this.cellSideCount, this.cellSideCount],
            u_cellSize: this.simulationParams.H,
        });
        twgl.drawBufferInfo(gl, this.quadBufferInfo);

        // perform the integration to update the particles position and velocity
        gl.useProgram(this.integratePrg.program);
        twgl.bindFramebufferInfo(gl, this.outFBO);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        twgl.setUniforms(this.integratePrg, { 
            u_positionTexture: this.inFBO.attachments[0], 
            u_velocityTexture: this.inFBO.attachments[1],
            u_forceTexture: this.forceFBO.attachments[0],
            u_densityPressureTexture: this.pressureFBO.attachments[0],
            u_pointerPos: this.pointerLerp,
            u_pointerVelocity: this.pointerLerpDelta,
            u_dt: deltaTime,
            u_domainScale: this.domainScale
        });
        twgl.setBlockUniforms(
            this.pointerParamsUBO,
            {
                pointerRadius: this.pointerParams.RADIUS,
                pointerStrength: this.pointerParams.STRENGTH,
                pointerPos: this.pointerLerp,
                pointerVelocity: this.pointerLerpDelta
            } 
        );
        twgl.setUniformBlock(gl, this.integratePrg, this.pointerParamsUBO);
        twgl.drawBufferInfo(gl, this.quadBufferInfo);

        // update the current result textures
        this.currentPositionTexture = this.outFBO.attachments[0];
        this.currentVelocityTexture = this.outFBO.attachments[1];

        // swap the integrate FBOs
        const tmp = this.inFBO;
        this.inFBO = this.outFBO;
        this.outFBO = tmp;
    }

    #prepare() {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        // update the indices structure
        gl.useProgram(this.indicesPrg.program);
        twgl.bindFramebufferInfo(gl, this.indices1FBO);
        gl.bindVertexArray(this.quadVAO);
        twgl.setUniforms(this.indicesPrg, { 
            u_positionTexture: this.currentPositionTexture,
            u_cellTexSize: [this.cellSideCount, this.cellSideCount],
            u_cellSize: this.simulationParams.H,
            u_domainScale: this.domainScale,
        });
        twgl.drawBufferInfo(gl, this.quadBufferInfo);

        // sort by cell id
        let sortOutFBO = this.indices1FBO;
        let sortInFBO = this.indices2FBO;
        gl.useProgram(this.sortPrg.program);

        // https://developer.nvidia.com/gpugems/gpugems2/part-vi-simulation-and-numerical-algorithms/chapter-46-improved-gpu-sorting
        let pass = -1;
        let stage = -1;
        let stepsLeft = this.totalSortSteps;
        while(stepsLeft) {
            // update pass and stage uniforms
            pass--;
            if (pass < 0) {
                // next stage
                stage++;
                pass = stage;
            }

            const pstage = (1 << stage);
            const ppass  = (1 << pass);

            twgl.bindFramebufferInfo(gl, sortInFBO);
            twgl.setUniforms(this.sortPrg, { 
                u_indicesTexture: sortOutFBO.attachments[0],
                u_twoStage: pstage + pstage,
                u_passModStage: ppass % pstage,
                u_twoStagePmS1: (pstage + pstage) - (ppass % pstage) - 1,
                u_texSize: [this.textureSize, this.textureSize],
                u_ppass: ppass
            });
            twgl.drawBufferInfo(gl, this.quadBufferInfo);

            // buffer swap
            const tmp = sortOutFBO;
            sortOutFBO = sortInFBO;
            sortInFBO = tmp;

            stepsLeft--;


            /*if (this.#frames > 0 && this.#frames < 2) {
                console.log('pstage:', pstage, 'ppass:', ppass, 'twoStage:', pstage+pstage, 'passModStage:', ppass % pstage, 'twoStagePmS1:', (pstage + pstage) - (ppass % pstage) - 1);
                console.log('particle count:', this.NUM_PARTICLES);
                console.log('total steps:', this.totalSortSteps);
                const indicesData = new Uint32Array(this.NUM_PARTICLES * 4);
                gl.readPixels(0, 0, this.textureSize, this.textureSize, gl.RGBA_INTEGER, gl.UNSIGNED_INT, indicesData)
                const cells = indicesData.reduce((arr, v, i) => i % 4 === 0 ? [...arr, v] : arr, []);
                const cellIds = cells.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
                const particles = indicesData.reduce((arr, v, i) => i % 4 === 1 ? [...arr, v] : arr, []);
                const particleIds = particles.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
                console.log(cellIds);
                console.log('particleCount:', particleIds.length);
                const isSorted = cellIds.every((v, i) => i === 0 || cellIds[i - 1] < v);
                if (particleIds.length === this.NUM_PARTICLES && isSorted) 
                    console.warn('success')
                /*else
                    console.error('fail');
                for(let i=0; i<this.NUM_PARTICLES; i++) {
                    console.log(i, 'cellId:',indicesData[i * 4], 'particleId:', indicesData[i * 4 + 1], 'z:', indicesData[i * 4 + 2], 'w:', indicesData[i * 4 + 3] )
                }/
                
            }*/
        }

        /*const indicesData = new Uint32Array(this.NUM_PARTICLES * 4);
        gl.readPixels(0, 0, this.textureSize, this.textureSize, gl.RGBA_INTEGER, gl.UNSIGNED_INT, indicesData)
        const cells = indicesData.reduce((arr, v, i) => i % 4 === 0 ? [...arr, v] : arr, []);
        const cellIds = cells.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
        const particles = indicesData.reduce((arr, v, i) => i % 4 === 1 ? [...arr, v] : arr, []);
        const particleIds = particles.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
        const isSorted = cellIds.every((v, i) => i === 0 || cellIds[i - 1] < v);
        if (particleIds.length !== this.NUM_PARTICLES && !isSorted) 
            console.error('fail');*/


        /*if (this.debugKey || (this.#frames > 20 && this.#frames < 22)) {
            const indicesData = new Uint32Array(this.NUM_PARTICLES * 4);
            gl.readPixels(0, 0, this.textureSize, this.textureSize, gl.RGBA_INTEGER, gl.UNSIGNED_INT, indicesData)
            const cells = indicesData.reduce((arr, v, i) => i % 4 === 0 ? [...arr, v] : arr, []);
            const cellIds = cells.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
            const particles = indicesData.reduce((arr, v, i) => i % 4 === 1 ? [...arr, v] : arr, []);
            const particleIds = particles.reduce((arr, value) => arr.includes(value) ? arr : [...arr, value], []);
            const isSorted = cellIds.every((v, i) => i === 0 || cellIds[i - 1] < v);
            for(let i=0; i<this.NUM_PARTICLES; i++) {
                console.log(i, 'cellId:',indicesData[i * 4], 'particleId:', indicesData[i * 4 + 1], 'z:', indicesData[i * 4 + 2], 'w:', indicesData[i * 4 + 3] )
            }
        }*/

        // set the offset list elements
        gl.useProgram(this.offsetPrg.program);
        twgl.bindFramebufferInfo(gl, this.offsetFBO);
        twgl.setUniforms(this.offsetPrg, { 
            u_indicesTexture: sortOutFBO.attachments[0],
            u_texSize: [this.cellSideCount, this.cellSideCount],
            u_particleTexSize: [this.textureSize, this.textureSize],
        });
        gl.clearColor(1, 0, 0, 0);
        twgl.drawBufferInfo(gl, this.quadBufferInfo);

        this.currentIndicesTexture = sortOutFBO.attachments[0];

        /*if (this.debugKey || (this.#frames > 20 && this.#frames < 22)) {
            console.warn('offset pass');
            const indicesData = new Uint32Array(this.numCells * 1);
            gl.readPixels(0, 0, this.cellSideCount, this.cellSideCount, gl.RED_INTEGER, gl.UNSIGNED_INT, indicesData)
            for(let i=0; i<this.numCells; i++) {
                console.log(i, 'offset:',indicesData[i])
            }

            this.debugKey = false;
        }*/
    }

    #animate(deltaTime) {
        this.#updatePointer();


        // use a fixed deltaTime of 10 ms adapted to
        // device frame rate
        deltaTime = 16 * this.#deltaFrames;

        // simulate at least once
        this.#simulate(deltaTime);

        // clear the pointer force so that it wont add up during
        // subsequent simulation steps
        vec2.set(this.pointerLerpDelta, 0, 0);

        // additional simulation steps
        for(let i=0; i<this.simulationParams.STEPS; ++i) {
            this.#simulate(deltaTime);
        }
    }

    #render() {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        twgl.bindFramebufferInfo(gl, null);
        gl.disable(gl.CULL_FACE);
        gl.disable(gl.DEPTH_TEST);
        gl.clearColor(0., 0., 0., 1.);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.DST_ALPHA);

        gl.useProgram(this.drawPrg.program);
        twgl.setUniforms(this.drawPrg, { 
            u_positionTexture: this.currentPositionTexture,
            u_velocityTexture: this.currentVelocityTexture,
            u_resolution: this.viewportSize,
            u_cellTexSize: [this.cellSideCount, this.cellSideCount],
            u_cellSize: this.simulationParams.H,
            u_domainScale: this.domainScale,
        });
        gl.drawArrays(gl.POINTS, 0, this.NUM_PARTICLES);
        gl.disable(gl.BLEND);
    }
}