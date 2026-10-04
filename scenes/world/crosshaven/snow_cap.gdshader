shader_type canvas_item;

uniform float snow_amount = 0.0;
uniform float cap = 0.36;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float band = 1.0 - smoothstep(cap * 0.45, cap, UV.y);
	float mask = smoothstep(0.18, 0.62, tex.a);
	float m = band * snow_amount * mask;
	vec3 frost = vec3(0.94, 0.97, 1.0);
	COLOR = vec4(mix(tex.rgb, frost, m), tex.a);
}
