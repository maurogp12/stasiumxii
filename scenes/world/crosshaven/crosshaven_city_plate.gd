extends Node2D

## VIEW ONLY. Draws a plate city (backend/plate_city.gd): the painted ground,
## the y-sorted sprite layers, the player plot houses and the pets, and fades
## whatever stands in front of the hero. Walk data stays on the WorldZone.
##
## Depth: every layer has an absolute z from its sort line with the walker's
## own formula (`round(world_y * 10 / 16)`), so the hero, NPCs, pets and
## layers share one y-sort. Bridges ("under") sit just above the ground.
## Fade (Luca: every obstacle): a fading layer that draws in front of the hero
## and whose opaque pixels meet the hero's body box ramps to its min alpha.
## Performance mode: half-size ground, instant fades, pets do not hop.

const PlateCity := preload("res://backend/plate_city.gd")

const GROUND_Z := -4000
const UNDER_Z := -3900
const FADE_SECONDS := 0.25
## Hero body box around the feet, world px (heroes stand 54-63 px).
const BODY_HALF_W := 13.0
const BODY_TOP := 58.0
const BODY_BOTTOM := 4.0

var city = null
var lite := false
var hour := 12.0
var rows: Array = []
var plot_nodes: Dictionary = {}
var pet_nodes: Array = []
var _ground: Sprite2D
var water: Sprite2D
var _ground_lite := false
var _covering: Array = []
var footprints: Node2D
static var _tex_cache: Dictionary = {}


func setup(target, lite_mode: bool) -> void:
	city = target
	lite = lite_mode
	name = "CityPlate"
	position = Vector2.ZERO
	_build_ground()
	_build_water()
	_build_layers()
	_build_plots()
	_build_pets()
	footprints = Node2D.new()
	footprints.name = "Footprints"
	footprints.z_as_relative = false
	footprints.z_index = UNDER_Z - 50
	footprints.visible = false
	footprints.draw.connect(_draw_footprints)
	add_child(footprints)


## Ground image swap only (the layers keep their 1x art either way).
func set_lite(on: bool) -> void:
	lite = on
	if _ground_lite != on:
		_build_ground()
	if water != null:
		water.visible = not on


func set_hour(h: float) -> void:
	hour = h


func is_day() -> bool:
	return city == null or city.is_day(hour)


## World-node API the tile ground also answers.
func redraw_all() -> void:
	pass


func cover_at(_cell: Vector2i) -> float:
	return 0.0


func add_gate_arrow(_cell: Vector2i, _dir: Vector2i) -> void:
	pass


func warm(_view: Rect2, budget: int) -> int:
	return budget


func ground_texture() -> Texture2D:
	return _ground.texture if _ground != null else null


func ground_is_lite() -> bool:
	return _ground_lite


static func load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_tex_cache[path] = tex
	return tex


static func clear_textures() -> void:
	_tex_cache.clear()


func _build_ground() -> void:
	if _ground != null:
		_ground.free()
	var plate: Dictionary = city.doc["plate"]
	var file := str(plate["ground_lite"] if lite else plate["ground"])
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ground.texture = load_tex(city.art_path(file))
	_ground_lite = lite
	if _ground.texture != null:
		_ground.scale = city.plate_size() * city.scale() / _ground.texture.get_size()
	_ground.position = city.plate_to_world(Vector2.ZERO)
	_ground.z_as_relative = false
	_ground.z_index = GROUND_Z
	add_child(_ground)
	move_child(_ground, 0)


## Animated river (shader over the painted base). Performance mode hides it:
## the ground already holds the still painted water.
func _build_water() -> void:
	var spec: Dictionary = city.doc.get("water", {})
	if spec.is_empty():
		return
	var base := load_tex(city.art_path(str(spec["base"])))
	if base == null:
		return
	water = Sprite2D.new()
	water.name = "Water"
	water.centered = false
	water.texture = base
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	water.position = city.plate_to_world(Vector2.ZERO)
	water.scale = city.plate_size() * city.scale() / base.get_size()
	water.z_as_relative = false
	water.z_index = GROUND_Z + 5
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/crosshaven/crosshaven_city_water.gdshader")
	mat.set_shader_parameter("ripple", load_tex(city.art_path(str(spec["ripple"]))))
	mat.set_shader_parameter("fx_tex", load_tex(city.art_path(str(spec["fx"]))))
	mat.set_shader_parameter("plate_size", city.plate_size())
	var flow: Array = spec["flow_dir"]
	mat.set_shader_parameter("flow_dir", Vector2(float(flow[0]), float(flow[1])))
	mat.set_shader_parameter("speed", float(spec["speed_px_s"]))
	mat.set_shader_parameter("tile_px", float(spec["tile_px"]))
	var sec: Dictionary = spec["second_layer"]
	mat.set_shader_parameter("offset2", Vector2(float(sec["offset"][0]), float(sec["offset"][1])))
	mat.set_shader_parameter("speed2", float(sec["speed_mult"]))
	mat.set_shader_parameter("alpha2", float(sec["alpha"]))
	mat.set_shader_parameter("flip2", bool(sec["flip"]))
	water.material = mat
	water.visible = not lite
	add_child(water)


func _sprite(tex: Texture2D, plate_pos: Vector2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.texture = tex
	s.position = city.plate_to_world(plate_pos)
	s.scale = Vector2.ONE * city.scale()
	s.z_as_relative = false
	s.z_index = clampi(z, -4096, 4096)
	add_child(s)
	return s


func _sort_z(plate_y: float) -> int:
	return PlateCity.z_for_world_y(city.plate_to_world(Vector2(0, plate_y)).y)


func _build_layers() -> void:
	rows.clear()
	var under_i := 0
	for rec in city.layers():
		if bool(rec.get("hidden", false)):
			continue
		var tex := load_tex(city.art_path(str(rec["file"])))
		var z := 0
		if bool(rec.get("under", false)):
			z = UNDER_Z + under_i
			under_i += 1
		else:
			z = _sort_z(float(rec["sort_y"]))
		var s := _sprite(tex, Vector2(float(rec["x"]), float(rec["y"])), z)
		s.name = "L%03d_%s" % [int(rec["id"]), str(rec["tag"])]
		# Plants carry a scale jitter and a mirror (seeded in the build).
		var k := float(rec.get("k", 1.0))
		s.scale *= k
		s.flip_h = bool(rec.get("flip", false))
		var row := _add_row(s, str(rec["tag"]), Vector2(float(rec["w"]), float(rec["h"])) * k, float(rec["sort_y"]),
			bool(rec.get("fade", false)), float(rec.get("fade_min_alpha", 0.45)), rec.get("mask", {}), int(rec["id"]))
		row["k"] = k
		row["flip"] = s.flip_h


func _add_row(s: Sprite2D, tag: String, size: Vector2, sort_y: float, fade: bool, min_alpha: float, mask: Dictionary, id: int) -> Dictionary:
	var row := {
		"node": s, "tag": tag, "id": id,
		"rect": Rect2(s.position, size * city.scale()),
		"sort_y": sort_y,
		"z": s.z_index,
		"fade": fade,
		"min_alpha": min_alpha,
		"mask": PlateCity.unpack_mask(mask) if fade else {},
		"alpha": 1.0,
	}
	rows.append(row)
	return row


func _build_plots() -> void:
	plot_nodes.clear()
	if city.plot_houses_hidden():
		return
	for p in city.plots():
		var tier := str(p["tier"])
		var tex := load_tex(city.house_art(tier))
		var size: Vector2 = city.house_size(tier)
		if tex != null:
			size = tex.get_size()
		var anchor := Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1]))
		var top_left := anchor - Vector2(size.x * 0.5, size.y)
		var s := _sprite(tex, top_left, _sort_z(anchor.y))
		s.name = "Plot_%s_%s" % [str(p["id"]), tier]
		var row := _add_row(s, "plot_house", size, anchor.y, true, 0.45, city.house_mask(tier), -1)
		row["plot"] = str(p["id"])
		plot_nodes[str(p["id"])] = s


func _build_pets() -> void:
	pet_nodes.clear()
	for rec in city.pets():
		var tex := load_tex(city.art_path(str(rec["sprite"])))
		var pet := Sprite2D.new()
		pet.name = "Pet_%s_%d" % [str(rec["name"]), pet_nodes.size()]
		pet.texture = tex
		pet.centered = false
		pet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if tex != null:
			pet.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		pet.z_as_relative = false
		pet.scale = Vector2.ONE * city.scale()
		add_child(pet)
		var a: Vector2 = city.plate_to_world(Vector2(float(rec["a"][0]), float(rec["a"][1])))
		var b: Vector2 = city.plate_to_world(Vector2(float(rec["b"][0]), float(rec["b"][1])))
		pet_nodes.append({"node": pet, "a": a, "b": b, "t": 0.0, "dir": 1.0, "wait": 0.0,
			"speed": float(rec["speed"]) * city.scale(), "pause": float(rec["pause"]), "hop": float(rec["hop_px"]),
			"night": str(rec.get("night", "indoors"))})
		_place_pet(pet_nodes[pet_nodes.size() - 1], 0.0)


## Pets trot a <-> b with a pause at each end. At night the dog goes in and
## the cat stays out.
func tick_pets(delta: float) -> void:
	var day := is_day()
	for p in pet_nodes:
		var node: Sprite2D = p["node"]
		var out := day or str(p["night"]) == "out"
		node.visible = out
		if not out:
			continue
		if float(p["wait"]) > 0.0:
			p["wait"] = float(p["wait"]) - delta
			_place_pet(p, 0.0)
			continue
		var span := maxf(1.0, (p["a"] as Vector2).distance_to(p["b"]))
		var t := float(p["t"]) + float(p["dir"]) * float(p["speed"]) * delta / span
		if t >= 1.0 or t <= 0.0:
			t = clampf(t, 0.0, 1.0)
			p["dir"] = -float(p["dir"])
			p["wait"] = float(p["pause"])
		p["t"] = t
		_place_pet(p, delta)


func _place_pet(p: Dictionary, delta: float) -> void:
	var node: Sprite2D = p["node"]
	var at: Vector2 = (p["a"] as Vector2).lerp(p["b"], float(p["t"]))
	var hop := 0.0
	if delta > 0.0 and not lite:
		hop = absf(sin(float(Time.get_ticks_msec()) * 0.012)) * float(p["hop"])
	node.position = at - Vector2(0, hop * city.scale())
	node.flip_h = (p["b"] as Vector2).x < (p["a"] as Vector2).x if float(p["dir"]) > 0.0 else (p["a"] as Vector2).x < (p["b"] as Vector2).x
	node.z_index = PlateCity.z_for_world_y(at.y) + 2


## Fade pass. `feet` is the hero's ground point (world px), `lift` his
## elevation in px, `hero_z` his z. Returns true while a layer covers him.
func update_cover(feet: Vector2, lift: float, hero_z: int, delta: float) -> bool:
	var body := Rect2(feet.x - BODY_HALF_W, feet.y - lift - BODY_TOP, BODY_HALF_W * 2.0, BODY_TOP - BODY_BOTTOM)
	var covered := false
	_covering.clear()
	var step := 1.0 if lite else delta / FADE_SECONDS
	for row in rows:
		if not bool(row["fade"]):
			continue
		var want := 1.0
		if int(row["z"]) > hero_z and (row["rect"] as Rect2).intersects(body) and _mask_hits(row, body):
			want = float(row["min_alpha"])
			covered = true
			_covering.append(row)
		var a := float(row["alpha"])
		if a != want:
			a = move_toward(a, want, step * (1.0 - float(row["min_alpha"])) if not lite else 1.0)
			row["alpha"] = a
			(row["node"] as CanvasItem).modulate.a = a
	return covered


## Rows fading over the hero on the last update.
func covering() -> Array:
	return _covering


func _mask_hits(row: Dictionary, body: Rect2) -> bool:
	var m: Dictionary = row["mask"]
	if m.is_empty():
		return true
	var rect: Rect2 = row["rect"]
	var step: float = float(m["step"]) * city.scale() * float(row.get("k", 1.0))
	var w := int(m["w"])
	var h := int(m["h"])
	var bits: PackedByteArray = m["bits"]
	var local := Rect2(body.position - rect.position, body.size)
	if bool(row.get("flip", false)):
		local.position.x = rect.size.x - local.end.x
	var x0 := clampi(int(floor(local.position.x / step)), 0, w - 1)
	var x1 := clampi(int(floor(local.end.x / step)), 0, w - 1)
	var y0 := clampi(int(floor(local.position.y / step)), 0, h - 1)
	var y1 := clampi(int(floor(local.end.y / step)), 0, h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if bits[y * w + x] == 1:
				return true
	return false


## Debug overlay: the reserved plot (Legendary) and building footprints.
func set_footprints_visible(on: bool) -> void:
	if footprints != null:
		footprints.visible = on
		footprints.queue_redraw()


func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _draw_footprints() -> void:
	var s: float = city.scale()
	var font := ThemeDB.fallback_font
	for f in city.doc.get("building_footprints", []):
		var c: Vector2 = city.plate_to_world(Vector2(float(f["c"][0]), float(f["c"][1])))
		var r := Vector2(float(f["r"][0]), float(f["r"][1])) * s
		footprints.draw_colored_polygon(_ellipse(c, r), Color(0.95, 0.55, 0.2, 0.18))
		footprints.draw_polyline(_ellipse(c, r), Color(1.0, 0.6, 0.2, 0.9), 2.0)
	var lw: float = city.clearance_px("legendary")
	for p in city.plots():
		var a: Vector2 = city.plate_to_world(Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1])))
		var r := Vector2(lw * 0.5, lw * 0.25) * s
		var c := a - Vector2(0, r.y)
		footprints.draw_colored_polygon(_ellipse(c, r), Color(0.3, 0.6, 1.0, 0.16))
		footprints.draw_polyline(_ellipse(c, r), Color(0.4, 0.75, 1.0, 0.95), 3.0)
		footprints.draw_circle(a, 6.0, Color(1, 0.2, 0.9))
		footprints.draw_string(font, a + Vector2(-30, 26), "%s %s" % [p["id"], p["tier"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))


## Row by layer id (tests).
func row_of(id: int) -> Dictionary:
	for row in rows:
		if int(row["id"]) == id:
			return row
	return {}
