shader_type canvas_item;

// Body recolour for the 2D puppet. R = skin, G = hair, B = eyes.
// Black leaves the texel as painted. Shading stays in the paint:
// the same luminance-times-tint maths as the closed 3D stage.
// Compatibility-safe: no screen texture, depth, or post effects.

uniform vec3 skin : source_color = vec3(0.776, 0.525, 0.259);
uniform vec3 hair : source_color = vec3(0.231, 0.141, 0.078);
uniform vec3 eyes : source_color = vec3(0.239, 0.169, 0.122);
uniform sampler2D mask_tex : filter_nearest, repeat_disable;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 mask = texture(mask_tex, UV).rgb;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = lum * 2.0 * skin;
	c.rgb = mix(c.rgb, tinted, mask.r);
	tinted = lum * 2.0 * hair;
	c.rgb = mix(c.rgb, tinted, mask.g);
	tinted = lum * 2.0 * eyes;
	c.rgb = mix(c.rgb, tinted, mask.b);
	COLOR = c;
}
