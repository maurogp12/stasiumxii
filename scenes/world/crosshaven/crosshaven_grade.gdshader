shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.58;
uniform float bloom_softness : hint_range(0.01, 1.0) = 0.28;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.42;
uniform float warmth : hint_range(0.0, 0.5) = 0.14;
uniform float vignette : hint_range(0.0, 1.0) = 0.32;
uniform float haze : hint_range(0.0, 0.5) = 0.12;
uniform vec3 warm_col : source_color = vec3(1.0, 0.92, 0.78);
uniform vec3 haze_col : source_color = vec3(0.70, 0.80, 0.90);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * 2.4;
	vec3 c = texture(screen_tex, uv).rgb;
	vec3 blur = c * 0.36;
	blur += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb * 0.16;
	blur += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb * 0.16;
	blur += texture(screen_tex, uv + vec2(0.0, px.y)).rgb * 0.16;
	blur += texture(screen_tex, uv - vec2(0.0, px.y)).rgb * 0.16;
	float luma = dot(blur, vec3(0.2126, 0.7152, 0.0722));
	float mask = smoothstep(bloom_threshold, bloom_threshold + bloom_softness, luma);
	vec3 graded = mix(c, warm_col, warmth);
	graded += blur * mask * bloom_strength;
	float far = smoothstep(0.62, 0.0, uv.y);
	graded = mix(graded, haze_col, haze * far);
	vec2 p = uv * 2.0 - 1.0;
	float vig = smoothstep(0.28, 1.15, dot(p, p)) * vignette;
	graded = mix(graded, graded * vec3(0.52, 0.46, 0.40), vig);
	COLOR = vec4(graded, 1.0);
}
