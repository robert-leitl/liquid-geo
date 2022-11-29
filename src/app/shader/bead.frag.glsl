#version 300 es

precision highp float;

uniform sampler2D u_spectrumTexture;
uniform sampler2D u_lightDepthTexture;

out vec4 outColor;

in vec3 v_position;
in vec4 v_lightSpacePosition;
in vec3 v_normal;
in float v_emission;
flat in int v_instanceId;

#define BOXBLUR2D_KERNELSIZE 7

ivec2 ndx2tex(ivec2 dimensions, int index) {
    int y = index / dimensions.x;
    int x = index % dimensions.x;
    return ivec2(x, y);
}

float shadow(vec2 lightSpacePos, float depth) {
    float projectedDepth = texture(u_lightDepthTexture, lightSpacePos.xy).r;
    return (depth <= projectedDepth) ? 1. : 0.;
}

float blurShadow(in vec2 st, in float depth, in vec2 offset) {
    float color = shadow(st, depth);                         // center
    color += shadow(st + vec2(-offset.x, offset.y), depth);  // tleft
    color += shadow(st + vec2(-offset.x, 0.), depth);        // left
    color += shadow(st + vec2(-offset.x, -offset.y), depth); // bleft
    color += shadow(st + vec2(0., offset.y), depth);         // top
    color += shadow(st + vec2(0., -offset.y), depth);        // bottom
    color += shadow(st + offset, depth);                     // tright
    color += shadow(st + vec2(offset.x, 0.), depth);         // right
    color += shadow(st + vec2(offset.x, -offset.y), depth);  // bright
    return color * 0.1111111111; // 1./9.
}

float blurShadow2(in vec2 st, in float depth, in vec2 offset) {
    float color = 0.;
    float accumWeight = 0.;
    float f_kernelSize = float(BOXBLUR2D_KERNELSIZE);
    float kernelSize2 = f_kernelSize * f_kernelSize;
    float weight = 1. / kernelSize2;

    for (int j = 0; j < BOXBLUR2D_KERNELSIZE; j++) {
        float y = -.5 * (f_kernelSize - 1.) + float(j);
        for (int i = 0; i < BOXBLUR2D_KERNELSIZE; i++) {
            float x = -.5 * (f_kernelSize - 1.) + float(i);
            color += shadow(st + vec2(x, y) * offset, depth) * weight;
        }
    }
    return color;
}

void main() {
    // divide by w to get the correct value
    vec3 lightSpacePosition = v_lightSpacePosition.xyz / v_lightSpacePosition.w;
    vec2 shadowMapRes = vec2(textureSize(u_lightDepthTexture, 0));
    vec2 offset = 1. / shadowMapRes;
    lightSpacePosition = lightSpacePosition * 0.5 + 0.5;
    float currentDepth = lightSpacePosition.z - 0.009;
    float shadow = blurShadow2(lightSpacePosition.xy, currentDepth, offset * 2.);
    float shadowFactor = 0.7;
    shadow = (shadow * shadowFactor + (1. - shadowFactor));

    vec3 color = v_normal;
    color.r += v_emission;
    color *= shadow;

    outColor = vec4(color, 1.);

    //outColor = vec4((float(v_instanceId + 1) / 512.));
}