shader_type canvas_item;

// Local occluder fade (coordinator round 3): only the part of a wall, tower,
// gatehouse or house in front of the hero turns see-through, to about 0.5
// alpha, with no tint. Everything else of the sprite stays opaque.

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre_px = vec2(0.0);
uniform vec2 radius_px = vec2(64.0, 80.0);
uniform float soft : hint_range(0.01, 1.0) = 0.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float r = length((px - centre_px) / radius_px);
	float m = 1.0 - smoothstep(1.0 - soft, 1.0, r);
	c.a *= mix(1.0, min_alpha, fade * m);
	COLOR = c;
}
