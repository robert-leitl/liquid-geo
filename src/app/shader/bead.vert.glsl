#version 300 es

uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform mat4 u_worldMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;
uniform float u_time;

in vec3 a_position;
in vec3 a_normal;
in mat4 a_instanceMatrix;

out vec3 v_position;
out vec3 v_normal;

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
    ivec2 pi_tex = ndx2tex(poisitionTexDimensions, gl_InstanceID);
    vec4 pi = texelFetch(u_positionTexture, pi_tex, 0);
    vec4 vi = texelFetch(u_velocityTexture, pi_tex, 0);

    float scale = 0.085;
    vec4 pos = vec4(a_position * scale, 1.);

    vec3 up = vec3(1., 0., 0.);
    vec3 axis = vec3(0., pi.z, pi.y);
    float angle = acos(dot(up, pi.xyz));
    mat3 lookAtMatrix = calcLookAtMatrix(vec3(0., 0., 0.), pi.xyz, 0.);
    pos = vec4(lookAtMatrix * pos.xyz, 1.);

    float flipFactor = mix(1., -0.96, step(0., -pi.z));
    pos += pi * (rand(float(gl_InstanceID)) * 0.01 + 0.98) * flipFactor;

    vec4 worldPosition = u_worldMatrix * pos;

    v_position = worldPosition.xyz;
    v_normal = lookAtMatrix * -a_normal;
    gl_Position = u_projectionMatrix * u_viewMatrix * worldPosition;
}