extends Node2D

## VIEW ONLY. Draws a TileCity (backend/tile_city.gd): the autotiled ground
## (one canvas item, drawn once) and every piece as a y-sorted sprite whose
## foot is its anchor cell's south corner. Pieces use the same absolute z
## formula as the walker (world y), so the hero sorts among them.

const PlateCity := preload("res://backend/plate_city.gd")
const GROUND_Z := -4000

var city: TileCity
var ground: Node2D
var piece_nodes: Array = []
var _tex := {}
var ground_tiles_drawn := 0


func setup(tc: TileCity) -> void:
	city = tc
	name = "TileCity"
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_as_relative = false
	ground.z_index = GROUND_Z
	ground.draw.connect(_draw_ground)
	add_child(ground)
	_build_pieces()


func tex(file: String) -> Texture2D:
	if _tex.has(file):
		return _tex[file]
	var path := city.kit_dir.path_join(file)
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[file] = t
	return t


func _draw_ground() -> void:
	var tw := float(city.kit["tile_px"][0])
	var th := float(city.kit["tile_px"][1])
	var size := city.tile
	ground_tiles_drawn = 0
	for y in city.height + 1:
		for x in city.width + 1:
			var v := Vector2i(x, y)
			var layers := city.corner_layers(v)
			if layers.is_empty():
				continue
			# the vertex is the top corner of cell (x, y)
			var at := city.cell_to_world(Vector2(x, y)) - Vector2(0, size.y * 0.5)
			var rect := Rect2(at - size * 0.5, size)
			for l in layers:
				var t: Dictionary = l[0]
				var atlas := tex(str(t["atlas"]))
				if atlas == null:
					continue
				ground.draw_texture_rect_region(atlas, rect, Rect2(float(int(l[1])) * tw, 0.0, tw, th))
				ground_tiles_drawn += 1


func _build_pieces() -> void:
	piece_nodes.clear()
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
		s.offset = -Vector2(float(spec["foot"][0]), float(spec["foot"][1]))
		s.position = foot
		s.z_as_relative = false
		s.z_index = clampi(PlateCity.z_for_world_y(foot.y), -4096, 4096)
		s.name = "%s_%d" % [str(p["kind"]), i]
		add_child(s)
		piece_nodes.append({"node": s, "piece": p, "foot": foot})
		i += 1


## Sort key of a body standing at world `feet` (same formula as the pieces).
static func z_at(feet: Vector2) -> int:
	return PlateCity.z_for_world_y(feet.y)
