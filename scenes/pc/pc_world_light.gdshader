shader_type canvas_item;

// 4.5a NPC world light, the Crosshaven grade on the character.
// The paint already carries the key. This is the engine grade the world
// puts on NPCs: a slight warm multiply, +6% saturation, contrast 1.04.
// The hero stays clear of the world's edge haze. Straight alpha is kept.
uniform float warmth = 1.0;
uniform vec3 warm_mul : source_color = vec3(1.02, 1.0, 0.96);
uniform float saturation = 1.06;
uniform float contrast = 1.04;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb *= mix(vec3(1.0), warm_mul, warmth);
	float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = mix(vec3(luma), c.rgb, saturation);
	c.rgb = (c.rgb - vec3(0.5)) * contrast + vec3(0.5);
	COLOR = vec4(clamp(c.rgb, vec3(0.0), vec3(1.0)), c.a);
}
