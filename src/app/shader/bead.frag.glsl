#version 300 es

precision highp float;

uniform sampler2D u_spectrumTexture;
uniform sampler2D u_lightDepthTexture;
uniform sampler2D u_envMapTexture;
uniform sampler2D u_normalMapTexture;

out vec4 outColor;

in vec3 v_position;
in vec4 v_lightSpacePosition;
in vec3 v_normal;
in vec3 v_surfaceToView;
in vec2 v_texcoord;
in vec3 v_tangent;
in float v_emission;
in float v_darken;
flat in int v_instanceId;

#define BOXBLUR2D_KERNELSIZE 7
#define PI 3.1415926535

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

float powFast(float a, float b) {
  return a / ((1. - b) * a + b);
}

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

void main() {
    vec3 color = vec3(0.);

    vec3 T = normalize(v_tangent);
    vec3 N = normalize(v_normal);
    vec3 V = normalize(v_surfaceToView);
    vec3 R = reflect(N, V);

    // perturb normal
    vec3 B = normalize(cross(N, T));
    mat3 tangentSpace = mat3(T, B, N);
    vec3 normalOffset = texture(u_normalMapTexture, v_texcoord + float(v_instanceId) * 0.5).xyz;
    normalOffset = normalOffset.rgb * 2. - 1.;
    N = normalize(mix(N, tangentSpace * normalOffset, 1.5));

    // get shadow factor
    // divide by w to get the correct value
    vec3 lightSpacePosition = v_lightSpacePosition.xyz / v_lightSpacePosition.w;
    vec2 shadowMapRes = vec2(textureSize(u_lightDepthTexture, 0));
    vec2 offset = 1. / shadowMapRes;
    lightSpacePosition = lightSpacePosition * 0.5 + 0.5;
    float currentDepth = lightSpacePosition.z - 0.009;
    float shadow = blurShadow(lightSpacePosition.xy, currentDepth, offset * 2.);
    float shadowFactor = 1.;
    shadow = (shadow * shadowFactor + (1. - shadowFactor));

    // fresnel
    float fresnel = 1. - max(0., dot(V, N));

    // specular lighting
    float specularValue = powFast(max(0.0, dot(R, -V)), 50.);
    vec3 specular = specularValue * vec3(1., 0.95, 0.95);

    // env lighting
    float phi   = atan(-N.z, N.x) - 0.35;
    float theta = acos(N.y);
    vec2 equiPos = vec2(-phi / (2. * PI), theta / PI);
    vec3 ambient = texture(u_envMapTexture, equiPos).rgb;
    color += ambient * .9;

    // apply shadow
    color *= shadow;

    // add emission effect
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.1, 0.75, 0.2); 	
    vec3 d = vec3(0.00, 0.05, 0.20);
    vec3 emission = palette( v_emission * 0.53 + 0.4, a, b, c, d) * v_emission;
    color += emission;

    // add subtle fresnel
    color += fresnel * 0.1;

    // darken the bottom layer
    color *= v_darken;
    
    outColor = vec4(color, 1.);
}