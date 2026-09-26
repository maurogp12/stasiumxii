shader_type canvas_item;

// View grade for the Locked Koliseo diamonds. Sharpens the existing paint,
// lifts a north facet and a warm edge, and keeps the sheet's hue.
// Water and lava breathe in brightness. A glass color wash is not applied.
// No gameplay data.

uniform float contrast = 1.12;
uniform float sat_boost = 1.15;
uniform float lift = 1.0;
uniform vec3 grade = vec3(1.0);
uniform float shimmer = 0.0;
uniform vec3 shimmer_color = vec3(1.0, 0.96, 0.86);
uniform float shimmer_speed = 1.2;
uniform float phase = 0.0;
uniform float pulse_amp = 0.02;
uniform float pulse_speed = 1.1;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	vec3 blur = (
		texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).rgb
		+ texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb
	) * 0.25;
	vec3 sharp = tex.rgb + (tex.rgb - blur) * 0.9;
	sharp *= COLOR.rgb;
	float luma = dot(sharp, vec3(0.299, 0.587, 0.114));
	vec3 sat = mix(vec3(luma), sharp, sat_boost);
	sat = (sat - vec3(0.5)) * contrast + vec3(0.5);
	sat *= grade * lift;
	// North facet catches the sun. South facet sits in warm shade.
	// This is a light, not a recolor.
	float face = smoothstep(0.82, 0.08, UV.y);
	sat *= mix(0.74, 1.16, face);
	float diamond = abs(UV.x - 0.5) * 2.0 + abs(UV.y - 0.5) * 2.0;
	float lip = smoothstep(0.72, 0.96, diamond) * smoothstep(0.58, 0.22, UV.y);
	sat += vec3(0.09, 0.07, 0.035) * lip * tex.a;
	sat += shimmer_color * 0.0;
	// Life on water and lava stays a brightness breath. shimmer_color is unused
	// so a caller cannot stain the sheet.
	float wave = sin((UV.x * 2.1 + UV.y) * 7.0 + TIME * shimmer_speed + phase);
	float sheen = smoothstep(0.82, 1.0, wave) * shimmer * tex.a;
	sat *= 1.0 + sheen * 0.1;
	float breathe = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	sat *= mix(1.0 - pulse_amp, 1.0 + pulse_amp, breathe);
	COLOR = vec4(clamp(sat, vec3(0.0), vec3(1.15)), tex.a * COLOR.a);
}
