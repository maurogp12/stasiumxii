shader_type canvas_item;

// Living surfaces for the look-picture arenas (view only, no gameplay data).
// Noise is sampled in board space, not per tile, so neighbouring cells of one
// surface flow into each other: lava reads as rivers, runes as one grid.
//   mode 1  molten lava: domain-warped flow, crust veins, heat pulse
//   mode 2  basalt: the stamp plus sparse glowing cracks
//   mode 3  energy runes: dark cell with crackling violet/blue veins
//   mode 4  slate: the stamp lifted, with a faint cold sheen
//   mode 5  water: the stamp with drifting caustic light and a soft swell
//   mode 6  boiling water: churning swell and bubbles that rise, swell and pop

uniform int mode = 0;
uniform float gain = 1.0;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.02 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

// Board space: one unit per cell, un-squashed from the 2:1 iso diamond.
vec2 board_uv(vec2 w) {
	return vec2(w.x / 64.0 + w.y / 32.0, w.y / 32.0 - w.x / 64.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb * gain;
	vec2 p = board_uv(world);
	float t = TIME;
	vec3 col = base;
	if (mode == 1) {
		// Broad features (a few cells wide) so a lava channel reads as one river.
		vec2 lp = p * 0.45;
		vec2 q = vec2(fbm(lp + vec2(t * 0.05, 0.0)), fbm(lp + vec2(4.2, 1.3) - vec2(0.0, t * 0.04)));
		float n = fbm(lp * 1.2 + 2.2 * q + vec2(t * 0.07, -t * 0.03));
		vec3 crust = vec3(0.16, 0.03, 0.01);
		vec3 hot = vec3(1.0, 0.33, 0.04);
		vec3 white_hot = vec3(1.0, 0.86, 0.38);
		col = mix(crust, hot, smoothstep(0.30, 0.58, n));
		col = mix(col, white_hot, smoothstep(0.62, 0.82, n));
		// Dark cooling veins drift over the flow.
		float vein = 1.0 - abs(fbm(p * 2.6 - q * 1.5 + vec2(0.0, t * 0.06)) * 2.0 - 1.0);
		col *= 1.0 - smoothstep(0.90, 0.99, vein) * 0.55;
		col *= 0.92 + 0.12 * sin(t * 1.7 + n * 6.0);
		// Keep a little of the painted molten texture.
		col = mix(col, base * vec3(1.1, 0.95, 0.8), 0.12);
		col *= 1.12;
	} else if (mode == 2) {
		// Charcoal basalt: pull the painted rock toward a cool dark grey so it
		// never competes with the lava, then open sparse glowing cracks.
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(lum) * vec3(1.0, 0.92, 0.88), 0.55) * 0.95;
		float mask = smoothstep(0.58, 0.68, fbm(p * 0.55 + vec2(7.0)));
		float ridge = 1.0 - abs(fbm(p * 2.1) * 2.0 - 1.0);
		float crack = smoothstep(0.955, 0.995, ridge) * mask;
		float heat = 0.75 + 0.25 * sin(t * 2.2 + p.x * 1.3 + p.y);
		col = base + vec3(1.0, 0.36, 0.06) * crack * heat * 1.3;
		col += vec3(0.30, 0.07, 0.01) * smoothstep(0.85, 0.99, ridge) * mask * 0.35;
	} else if (mode == 3) {
		vec3 deep = vec3(0.05, 0.03, 0.12);
		col = mix(deep, base, 0.55);
		float flow = fbm(p * 3.2 + vec2(t * 0.35, -t * 0.22));
		float vein = 1.0 - abs(flow * 2.0 - 1.0);
		float arc = smoothstep(0.90, 0.985, vein);
		float flicker = 0.65 + 0.35 * step(0.35, noise(vec2(t * 9.0, p.x * 3.0)));
		col += vec3(0.55, 0.30, 1.0) * arc * flicker * 1.2;
		col += vec3(0.25, 0.45, 1.0) * smoothstep(0.75, 0.9, vein) * 0.25;
		// Soft rune glow breathing from the cell centre.
		vec2 c = UV - vec2(0.5);
		float d = length(c * vec2(1.0, 2.0));
		col += vec3(0.35, 0.18, 0.75) * (1.0 - smoothstep(0.0, 0.5, d)) * (0.25 + 0.15 * sin(t * 2.0 + p.x));
	} else if (mode == 5) {
		// Two caustic layers drifting against each other, board-continuous.
		float c1 = 1.0 - abs(fbm(p * 2.4 + vec2(t * 0.18, t * 0.07)) * 2.0 - 1.0);
		float c2 = 1.0 - abs(fbm(p * 3.1 - vec2(t * 0.11, -t * 0.15) + vec2(2.0)) * 2.0 - 1.0);
		float caustic = smoothstep(0.86, 0.98, c1) * 0.7 + smoothstep(0.88, 0.99, c2) * 0.5;
		float swell = 0.94 + 0.08 * sin(t * 1.3 + p.x * 0.9 + p.y * 0.6);
		col = base * swell + vec3(0.55, 0.85, 1.0) * caustic * 0.45;
	} else if (mode == 6) {
		// Churn: fast warped swell so the surface never sits still.
		float churn = fbm(p * 2.8 + vec2(t * 0.6, -t * 0.45));
		col = base * (0.9 + 0.25 * churn);
		// Bubbles: a few per cell, each on its own rise-and-pop cycle.
		vec2 g = p * 3.0;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float seed = hash(id);
		vec2 off = vec2(hash(id + 7.1), hash(id + 3.7)) - 0.5;
		float phase = fract(t * (0.55 + seed * 0.6) + seed * 9.0);
		float r = 0.08 + 0.22 * phase;
		float d = length(f - off * 0.5);
		float ring = smoothstep(r + 0.06, r, d) * smoothstep(r - 0.09, r - 0.02, d);
		float fade = smoothstep(1.0, 0.75, phase) * step(0.35, seed);
		col += vec3(0.75, 0.95, 1.0) * ring * fade * 0.9;
		// Heat shimmer from the lava under it.
		col += vec3(0.35, 0.12, 0.02) * smoothstep(0.6, 0.85, churn) * 0.5;
	} else if (mode == 4) {
		// Near-black slate, cooled toward the picture's blue-violet night.
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(lum) * vec3(0.86, 0.86, 1.08), 0.6);
		float sheen = fbm(p * 1.4 + vec2(t * 0.02, 0.0));
		col = base + vec3(0.04, 0.04, 0.08) * smoothstep(0.55, 0.8, sheen);
	}
	COLOR = vec4(col, tex.a * COLOR.a);
}
