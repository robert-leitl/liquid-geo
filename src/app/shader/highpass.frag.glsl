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

vec4 sampleHalo(in vec2 uv, in float radius, in float aspectRatio, in float threshold) {
	vec2 haloVec = vec2(0.5) - uv;
    haloVec.x /= aspectRatio;
    haloVec = normalize(haloVec);
    haloVec.x *= aspectRatio;
    vec2 wuv = (uv - vec2(0.5, 0.0)) / vec2(aspectRatio, 1.0) + vec2(0.5, 0.0);
    float haloWeight = distance(wuv, vec2(0.5));
    haloWeight = windowCubic(haloWeight, radius, 0.01);
	haloVec *= radius;
	return applyThreshold(texture(u_colorTexture, uv + haloVec), threshold) * haloWeight;
}

void main() {
    vec2 texSize = vec2(textureSize(u_colorTexture, 0));
    vec2 texel = 1. / texSize;

    float haloThreshold = 0.3;
    float haloRadius = 0.6;
    vec2 shift = vec2(texel.x, 0.) * 50.;
    float haloR = sampleHalo(v_uv - shift, haloRadius, texSize.y / texSize.x, haloThreshold).r;
    float haloG = sampleHalo(v_uv, haloRadius, texSize.y / texSize.x, haloThreshold).g;
    float haloB = sampleHalo(v_uv + shift, haloRadius, texSize.y / texSize.x, haloThreshold).b;
    vec4 halo = vec4(haloR, haloG, haloB, 0.);

    outColor = applyThreshold(texture(u_colorTexture, v_uv), 0.4) * 200. + halo * 2000.;
}