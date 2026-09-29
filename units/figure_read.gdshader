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
// Board lighting (view only): gamma lift of the dark painted tones, a touch
// more colour, and a soft key-light rim on the upper-left edge so a figure
// pops off the floor at board scale. 0 leaves the texel alone.
uniform float lift = 0.0;
uniform float sat = 1.0;
uniform float edge_light = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform float breath = 0.0;
uniform float breath_phase = 0.0;
uniform float sway = 0.0;

// Godot 4: the fragment COLOR input is already texture x vertex colour.
// Multiplying the texel by it again squared every colour (the painted sheets
// went near-black on the board). Carry the vertex colour (modulate) instead.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

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
	if (alpha > 0.5) {
		if (lift > 0.001) {
			rgb = pow(max(rgb, vec3(0.0)), vec3(1.0 / (1.0 + lift)));
		}
		if (abs(sat - 1.0) > 0.001) {
			float l2 = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
			rgb = clamp(mix(vec3(l2), rgb, sat), 0.0, 1.0);
		}
		if (edge_light > 0.001) {
			vec2 k = TEXTURE_PIXEL_SIZE * 2.5;
			float lit = 1.0 - texture(TEXTURE, luv + vec2(-k.x, -k.y)).a;
			lit = max(lit, 0.6 * (1.0 - texture(TEXTURE, luv + vec2(0.0, -k.y * 1.4)).a));
			rgb = mix(rgb, edge_color.rgb, clamp(lit, 0.0, 1.0) * edge_light);
		}
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
	COLOR = vec4(rgb, alpha) * v_modulate;
}
