shader_type canvas_item;

// View grade for the Locked Koliseo diamonds. Contrast, a north-lit falloff,
// and a slow sheen. No gameplay data.

uniform float contrast = 1.16;
uniform float sat_boost = 1.2;
uniform float lift = 1.0;
uniform vec3 grade = vec3(1.0);
uniform float shimmer = 0.0;
uniform vec3 shimmer_color = vec3(1.0, 0.96, 0.82);
uniform float shimmer_speed = 1.2;
uniform float phase = 0.0;
uniform float pulse_amp = 0.03;
uniform float pulse_speed = 1.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sat = mix(vec3(luma), tex.rgb, sat_boost);
	sat = (sat - vec3(0.5)) * contrast + vec3(0.5);
	sat *= grade * lift;
	float south = smoothstep(0.32, 1.0, UV.y);
	sat *= mix(1.05, 0.88, south);
	float wave = sin((UV.x * 2.1 + UV.y) * 13.0 + TIME * shimmer_speed + phase);
	float sheen = smoothstep(0.58, 1.0, wave) * shimmer * tex.a;
	sat = mix(sat, shimmer_color, sheen * 0.62);
	float breathe = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	sat *= mix(1.0 - pulse_amp, 1.0 + pulse_amp, breathe);
	COLOR = vec4(clamp(sat, vec3(0.0), vec3(1.45)), tex.a);
}
