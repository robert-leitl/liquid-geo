#version 300 es

precision highp float;

uniform sampler2D u_colorTexture;

out vec4 outColor;

in vec2 v_uv;

vec4 gaussianBlur2D(in sampler2D tex, in vec2 st, in vec2 offset, const int kernelSize) {
    vec4 accumColor = vec4(0.);
    #define GAUSSIANBLUR2D_KERNELSIZE kernelSize

    float accumWeight = 0.;
    const float k = .15915494; // 1 / (2*PI)
    float kernelSize2 = float(GAUSSIANBLUR2D_KERNELSIZE) * float(GAUSSIANBLUR2D_KERNELSIZE);

    for (int j = 0; j < GAUSSIANBLUR2D_KERNELSIZE; j++) {
        float y = -.5 * (float(GAUSSIANBLUR2D_KERNELSIZE) - 1.) + float(j);
        for (int i = 0; i < GAUSSIANBLUR2D_KERNELSIZE; i++) {
            float x = -.5 * (float(GAUSSIANBLUR2D_KERNELSIZE) - 1.) + float(i);
            float weight = (k / float(GAUSSIANBLUR2D_KERNELSIZE)) * exp(-(x * x + y * y) / (2. * kernelSize2));
            accumColor += weight * texture(tex, (st + vec2(x, y) * offset));
            accumWeight += weight;
        }
    }
    return accumColor / accumWeight;
}

void main() {
    vec2 texSize = vec2(textureSize(u_colorTexture, 0));
    outColor = gaussianBlur2D(u_colorTexture, v_uv, (1. / texSize) * 1.2, 20) * 1.6;
}