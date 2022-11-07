#version 300 es

precision highp float;
precision highp int;
precision highp usampler2D;

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform usampler2D u_indicesTexture;
uniform usampler2D u_offsetTexture;
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
    vec2 DOMAIN_SCALE;
    ivec2 CELL_TEX_SIZE;
    float CELL_SIZE;
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
    vec4 domainScale = vec4(DOMAIN_SCALE, 0., 0.);
    int emptyOffsetValue = PARTICLE_COUNT * PARTICLE_COUNT;
    int cellCount = CELL_TEX_SIZE.x * CELL_TEX_SIZE.y;

    vec4 p = texture(u_positionTexture, v_uv);
    vec4 pi = p * domainScale;
    vec4 vi = texture(u_velocityTexture, v_uv);
    vec2 ri = texture(u_densityPressureTexture, v_uv).xy;
    float pi_rho = ri.x;
    float pi_pressure = ri.y;
    vec4 force = vec4(0.);
    
    // find the cell id of this particle
    /*ivec2 cellIndex = pos2CellIndex(p.xy, CELL_TEX_SIZE, domainScale.xy, CELL_SIZE);

    for(int i = -1; i <= 1; ++i)
    {
        for(int j = -1; j <= 1; ++j)
        {
            ivec2 neighborIndex = cellIndex + ivec2(i, j);            
            int neighborId = tex2ndx(CELL_TEX_SIZE, neighborIndex) % cellCount;
            
            // look up the offset to the cell:
            int neighborIterator = int(texelFetch(u_offsetTexture, ndx2tex(CELL_TEX_SIZE, neighborId), 0).x);

            // iterate through particles in the neighbour cell (if iterator offset is valid)
            while(neighborIterator != emptyOffsetValue && neighborIterator < PARTICLE_COUNT)
            {
                uvec2 indexData = texelFetch(u_indicesTexture, ndx2tex(particleTexDimensions, neighborIterator), 0).xy;

                if(int(indexData.x) != neighborId) {
                    break;  // it means we stepped out of the neighbour cell list
                }

                // do force calculation
                uint pj_ndx = indexData.y;
                ivec2 pj_tex = ndx2tex(particleTexDimensions, int(pj_ndx));
                vec4 pj = texelFetch(u_positionTexture, pj_tex, 0) * domainScale;
                vec4 pij = pj - pi;
                float r2 = dot(pij, pij);

                if (r2 < HSQ) {
                    float r = sqrt(r2);

                    if (r != 0.) {
                        vec4 pressureForce = vec4(pij);
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

                neighborIterator++;
            }
        }
    }*/

    // loop over all other particles
    for(int i=0; i<PARTICLE_COUNT; i++) {
        ivec2 pj_tex = ndx2tex(particleTexDimensions, i);
        vec4 pj = texelFetch(u_positionTexture, pj_tex, 0) * domainScale;
        vec4 pij = pj - pi;
        float r2 = dot(pij, pij);

        if (r2 < HSQ) {
            float r = sqrt(r2);

            if (r == 0.) continue;

            vec4 pressureForce = vec4(pij);
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

    // compute boundary forces
    float h = H;
    float scale = 1.;
    vec2 minBound = -domainScale.xy * scale;
    vec2 maxBound = domainScale.xy * scale;
    float f = (MASS / (pi_rho + 0.0000000001)) * pi_pressure;

    if (pi.x < minBound.x + h) {
        float r = pi.x - minBound.x;
        force.x -= f * spiky_grad2Weight(r) * r;
    } else if (pi.x > maxBound.x - h) {
        float r = maxBound.x - pi.x;
        force.x += f * spiky_grad2Weight(r) * r;
    }
    if (pi.y < minBound.y + h) {
        float r = pi.y - minBound.y;
        force.y -= f * spiky_grad2Weight(r) * r;
    } else if (pi.y > maxBound.y - h) {
        float r = maxBound.y - pi.y;
        force.y += f * spiky_grad2Weight(r) * r;
    }

    outForce = vec4(force);
}