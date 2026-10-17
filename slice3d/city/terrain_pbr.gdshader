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
uniform float tiles[8];
uniform float normal_strength = 1.0;

varying vec3 wpos;

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
		float t = tiles[ids[k]];
		float h = texture(height_arr, vec3(wpos.xz / t, float(ids[k]))).r;
		score[k] = h + splat[k];
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
		vec3 uv = vec3(wpos.xz / tiles[ids[k]], float(ids[k]));
		alb += texture(albedo_arr, uv).rgb * w;
		nrm += texture(normal_arr, uv).rgb * w;
		orm += texture(orm_arr, uv).rgb * w;
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
