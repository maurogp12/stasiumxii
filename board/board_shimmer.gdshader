shader_type canvas_item;

// Slow brightness + sub-pixel UV drift for water and mud floors.
// Amplitude stays small so the diamond stays readable.

uniform float amplitude : hint_range(0.0, 0.12) = 0.045;
uniform float uv_amp : hint_range(0.0, 0.02) = 0.004;
uniform float speed : hint_range(0.2, 4.0) = 2.24;
uniform float phase = 0.0;

void fragment() {
	float t = TIME * speed + phase;
	vec2 uv = UV;
	uv.x += sin(t + UV.y * 10.0) * uv_amp;
	uv.y += cos(t * 0.8 + UV.x * 8.0) * (uv_amp * 0.65);
	vec4 tex = texture(TEXTURE, uv);
	tex.rgb *= 1.0 + sin(t) * amplitude;
	COLOR = tex * COLOR;
}
