shader_type canvas_item;

// Animated river for the plate city (Rosebud water package, Mauro item 9).
// Drawn on a sprite of water_base.png that covers the plate: TEXTURE is the
// painted base (alpha = river). Two ripple layers scroll along the flow (the
// second flipped, slower, offset); their alpha is scaled by depth; foam is a
// value noise times the foam zone.

uniform sampler2D ripple : repeat_enable, filter_linear;
uniform sampler2D fx_tex : filter_linear;
uniform vec2 plate_size = vec2(5120.0, 2880.0);
uniform vec2 flow_dir = vec2(-0.86, 0.51);
uniform float speed = 24.0;
uniform float tile_px = 256.0;
uniform vec2 offset2 = vec2(97.0, 41.0);
uniform float speed2 = 0.7;
uniform float alpha2 = 0.55;
uniform bool flip2 = true;
uniform float depth_base = 0.45;
uniform float depth_gain = 0.55;
uniform float time_scale = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) {
		discard;
	}
	vec4 fx = texture(fx_tex, UV);
	float t = TIME * time_scale;
	vec2 p = UV * plate_size;
	vec2 dir = normalize(flow_dir);
	vec2 u1 = (p - dir * speed * t) / tile_px;
	vec2 u2 = (p + offset2 - dir * speed * speed2 * t) / tile_px;
	if (flip2) {
		u2.x = -u2.x;
	}
	vec4 r1 = texture(ripple, u1);
	vec4 r2 = texture(ripple, u2);
	float depth_k = depth_base + depth_gain * fx.r;
	vec3 col = base.rgb;
	col = mix(col, r1.rgb, clamp(r1.a * depth_k, 0.0, 1.0));
	col = mix(col, r2.rgb, clamp(r2.a * alpha2 * depth_k, 0.0, 1.0));
	// Glints where both layers are thin: the lit crests of the painted ripples.
	float crest = (1.0 - r1.a) * (1.0 - r2.a);
	col += vec3(0.10, 0.16, 0.16) * smoothstep(0.55, 0.95, crest) * depth_k;
	float n = vnoise(p * 0.045 + dir * t * 0.9) * 0.6 + vnoise(p * 0.11 - dir.yx * t * 1.3) * 0.4;
	float foam = fx.g * smoothstep(0.42, 0.75, n);
	col = mix(col, vec3(0.92, 0.97, 0.96), clamp(foam * 0.9, 0.0, 1.0));
	COLOR = vec4(col, base.a);
}
