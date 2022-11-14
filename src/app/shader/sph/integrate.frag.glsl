
#version 300 es

precision highp float;

uniform sampler2D u_forceTexture;
uniform sampler2D u_positionTexture;
uniform sampler2D u_velocityTexture;
uniform sampler2D u_densityPressureTexture;
uniform float u_dt;
uniform float u_time;
uniform vec4 u_domainScale;

layout(std140) uniform u_PointerParams {
    vec3 pointerPos;
    vec3 pointerVelocity;
    float pointerRadius;
    float pointerStrength;
};

in vec2 v_uv;

layout(location = 0) out vec4 outPosition;
layout(location = 1) out vec4 outVelocity;

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

vec3 snoiseVec3( vec3 x ){
  float s  = noise(vec3( x ));
  float s1 = noise(vec3( x.y - 19.1 , x.z + 33.4 , x.x + 47.2 ));
  float s2 = noise(vec3( x.z + 74.2 , x.x - 124.5 , x.y + 99.4 ));
  vec3 c = vec3( s , s1 , s2 );
  return c;
}

vec3 curlNoise( vec3 p ){
  const float e = .1;
  vec3 dx = vec3( e   , 0.0 , 0.0 );
  vec3 dy = vec3( 0.0 , e   , 0.0 );
  vec3 dz = vec3( 0.0 , 0.0 , e   );

  vec3 p_x0 = snoiseVec3( p - dx );
  vec3 p_x1 = snoiseVec3( p + dx );
  vec3 p_y0 = snoiseVec3( p - dy );
  vec3 p_y1 = snoiseVec3( p + dy );
  vec3 p_z0 = snoiseVec3( p - dz );
  vec3 p_z1 = snoiseVec3( p + dz );

  float x = p_y1.z - p_y0.z - p_z1.y + p_z0.y;
  float y = p_z1.x - p_z0.x - p_x1.z + p_x0.z;
  float z = p_x1.y - p_x0.y - p_y1.x + p_y0.x;

  const float divisor = 1.0 / ( 2.0 * e );
  return normalize( vec3( x , y , z ) * divisor );
}

void main() {
    ivec2 particleTexDimensions = textureSize(u_positionTexture, 0);
    vec4 domainScale = u_domainScale;

    vec4 pi = texture(u_positionTexture, v_uv);
    vec4 vi = texture(u_velocityTexture, v_uv);
    vec4 fi = texture(u_forceTexture, v_uv);
    vec4 ri = texture(u_densityPressureTexture, v_uv);

    // integrate to update the velocity
    float dt = (u_dt * 0.001);
    float rho = ri.x + 0.000000001;
    vec4 ai = fi / rho;
    vi += ai * dt;

    // apply the pointer force
    vec4 pointerPos = vec4(pointerPos, 0.);
    float prFront = length(pointerPos * domainScale - pi * domainScale);
    float prBack = length(pointerPos * domainScale + pi * domainScale);
    if (prFront < pointerRadius) {
        vi += vec4(pointerVelocity, 0.) * pointerStrength * (1. - prFront / pointerRadius);
    } else if (prBack < pointerRadius) {
        vi -= vec4(pointerVelocity, 0.) * pointerStrength * 0.8 * (1. - prBack / pointerRadius);
    }

    // update the position
    pi += (vi + 0.5 * ai * dt) * dt;
    pi = normalize(pi);

    // damp the velocity a bit
    vi *= 0.99;

    // add noise
    vec3 n = curlNoise(pi.xyz * 2.5 + sin(u_time * 0.0001) * 2.) * 2. - 1.;
    vi.xyz += n * 0.008;
    
    outPosition = pi;
    outVelocity = vi;
}