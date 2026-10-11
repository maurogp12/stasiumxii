shader_type canvas_item;
render_mode unshaded;

// 0 is the cool storm sea. 1 is the crimson class screen. One painting.
uniform float grade : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 crimson = vec3(min(luma * 1.45, 1.0), luma * 0.38, luma * 0.32);
	COLOR = vec4(mix(tex.rgb, crimson, grade), tex.a);
}
