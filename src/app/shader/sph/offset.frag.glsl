#version 300 es

precision highp float;
precision highp usampler2D;

uniform usampler2D u_indicesTexture;
uniform ivec2 u_texSize;
uniform ivec2 u_particleTexSize;

out uint outIndices;

#include ./utils/particle-utils.glsl;

void main() {
    ivec2 texSize = u_texSize;
    ivec2 particleTexSize = u_particleTexSize;
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    float width = float(texSize.x);
    float height = float(texSize.y);
    float particleCount = float(particleTexSize * particleTexSize);

    uvec4 self = texture(u_indicesTexture, uv);
    uint selfCellId = self.x;
    float i = floor(uv.x * width) + floor(uv.y * height) * width;
    uint offsetCellId = uint(i);

    for(int n=0; n<int(particleCount); n++) {
        uvec4 c = texelFetch(u_indicesTexture, ndx2tex(particleTexSize, n), 0);
        if (c.x == offsetCellId) {
            outIndices = uint(n);
            break;
        } else {
            outIndices = uint(particleCount * particleCount);
        }
    }

}
