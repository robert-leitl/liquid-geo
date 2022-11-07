#version 300 es

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform vec2 u_resolution;
uniform vec2 u_domainScale;
uniform ivec2 u_cellTexSize;
uniform float u_cellSize;

out float v_velocity;
flat out vec3 v_color;

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
    int cellId = pos2CellId(pi.xy, u_cellTexSize, u_domainScale, u_cellSize);

    gl_Position = vec4(pi.xyz, 1.);
    gl_PointSize = pointSize;

    float numCells = float(u_cellTexSize.x * u_cellTexSize.y);

    /*vec3 a = vec3(0.5, 0.5, 0.5);		
    vec3 b = vec3(0.5, 0.5, 0.5);	
    vec3 c = vec3(1.0, 0.7, 0.4);	
    vec3 d = vec3(0.00, 0.15, 0.20);*/

    vec3 a = vec3(0.5, 0.5, 0.5);		
    vec3 b = vec3(0.5, 0.5, 0.5);	
    vec3 c = vec3(2.0, 1.0, 0.0);	
    vec3 d = vec3(0.50, 0.20, 0.25);

    float t = length(vi) * 0.1;

    v_color = palette(t, a, b, c, d) * 1.2;

    //v_color = hsv2rgb(vec3(fract((float(cellId) / numCells) * 5.), 0.5, 0.8));
}