shader_type canvas_item;

// VIEW ONLY. Smoothed sea shore over a ground chunk (crosshaven_ground.gd
// `_cache_shore`). Each shore cell draws its own diamond with UV = its cell
// position in the field texture, so the ground keeps its row order.
//
// The field holds one texel per cell (texel centre = cell centre):
//   r: signed distance to the cell coast in cells, land +, sea -, 0..1 = -4..4
//   g: snow on the shore (Northgate), 0..1
//   b: how much of the coast here is soft (sand or snow, not cliff or bank)
// A Catmull-Rom read of it is a smooth signed distance: a straight cell coast
// stays exactly where it is, a one-cell stair becomes a straight line through
// the step midpoints, and a lone cell keeps its middle. The bands below are
// drawn from that one value, so no cell edge shows.

uniform sampler2D field : filter_nearest, repeat_disable;
uniform vec2 field_size = vec2(1.0);
// World cell of field texel (0, 0).
uniform vec2 field_origin = vec2(0.0);
uniform sampler2D sand_tex : filter_linear, repeat_disable;
uniform sampler2D sea_tex : filter_linear, repeat_enable;
uniform vec2 sea_period = vec2(256.0, 128.0);
// The ground's ripple sway (px), so the sea under the band moves with the tiles.
uniform vec2 sway = vec2(0.0);
// 1 = foam laps and drifts with TIME. 0 = Performance mode: one still frame.
uniform float animate = 1.0;
uniform vec3 sand_tint = vec3(1.0);
// The ground's world-space snow field, so the snow bands match the snow floor.
uniform sampler2D snow_tex : filter_linear, repeat_enable;
uniform vec2 snow_period = vec2(256.0, 128.0);

varying vec2 cell_uv;

void vertex() {
	cell_uv = UV;
}

float texel_s(ivec2 at) {
	ivec2 c = clamp(at, ivec2(0), ivec2(field_size) - ivec2(1));
	return texelFetch(field, c, 0).r * 8.0 - 4.0;
}

vec2 texel_gb(ivec2 at) {
	ivec2 c = clamp(at, ivec2(0), ivec2(field_size) - ivec2(1));
	return texelFetch(field, c, 0).gb;
}

vec4 cr_weights(float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return vec4(
		-0.5 * t3 + t2 - 0.5 * t,
		1.5 * t3 - 2.5 * t2 + 1.0,
		-1.5 * t3 + 2.0 * t2 + 0.5 * t,
		0.5 * t3 - 0.5 * t2);
}

float field_s(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec4 wx = cr_weights(f.x);
	vec4 wy = cr_weights(f.y);
	ivec2 b = ivec2(i) - ivec2(1);
	float s = 0.0;
	for (int y = 0; y < 4; y++) {
		float row = 0.0;
		for (int x = 0; x < 4; x++) {
			row += texel_s(b + ivec2(x, y)) * wx[x];
		}
		s += row * wy[y];
	}
	return s;
}

vec2 field_gb(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, p - i);
	ivec2 b = ivec2(i);
	vec2 a = mix(texel_gb(b), texel_gb(b + ivec2(1, 0)), f.x);
	vec2 c = mix(texel_gb(b + ivec2(0, 1)), texel_gb(b + ivec2(1, 1)), f.x);
	return mix(a, c, f.y);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The kit sand tile, mapped onto each cell's diamond in world space and
// flipped per cell, like the ground's own interiors.
vec3 sand_at(vec2 q) {
	vec2 cell = floor(q + 0.5);
	vec2 f = q - cell;
	vec2 o = vec2((f.x - f.y) * 32.0, (f.x + f.y) * 16.0);
	vec2 uv = (o + vec2(32.0, 16.0)) / vec2(64.0, 32.0);
	float h = hash12(cell * 1.7 + 3.1);
	if (h > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = 0.5 + (uv - 0.5) * 0.9;
	return texture(sand_tex, uv).rgb * sand_tint;
}

void fragment() {
	vec2 q = cell_uv + field_origin;
	vec2 w = vec2((q.x - q.y) * 32.0, (q.x + q.y) * 16.0);
	float t = TIME * animate;
	float s = field_s(cell_uv);
	vec2 gb = field_gb(cell_uv);
	float snow = gb.x;
	float soft = smoothstep(0.3, 0.75, gb.y);
	// Painterly wobble in world space, so the line runs on across cells.
	float n1 = vnoise(w * 0.045);
	float n2 = vnoise(w * 0.11 + 17.0);
	float sw = s + (n1 - 0.5) * 0.16 + (n2 - 0.5) * 0.07;
	// The water's edge breathes a little up and down the sand.
	float tide = 0.05 * sin(t * 0.9 + (w.x + w.y) * 0.004) * animate;
	float edge = sw + tide;

	vec3 sand = sand_at(q);
	vec3 snow_col = texture(snow_tex, w / snow_period).rgb;
	sand = mix(sand, snow_col, snow);
	vec3 sea = texture(sea_tex, (w + sway) / sea_period).rgb;

	vec3 col;
	float alpha;
	if (edge >= 0.0) {
		// Sand: wet and darker by the water, dry further up.
		float wet = 1.0 - smoothstep(0.0, 0.5 + 0.12 * n2, edge);
		vec3 wet_sand = sand * vec3(0.74, 0.70, 0.66) + vec3(0.02, 0.03, 0.05);
		vec3 wet_snow = sand * vec3(0.80, 0.86, 0.92);
		col = mix(sand, mix(wet_sand, wet_snow, snow), wet * mix(0.9, 0.45, snow));
		// A thin glossy sheen where the last wave drained.
		float sheen = (1.0 - smoothstep(0.0, 0.09, edge)) * 0.25;
		col = mix(col, vec3(0.92, 0.95, 0.96), sheen);
		alpha = 1.0 - smoothstep(0.55, 0.95, sw);
	} else {
		float depth = -edge;
		vec3 turq = mix(vec3(0.36, 0.71, 0.72), vec3(0.30, 0.56, 0.70), snow);
		// Clear shallows over sand, then turquoise, then the open sea.
		vec3 shallow = mix(sand * vec3(0.80, 0.93, 0.92), turq, smoothstep(0.0, mix(0.45, 0.2, snow), depth) * mix(0.85, 1.0, snow));
		col = mix(shallow, sea, smoothstep(mix(0.25, 0.1, snow), mix(1.9, 1.2, snow), depth));
		// Foam: a bright broken crest on the line, a softer lap behind it.
		float crest = 1.0 - smoothstep(0.03, 0.14 + 0.05 * n1, depth);
		crest *= 0.65 + 0.35 * smoothstep(0.25, 0.6, vnoise(w * 0.09 - vec2(t * 0.6, 0.0)));
		float lap_at = 0.30 + 0.07 * sin(t * 0.7 + n1 * 6.0);
		float lap = 1.0 - smoothstep(0.0, 0.06, abs(depth - lap_at));
		lap *= smoothstep(0.35, 0.7, vnoise(w * 0.07 + vec2(0.0, t * 0.4) + 40.0)) * 0.55;
		float veil = (1.0 - smoothstep(0.0, 0.45, depth)) * 0.22;
		vec3 foam = mix(vec3(0.97, 0.99, 1.0), vec3(0.90, 0.96, 1.0), snow);
		col = mix(col, foam, clamp(max(crest * 0.92, lap) + veil, 0.0, 1.0));
		alpha = 1.0 - smoothstep(1.2, 2.2, depth);
	}
	COLOR = vec4(col, alpha * soft);
}
