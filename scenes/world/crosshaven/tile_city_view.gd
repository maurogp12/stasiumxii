extends Node2D

## VIEW ONLY. Draws a TileCity (backend/tile_city.gd): the autotiled ground
## (one canvas item, drawn once; mask-15 tiles pick a full-tile variant), the
## animated water layer (its own canvas item, redrawn at the kit fps), and
## every piece as a y-sorted sprite whose foot is its anchor (or world_foot).
## Gate pieces with a door strip get the door as its own sprite just under
## the curtain (kit layer order: ground < door < curtain < actors).

const PlateCity := preload("res://backend/plate_city.gd")
const GROUND_Z := -4000
const UNDER_Z := -3900

var city: TileCity
var ground: Node2D
var water: Node2D
var piece_nodes: Array = []
var door_nodes: Dictionary = {}
var _tex := {}
var ground_tiles_drawn := 0
var water_tiles_drawn := 0
var water_frame := 0
var _water_t := 0.0
var _water_cells: Array = []
var _water_terrain: Dictionary = {}
var _animated: Array = []
var _anim_t := 0.0


func setup(tc: TileCity) -> void:
	city = tc
	name = "TileCity"
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_as_relative = false
	ground.z_index = GROUND_Z
	ground.draw.connect(_draw_ground)
	add_child(ground)
	for t in city.kit["terrains"]:
		if t.has("anim"):
			_water_terrain = t
	if not _water_terrain.is_empty():
		water = Node2D.new()
		water.name = "Water"
		water.z_as_relative = false
		water.z_index = GROUND_Z + 1
		water.draw.connect(_draw_water)
		add_child(water)
	_build_pieces()


func tex(file: String) -> Texture2D:
	if _tex.has(file):
		return _tex[file]
	var path := city.kit_dir.path_join(file).simplify_path()
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[file] = t
	return t


func _src_rect(t: Dictionary, mask: int, frame: int = 0, v: Vector2i = Vector2i.ZERO) -> Array:
	var tw := float(city.kit["tile_px"][0])
	var th := float(city.kit["tile_px"][1])
	var cols := int(t.get("atlas_cols", 16))
	if mask == 15 and t.has("full_variants") and frame == 0:
		# full tiles: the atlas tile or one of the variants, picked by the vertex
		var n := int(t.get("variants", 3))
		var pick := absi(hash(v)) % (n + 1)
		if pick > 0:
			return [tex(str(t["full_variants"])), Rect2((pick - 1) * tw, 0, tw, th)]
	var x := float(mask % cols) * tw
	var y := float(mask / cols) * th
	var file := str(t["atlas"])
	if frame > 0 and t.has("anim"):
		file = str(t["anim"])
		x += float(frame) * tw * float(cols)
	return [tex(file), Rect2(x, y, tw, th)]


func _draw_ground() -> void:
	var size := city.tile
	ground_tiles_drawn = 0
	_water_cells.clear()
	for y in city.height + 1:
		for x in city.width + 1:
			var v := Vector2i(x, y)
			var layers := city.corner_layers(v)
			if layers.is_empty():
				continue
			var at := city.cell_to_world(Vector2(x, y)) - Vector2(0, size.y * 0.5)
			var rect := Rect2(at - size * 0.5, size)
			for l in layers:
				var t: Dictionary = l[0]
				if t.has("anim") and water != null:
					_water_cells.append([rect, int(l[1]), v])
					continue
				var src: Array = _src_rect(t, int(l[1]), 0, v)
				if src[0] == null:
					continue
				ground.draw_texture_rect_region(src[0], rect, src[1])
				ground_tiles_drawn += 1
	if water != null:
		water.queue_redraw()


func _draw_water() -> void:
	water_tiles_drawn = 0
	for w in _water_cells:
		var src: Array = _src_rect(_water_terrain, int(w[1]), water_frame, w[2])
		if src[0] == null:
			continue
		water.draw_texture_rect_region(src[0], w[0], src[1])
		water_tiles_drawn += 1


## Water and animated pieces at the kit fps.
func tick(delta: float) -> void:
	_anim_t += delta
	for pn in _animated:
		var a: Dictionary = pn["anim"]
		var f := int(_anim_t * float(a.get("fps", 8.0))) % int(a.get("frames", 1))
		(pn["node"] as Sprite2D).region_rect = Rect2(float(f) * float(a["frame_w"]), 0, float(a["frame_w"]), float(a["frame_h"]))
	if water == null or _water_terrain.is_empty():
		return
	_water_t += delta
	var f := int(_water_t * float(_water_terrain.get("anim_fps", 8.0))) % int(_water_terrain.get("anim_frames", 1))
	if f != water_frame:
		water_frame = f
		water.queue_redraw()


func _build_pieces() -> void:
	piece_nodes.clear()
	door_nodes.clear()
	var k := city.kit_scale()
	var i := 0
	for p in city.pieces():
		var spec := city.piece_spec(p)
		var s := Sprite2D.new()
		s.texture = tex(str(spec["file"]))
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.scale = Vector2.ONE * k
		var foot := city.piece_foot(p)
		var fx := float(spec["foot"][0])
		if bool(p.get("flip", false)) and s.texture != null:
			s.flip_h = true
			fx = float(s.texture.get_width()) - fx
		# top-left placement (the plate view's fade and masks expect it)
		s.position = foot - Vector2(fx, float(spec["foot"][1])) * k
		s.z_as_relative = false
		if bool(p.get("under", false)):
			s.z_index = UNDER_Z + i % 50
		else:
			s.z_index = clampi(PlateCity.z_for_world_y(foot.y), -4096, 4096)
		s.name = "%s_%d" % [str(p["kind"]), i]
		add_child(s)
		var pn := {"node": s, "piece": p, "foot": foot}
		var glow: Dictionary = spec.get("glow", {})
		if not glow.is_empty():
			# the kit's additive night glow, riding on its parent
			var gs := Sprite2D.new()
			gs.texture = tex(str(glow["file"]))
			gs.centered = false
			gs.scale = s.scale
			var off := Vector2(float(glow["offset"][0]), float(glow["offset"][1]))
			if s.flip_h and s.texture != null and gs.texture != null:
				gs.flip_h = true
				off.x = float(s.texture.get_width()) - off.x - float(gs.texture.get_width())
			gs.position = s.position + off * k
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			gs.material = add
			gs.z_as_relative = false
			gs.z_index = clampi(s.z_index + 1, -4096, 4096)
			gs.visible = false
			gs.name = "%s_glow" % s.name
			add_child(gs)
			pn["glow"] = gs
		var anim: Dictionary = spec.get("anim", {})
		if not anim.is_empty():
			# an animated strip replaces the still (fountain, mill wheel, smoke)
			var at := tex(str(anim["file"]))
			if at != null:
				s.texture = at
				s.region_enabled = true
				s.region_rect = Rect2(0, 0, float(anim["frame_w"]), float(anim["frame_h"]))
				pn["anim"] = anim
				_animated.append(pn)
		piece_nodes.append(pn)
		var door: Dictionary = spec.get("door", {})
		if not door.is_empty():
			var d := Sprite2D.new()
			d.texture = tex(str(door["file"]))
			d.centered = false
			d.region_enabled = true
			d.region_rect = Rect2(0, 0, float(door["frame_w"]), float(door["frame_h"]))
			d.scale = s.scale
			d.position = s.position + Vector2(float(door["offset"][0]), float(door["offset"][1])) * k
			d.z_as_relative = false
			d.z_index = s.z_index - 1
			d.name = "door_%s" % str(p.get("gate", i))
			add_child(d)
			door_nodes[str(p.get("gate", i))] = {"node": d, "spec": door}
		i += 1


## Door frame `f` (0 shut .. frames-1 open) for gate `id`.
func set_door_frame(id: String, f: int) -> void:
	if not door_nodes.has(id):
		return
	var dn: Dictionary = door_nodes[id]
	var spec: Dictionary = dn["spec"]
	var fw := float(spec["frame_w"])
	(dn["node"] as Sprite2D).region_rect = Rect2(float(clampi(f, 0, int(spec["frames"]) - 1)) * fw, 0, fw, float(spec["frame_h"]))


## Sort key of a body standing at world `feet` (same formula as the pieces).
static func z_at(feet: Vector2) -> int:
	return PlateCity.z_for_world_y(feet.y)
