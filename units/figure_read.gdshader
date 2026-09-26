shader_type canvas_item;

// Board-scale read for heroes and Stasis foes. A dark rim holds the
// silhouette at phone size, and a warm north light matches the arena.
// The texture hue stays. No gameplay data.

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	vec3 blur = (
		texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).rgb
		+ texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb
	) * 0.25;
	vec3 sharp = tex.rgb + (tex.rgb - blur) * 0.7;
	float luma = dot(sharp, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(luma), sharp, 1.38);
	col = (col - vec3(0.5)) * 1.14 + vec3(0.5);
	float key = smoothstep(0.92, 0.12, UV.y) * smoothstep(0.95, 0.15, UV.x);
	col *= mix(vec3(0.80, 0.76, 0.70), vec3(1.14, 1.08, 0.98), key);
	float ring = 0.0;
	ring = max(ring, texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(-px.x * 2.0, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, -px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(px.x * 2.0, px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(-px.x * 2.0, px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(px.x * 2.0, -px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(-px.x * 2.0, -px.y * 2.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(px.x * 3.0, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(-px.x * 3.0, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, px.y * 3.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, -px.y * 3.0)).a);
	float rim = smoothstep(0.2, 0.75, ring) * (1.0 - tex.a);
	vec3 ink = vec3(0.07, 0.04, 0.035);
	vec3 rgb = mix(ink, clamp(col, vec3(0.0), vec3(1.12)), tex.a);
	float alpha = max(tex.a, rim * 0.94);
	COLOR = vec4(rgb, alpha) * COLOR;
}
