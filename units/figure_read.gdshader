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
// Living idle (view only). The body stretches a little from the feet and the
// head sways, so a standing fighter breathes. The cell's foot row is 150/160.
// Done in the sample, not on the node, so positions and scales stay exact.
uniform float breath = 0.0;
uniform float breath_phase = 0.0;
uniform float sway = 0.0;

vec2 living_uv(vec2 uv) {
	float foot = 150.0 / 160.0;
	float s = breath * sin(TIME * 3.3 + breath_phase);
	uv.y = foot + (uv.y - foot) / (1.0 + s);
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 - s * 0.5);
	uv.x += sway * sin(TIME * 1.7 + breath_phase * 1.3) * clamp(foot - uv.y, 0.0, 1.0);
	return uv;
}

void fragment() {
	vec2 luv = living_uv(UV);
	vec4 tex = texture(TEXTURE, luv);
	vec3 rgb = tex.rgb;
	float alpha = tex.a;
	if (mid_mix > 0.001 && alpha > 0.9) {
		float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float crush = 1.0 - smoothstep(0.05, 0.28, luma);
		rgb = mix(rgb, mid_tone.rgb, crush * mid_mix);
	}
	if (rim_px > 0.001 && alpha < 0.2) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_px;
		float ring = texture(TEXTURE, luv + vec2(px.x, 0.0)).a;
		ring = max(ring, texture(TEXTURE, luv + vec2(-px.x, 0.0)).a);
		ring = max(ring, texture(TEXTURE, luv + vec2(0.0, px.y)).a);
		ring = max(ring, texture(TEXTURE, luv + vec2(0.0, -px.y)).a);
		if (ring > 0.82) {
			rgb = rim_ink.rgb;
			alpha = 1.0;
		}
	}
	COLOR = vec4(rgb, alpha) * COLOR;
}
