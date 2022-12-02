#version 300 es

precision highp float;

uniform sampler2D u_colorTexture;

out vec4 outColor;

in vec2 v_uv;

// credits: https://john-chapman.github.io/2017/11/05/pseudo-lens-flare.html

vec4 applyThreshold(in vec4 rgb, in float threshold) {
	return max(rgb - vec4(threshold), vec4(0.0));
}

// Cubic window; map [0, _radius] in [1, 0] as a cubic falloff from _center.
float windowCubic(float x, float center, float radius) {
	x = min(abs(x - center) / radius, 1.0);
	return 1.0 - x * x * (3.0 - 2.0 * x);
}

vec4 sampleHalo(in vec2 uv, in float radius, in vec2 aspect, in float threshold) {
    vec2 off = .5 - uv;
    off *= aspect;
    off = normalize(off * .5);
    off /= aspect;
    off *= radius;
    vec2 st = uv + off;
    float mask = windowCubic(length((2. * uv - 1.) * aspect), radius * 2., 0.1);
    return applyThreshold(texture(u_colorTexture, st), threshold) * mask;
}

void main() {
    vec2 texSize = vec2(textureSize(u_colorTexture, 0));
    vec2 texel = 1. / texSize;

    float haloThreshold = 0.3;
    float haloRadius = .7;
    vec2 aspect = texSize / min(texSize.y, texSize.x);
    float shift = min(texel.x, texel.y) * 30.;
    float haloR = sampleHalo(v_uv, haloRadius - shift * 3., aspect, haloThreshold).r;
    float haloG = sampleHalo(v_uv, haloRadius - shift * 2., aspect, haloThreshold).g;
    float haloB = sampleHalo(v_uv, haloRadius - shift, aspect, haloThreshold).b;
    vec4 halo = vec4(haloR, haloG, haloB, 0.);

    outColor = applyThreshold(texture(u_colorTexture, v_uv), 0.4) * 200. + halo * 5.;
}