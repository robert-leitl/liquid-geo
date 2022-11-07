#version 300 es

uniform mat4 u_worldMatrix;
uniform mat4 u_viewMatrix;
uniform mat4 u_projectionMatrix;

in vec3 a_position;
in vec3 a_normal;

out vec3 v_position;
out vec3 v_normal;

void main() {
    vec4 worldPosition = u_worldMatrix * vec4(a_position, 1.);

    v_position = worldPosition.xyz;
    v_normal = a_normal;
    gl_Position = u_projectionMatrix * u_viewMatrix * worldPosition;
}