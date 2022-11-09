#version 300 es

precision highp float;
precision highp int;
precision highp usampler2D;

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform sampler2D u_densityPressureTexture;
uniform int u_particleCount;
uniform vec2 u_domainScale;

layout(std140) uniform u_SimulationParams {
    float H;
    float HSQ;
    float MASS;
    float REST_DENS;
    float GAS_CONST;
    float VISC;
    float POLY6;
    float SPIKY_GRAD;
    float VISC_LAP;
    float POINTER_RADIUS;
    float POINTER_STRENGTH;
    int PARTICLE_COUNT;
    vec4 DOMAIN_SCALE;
};

in vec2 v_uv;

out vec4 outForce;

#include ./utils/particle-utils.glsl;

float spiky_grad2Weight(float r) {
    float temp = max(0., H - r);
    return (SPIKY_GRAD * temp * temp) / r;
}

float visc_laplWeight(float r) {
    return VISC_LAP * (1. - r / H);
}

void main() {
    ivec2 particleTexDimensions = textureSize(u_positionTexture, 0);
    vec4 domainScale = DOMAIN_SCALE;

    vec4 p = texture(u_positionTexture, v_uv);
    vec4 pi = p * domainScale;
    vec4 vi = texture(u_velocityTexture, v_uv);
    vec2 ri = texture(u_densityPressureTexture, v_uv).xy;
    float pi_rho = ri.x;
    float pi_pressure = ri.y;
    vec4 force = vec4(0.);

    // loop over all other particles
    for(int i=0; i<PARTICLE_COUNT; i++) {
        ivec2 pj_tex = ndx2tex(particleTexDimensions, i);
        vec4 pj = texelFetch(u_positionTexture, pj_tex, 0) * domainScale;
        vec4 pij = pj - pi;

        vec3 b = cross(pj.xyz, pi.xyz);
        vec3 t = cross(pi.xyz, b);

        float sr = sphericalDistance(pi.xyz, pj.xyz);

        if (sr < H) {
            float r = sr;

            if (r <= 0.0001) continue;

            vec4 pressureForce = vec4(t, 0.);
            vec4 viscosityForce = vec4(0.);

            vec2 rj = texelFetch(u_densityPressureTexture, pj_tex, 0).xy;
            float pj_rho = rj.x;
            float pj_pressure = rj.y;
            vec4 vj = texelFetch(u_velocityTexture, pj_tex, 0);

            // compute pressure force contribution
            float pF = MASS * ((pi_pressure + pj_pressure) / (2. * pj_rho)) * spiky_grad2Weight(r);
            pressureForce *= pF;

            // compute viscosity force contribution
            viscosityForce = (vj - vi) * (VISC * MASS * visc_laplWeight(r) / pj_rho);

            force += pressureForce + viscosityForce;
        }
    }

    outForce = vec4(force);
}