shader_type canvas_item;
render_mode unshaded;

uniform float vignette = 0.28;
uniform float haze = 0.14;
uniform vec3 haze_col : source_color = vec3(0.96, 0.90, 0.78);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float vig = smoothstep(0.28, 1.15, dot(p, p)) * vignette;
	COLOR = vec4(haze_col, clamp(haze * 0.4 + vig, 0.0, 0.7));
}
