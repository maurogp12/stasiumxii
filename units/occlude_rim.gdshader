shader_type canvas_item;

// Outline only. The interior stays clear so the fighter in front remains
// readable, and the class-coloured edge of the one behind shows through.
uniform vec4 ink : source_color = vec4(0.45, 0.75, 0.5, 1.0);
uniform float px = 3.0;

void fragment() {
	vec2 s = TEXTURE_PIXEL_SIZE * px;
	float a = texture(TEXTURE, UV).a;
	float ring = texture(TEXTURE, UV + vec2(s.x, 0.0)).a;
	ring = max(ring, texture(TEXTURE, UV + vec2(-s.x, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, s.y)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, -s.y)).a);
	if (a < 0.2 && ring > 0.35) {
		COLOR = vec4(ink.rgb, 0.92);
	} else {
		COLOR = vec4(0.0);
	}
}
