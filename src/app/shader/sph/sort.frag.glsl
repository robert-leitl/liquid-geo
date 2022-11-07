#version 300 es

precision highp float;
precision highp usampler2D;

uniform float u_twoStage;
uniform float u_passModStage;
uniform float u_twoStagePmS1;
uniform ivec2 u_texSize;
uniform float u_ppass;
uniform usampler2D u_indicesTexture;

out uvec4 outIndices;

#include ./utils/particle-utils.glsl;

void main() {
    ivec2 texSize = u_texSize;
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    float particleCount = float(texSize * texSize);
    float width = float(texSize.x);
    float height = float(texSize.y);

    // get self
    uvec4 self = texture(u_indicesTexture, uv);
    float i = floor(uv.x * width) + floor(uv.y * height) * width;

    // my position within the range to merge
    float j = floor(mod(i, u_twoStage));
    float compare;

    if ( (j < u_passModStage) || (j > u_twoStagePmS1) )
    // must copy -> compare with self
    compare = 0.0;
    else
    // must sort
    if ( mod((j + u_passModStage) / u_ppass, 2.0) < 1.0)
        // we are on the left side -> compare with partner on the right
        compare = 1.0;
    else
        // we are on the right side -> compare with partner on the left
        compare = -1.0;

    // get the partner
    float adr = i + compare * u_ppass;
    uvec4 partner = texture(u_indicesTexture, vec2(floor(mod(adr, width)) / width, floor(adr / width) / height));

    // on the left it's a < operation; on the right it's a >= operation
    outIndices = (float(self.x) * compare < float(partner.x) * compare) ? self : partner;
}
