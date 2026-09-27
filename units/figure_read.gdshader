shader_type canvas_item;

// The locked sheets have no cyan. Sampling neighbors and painting a rim
// turns the soft matte into a halo. Over Windmere ice that halo reads as
// a jagged cyan fringe. This samples the texel only. Modulate still hides
// an Invisible body. No gameplay data.

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
