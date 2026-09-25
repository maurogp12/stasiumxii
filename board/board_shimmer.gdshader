shader_type canvas_item;

// Slow mid-value drift for water and mud. The crest is the painted texel.
// Nothing is added on top, so the floor cannot throw a hit-flash highlight.

uniform float amplitude : hint_range(0.0, 0.08) = 0.03;
uniform float uv_amp : hint_range(0.0, 0.02) = 0.0015;
uniform float speed : hint_range(0.2, 4.0) = 1.5;
uniform float phase = 0.0;

void fragment() {
	float t = TIME * speed + phase;
	vec2 uv = UV + vec2(sin(t), cos(t * 0.85)) * uv_amp;
	vec4 tex = texture(TEXTURE, uv);
	float wave = sin(t);
	float k = 1.0 - amplitude * (0.5 - 0.5 * wave);
	tex.rgb *= k;
	COLOR = tex * COLOR;
}
