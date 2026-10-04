shader_type canvas_item;

uniform float snow_amount = 0.0;
uniform float cap = 0.62;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// The frame's empty top sits above the roof. The band reaches the slope
	// and paints it solid white, following the sprite's own alpha.
	float band = 1.0 - smoothstep(cap * 0.62, cap, UV.y);
	float mask = smoothstep(0.08, 0.40, tex.a);
	float m = clamp(band * snow_amount, 0.0, 1.0) * mask;
	COLOR = vec4(mix(tex.rgb, vec3(1.0), m), tex.a);
}
