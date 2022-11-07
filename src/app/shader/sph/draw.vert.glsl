#version 300 es

uniform mat4 u_worldMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;
uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform vec2 u_resolution;
uniform vec2 u_domainScale;
uniform ivec2 u_cellTexSize;
uniform float u_cellSize;

out float v_velocity;
flat out vec4 v_color;

#include ./utils/particle-utils.glsl;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// @see https://iquilezles.org/articles/palettes/
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

void main() {
    ivec2 poisitionTexDimensions = textureSize(u_positionTexture, 0);

    ivec2 pi_tex = ndx2tex(poisitionTexDimensions, gl_VertexID);
    vec4 pi = texelFetch(u_positionTexture, pi_tex, 0);
    vec4 vi = texelFetch(u_velocityTexture, pi_tex, 0);
    v_velocity = length(vi);
    float pointSize = max(u_resolution.x, u_resolution.y) * 0.01;

    gl_PointSize = pointSize * (pi.z * 0.5 + 1.)* (pi.z * 0.5 + 1.);
    vec4 worldPosition = u_worldMatrix * vec4(pi.xyz, 1.);
    gl_Position = u_projectionMatrix * u_viewMatrix * worldPosition;

    vec3 a = vec3(0.5, 0.5, 0.5);		
    vec3 b = vec3(0.5, 0.5, 0.5);	
    vec3 c = vec3(2.0, 1.0, 0.0);	
    vec3 d = vec3(0.50, 0.20, 0.25);

    float t = length(vi) * 0.1;

    v_color = vec4(palette(t, a, b, c, d) * 1.2, 1.);
    //v_color.a = (pi.z * 0.5 + 1.) * 0.5;
}