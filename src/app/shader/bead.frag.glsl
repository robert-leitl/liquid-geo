#version 300 es

precision highp float;

out vec4 outColor;

in vec3 v_position;
in vec2 v_texcoord;
in vec3 v_normal;

void main() {
    outColor = vec4(v_normal, 1.);
}