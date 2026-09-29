shader_type canvas_item;

// Painted day sky behind a Koliseo arena (Dofus-style floating island read).
// Vertical gradient, a warm sun bloom, and two layers of soft drifting cloud.
// View only. No gameplay data.

uniform vec4 sky_top : source_color = vec4(0.50, 0.76, 0.93, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.93, 0.95, 0.86, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.80, 1.0);
uniform float cloud_amount = 0.55;
uniform float drift = 0.012;
uniform vec2 sun_pos = vec2(0.78, 0.18);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(sky_top.rgb, sky_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	float sun = exp(-distance(uv * vec2(1.6, 1.0), sun_pos * vec2(1.6, 1.0)) * 5.5);
	col += sun_color.rgb * sun * 0.35;
	// Two cloud decks: a slow high veil and a puffier low bank.
	vec2 p = uv * vec2(3.2, 5.0);
	float high = fbm(p + vec2(TIME * drift, 0.0));
	float low = fbm(p * 1.6 + vec2(TIME * drift * 1.8, 3.0));
	float bank = smoothstep(0.35, 1.0, uv.y);
	float c = smoothstep(0.55, 0.85, high) * 0.45 + smoothstep(0.5, 0.78, low) * bank;
	c *= cloud_amount;
	// Cloud bellies take a touch of the lower sky so they sit in the light.
	vec3 cloud = mix(cloud_color.rgb, sky_bottom.rgb, 0.25);
	col = mix(col, cloud, clamp(c, 0.0, 0.9));
	COLOR = vec4(col, 1.0);
}
