shader_type canvas_item;

// View grade for the Locked Koliseo diamonds. Lifts contrast on the painted
// sheet and lays a north light on it. The high-frequency sheen is gone so
// water and dusk stone stay painted, not glass. The texture keeps its hue.
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
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sat = mix(vec3(luma), tex.rgb, sat_boost);
	sat = (sat - vec3(0.5)) * contrast + vec3(0.5);
	sat *= grade * lift;
	float south = smoothstep(0.28, 1.0, UV.y);
	sat *= mix(1.05, 0.88, south);
	// Slow painted variation. shimmer_color is kept so a caller can still
	// tint, but it only kisses the darkest grain instead of a glass spike.
	float grain = sin((UV.x * 2.4 + UV.y * 1.6) + TIME * shimmer_speed * 0.28 + phase);
	float kiss = smoothstep(0.55, 1.0, grain) * shimmer * tex.a * 0.06;
	sat = mix(sat, shimmer_color, kiss);
	float breathe = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	sat *= mix(1.0 - pulse_amp, 1.0 + pulse_amp, breathe);
	COLOR = vec4(clamp(sat, vec3(0.0), vec3(1.05)), tex.a);
}
