extends RefCounted
class_name PaintedRoom

## Painted arena plates. Backgrounds, occluders, and surface crops load as
## raw WebP bytes (webpbin) so the phone pack keeps the authored file size.
## Gameplay tiles stay in charge of highlights, grid ink, edge glow, and input.

const ROOT := "res://art/rooms/"
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const ARENA_LOOK := preload("res://board/arena_look.gd")
const WINDMERE := preload("res://board/windmere_alive.gd")

## Stasis Brinewake only. One scrolling layer, above the plate and under the cells.
const RAIN_CODE := "shader_type canvas_item;
uniform float slant = 0.4;
uniform float speed = 1.0;
uniform vec4 drop_color : source_color = vec4(0.78, 0.86, 0.94, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 flow = vec2(uv.x + uv.y * slant, uv.y);
	float t = TIME * speed;
	vec2 g = vec2(flow.x * 70.0, flow.y * 46.0 - t * 16.0);
	vec2 cell = floor(g);
	float h = hash(cell);
	float streak = step(0.86, h);
	float along = fract(g.y);
	float body = smoothstep(0.0, 0.05, along) * smoothstep(0.42, 0.12, along);
	float across = smoothstep(0.07, 0.0, abs(fract(g.x) - mix(0.35, 0.65, h)));
	float rain = streak * body * across;
	vec2 g2 = vec2(flow.x * 48.0 + 4.0, flow.y * 32.0 - t * 9.0);
	float h2 = hash(floor(g2) + vec2(19.0, 3.0));
	float rain2 = step(0.9, h2) * smoothstep(0.5, 0.1, fract(g2.y)) * smoothstep(0.06, 0.0, abs(fract(g2.x) - 0.5));
	vec2 s = uv * vec2(16.0, 11.0);
	vec2 sc = floor(s);
	float sh = hash(sc + vec2(7.0, 13.0));
	float splash = 0.0;
	if (sh > 0.94) {
		float phase = fract(t * 0.45 + sh);
		float dist = length(fract(s) - vec2(0.5));
		splash = smoothstep(0.045, 0.0, abs(dist - phase * 0.42)) * (1.0 - phase);
	}
	float a = clamp(rain * 0.20 + rain2 * 0.12 + splash * 0.16, 0.0, 0.26);
	COLOR = vec4(drop_color.rgb, a);
}
"

static var _tex: Dictionary = {}
static var _bound_room: String = ""
## Tall centrepiece. Neighbouring floor tiles and raised blocks stay under the
## shaft. Fighters on the near side are lifted back above it in BoardView.
static var _tower_cell := Vector2i(-999, -999)
static var _tower_z := -1


static func room_id_for(map_id: String, stasis_letter: String) -> String:
	var biome := ARENA_LOOK.normalize(map_id)
	if biome == "":
		return ""
	var letter := stasis_letter.strip_edges().to_lower()
	if letter == "a" or letter == "b":
		return "stasis_%s_room_%s" % [biome, letter]
	return "koliseo_%s" % biome


static func texture_from_webpbin(path: String) -> Texture2D:
	if _tex.has(path):
		var cached: Variant = _tex[path]
		return cached as Texture2D if cached is Texture2D else null
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			# Transparent texels are near-black. Linear filtering was drawing
			# that as a dark fringe around every prop. Bleed the opaque color out.
			if image.detect_alpha() != Image.ALPHA_NONE:
				image.fix_alpha_edges()
			tex = ImageTexture.create_from_image(image)
	_tex[path] = tex
	return tex


## True when this board is showing a painted plate. Tiles then skip their
## own floor stamp and prop art. Missing rooms leave the old stamps in place.
static func bind(parent: Node2D, room_id: String, tiles: Dictionary) -> bool:
	var host := parent.get_node_or_null("PaintedRoom") as Node2D
	if room_id != "" and room_id == _bound_room and host != null and host.get_child_count() > 0:
		return true
	if room_id == "":
		_clear(host, tiles)
		return false
	var place_path := "%s%s/place.json" % [ROOT, room_id]
	if not FileAccess.file_exists(place_path):
		_clear(host, tiles)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(place_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_clear(host, tiles)
		return false
	var place: Dictionary = parsed
	_drop_other_rooms(room_id)
	if host == null:
		host = Node2D.new()
		host.name = "PaintedRoom"
		parent.add_child(host)
	else:
		for child in host.get_children():
			host.remove_child(child)
			child.free()
	_tower_cell = Vector2i(-999, -999)
	_tower_z = -1
	parent.move_child(host, 0)
	for cell in tiles.keys():
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_occluder_covers_grid"):
			tile.set_occluder_covers_grid(false)
		if tile != null and tile.has_method("set_raised_top"):
			tile.set_raised_top(false)
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(false)
	var pos: Array = place.get("position", [-610.0, -366.0])
	var origin := Vector2(float(pos[0]), float(pos[1]))
	var surround_file := str(place.get("surround", ""))
	if surround_file != "":
		var sea := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, surround_file])
		if sea != null:
			var sea_sprite := Sprite2D.new()
			sea_sprite.name = "Surround"
			sea_sprite.texture = sea
			sea_sprite.centered = false
			sea_sprite.scale = Vector2(0.5, 0.5)
			sea_sprite.position = origin
			sea_sprite.z_index = int(place.get("z", -199)) - 1
			sea_sprite.z_as_relative = true
			host.add_child(sea_sprite)
	var bg := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(place.get("background", ""))])
	if bg != null:
		var sprite := Sprite2D.new()
		sprite.name = "Background"
		sprite.texture = bg
		sprite.centered = false
		sprite.scale = Vector2(0.5, 0.5)
		sprite.position = origin
		sprite.z_index = int(place.get("z", -199))
		sprite.z_as_relative = true
		host.add_child(sprite)
		_add_brine_rain(host, sprite, bg, room_id)
	for raw in place.get("occluders", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var occ: Dictionary = raw
		var cell := _cell(occ.get("cell", [0, 0]))
		var tile: Node = tiles.get(cell)
		var elev := float(tile.elevation) if tile != null and "elevation" in tile else 0.0
		var tex := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(occ.get("file", ""))])
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.scale = Vector2(0.5, 0.5)
		var off: Array = occ.get("offset", [0.0, 0.0])
		# The plate already contains this cut. The offset was measured from the
		# flat cell, and it already lifts the top face onto the raised diamond.
		# Anchoring at the cell elevation paints a second block above the plate.
		sprite.position = VISUAL_SORT.cell_to_local(cell, 0.0) + Vector2(float(off[0]), float(off[1])) * 0.5
		sprite.z_index = VISUAL_SORT.occluder_z_index(cell, elev)
		sprite.z_as_relative = true
		var whats: Array = occ.get("what", [])
		var what := str(whats[0]) if whats.size() > 0 else ""
		sprite.set_meta("what", what)
		sprite.set_meta("cell", cell)
		sprite.set_meta("elev", elev)
		sprite.set_meta("rect", _occluder_rect(cell, occ))
		host.add_child(sprite)
		var raised := elev > 0.05
		if tile == null:
			continue
		if raised and tile.has_method("set_raised_top"):
			# Walkable top: one block, grid diamond on that top.
			tile.set_raised_top(true)
		elif tile.has_method("set_occluder_covers_grid"):
			tile.set_occluder_covers_grid(true)
	_lift_tower(host, place, tiles)
	_add_pit_glow(host, tiles)
	var surfaced := {}
	for raw in place.get("surfaces", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var surf: Dictionary = raw
		var cell := _cell(surf.get("cell", [0, 0]))
		var tile: Node = tiles.get(cell)
		if tile == null or not tile.has_method("set_painted_floor"):
			continue
		var tex := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(surf.get("file", ""))])
		if tex == null:
			continue
		tile.set_painted_floor(true, tex, int(surf.get("mode", 0)), float(surf.get("gain", 1.0)))
		surfaced[cell] = true
	for cell in tiles.keys():
		if surfaced.has(cell):
			continue
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(true)
	_add_slag_lava(host, room_id)
	_add_windmere(host, room_id)
	_bound_room = room_id
	return true


## Slagcrown lava, set B. Four shared frame strips, one sprite per lava cell.
## Ping-pong f1-f2-f3-f2 at 180 ms. Neighbours take different variants and phases.
const LAVA_ROOT := "res://art/lava/slagcrown_b/"
const LAVA_FRAME_SEC := 0.18
static var _lava_frames: SpriteFrames


static func _ensure_lava_frames() -> SpriteFrames:
	if _lava_frames != null:
		return _lava_frames
	var book := SpriteFrames.new()
	for variant in 4:
		var anim := "v%d" % variant
		book.add_animation(anim)
		book.set_animation_loop(anim, true)
		book.set_animation_speed(anim, 1.0 / LAVA_FRAME_SEC)
		var steps: Array = []
		for frame in 3:
			steps.append(texture_from_webpbin("%sv%d_f%d.webpbin" % [LAVA_ROOT, variant + 1, frame + 1]))
		for index in [0, 1, 2, 1]:
			if steps[index] != null:
				book.add_frame(anim, steps[index])
	_lava_frames = book
	return book


static func _lava_tags_path(room_id: String) -> String:
	if room_id.begins_with("stasis_"):
		return "res://art/maps/stasis_v1/%s_15x15_tags.json" % room_id.trim_prefix("stasis_")
	return "res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % room_id.trim_prefix("koliseo_")


static func _add_slag_lava(host: Node2D, room_id: String) -> void:
	if not room_id.contains("slagcrown"):
		return
	var path := _lava_tags_path(room_id)
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var book := _ensure_lava_frames()
	for raw in (parsed as Dictionary).get("cells", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = raw
		if str(rec.get("terrain", "")) != "lava":
			continue
		var cell := Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))
		var variant := posmod(cell.x + cell.y * 2, 4)
		var anim := "v%d" % variant
		if book.get_frame_count(anim) < 4:
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Lava_%d_%d" % [cell.x, cell.y]
		sprite.sprite_frames = book
		sprite.centered = true
		# 256x128 art covers the 64x32 world diamond. Sharper than the 128x64 slot on a phone.
		sprite.scale = Vector2(0.25, 0.25)
		sprite.position = VISUAL_SORT.cell_to_local(cell, 0.0)
		sprite.z_index = VISUAL_SORT.tile_z_index(cell, 0.0)
		sprite.z_as_relative = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		host.add_child(sprite)
		sprite.play(anim)
		# Eight starts across the 0.72 s loop, so a row does not pulse as one.
		var into := float(posmod(cell.x * 13 + cell.y * 29, 8)) * (LAVA_FRAME_SEC * 0.5)
		sprite.set_frame_and_progress(int(into / LAVA_FRAME_SEC) % 4, fmod(into, LAVA_FRAME_SEC) / LAVA_FRAME_SEC)


static func _add_windmere(host: Node2D, room_id: String) -> void:
	WINDMERE.attach(host, room_id)


## Light rain over the flooding hold. Above the plate, under tiles and fighters.
static func _add_brine_rain(host: Node2D, background: Sprite2D, tex: Texture2D, room_id: String) -> void:
	if room_id != "stasis_brinewake_room_a" and room_id != "stasis_brinewake_room_b":
		return
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	var rain := Sprite2D.new()
	rain.name = "BrineRain"
	rain.texture = ImageTexture.create_from_image(image)
	rain.centered = false
	rain.position = background.position
	rain.scale = tex.get_size() * 0.5 / 4.0
	rain.z_index = -170
	rain.z_as_relative = true
	var shader := Shader.new()
	shader.code = RAIN_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if room_id.ends_with("_a"):
		mat.set_shader_parameter("slant", 0.55)
		mat.set_shader_parameter("speed", 1.05)
	else:
		mat.set_shader_parameter("slant", -0.32)
		mat.set_shader_parameter("speed", 0.85)
	rain.material = mat
	host.add_child(rain)


## A fighter whose cell is on the near side of the tower (same row or in front)
## paints above the lifted shaft. Elevation still breaks ties on that row.
## Cells behind the tower keep their own z, so they stay behind the stone.
static func adjust_unit_z(cell: Vector2i, elevation: float, z: int) -> int:
	if _tower_z < 0:
		return z
	var ahead := cell.x + cell.y - (_tower_cell.x + _tower_cell.y)
	if ahead < 0:
		return z
	var lifted := _tower_z + 1 + ahead * VISUAL_SORT.TILE_Z_SCALE
	lifted += int(round(elevation * float(VISUAL_SORT.ELEVATION_Z_SCALE)))
	return maxi(z, lifted)


static func _lift_tower(host: Node2D, _place: Dictionary, tiles: Dictionary) -> void:
	var tower: Sprite2D = null
	var blocks: Array = []
	for child in host.get_children():
		if not (child is Sprite2D) or not child.has_meta("what"):
			continue
		var what := str(child.get_meta("what"))
		if what == "tower":
			tower = child
		elif what.begins_with("elevation"):
			blocks.append(child)
	if tower == null:
		return
	var tower_cell: Vector2i = tower.get_meta("cell")
	var tower_elev := float(tower.get_meta("elev"))
	var tower_rect: Rect2 = tower.get_meta("rect")
	var cover := VISUAL_SORT.occluder_z_index(tower_cell, tower_elev)
	var grown := tower_rect.grow(6.0)
	for block in blocks:
		var block_cell: Vector2i = block.get_meta("cell")
		var rect: Rect2 = block.get_meta("rect")
		var near := maxi(absi(block_cell.x - tower_cell.x), absi(block_cell.y - tower_cell.y)) <= 2
		if not near and not grown.intersects(rect):
			continue
		cover = maxi(cover, VISUAL_SORT.occluder_z_index(block_cell, float(block.get_meta("elev"))))
	for key in tiles.keys():
		var cell: Vector2i = key
		var tile: Node = tiles[key]
		if tile == null:
			continue
		if maxi(absi(cell.x - tower_cell.x), absi(cell.y - tower_cell.y)) > 2:
			continue
		var elev := float(tile.elevation) if "elevation" in tile else 0.0
		# Grid ink and the walk wash sit a few steps above the tile node.
		cover = maxi(cover, VISUAL_SORT.tile_z_index(cell, elev) + 3)
	tower.z_index = cover + 1
	_tower_cell = tower_cell
	_tower_z = tower.z_index
	print("tower sort ", tower_cell, " z ", tower.z_index)


static func _occluder_rect(cell: Vector2i, occ: Dictionary) -> Rect2:
	var off: Array = occ.get("offset", [0.0, 0.0])
	var size: Array = occ.get("size", [0.0, 0.0])
	var origin := VISUAL_SORT.cell_to_local(cell, 0.0) + Vector2(float(off[0]), float(off[1])) * 0.5
	return Rect2(origin, Vector2(float(size[0]), float(size[1])) * 0.5)


const PIT_GLOW_CODE := "shader_type canvas_item; uniform float phase = 0.0; void fragment() { float pulse = 0.86 + 0.14 * sin(TIME * 1.5 + phase); COLOR = texture(TEXTURE, UV); COLOR.rgb *= pulse; COLOR.a *= pulse; }"
static var _pit_glow_tex: Texture2D
static var _pit_glow_shader: Shader


static func _glow_texture() -> Texture2D:
	if _pit_glow_tex != null:
		return _pit_glow_tex
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - center) / center
			var dy := (float(y) + 0.5 - center) / center
			var dist := sqrt(dx * dx + dy * dy)
			var fall := clampf(1.0 - dist, 0.0, 1.0)
			fall = pow(fall, 1.45)
			var alpha := fall * 0.82
			image.set_pixel(x, y, Color(0.86, 0.42, 1.0, alpha))
	_pit_glow_tex = ImageTexture.create_from_image(image)
	return _pit_glow_tex


static func _glow_shader() -> Shader:
	if _pit_glow_shader == null:
		_pit_glow_shader = Shader.new()
		_pit_glow_shader.code = PIT_GLOW_CODE
	return _pit_glow_shader


## Soft violet pool on the floor around each pit beside the tower. Above the
## plate, under the raised blocks and the shaft. Not a flat neon disc.
static func _add_pit_glow(host: Node2D, tiles: Dictionary) -> void:
	if _tower_z < 0:
		return
	var tex := _glow_texture()
	var n := 0
	for key in tiles.keys():
		var cell: Vector2i = key
		var tile: Node = tiles[key]
		if tile == null or str(tile.terrain_type) != "mud":
			continue
		if maxi(absi(cell.x - _tower_cell.x), absi(cell.y - _tower_cell.y)) > 2:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "PitGlow"
		sprite.texture = tex
		sprite.centered = true
		sprite.position = VISUAL_SORT.cell_to_local(cell, 0.0)
		# Iso pool: wider than the cell so the light spills onto the bronze flags.
		sprite.scale = Vector2(176.0 / 256.0, 88.0 / 256.0)
		sprite.z_index = -188
		sprite.z_as_relative = true
		var mat := ShaderMaterial.new()
		mat.shader = _glow_shader()
		mat.set_shader_parameter("phase", float(n) * 1.8)
		sprite.material = mat
		host.add_child(sprite)
		n += 1


static func _clear(host: Node2D, tiles: Dictionary) -> void:
	_bound_room = ""
	_tower_cell = Vector2i(-999, -999)
	_tower_z = -1
	if host != null and is_instance_valid(host):
		var parent_node := host.get_parent()
		if parent_node != null:
			parent_node.remove_child(host)
		host.free()
	for cell in tiles.keys():
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_occluder_covers_grid"):
			tile.set_occluder_covers_grid(false)
		if tile != null and tile.has_method("set_raised_top"):
			tile.set_raised_top(false)
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(false)


static func _drop_other_rooms(room_id: String) -> void:
	var keep := "%s%s/" % [ROOT, room_id]
	var drop: Array = []
	for key in _tex.keys():
		if not str(key).begins_with(keep):
			drop.append(key)
	for key in drop:
		_tex.erase(key)


static func _cell(raw: Variant) -> Vector2i:
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO
