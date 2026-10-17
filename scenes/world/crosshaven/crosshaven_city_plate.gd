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
## Lamp light (coordinator review 5): {halo, pool, base_a} per lamp head.
var lights: Array = []
## Round 18: one record per gate with a portcullis: node, lift (0 down, 1 up),
## target, idle time, trigger point (world), block cells.
var gates_fx: Array = []
## Sound hook: there is no SFX system yet, so the creak/chain is a signal
## (kind "open" or "close") that an audio player can connect to later.
signal gate_sound(gate_id: String, kind: String)
var _light_t := 0.0
static var _tex_cache: Dictionary = {}


func setup(target, lite_mode: bool) -> void:
	city = target
	lite = lite_mode
	name = "CityPlate"
	position = Vector2.ZERO
	if city.tile_mode():
		_build_tile()
	else:
		_build_ground()
		_build_water()
		_build_layers()
		_build_plots()
		_build_portcullis()
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
	if _ground_lite != on and not city.tile_mode():
		_build_ground()
	if water != null:
		water.visible = not on
	_sync_lights(0.0)


func set_hour(h: float) -> void:
	hour = h
	_sync_lights(0.0)


## Lamps are lit at dusk and night (data: lights.on_from_hour / off_at_hour).
func lamps_lit() -> bool:
	var cfg: Dictionary = city.doc.get("lights", {}) if city != null else {}
	if cfg.is_empty():
		return false
	return hour >= float(cfg.get("on_from_hour", 16.0)) or hour < float(cfg.get("off_at_hour", 7.0))


## Shows or hides the lamp light; outside Performance mode the halo breathes a
## little. Performance mode keeps it still (no per-frame change).
func _sync_lights(delta: float) -> void:
	_sync_gate_glow()
	if lights.is_empty():
		return
	var on := lamps_lit()
	_light_t += delta
	for i in lights.size():
		var l: Dictionary = lights[i]
		var halo: Sprite2D = l["halo"]
		var pool: Sprite2D = l["pool"]
		if halo.visible != on:
			halo.visible = on
		if pool != null and pool.visible != on:
			pool.visible = on
		var pl: PointLight2D = l.get("light")
		if pl != null and pl.enabled != (on and not lite):
			pl.enabled = on and not lite
		if on and not lite and delta > 0.0:
			var f := 0.92 + 0.08 * sin(_light_t * 5.3 + float(i) * 1.7) * sin(_light_t * 2.1 + float(i))
			halo.modulate.a = float(l["base_a"]) * f
		elif on:
			halo.modulate.a = float(l["base_a"])


static var _light_tex: Texture2D


## Soft radial falloff, 256 px (a light's texture_scale sets its radius).
static func _light_texture() -> Texture2D:
	if _light_tex != null:
		return _light_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_light_tex = t
	return t


func tick_lights(delta: float) -> void:
	_sync_lights(delta)


func _add_lamp_light(s: Sprite2D, rec: Dictionary, k: float) -> void:
	var cfg: Dictionary = city.doc.get("lights", {})
	var lamps: Dictionary = cfg.get("lamps", {})
	var plant := str(rec.get("plant", ""))
	if cfg.is_empty() or not lamps.has(plant):
		return
	var halo_tex := load_tex(str(cfg.get("halo", "")))
	var pool_tex := load_tex(str(cfg.get("pool", "")))
	if halo_tex == null:
		return
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var col: Array = cfg.get("color", [1.0, 0.82, 0.55])
	var tint := Color(float(col[0]), float(col[1]), float(col[2]))
	var size: Vector2 = Vector2(float(rec["w"]), float(rec["h"])) * k * city.scale()
	var first := true
	var first_light := true
	for head in (lamps[plant] as Dictionary).get("heads", []):
		var fx := float(head[0])
		if s.flip_h:
			fx = 1.0 - fx
		var halo := Sprite2D.new()
		halo.texture = halo_tex
		halo.material = add
		halo.position = s.position + Vector2(fx * size.x, float(head[1]) * size.y)
		halo.scale = Vector2.ONE * float(cfg.get("halo_scale", 1.25)) * city.scale()
		halo.z_as_relative = false
		halo.z_index = clampi(s.z_index + 1, -4096, 4096)
		halo.self_modulate = tint
		halo.modulate.a = float(cfg.get("halo_alpha", 0.95))
		halo.visible = false
		halo.name = "%s_halo" % s.name
		add_child(halo)
		var pool: Sprite2D = null
		if first and pool_tex != null:
			# one light circle on the ground per lamp, under every sorted layer
			pool = Sprite2D.new()
			pool.texture = pool_tex
			pool.material = add
			pool.position = s.position + Vector2(size.x * 0.5, size.y - 2.0)
			pool.scale = Vector2.ONE * float(cfg.get("pool_scale", 1.4)) * city.scale()
			pool.z_as_relative = false
			pool.z_index = UNDER_Z + 80
			pool.self_modulate = tint
			pool.modulate.a = float(cfg.get("pool_alpha", 0.85))
			pool.visible = false
			pool.name = "%s_pool" % s.name
			add_child(pool)
		first = false
		var lamp_light: PointLight2D = null
		if first_light and bool(cfg.get("point_light", false)):
			# lifts the night tint round the lamp (CanvasModulate dims the halo)
			lamp_light = PointLight2D.new()
			lamp_light.texture = _light_texture()
			var radius: float = float(cfg.get("light_radius_px", 190.0)) * city.scale()
			lamp_light.texture_scale = radius / 128.0
			lamp_light.color = tint
			lamp_light.energy = float(cfg.get("light_energy", 1.15))
			lamp_light.position = s.position + Vector2(size.x * 0.5, size.y * (1.0 - float(cfg.get("light_lift", 0.35))))
			lamp_light.enabled = false
			lamp_light.name = "%s_light" % s.name
			add_child(lamp_light)
		first_light = false
		lights.append({"halo": halo, "pool": pool, "light": lamp_light, "base_a": float(cfg.get("halo_alpha", 0.95)), "plant": plant})


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
	lights.clear()
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
		_add_lamp_light(s, rec, k)


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
		var local: bool = str(row["tag"]) in LOCAL_FADE_TAGS
		var low: float = maxf(float(row["min_alpha"]), LOCAL_MIN_ALPHA) if local else float(row["min_alpha"])
		var want := 1.0
		if int(row["z"]) > hero_z and (row["rect"] as Rect2).intersects(body) and _mask_hits(row, body):
			want = low
			covered = true
			_covering.append(row)
			if local:
				row["fade_at"] = body.get_center()
				row["fade_feet"] = Vector2(feet.x, feet.y - lift)
		var a := float(row["alpha"])
		if a != want:
			a = move_toward(a, want, step * (1.0 - low) if not lite else 1.0)
			row["alpha"] = a
			if not local:
				(row["node"] as CanvasItem).modulate.a = a
		if local and (a < 1.0 or (row["node"] as CanvasItem).material != null):
			_local_fade(row, a, low)
	return covered


## Round 3: walls, towers, gatehouses and houses fade only round the hero
## (a soft ellipse at about 0.5 alpha, no tint), not the whole sprite.
const LOCAL_FADE_TAGS := ["wall", "tower", "gate_back", "lintel", "watergate", "house", "stall"]
const LOCAL_MIN_ALPHA := 0.5
## Round 22: these fade in a box clamped to the hero's sprite, not an ellipse.
const BOX_FADE_TAGS := ["wall", "tower", "gate_back", "lintel", "watergate"]
## Hero sprite size in world px (the world sets it from the walker's strips).
var fade_body := Vector2(44.0, 80.0)
## Hole size round the hero's body centre, world px.
const LOCAL_FADE_RADIUS := Vector2(58.0, 74.0)
static var _fade_shader: Shader


func _local_fade(row: Dictionary, a: float, low: float) -> void:
	var s := row["node"] as Sprite2D
	if a >= 1.0:
		s.material = null
		return
	var mat := s.material as ShaderMaterial
	if mat == null:
		if _fade_shader == null:
			_fade_shader = load("res://scenes/world/crosshaven/crosshaven_city_fade.gdshader")
		mat = ShaderMaterial.new()
		mat.shader = _fade_shader
		s.material = mat
	var sc := s.scale.x
	var at: Vector2 = row.get("fade_at", s.position)
	var local := (at - s.position) / sc
	if s.flip_h and s.texture != null:
		local.x = float(s.texture.get_width()) - local.x
	mat.set_shader_parameter("centre_px", local)
	mat.set_shader_parameter("radius_px", LOCAL_FADE_RADIUS / sc)
	# walls and towers: a box exactly round the hero's sprite (feet to head)
	var boxed: bool = str(row["tag"]) in BOX_FADE_TAGS and row.has("fade_feet")
	mat.set_shader_parameter("use_box", boxed)
	if boxed:
		var f: Vector2 = (row["fade_feet"] as Vector2) - s.position
		var half_w := fade_body.x * 0.5
		var bmin := Vector2(f.x - half_w, f.y - fade_body.y) / sc
		var bmax := Vector2(f.x + half_w, f.y + 2.0) / sc
		if s.flip_h and s.texture != null:
			var tw := float(s.texture.get_width())
			var x0 := tw - bmax.x
			bmax.x = tw - bmin.x
			bmin.x = x0
		mat.set_shader_parameter("box_min_px", bmin)
		mat.set_shader_parameter("box_max_px", bmax)
		mat.set_shader_parameter("box_soft_px", 5.0 / sc)
	mat.set_shader_parameter("min_alpha", low)
	mat.set_shader_parameter("fade", clampf((1.0 - a) / maxf(0.001, 1.0 - low), 0.0, 1.0))


## What a row shows at the hero: its whole-sprite alpha, or the local fade.
func alpha_seen(row: Dictionary) -> float:
	var s := row["node"] as CanvasItem
	if s.material is ShaderMaterial:
		var m := s.material as ShaderMaterial
		return lerpf(1.0, float(m.get_shader_parameter("min_alpha")), float(m.get_shader_parameter("fade")))
	return s.modulate.a


## Tags whose art hides an NPC's name plate (coordinator review 4).
const LABEL_OCCLUDERS := ["wall", "tower", "gate_back", "lintel", "watergate", "house", "stall"]


## True when a solid obstacle drawn in front of a body at `feet` (sort z `z`)
## covers it: the fade's own test (rect, then alpha mask), without fading.
func occluded(feet: Vector2, z: int) -> bool:
	var body := Rect2(feet.x - BODY_HALF_W, feet.y - BODY_TOP, BODY_HALF_W * 2.0, BODY_TOP - BODY_BOTTOM)
	for row in rows:
		if not (str(row.get("tag", "")) in LABEL_OCCLUDERS):
			continue
		if int(row["z"]) > z and (row["rect"] as Rect2).intersects(body) and _mask_hits(row, body):
			return true
	return false


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


const TileView := preload("res://scenes/world/crosshaven/tile_city_view.gd")
## kit piece kind -> the layer tag the fade, labels and tests know
const TILE_TAGS := {
	"wall": "wall", "tower": "tower", "gate": "gate_back", "castle": "castle", "cathedral": "cathedral",
	"townhall": "townhall", "bank": "bank", "house": "house", "workshop": "workshop", "mill": "mill",
	"stall": "stall", "fountain": "fountain", "well": "well", "lamp": "lamp", "bush": "plant",
	"plot_normal": "plot_house", "plot_rare": "plot_house", "plot_legendary": "plot_house", "bridge": "bridge",
}
var tile_view: Node2D
static var _mask_cache := {}


## Round 25: the modular city. The tile view draws the autotiled ground and
## the kit pieces; each piece becomes a row here, so the y-sort, local fade,
## label occlusion, lamps, doors and plots work as on the plate.
func _build_tile() -> void:
	rows.clear()
	lights.clear()
	tile_view = TileView.new()
	add_child(tile_view)
	tile_view.setup(city.tile)
	tile_view.ground.z_index = GROUND_Z
	var k: float = city.tile.kit_scale()
	var id := 50000
	for pn in tile_view.piece_nodes:
		var s: Sprite2D = pn["node"]
		var p: Dictionary = pn["piece"]
		var kind := str(p["kind"])
		var tag := str(TILE_TAGS.get(kind, kind))
		if s.texture == null:
			continue
		var size: Vector2 = s.texture.get_size() * k / city.scale()
		var foot: Vector2 = pn["foot"]
		var fade: bool = s.texture.get_size().y * k >= 40.0 and kind != "bridge"
		var mask := _tex_mask(s.texture) if fade else {}
		var row := {
			"node": s, "tag": tag, "id": id, "kind": kind,
			"rect": Rect2(s.position, s.texture.get_size() * k),
			"sort_y": city.world_to_plate(foot).y, "z": s.z_index, "fade": fade,
			"min_alpha": 0.45, "mask": mask, "alpha": 1.0, "k": k / city.scale(), "flip": false,
			"piece": p,
		}
		rows.append(row)
		id += 1
		if kind == "lamp":
			_add_tile_lamp(s, foot, k)
		if p.has("plot"):
			plot_nodes[str(p["plot"])] = s
	_build_tile_gates()


## Fade mask of a kit texture: 8 texture px per bit (cached per texture).
func _tex_mask(t: Texture2D) -> Dictionary:
	if _mask_cache.has(t):
		return _mask_cache[t]
	var img := t.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var w := int(ceil(img.get_width() / 8.0))
	var h := int(ceil(img.get_height() / 8.0))
	var small := img.duplicate() as Image
	small.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var bits := PackedByteArray()
	bits.resize(w * h)
	for y in h:
		for x in w:
			bits[y * w + x] = 1 if small.get_pixel(x, y).a > 0.12 else 0
	var m := {"step": 8, "w": w, "h": h, "bits": bits}
	_mask_cache[t] = m
	return m


## A lamp's head glow, ground pool and (outside Performance mode) point light,
## lit from dusk to dawn like the plate lamps.
func _add_tile_lamp(s: Sprite2D, foot: Vector2, k: float) -> void:
	var cfg: Dictionary = city.doc.get("lights", {})
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tint := Color(1.0, 0.8, 0.5)
	var head := Vector2(foot.x, s.position.y + 14.0 * k)
	var halo := Sprite2D.new()
	halo.texture = _light_texture()
	halo.material = add
	halo.position = head
	halo.scale = Vector2.ONE * 0.32
	halo.self_modulate = tint
	halo.modulate.a = 0.9
	halo.z_as_relative = false
	halo.z_index = clampi(s.z_index + 1, -4096, 4096)
	halo.visible = false
	halo.name = "%s_halo" % s.name
	add_child(halo)
	var pool := Sprite2D.new()
	pool.texture = _light_texture()
	pool.material = add
	pool.position = foot
	pool.scale = Vector2(0.9, 0.45)
	pool.self_modulate = tint
	pool.modulate.a = 0.55
	pool.z_as_relative = false
	pool.z_index = UNDER_Z + 80
	pool.visible = false
	pool.name = "%s_pool" % s.name
	add_child(pool)
	var pl := PointLight2D.new()
	pl.texture = _light_texture()
	pl.texture_scale = float(cfg.get("light_radius_px", 170.0)) * city.scale() / 128.0
	pl.color = tint
	pl.energy = float(cfg.get("light_energy", 1.1))
	pl.position = foot - Vector2(0, 20)
	pl.enabled = false
	pl.name = "%s_light" % s.name
	add_child(pl)
	lights.append({"halo": halo, "pool": pool, "light": pl, "base_a": 0.9, "plant": "tile_lamp"})


## Gates on the tile map: the kit's gate piece (its "frames" when the kit has
## door frames; until then it turns see-through as it opens), blocking the
## city.json passage cells under the arch until it is open.
func _build_tile_gates() -> void:
	gates_fx.clear()
	for row in rows:
		if str(row.get("kind", "")) != "gate":
			continue
		var p: Dictionary = row["piece"]
		var gid := str(p.get("gate", ""))
		var block := {}
		for g in city.gates():
			if str(g["id"]) != gid:
				continue
			var rec: Dictionary = g.get("door", g.get("portcullis", {}))
			for c in rec.get("block_cells", []):
				block[Vector2i(int(c[0]), int(c[1]))] = true
		var spec: Dictionary = city.tile.piece_spec(p)
		var frames: Array = []
		for f in spec.get("frames", []):
			frames.append(tile_view.tex(str(f)))
		var foot: Vector2 = city.tile.piece_foot(p)
		gates_fx.append({
			"id": gid, "node": row["node"], "lift": 0.0, "target": 0.0, "idle": 0.0, "glow": null, "light": null,
			"kind": "door" if frames.size() >= 2 else "fade", "frames": frames, "frame": 0.0, "fps": float(spec.get("fps", 12.0)),
			"at": foot, "open_s": 0.6, "close_after_s": 1.5, "trigger": 3.0, "block": block,
		})


const PORTCULLIS_SHADER := preload("res://scenes/world/crosshaven/crosshaven_portcullis.gdshader")


func _build_portcullis() -> void:
	gates_fx.clear()
	for g in city.gates():
		# Round 21: wooden double doors (8 frames) when the gate has them;
		# otherwise the round 18 portcullis (data decides, nothing removed)
		var dr: Dictionary = g.get("door", {})
		var pc: Dictionary = dr if not dr.is_empty() else g.get("portcullis", {})
		if pc.is_empty():
			continue
		var kind := "door" if not dr.is_empty() else "portcullis"
		var frames: Array = []
		var s: Sprite2D
		if kind == "door":
			for f in dr["frames"]:
				frames.append(load_tex(city.art_path(str(f))))
			s = _sprite(frames[0], Vector2(float(dr["x"]), float(dr["y"])), _sort_z(float(dr["sort_y"])))
			s.name = "GateDoor_%s" % str(g["id"])
			var sh: Dictionary = dr.get("shadow", {})
			if not sh.is_empty():
				var ss := _sprite(load_tex(city.art_path(str(sh["file"]))), Vector2(float(sh["x"]), float(sh["y"])), _sort_z(float(sh["sort_y"])))
				ss.name = "GateShadow_%s" % str(g["id"])
		else:
			var tex := load_tex(city.art_path(str(pc["file"])))
			s = _sprite(tex, Vector2(float(pc["x"]), float(pc["y"])), _sort_z(float(pc["sort_y"])))
			s.name = "Portcullis_%s" % str(g["id"])
			var mat := ShaderMaterial.new()
			mat.shader = PORTCULLIS_SHADER
			mat.set_shader_parameter("opening", load_tex(city.art_path(str(pc["opening"]))))
			mat.set_shader_parameter("lift", 0.0)
			s.material = mat
		var block := {}
		for c in pc.get("block_cells", []):
			block[Vector2i(int(c[0]), int(c[1]))] = true
		# Round 19: a warm lamp glow at the gate mouth by night
		var gcfg: Dictionary = (city.doc.get("lights", {}) as Dictionary).get("gate_glow", {})
		var glow: Sprite2D = null
		var gl: PointLight2D = null
		if not gcfg.is_empty():
			var tint_a: Array = gcfg.get("tint", [1.0, 0.72, 0.42])
			var tint := Color(float(tint_a[0]), float(tint_a[1]), float(tint_a[2]))
			var mouth: Vector2 = city.plate_to_world(Vector2(float(pc["foot"][0]), float(pc["foot"][1]) - float(gcfg.get("lift_px", 30.0))))
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow = Sprite2D.new()
			glow.name = "GateGlow_%s" % str(g["id"])
			glow.texture = _light_texture()
			glow.material = add
			glow.position = mouth
			glow.scale = Vector2(1.0, 0.75) * float(gcfg.get("radius_px", 150.0)) * city.scale() / 128.0
			glow.self_modulate = tint
			glow.modulate.a = float(gcfg.get("alpha", 0.75))
			glow.z_as_relative = false
			glow.z_index = clampi(s.z_index + 1, -4096, 4096)
			glow.visible = false
			add_child(glow)
			gl = PointLight2D.new()
			gl.name = "GateLight_%s" % str(g["id"])
			gl.texture = _light_texture()
			gl.texture_scale = float(gcfg.get("radius_px", 150.0)) * 2.0 * city.scale() / 256.0
			gl.color = tint
			gl.energy = float(gcfg.get("energy", 1.0))
			gl.position = mouth
			gl.enabled = false
			add_child(gl)
		gates_fx.append({
			"id": str(g["id"]), "node": s, "lift": 0.0, "target": 0.0, "idle": 0.0, "glow": glow, "light": gl,
			"kind": kind, "frames": frames, "frame": 0.0, "fps": float(pc.get("fps", 12.0)),
			"at": city.plate_to_world(Vector2(float(pc["foot"][0]), float(pc["foot"][1]))),
			"open_s": float(pc.get("open_s", 0.6)), "close_after_s": float(pc.get("close_after_s", 1.5)),
			"trigger": float(pc.get("trigger_hero_heights", 3.0)), "block": block,
		})


## Open a gate (doors play f00 -> last at their fps; a portcullis rises over
## `open_s`) while a body (hero or NPC, world feet) is within `trigger` hero
## heights of its arch; close it once nobody has been near for `close_after_s`.
func tick_gates(delta: float, bodies: Array, hero_h: float) -> void:
	for gf in gates_fx:
		var near := false
		for b in bodies:
			if (b as Vector2).distance_to(gf["at"]) <= float(gf["trigger"]) * hero_h:
				near = true
				break
		if near:
			gf["idle"] = 0.0
			if float(gf["target"]) < 1.0:
				gf["target"] = 1.0
				_gate_sound(str(gf["id"]), "open")
		else:
			gf["idle"] = float(gf["idle"]) + delta
			if float(gf["target"]) > 0.0 and float(gf["idle"]) >= float(gf["close_after_s"]):
				gf["target"] = 0.0
				_gate_sound(str(gf["id"]), "close")
		if str(gf["kind"]) == "fade":
			gf["lift"] = move_toward(float(gf["lift"]), float(gf["target"]), delta / maxf(0.01, float(gf["open_s"])))
			(gf["node"] as CanvasItem).self_modulate.a = 1.0 - 0.75 * float(gf["lift"])
			continue
		if str(gf["kind"]) == "door":
			# f00 closed .. last frame open, at the kit's fps both ways
			var frames: Array = gf["frames"]
			var last := float(frames.size() - 1)
			gf["frame"] = move_toward(float(gf["frame"]), float(gf["target"]) * last, delta * float(gf["fps"]))
			gf["lift"] = float(gf["frame"]) / maxf(1.0, last)
			var tex: Texture2D = frames[int(floor(float(gf["frame"]) + 0.001))]
			if (gf["node"] as Sprite2D).texture != tex:
				(gf["node"] as Sprite2D).texture = tex
			continue
		var step := delta / maxf(0.01, float(gf["open_s"]))
		gf["lift"] = move_toward(float(gf["lift"]), float(gf["target"]), step)
		var mat := (gf["node"] as CanvasItem).material as ShaderMaterial
		mat.set_shader_parameter("lift", float(gf["lift"]))


## True while the cell sits under a gate arch whose grate is not up yet.
func gate_closed_at(cell: Vector2i) -> bool:
	for gf in gates_fx:
		# a door blocks until it is fully open; a portcullis once it is 3/4 up
		var need := 1.0 if str(gf["kind"]) in ["door", "fade"] else 0.75
		if (gf["block"] as Dictionary).has(cell) and float(gf["lift"]) < need - 0.0001:
			return true
	return false


func _sync_gate_glow() -> void:
	var on := lamps_lit()
	for gf in gates_fx:
		var glow: Sprite2D = gf.get("glow")
		if glow != null and glow.visible != on:
			glow.visible = on
		var gl: PointLight2D = gf.get("light")
		if gl != null and gl.enabled != (on and not lite):
			gl.enabled = on and not lite


func gate_fx(id: String) -> Dictionary:
	for gf in gates_fx:
		if str(gf["id"]) == id:
			return gf
	return {}


func _gate_sound(id: String, kind: String) -> void:
	gate_sound.emit(id, kind)


## Row by layer id (tests).
func row_of(id: int) -> Dictionary:
	for row in rows:
		if int(row["id"]) == id:
			return row
	return {}
