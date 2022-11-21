
#version 300 es

precision highp float;

uniform sampler2D u_forceTexture;
uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform sampler2D u_densityPressureTexture;
uniform float u_dt;
uniform float u_time;
uniform vec4 u_domainScale;

layout(std140) uniform u_PointerParams {
    vec3 pointerPos;
    vec3 pointerVelocity;
    float pointerRadius;
    float pointerStrength;
};

in vec2 v_uv;

layout(location = 0) out vec4 outPosition;
layout(location = 1) out vec4 outVelocity;

#include ./utils/particle-utils.glsl;

void main() {
    ivec2 particleTexDimensions = textureSize(u_positionTexture, 0);
    vec4 domainScale = u_domainScale;

    vec4 pi = texture(u_positionTexture, v_uv);
    vec4 vi = texture(u_velocityTexture, v_uv);
    vec4 fi = texture(u_forceTexture, v_uv);
    vec4 ri = texture(u_densityPressureTexture, v_uv);

    // integrate to update the velocity
    float dt = (u_dt * 0.001);
    float rho = ri.x + 0.000000001;
    vec4 ai = fi / rho;
    vi += ai * dt;

    // apply the pointer force
    vec4 pointerPos = vec4(pointerPos, 0.);
    float prFront = length(pointerPos * domainScale - pi * domainScale);
    float prBack = length(pointerPos * domainScale + pi * domainScale);
    if (prFront < pointerRadius) {
        vi += vec4(pointerVelocity, 0.) * pointerStrength * (1. - prFront / pointerRadius);
    } else if (prBack < pointerRadius) {
        // flip the pointer force on the back and lessen its strength, because
        // the back particles are used to generate a second layer in the front of the sphere
        vi -= vec4(pointerVelocity, 0.) * pointerStrength * 0.8 * (1. - prBack / pointerRadius);
    }

    // update the position
    pi += (vi + 0.5 * ai * dt) * dt;
    pi = normalize(pi);

    // damp the velocity a bit
    vi *= 0.99;

    // add noise
    vec3 n = curlNoise(pi.xyz * 2.5 + sin(u_time * 0.0001) * 2.) * 2. - 1.;
    vi.xyz += n * 0.008;
    
    outPosition = pi;
    outVelocity = vi;
}