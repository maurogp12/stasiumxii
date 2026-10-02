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
// Shared phone silhouette. One warm texel outside the paint so a light
// body reads on snow and a dark body reads on a night board. Class rim_px
// still owns the ochre / stone edge and overwrites this where it draws.
// 0 leaves that fringe alone. Not a team tint and not a cyan halo.
uniform float board_ink = 0.0;
uniform vec4 board_ink_color : source_color = vec4(0.16, 0.07, 0.04, 1.0);
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
uniform float breath_rate = 3.3;
// Stasis foe body (view only, Mauro 29 Sep 2026: "the boss looks not even like
// a monster"). lean shears the body from the feet (+ leans to screen right),
// squash presses it into the ground, mirror turns a one-sided painting to
// face its target. Heroes keep 0 (their facings are baked sheets).
uniform float lean = 0.0;
uniform float squash = 0.0;
uniform float mirror = 0.0;

// Godot 4: the fragment COLOR input is already texture x vertex colour.
// Multiplying the texel by it again squared every colour (the painted sheets
// went near-black on the board). Carry the vertex colour (modulate) instead.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

vec2 living_uv(vec2 uv) {
	float foot = 150.0 / 160.0;
	if (mirror > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	float s = breath * sin(TIME * breath_rate + breath_phase) - squash;
	uv.y = foot + (uv.y - foot) / (1.0 + s);
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 - s * 0.5);
	float h = clamp(foot - uv.y, 0.0, 1.0);
	uv.x += sway * sin(TIME * 1.7 + breath_phase * 1.3) * h;
	uv.x -= (mirror > 0.5 ? -lean : lean) * h;
	return uv;
}

void fragment() {
	vec2 luv = living_uv(UV);
	vec4 tex = texture(TEXTURE, luv);
	if (luv.x < 0.0 || luv.x > 1.0 || luv.y < 0.0 || luv.y > 1.0) {
		tex = vec4(0.0);
	}
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
	if (board_ink > 0.001 && alpha < 0.2) {
		vec2 ink_px = TEXTURE_PIXEL_SIZE * board_ink;
		float ink_ring = texture(TEXTURE, luv + vec2(ink_px.x, 0.0)).a;
		ink_ring = max(ink_ring, texture(TEXTURE, luv + vec2(-ink_px.x, 0.0)).a);
		ink_ring = max(ink_ring, texture(TEXTURE, luv + vec2(0.0, ink_px.y)).a);
		ink_ring = max(ink_ring, texture(TEXTURE, luv + vec2(0.0, -ink_px.y)).a);
		if (ink_ring > 0.82) {
			rgb = board_ink_color.rgb;
			alpha = 1.0;
		}
	}
	COLOR = vec4(rgb, alpha) * v_modulate;
}
