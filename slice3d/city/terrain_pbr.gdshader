shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Height-blended PBR splat for the city ground (art kit terrain sets).
// id_map holds one material id per layout cell; each pixel blends the four
// nearest cells' materials with weight_i = max(0, h_i + splat_i - max_j + c)
// (terrain_materials.json). Texture arrays keep the sampler count low enough
// for the Compatibility renderer.

uniform sampler2DArray albedo_arr : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_arr : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray orm_arr : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray height_arr : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D id_map : filter_nearest;
uniform vec2 map_cells = vec2(245.0, 245.0);
uniform float cell_m = 1.5;
uniform float contrast = 0.15;
uniform int outside_id = 1;
uniform float tiles[9];
// Cobble variants: cells with cobble_a mix in cobble_b by world noise
// (period ~mix_period m) through a sharp height cut, so whole cobbles switch;
// a narrow joint-darkening band hides cut stones (terrain_materials.json).
uniform int cobble_a = -1;
uniform int cobble_b = -1;
uniform float mix_period = 8.0;
uniform float mix_cut = 0.08;
uniform float joint_dark = 0.3;
uniform float normal_strength = 1.0;

varying vec3 wpos;

float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

// Weight of cobble a at this point (1 = all a, 0 = all b).
float cobble_wa(vec2 xz, float ha, float hb) {
	float n = vnoise(xz / mix_period) * 0.75 + vnoise(xz / (mix_period * 0.37)) * 0.25;
	float d = (ha + 1.6 * (1.0 - n)) - (hb + 1.6 * n);
	return clamp(d / mix_cut + 0.5, 0.0, 1.0);
}

float mat_height(int id, vec2 xz) {
	float h = texture(height_arr, vec3(xz / tiles[id], float(id))).r;
	if (id == cobble_a && cobble_b >= 0) {
		float hb = texture(height_arr, vec3(xz / tiles[cobble_b], float(cobble_b))).r;
		h = mix(hb, h, cobble_wa(xz, h, hb));
	}
	return h;
}

void mat_sample(int id, vec2 xz, out vec3 alb, out vec3 nrm, out vec3 orm) {
	vec3 uv = vec3(xz / tiles[id], float(id));
	alb = texture(albedo_arr, uv).rgb;
	nrm = texture(normal_arr, uv).rgb;
	orm = texture(orm_arr, uv).rgb;
	if (id == cobble_a && cobble_b >= 0) {
		vec3 ub = vec3(xz / tiles[cobble_b], float(cobble_b));
		float ha = texture(height_arr, uv).r;
		float hb = texture(height_arr, ub).r;
		float wa = cobble_wa(xz, ha, hb);
		alb = mix(texture(albedo_arr, ub).rgb, alb, wa);
		nrm = mix(texture(normal_arr, ub).rgb, nrm, wa);
		orm = mix(texture(orm_arr, ub).rgb, orm, wa);
		float band = 1.0 - abs(2.0 * wa - 1.0);
		alb *= 1.0 - joint_dark * band;
	}
}

int cell_id(vec2 c) {
	if (c.x < 0.0 || c.y < 0.0 || c.x >= map_cells.x || c.y >= map_cells.y) {
		return outside_id;
	}
	return int(texelFetch(id_map, ivec2(c), 0).r * 255.0 + 0.5);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = wpos.xz / cell_m - 0.5;
	vec2 b = floor(p);
	vec2 f = p - b;
	int ids[4];
	float bw[4];
	ids[0] = cell_id(b);
	ids[1] = cell_id(b + vec2(1.0, 0.0));
	ids[2] = cell_id(b + vec2(0.0, 1.0));
	ids[3] = cell_id(b + vec2(1.0, 1.0));
	bw[0] = (1.0 - f.x) * (1.0 - f.y);
	bw[1] = f.x * (1.0 - f.y);
	bw[2] = (1.0 - f.x) * f.y;
	bw[3] = f.x * f.y;
	// merge corners that share a material
	float splat[4];
	for (int k = 0; k < 4; k++) {
		splat[k] = 0.0;
		for (int m = 0; m < 4; m++) {
			if (ids[m] == ids[k]) { splat[k] += bw[m]; }
		}
	}
	float score[4];
	float best = -10.0;
	for (int k = 0; k < 4; k++) {
		score[k] = mat_height(ids[k], wpos.xz) + splat[k];
		best = max(best, score[k]);
	}
	vec3 alb = vec3(0.0);
	vec3 nrm = vec3(0.0);
	vec3 orm = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 4; k++) {
		bool dup = false;
		for (int m = 0; m < k; m++) {
			if (ids[m] == ids[k]) { dup = true; }
		}
		if (dup) { continue; }
		float w = max(0.0, score[k] - best + contrast);
		if (w <= 0.0) { continue; }
		vec3 a; vec3 nn; vec3 o;
		mat_sample(ids[k], wpos.xz, a, nn, o);
		alb += a * w;
		nrm += nn * w;
		orm += o * w;
		wsum += w;
	}
	wsum = max(wsum, 1e-4);
	ALBEDO = alb / wsum;
	NORMAL_MAP = nrm / wsum;
	NORMAL_MAP_DEPTH = normal_strength;
	orm /= wsum;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
}
