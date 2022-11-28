#version 300 es

precision highp float;

uniform sampler2D u_texture;

out vec4 outColor;

in vec2 v_uv;

void main() {
    outColor = vec4(texture(u_texture, v_uv));
}