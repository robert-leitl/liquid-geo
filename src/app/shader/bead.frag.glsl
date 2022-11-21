#version 300 es

precision highp float;

uniform sampler2D u_spectrumTexture;

out vec4 outColor;

in vec3 v_position;
in vec3 v_normal;
flat in int v_instanceId;

ivec2 ndx2tex(ivec2 dimensions, int index) {
    int y = index / dimensions.x;
    int x = index % dimensions.x;
    return ivec2(x, y);
}

void main() {
    outColor = vec4(v_normal, 1.);

    //outColor = vec4((float(v_instanceId + 1) / 512.));
}