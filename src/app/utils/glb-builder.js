import {load} from '@loaders.gl/core';
import {GLBLoader} from '@loaders.gl/gltf';

/**
 * Based on https://github.com/visgl/loaders.gl/blob/master/examples/experimental/gltf-with-raw-webgl/GlbBuilder.js
 */
export class GLBBuilder {

    constructor(gl) {
        this.gl = gl;
    }

    async load(url) {
        this.glb = await load(fetch(url), GLBLoader);

        this.primitives = [];
        for (let mesh of this.glb.json.meshes) {
            for (let primitiveDef of mesh.primitives) {
                const primitive = await this.loadPrimitive(this.glb, mesh.name, primitiveDef);
                if (primitive) {
                    this.primitives.push(primitive);
                }
            }
        }

        return this.primitives;
    }

    getPrimitiveDataByMeshName(meshName) {
        return this.primitives.find(item => item.meshName == meshName);
    }

    async loadPrimitive(glb, meshName, primitiveDef) {
        /** @type {WebGLRenderingContext} */
        const gl = this.gl;

        const indices = GLBBuilder.getAccessorData(glb, primitiveDef.indices);
        const vertices = GLBBuilder.getAccessorData(glb, primitiveDef.attributes.POSITION);
        const normals = GLBBuilder.getAccessorData(glb, primitiveDef.attributes.NORMAL);
        const texcoords = GLBBuilder.getAccessorData(glb, primitiveDef.attributes.TEXCOORD_0);
        const tangents = GLBBuilder.getAccessorData(glb, primitiveDef.attributes.TANGENT);

        if (!indices || !vertices || !normals || !texcoords || !tangents) return null;

        // Create buffers:
        const indicesBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indicesBuffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

        const verticesBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, verticesBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

        const normalsBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, normalsBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, normals, gl.STATIC_DRAW);

        const texcoordsBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, texcoordsBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, texcoords, gl.STATIC_DRAW);

        const tangentsBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, tangentsBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, tangents, gl.STATIC_DRAW);

        const buffers = {

            indices: {
                data: indices,
                webglBuffer: indicesBuffer,
                length: indices.length,
                dataType: GLBBuilder.getAccessorDataType(gl, glb, primitiveDef.indices),
                numberOfComponents: GLBBuilder.getAccessorNumberOfComponents(glb, primitiveDef.indices)
            },

            vertices: {
                data: vertices,
                webglBuffer: verticesBuffer,
                length: vertices.length,
                dataType: GLBBuilder.getAccessorDataType(gl, glb, primitiveDef.attributes.POSITION),
                numberOfComponents: GLBBuilder.getAccessorNumberOfComponents(glb, primitiveDef.attributes.POSITION),
                stride: glb.json.bufferViews[glb.json.accessors[primitiveDef.attributes.POSITION].bufferView].byteStride || 0
            },

            normals: {
                data: normals,
                webglBuffer: normalsBuffer,
                length: normals.length,
                dataType: GLBBuilder.getAccessorDataType(gl, glb, primitiveDef.attributes.NORMAL),
                numberOfComponents: GLBBuilder.getAccessorNumberOfComponents(glb, primitiveDef.attributes.NORMAL),
                stride: glb.json.bufferViews[glb.json.accessors[primitiveDef.attributes.NORMAL].bufferView].byteStride || 0
            },

            texcoords: {
                data: texcoords,
                webglBuffer: texcoordsBuffer,
                length: texcoords.length,
                dataType: GLBBuilder.getAccessorDataType(gl, glb, primitiveDef.attributes.TEXCOORD_0),
                numberOfComponents: GLBBuilder.getAccessorNumberOfComponents(glb, primitiveDef.attributes.TEXCOORD_0),
                stride: glb.json.bufferViews[glb.json.accessors[primitiveDef.attributes.TEXCOORD_0].bufferView].byteStride || 0
            },

            tangents: {
                data: tangents,
                webglBuffer: tangentsBuffer,
                length: tangents.length,
                dataType: GLBBuilder.getAccessorDataType(gl, glb, primitiveDef.attributes.TANGENT),
                numberOfComponents: GLBBuilder.getAccessorNumberOfComponents(glb, primitiveDef.attributes.TANGENT),
                stride: glb.json.bufferViews[glb.json.accessors[primitiveDef.attributes.TANGENT].bufferView].byteStride || 0
            }
        };

        return {
            meshName,
            buffers: buffers
        }
    }

    static getAccessorData(glb, accessorIndex) {

        const accessorDef = glb.json.accessors[accessorIndex];

        if (accessorDef) {

            const binChunk = glb.binChunks[0];

            const bufferViewDef = glb.json.bufferViews[accessorDef.bufferView];
            const componentType = accessorDef.componentType;
            const count = accessorDef.count;

            const byteOffset = binChunk.byteOffset + (accessorDef.byteOffset || 0) + bufferViewDef.byteOffset;

            let numberOfComponents = GLBBuilder.getAccessorNumberOfComponents(glb, accessorIndex);

            switch (componentType) {
                case 5120: { return new Int8Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
                case 5121: { return new Uint8Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
                case 5122: { return new Int16Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
                case 5123: { return new Uint16Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
                case 5125: { return new Uint32Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
                case 5126: { return new Float32Array(binChunk.arrayBuffer, byteOffset, count * numberOfComponents); }
            }
        }

        return null;
    }

    static getAccessorNumberOfComponents(glb, accessorIndex) {

        const accessorDef = glb.json.accessors[accessorIndex];

        switch (accessorDef.type) {
            case "SCALAR": return 1;
            case "VEC2": return 2;
            case "VEC3": return 3;
            case "VEC4": return 4;
            case "MAT2": return 4;
            case "MAT3": return 9;
            case "MAT4": return 16;
        }

        return null;
    }

    static getAccessorDataType(gl, glb, accessorIndex) {

        const accessorDef = glb.json.accessors[accessorIndex];
        const componentType = accessorDef.componentType;

        switch (componentType) {
            case 5120: { return gl.BYTE; }
            case 5121: { return gl.UNSIGNED_BYTE; }
            case 5122: { return gl.SHORT; }
            case 5123: { return gl.UNSIGNED_SHORT; }
            case 5125: { return gl.UNSIGNED_INT; }
            case 5126: { return gl.FLOAT; }
        }
    }
}