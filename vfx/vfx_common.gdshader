shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform float uv_swirl : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.102, 0.063, 0.086, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float ang = uv_swirl * centered.x * 2.4;
	float c = cos(ang);
	float s = sin(ang);
	vec2 swirled = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + vec2(0.5);
	vec4 tex = texture(TEXTURE, swirled);
	float rad = length((UV - vec2(0.5)) * vec2(1.0, 2.0));
	float edge = smoothstep(0.28, 0.48, rad);
	vec4 col = tex * tint;
	col.rgb = mix(col.rgb, outline_color.rgb, outline * edge);
	col.a *= smoothstep(dissolve, dissolve + 0.12, 1.0 - rad);
	COLOR = col;
}
