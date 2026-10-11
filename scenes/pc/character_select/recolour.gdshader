shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

// Body recolour for the character-select stage (§11 overrides §5.4).
// R = skin, G = hair, B = eyes. Black leaves the texel as painted
// (tunic, trousers, boots, weapon, gear). Shading stays in the albedo:
// the same luminance is tinted per channel, in R, G, B order.
// Compatibility-safe: no screen texture, depth, or post effects.

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform vec3 skin : source_color = vec3(0.76, 0.58, 0.46);
uniform vec3 hair : source_color = vec3(0.25, 0.14, 0.08);
uniform vec3 eyes : source_color = vec3(0.22, 0.40, 0.62);

// Face-type hook for a later texture atlas. The stage also swaps face
// meshes. This uniform does not shift colour (the added term is zero).
uniform float face_index : hint_range(0.0, 4.0) = 0.0;

// Premium dye hook. Creation leaves dye_enabled at 0, so armour stays
// painted. A later package sets dye_mask (R = cloth to tint), dye_tint,
// and dye_enabled. This package does not sell or apply dye.
uniform sampler2D dye_mask : filter_nearest, repeat_disable, hint_default_black;
uniform vec3 dye_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float dye_enabled = 0.0;

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	vec3 mask = texture(mask_tex, UV).rgb;
	float lum = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = lum * 2.0 * skin;
	albedo.rgb = mix(albedo.rgb, tinted, mask.r);
	tinted = lum * 2.0 * hair;
	albedo.rgb = mix(albedo.rgb, tinted, mask.g);
	tinted = lum * 2.0 * eyes;
	albedo.rgb = mix(albedo.rgb, tinted, mask.b);
	float dye = texture(dye_mask, UV).r * dye_enabled;
	tinted = lum * 2.0 * dye_tint;
	albedo.rgb = mix(albedo.rgb, tinted, dye);
	// face_index stays linked for an atlas. It does not change the colour.
	float face_hook = face_index;
	ALBEDO = albedo.rgb + vec3(face_hook * 0.0);
	ALPHA = albedo.a;
	ROUGHNESS = 0.84;
	METALLIC = 0.0;
}
