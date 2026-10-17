shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Foliage wind for the art kit's trees and plants. Vertex colour carries the
// wind weights: R = sway (whole branch bend, 0 at the trunk), G = phase
// (offsets the timing per branch), B = flutter (fast leaf jitter). Leaf
// cards use alpha scissor. Compatibility-safe.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool use_normal = false;
uniform float alpha_cut = 0.5;
uniform float sway_amount = 0.18;
uniform float flutter_amount = 0.04;
uniform float wind_speed = 1.0;
uniform vec2 wind_dir = vec2(1.0, 0.35);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = COLOR.r;
	float phase = COLOR.g * 6.2831;
	float flutter = COLOR.b;
	float t = TIME * wind_speed;
	float gust = 0.6 + 0.4 * sin(t * 0.37 + wp.x * 0.05 + wp.z * 0.03);
	vec2 d = normalize(wind_dir);
	float bend = sin(t * 1.3 + phase + (wp.x + wp.z) * 0.08) * sway_amount * gust * sway * VERTEX.y * 0.15;
	VERTEX.xz += d * bend;
	VERTEX += NORMAL * sin(t * 9.0 + phase * 3.0 + wp.y * 2.0) * flutter_amount * flutter;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA = c.a;
	ROUGHNESS = 0.85;
}
