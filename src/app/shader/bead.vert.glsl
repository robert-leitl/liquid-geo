#version 300 es

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform sampler2D u_spectrumTexture;
uniform vec3 u_cameraPosition;
uniform mat4 u_worldMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;
uniform mat4 u_lightViewProjectionMatrix;
uniform float u_time;

in vec3 a_position;
in vec3 a_normal;
in vec2 a_texcoord;
in vec3 a_tangent;
in mat4 a_instanceMatrix;

out vec3 v_position;
out vec4 v_lightSpacePosition;
out vec3 v_normal;
out vec3 v_tangent;
out vec2 v_texcoord;
out vec3 v_surfaceToView;
out float v_emission;
out float v_darken;
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

    
    // get an audio spectrum value from the front facing beads backwards
    float f = max(0., dot(vec3(0., 0., 1.), normalize(pi.xyz))) + .75;
    float freq = (1. - f);
    int bucketCount = spectrumTexSize.x * spectrumTexSize.y;
    int bucketNdx = int(floor(freq * float(bucketCount)));
    ivec2 bucketTex = ndx2tex(spectrumTexSize, bucketNdx);
    vec2 bucketUv = vec2(bucketTex) / vec2(spectrumTexSize);
    float audioOffset = texture(u_spectrumTexture, bucketUv).r;
    float offset = audioOffset * smoothstep(0.3, 1., noise((pi.xyz + u_time * 0.0005) * 3.)); 
    offset *= mix(1., 0., step(0., -pi.z));

    // add some variance and the offset from the audio spectrum to the radius
    float maxOffset = .3;
    pi *= (rand(float(gl_InstanceID)) * 0.01 + 0.98 + (offset * maxOffset));

    // scale the bead down to fit on the sphere
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
    v_darken = step(0., flipFactor) * 0.5 + 0.5;
    pos += pi * flipFactor;

    // the emission is defined by the beads velocity and audio offset
    v_emission = smoothstep(0.1, 1., (length(vi) * 0.2)) ;

    vec4 worldPosition = u_worldMatrix * pos;
    v_position = worldPosition.xyz;
    v_lightSpacePosition = u_lightViewProjectionMatrix * worldPosition;
    v_normal = lookAtMatrix * -a_normal;
    v_instanceId = gl_InstanceID;
    v_surfaceToView = u_cameraPosition - worldPosition.xyz;
    v_texcoord = a_texcoord;
    v_tangent = a_tangent;
    gl_Position = u_projectionMatrix * u_viewMatrix * worldPosition;
}