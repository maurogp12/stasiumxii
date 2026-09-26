shader_type canvas_item;

// Board-scale read for heroes and Stasis foes. A dark rim keeps the
// silhouette, and a soft north light matches the arena. The texture hue stays.
// No gameplay data.

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
	float s = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float e = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float w = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
	float neighbor = max(max(n, s), max(e, w));
	float rim = clamp(neighbor - tex.a, 0.0, 1.0) * 0.9;
	vec3 ink = vec3(0.10, 0.06, 0.05);
	float north = smoothstep(0.72, 0.18, UV.y);
	vec3 lit = tex.rgb * mix(vec3(0.92, 0.90, 0.86), vec3(1.06, 1.03, 0.96), north);
	vec3 col = mix(ink, lit, tex.a);
	float alpha = max(tex.a, rim);
	COLOR = vec4(col, alpha) * COLOR;
}
