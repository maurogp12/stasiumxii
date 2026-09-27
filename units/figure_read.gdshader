shader_type canvas_item;

// One read for every facing. Neighbor RGB is never sampled, so a soft
// fringe cannot turn into a cyan halo. A 1px warm ink edge (rim_px) keeps
// the silhouette on ice. Crushed blacks on a solid texel lift toward the
// class mid-tone. rim_px 0 and mid_mix 0 leave the texel alone.
// Modulate still hides an Invisible body. No gameplay data.

uniform vec4 rim_ink : source_color = vec4(0.0);
uniform float rim_px = 0.0;
uniform vec4 mid_tone : source_color = vec4(0.0);
uniform float mid_mix = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	float alpha = tex.a;
	if (mid_mix > 0.001 && alpha > 0.9) {
		float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float crush = 1.0 - smoothstep(0.05, 0.28, luma);
		rgb = mix(rgb, mid_tone.rgb, crush * mid_mix);
	}
	if (rim_px > 0.001 && alpha < 0.2) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_px;
		float ring = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		ring = max(ring, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
		ring = max(ring, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		ring = max(ring, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		if (ring > 0.82) {
			rgb = rim_ink.rgb;
			alpha = 1.0;
		}
	}
	COLOR = vec4(rgb, alpha) * COLOR;
}
