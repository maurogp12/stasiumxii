shader_type canvas_item;
render_mode unshaded;

// Drifting ground fog. Each frame of the strip is tileable. Vertex colour
// carries the per-cell fade, so the meadow join can go clear without a wall.
uniform sampler2D drift : repeat_enable, filter_linear;
uniform float animate = 1.0;

void fragment() {
	float frame = animate > 0.5 ? floor(mod(TIME * 8.0, 12.0)) : 0.0;
	vec2 uv = vec2((frame + fract(UV.x)) / 12.0, fract(UV.y));
	vec4 tex = texture(drift, uv);
	COLOR = vec4(tex.rgb, tex.a) * COLOR;
}
