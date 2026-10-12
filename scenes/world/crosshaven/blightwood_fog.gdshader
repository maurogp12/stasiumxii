shader_type canvas_item;
render_mode unshaded;

// One horizontally tiling fog band. `scroll` is in texture widths.
// Vertex colour carries the join fade.
uniform sampler2D fog_tex : repeat_enable, filter_linear;
uniform float uv_scale_x = 1.0;
uniform float scroll = 0.0;

void fragment() {
	vec2 uv = vec2(fract(UV.x * uv_scale_x + scroll), UV.y);
	vec4 tex = texture(fog_tex, uv);
	COLOR = vec4(tex.rgb, tex.a) * COLOR;
}
