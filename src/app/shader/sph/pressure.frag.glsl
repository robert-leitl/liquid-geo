
#version 300 es

precision highp float;
precision highp int;
precision highp usampler2D;

uniform sampler2D u_positionTexture;
uniform usampler2D u_indicesTexture;
uniform usampler2D u_offsetTexture;

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
    vec3 DOMAIN_SCALE;
    ivec2 CELL_TEX_SIZE;
    float CELL_SIZE;
};

in vec2 v_uv;

out vec2 outDensityPressure;

#include ./utils/particle-utils.glsl;

float poly6Weight(float r2) {
    float temp = max(0., HSQ - r2);
    return POLY6 * temp * temp * temp;
}

void main() {
    ivec2 particleTexDimensions = textureSize(u_positionTexture, 0);
    vec4 domainScale = vec4(DOMAIN_SCALE, 0.);
    int emptyOffsetValue = PARTICLE_COUNT * PARTICLE_COUNT;
    int cellCount = CELL_TEX_SIZE.x * CELL_TEX_SIZE.y;

    vec4 p = texture(u_positionTexture, v_uv);
    vec4 pi = p * domainScale;
    float rho = MASS * poly6Weight(0.);

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

                // do density estimation
                uint pj_ndx = indexData.y;
                vec4 pj = texelFetch(u_positionTexture, ndx2tex(particleTexDimensions, int(pj_ndx)), 0) * domainScale;
                vec4 pij = pj - pi;

                float r2 = dot(pij, pij);
                if (r2 < HSQ) {
                    float t = MASS * poly6Weight(r2);
                    rho += t;
                }

                neighborIterator++;
            }
        }
    }*/

    // loop over all other particles
    for(int i=0; i<PARTICLE_COUNT; i++) {
        vec4 pj = texelFetch(u_positionTexture, ndx2tex(particleTexDimensions, i), 0) * domainScale;

        float sr = sphericalDistance(pi.xyz, pj.xyz);
        float r2 = sr * sr;
        if (r2 < HSQ) {
            float t = MASS * poly6Weight(r2);
            rho += t;
        }
    }

    float pressure = max(GAS_CONST * (rho - REST_DENS), 0.);

    outDensityPressure = vec2(rho, pressure);
}