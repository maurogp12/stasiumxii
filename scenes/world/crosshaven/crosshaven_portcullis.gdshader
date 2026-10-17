shader_type canvas_item;

// A portcullis grate that slides up into the arch top. The sprite rect is the
// arch opening; `opening` is its shape, so the rising grate disappears into
// the masonry above it instead of drawing over the wall.
uniform sampler2D opening : filter_linear;
uniform float lift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv2 = UV + vec2(0.0, lift);
	vec4 c = uv2.y <= 1.0 ? texture(TEXTURE, uv2) : vec4(0.0);
	float m = texture(opening, UV).r;
	COLOR = vec4(c.rgb, c.a * m);
}
