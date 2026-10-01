shader_type canvas_item;
render_mode unshaded;

// One screen sample for the grade. Bloom is the same sample's highlight excess,
// so midtones are not lifted and the HUD (a later canvas layer) is untouched.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float warmth : hint_range(0.0, 1.0) = 1.0;
uniform float bloom_threshold : hint_range(0.5, 1.0) = 0.86;
uniform float bloom_strength : hint_range(0.0, 1.5) = 0.40;
uniform float contrast : hint_range(1.0, 1.2) = 1.04;
uniform float saturation : hint_range(1.0, 1.2) = 1.06;
uniform float haze_max : hint_range(0.0, 0.2) = 0.15;
uniform vec3 warm_mul : source_color = vec3(1.02, 1.0, 0.96);
uniform vec3 haze_col : source_color = vec3(0.45, 0.52, 0.62);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	// v7 paint already has the warm key and cool shade, so this multiply stays slight.
	// Rain drives warmth to 0 and skips it.
	c *= mix(vec3(1.0), warm_mul, warmth);
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	// The paint is already saturated. +6% in clear and in rain, so rain does not go gray.
	float sat = mix(1.06, saturation, warmth);
	c = mix(vec3(luma), c, sat);
	c = (c - vec3(0.5)) * contrast + vec3(0.5);
	// Window glow, lamp heads, fire, and water sparkles. Excess above the threshold, not the midtones.
	vec3 hi = max(c - vec3(bloom_threshold), vec3(0.0));
	c += hi * bloom_strength;
	// Edge and far haze. The center (the hero, under the camera) stays clear.
	vec2 p = uv * 2.0 - 1.0;
	float radial = length(p);
	float edge = smoothstep(0.62, 1.25, radial);
	float far = smoothstep(0.55, 0.02, uv.y) * smoothstep(0.25, 0.7, radial);
	float hero = smoothstep(0.48, 0.18, radial);
	float haze_a = min(haze_max, haze_max * max(edge, far * 0.65));
	haze_a *= (1.0 - hero);
	c = mix(c, haze_col, haze_a);
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
