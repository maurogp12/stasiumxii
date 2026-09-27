shader_type canvas_item;

// Board read for heroes and Stasis foes. The export fringe is a wide
// semi-transparent dark rim. Over ice that rim reads as a cyan jag, and
// the old 3px sample grew it. This floor drops the fringe. A one-texel
// ink hugs the solid silhouette. Crushed shadows lift so charcoal plate
// and iron stay shapes. The texture hue stays. No gameplay data.

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	float a = smoothstep(0.22, 0.55, tex.a);
	float cover = 0.0;
	cover = max(cover, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	cover = max(cover, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	cover = max(cover, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	cover = max(cover, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	float rim = smoothstep(0.62, 0.90, cover) * (1.0 - a);
	vec3 col = tex.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float shadow = 1.0 - smoothstep(0.08, 0.48, luma);
	vec3 lifted = col * vec3(1.28, 1.18, 1.08) + vec3(0.05, 0.035, 0.02);
	col = clamp(mix(col, lifted, shadow * 0.55), vec3(0.0), vec3(1.0));
	vec3 ink = vec3(0.06, 0.035, 0.028);
	vec3 rgb = mix(ink, col, a);
	float alpha = max(a, rim * 0.95);
	COLOR = vec4(rgb, alpha) * COLOR;
}
