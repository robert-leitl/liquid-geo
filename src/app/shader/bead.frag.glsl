#version 300 es

precision highp float;

uniform sampler2D u_spectrumTexture;
uniform sampler2D u_lightDepthTexture;

out vec4 outColor;

in vec3 v_position;
in vec4 v_lightSpacePosition;
in vec3 v_normal;
flat in int v_instanceId;

ivec2 ndx2tex(ivec2 dimensions, int index) {
    int y = index / dimensions.x;
    int x = index % dimensions.x;
    return ivec2(x, y);
}

float shadow(vec2 lightSpacePos, float depth) {
    float projectedDepth = texture(u_lightDepthTexture, lightSpacePos.xy).r;
    return (depth <= projectedDepth) ? 1. : 0.;
}

void main() {
    // divide by w to get the correct value
    vec3 lightSpacePosition = v_lightSpacePosition.xyz / v_lightSpacePosition.w;
    float offset = 0.005;
    lightSpacePosition = lightSpacePosition * 0.5 + 0.5;
    float currentDepth = lightSpacePosition.z - 0.005;
    float s1 = shadow(lightSpacePosition.xy, currentDepth);
    float s2 = shadow(lightSpacePosition.xy + vec2(offset, 0.), currentDepth);
    float s3 = shadow(lightSpacePosition.xy + vec2(0., offset), currentDepth);
    float s4 = shadow(lightSpacePosition.xy + vec2(offset, offset), currentDepth);
    float shadow = (s1 + s2 + s3 + s4) / 4.;

    float shadowFactor = 0.6;
    vec3 color = v_normal * (shadow * shadowFactor + (1. - shadowFactor));

    outColor = vec4(color, 1.);

    //outColor = vec4((float(v_instanceId + 1) / 512.));
}