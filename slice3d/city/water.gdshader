shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

// River and moat water: gentle waves, fresnel sky tint, foam flecks.
// No depth texture (Compatibility-safe).

uniform vec3 shallow : source_color = vec3(0.16, 0.24, 0.22);
uniform vec3 deep : source_color = vec3(0.05, 0.10, 0.11);
uniform vec3 sky : source_color = vec3(0.55, 0.62, 0.68);
uniform float flow_speed = 0.35;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.6 + TIME * 1.3) * 0.03 + cos(wpos.z * 0.5 + TIME) * 0.03;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME * flow_speed;
	float h1 = noise(p * 0.9 + vec2(t, t * 0.6));
	float h2 = noise(p * 2.3 - vec2(t * 1.3, t * 0.4));
	vec3 nrm = normalize(vec3((h1 - 0.5) * 0.5 + (h2 - 0.5) * 0.3, 1.0, (h2 - 0.5) * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, shallow, 0.4 + 0.4 * h1);
	col = mix(col, sky, fres * 0.6);
	float foam = smoothstep(0.82, 0.95, h2 * h1 * 1.6);
	col += foam * 0.15;
	ALBEDO = col;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	ALPHA = 0.86;
}
