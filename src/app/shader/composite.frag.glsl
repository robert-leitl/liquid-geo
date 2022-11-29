#version 300 es

precision highp float;

uniform sampler2D u_colorTexture;

out vec4 outColor;

in vec2 v_uv;

void main() {
    outColor = vec4(texture(u_colorTexture, v_uv));
}