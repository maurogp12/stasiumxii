shader_type canvas_item;

// Local occluder fade (coordinator round 3): only the part of a wall, tower,
// gatehouse or house in front of the hero turns see-through, to about 0.5
// alpha, with no tint. Everything else of the sprite stays opaque.
// Round 22: walls and towers use a box clamped to the hero's own sprite
// (feet to head), so no hole opens below his feet or round the wall top
// and he never reads as standing on the wall.

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre_px = vec2(0.0);
uniform vec2 radius_px = vec2(64.0, 80.0);
uniform float soft : hint_range(0.01, 1.0) = 0.35;
uniform bool use_box = false;
uniform vec2 box_min_px = vec2(0.0);
uniform vec2 box_max_px = vec2(0.0);
uniform float box_soft_px = 4.0;

void fragment() {
	// COLOR already holds the texture sample times the modulate
	vec4 c = COLOR;
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float m;
	if (use_box) {
		vec2 d = max(box_min_px - px, px - box_max_px);
		float out_d = max(d.x, d.y);
		m = 1.0 - smoothstep(-box_soft_px, 0.0, out_d);
	} else {
		float r = length((px - centre_px) / radius_px);
		m = 1.0 - smoothstep(1.0 - soft, 1.0, r);
	}
	c.a *= mix(1.0, min_alpha, fade * m);
	COLOR = c;
}
