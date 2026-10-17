shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Placeholder ground: vertex colour carries the layout's terrain colour
// (blended across cell corners); alpha carries how stony it is (cobble,
// plaza). World-space noise breaks the tiling; stony ground gets a
// procedural setts pattern. Works in the Compatibility renderer.

uniform float sett_size = 0.55;
uniform float wetness = 0.0;
uniform float snow = 0.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = fbm(p * 0.18);
	float n2 = fbm(p * 1.7);
	vec3 base = COLOR.rgb;
	float stone = COLOR.a;
	// soft large-scale variation (patches of dry and lush ground)
	vec3 col = base * (0.82 + 0.36 * n1) * (0.9 + 0.2 * n2);
	// setts: staggered rows of rounded stones with dark joints
	vec2 q = p / sett_size;
	q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float joint = smoothstep(0.36, 0.5, max(abs(f.x) * 0.92, abs(f.y)));
	float tint = 0.85 + 0.3 * hash(cell);
	vec3 setts = base * tint * (1.0 - 0.55 * joint);
	col = mix(col, setts * (0.9 + 0.2 * n1), stone);
	// grass blades read as fine speckle
	col *= 1.0 - (1.0 - stone) * 0.12 * step(0.62, hash(floor(p * 9.0)));
	col = mix(col, vec3(0.86, 0.88, 0.92), snow * smoothstep(0.35, 0.6, n1 + 0.2));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, stone) - wetness * 0.45;
	SPECULAR = 0.25 + wetness * 0.3;
}
