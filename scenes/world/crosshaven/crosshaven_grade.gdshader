shader_type canvas_item;
render_mode unshaded;

// One screen sample for the grade. Bloom is the same sample's highlight excess,
// so midtones are not lifted and the HUD (a later canvas layer) is untouched.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float warmth : hint_range(0.0, 1.0) = 1.0;
uniform float bloom_threshold : hint_range(0.5, 1.0) = 0.86;
uniform float bloom_strength : hint_range(0.0, 1.5) = 0.40;
uniform float contrast : hint_range(1.0, 1.2) = 1.04;
uniform float saturation : hint_range(0.4, 1.3) = 1.06;
uniform float haze_max : hint_range(0.0, 0.55) = 0.15;
// 0 keeps Crosshaven: rain still drops the golden multiply. 1 keeps a region
// grade on in any weather, so a thumbnail still shows that region's colour.
uniform float grade_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 warm_mul : source_color = vec3(1.02, 1.0, 0.96);
uniform vec3 haze_col : source_color = vec3(0.45, 0.52, 0.62);
// Luminance tint. 0 leaves Crosshaven alone. A region mixes toward luma * tint_col
// so the colour reads in a thumbnail, not only as a slight multiply.
uniform vec3 tint_col : source_color = vec3(1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 0.55) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	// v7 paint already has the warm key and cool shade, so this multiply stays slight.
	// Rain drives warmth to 0 and skips the Crosshaven gold. A region sets
	// grade_mix to 1 so its own multiply stays on in that rain.
	float grade_amt = max(warmth, grade_mix);
	c *= mix(vec3(1.0), warm_mul, grade_amt);
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	// The paint is already saturated. +6% in clear and in Crosshaven rain, so
	// that rain does not go gray. A region grade can still desaturate.
	float sat = mix(1.06, saturation, grade_amt);
	c = mix(vec3(luma), c, sat);
	// Recolour the luminance. A green plain stays green under a multiply;
	// mixing toward luma * tint_col shifts the mean hue at thumbnail size.
	luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(c, luma * tint_col, tint_amount * grade_amt);
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
	float edge_haze = haze_max * max(edge, far * 0.65) * (1.0 - hero);
	// Crosshaven's 0.15 stays an edge haze. Above that, the middle veils too,
	// so a murky region reads in a thumbnail and not only at the rim.
	float veil = max(haze_max - 0.2, 0.0) * (1.0 - hero * 0.35);
	float haze_a = min(0.55, max(veil, edge_haze));
	c = mix(c, haze_col, haze_a);
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
