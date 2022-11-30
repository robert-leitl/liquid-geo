#version 300 es

precision highp float;

uniform sampler2D u_colorTexture;
uniform sampler2D u_bloomTexture;

out vec4 outColor;

in vec2 v_uv;

float blendScreen(float base, float blend) {
	return 1.0-((1.0-base)*(1.0-blend));
}

vec3 blendScreen(vec3 base, vec3 blend) {
	return vec3(blendScreen(base.r,blend.r),blendScreen(base.g,blend.g),blendScreen(base.b,blend.b));
}

vec3 blendScreen(vec3 base, vec3 blend, float opacity) {
	return (blendScreen(base, blend) * opacity + base * (1.0 - opacity));
}

void main() {
    vec4 color = texture(u_colorTexture, v_uv);
    vec4 bloom = texture(u_bloomTexture, v_uv);

    vec3 comp = blendScreen(color.rgb, bloom.rgb, 0.4);

    outColor = vec4(comp, 0.);
}