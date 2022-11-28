#version 300 es

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform sampler2D u_spectrumTexture;
uniform mat4 u_worldMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;
uniform mat4 u_lightViewProjectionMatrix;
uniform float u_time;

in vec3 a_position;
in vec3 a_normal;
in mat4 a_instanceMatrix;

out vec3 v_position;
out vec4 v_lightSpacePosition;
out vec3 v_normal;
flat out int v_instanceId;

#include ./sph/utils/particle-utils.glsl;

#define PI 3.1415926535

mat3 calcLookAtMatrix(vec3 origin, vec3 target, float roll) {
  vec3 rr = vec3(sin(roll), cos(roll), 0.0);
  vec3 ww = normalize(target - origin);
  vec3 uu = normalize(cross(ww, rr));
  vec3 vv = normalize(cross(uu, ww));

  return mat3(uu, vv, ww);
}

float rand(float n){return fract(sin(n) * 43758.5453123);}

void main() {
    ivec2 poisitionTexDimensions = textureSize(u_positionTexture, 0);
    ivec2 spectrumTexSize = textureSize(u_spectrumTexture, 0);
    ivec2 pi_tex = ndx2tex(poisitionTexDimensions, gl_InstanceID);
    vec4 pi = texelFetch(u_positionTexture, pi_tex, 0);
    vec4 vi = texelFetch(u_velocityTexture, pi_tex, 0);

    
   //float f = float(gl_InstanceID + 1) / 512.;
    float f = max(0., dot(vec3(0., 0., 1.), normalize(pi.xyz)));
    float freq = (1. - f) * noise(pi.xyz * (sin(u_time * 0.001) + 2.));
    int bucketCount = spectrumTexSize.x * spectrumTexSize.y;
    int bucketNdx = int(floor(freq * float(bucketCount)));
    ivec2 bucketTex = ndx2tex(spectrumTexSize, bucketNdx);
    vec2 bucketUv = vec2(bucketTex) / vec2(spectrumTexSize);
    float audioOffset = texture(u_spectrumTexture, bucketUv).r;
    audioOffset *= min(0.1, length(vi)) * (f + 1.8);

    //f *= length(vi);
    //vec2 uv = vec2(mod(f, spectrumTexSize.x), floor(f / spectrumTexSize.y));
    //float audioOffset = texture(u_spectrumTexture, uv).r * 0.12;
    //audioOffset *= mix(1., 0., step(0., -pi.z));
    //audioOffset = 0.;

    audioOffset = smoothstep(0.3, 1., noise((pi.xyz + u_time * 0.0005) * 3.)); 
    audioOffset *= 0.15;
    //audioOffset = 0.;

    // add some variance to the radius
    pi *= (rand(float(gl_InstanceID)) * 0.01 + 0.98 + audioOffset);

    float scale = 0.075;
    vec4 pos = vec4(a_position * scale, 1.);

    // make the beads orient to the surface of the sphere
    vec3 up = vec3(1., 0., 0.);
    vec3 axis = vec3(0., pi.z, pi.y);
    float angle = acos(dot(up, pi.xyz));
    mat3 lookAtMatrix = calcLookAtMatrix(vec3(0., 0., 0.), pi.xyz, 0.);
    pos = vec4(lookAtMatrix * pos.xyz, 1.);

    // flip the beads on the back of the sphere to create
    // a second layer behind the sphere front layer
    float flipFactor = mix(1., -0.97, step(0., -pi.z));
    pos += pi * flipFactor;

    vec4 worldPosition = u_worldMatrix * pos;
    v_position = worldPosition.xyz;
    v_lightSpacePosition = u_lightViewProjectionMatrix * worldPosition;
    v_normal = lookAtMatrix * -a_normal;
    v_instanceId = gl_InstanceID;
    gl_Position = u_projectionMatrix * u_viewMatrix * worldPosition;
}