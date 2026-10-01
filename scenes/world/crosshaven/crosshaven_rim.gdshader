shader_type canvas_item;
render_mode unshaded;

// A soft rim of the hero, drawn above a building that is fading over him.
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 0.85);
uniform float width : hint_range(0.5, 3.0) = 1.6;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float around = 0.0;
	around = max(around, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	around = max(around, texture(TEXTURE, UV + px).a);
	around = max(around, texture(TEXTURE, UV - px).a);
	float rim = clamp(around - tex.a, 0.0, 1.0);
	COLOR = vec4(rim_color.rgb, rim * rim_color.a);
}
