#version 300 es

precision highp float;

in float v_velocity;
flat in vec3 v_color;

out vec4 outColor;

void main() {
    vec2 c = gl_PointCoord * 2. - 1.;
    float mask = 1. - smoothstep(0.7, 0.9, length(c));
    outColor = vec4(0.4 * v_velocity, 0.9, 1., .8) * mask;
    outColor = vec4(v_color, 1.) * mask;
}