extends Node2D

## VIEW ONLY. Draws one Crosshaven chunk's ground: terrain diamonds, height
## side faces, and exit markers. Walk data stays in `WorldZone` / `WorldWalk`.
##
## Art hook: a PNG at `TILE_ART_ROOT/<terrain id>.png` replaces the painted
## placeholder for that terrain, drawn like `board/tile.gd` (bottom on the
## diamond's south tip).

const TILE_ART_ROOT := "res://art/world/crosshaven/tiles/"
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")

const TOP := {
	"golden_plains": Color("d8c27a"),
	"dirt_road": Color("b48c5c"),
	"water": Color("3f8fc2"),
	"cliff": Color("8c857a"),
}
const SIDE := {
	"golden_plains": Color("9a7a46"),
	"dirt_road": Color("8a6a44"),
	"water": Color("2c6a92"),
	"cliff": Color("625c54"),
}
const EXIT_COLOR := Color(1.0, 0.84, 0.35, 0.85)

var zone: WorldZone
var _art: Dictionary = {}
var _exit_dirs: Dictionary = {}


## Ground is split into one canvas item per diagonal (x+y), z = diagonal * 10,
## so a raised tile in front covers the walker standing behind it.
static func row_z(diagonal: int) -> int:
	return diagonal * BoardVisualSort.TILE_Z_SCALE


func setup(target: WorldZone) -> void:
	zone = target
	for child in get_children():
		child.queue_free()
	_art.clear()
	for terrain in TOP.keys():
		var path := TILE_ART_ROOT + str(terrain) + ".png"
		if ResourceLoader.exists(path):
			_art[terrain] = load(path)
	_exit_dirs.clear()
	for exit_rec in zone.exits:
		var dir: Vector2i = WorldZone.EDGE_DIR.get(str(exit_rec["edge"]), Vector2i.ZERO)
		for link in exit_rec["links"]:
			var frm: Dictionary = link["from"]
			_exit_dirs[Vector2i(int(frm["x"]), int(frm["y"]))] = dir
	for d in range(zone.width + zone.height - 1):
		var row := Node2D.new()
		row.name = "Row%d" % d
		row.z_as_relative = false
		row.z_index = row_z(d)
		row.draw.connect(_draw_row.bind(row, d))
		add_child(row)


func has_art(terrain: String) -> bool:
	return _art.has(terrain)


func _draw_row(row: Node2D, s: int) -> void:
	var x0 := maxi(0, s - zone.height + 1)
	var x1 := mini(zone.width - 1, s)
	for x in range(x0, x1 + 1):
		var cell := Vector2i(x, s - x)
		_draw_cell(row, cell)
		if _exit_dirs.has(cell):
			_draw_exit(row, cell, _exit_dirs[cell])


func _draw_cell(ci: Node2D, cell: Vector2i) -> void:
	var terrain := zone.terrain_at(cell)
	var steps := zone.height_at(cell)
	var top: Color = TOP.get(terrain, Color.MAGENTA)
	var side: Color = SIDE.get(terrain, Color.DARK_MAGENTA)
	var lifted := Pick.diamond(cell, float(steps))
	if steps > 0:
		var drop := Vector2(0, float(steps) * BoardVisualSort.ELEVATION_PIXELS)
		ci.draw_colored_polygon(PackedVector2Array([lifted[3], lifted[2], lifted[2] + drop, lifted[3] + drop]), side)
		ci.draw_colored_polygon(PackedVector2Array([lifted[2], lifted[1], lifted[1] + drop, lifted[2] + drop]), side.darkened(0.18))
	if _art.has(terrain):
		var tex: Texture2D = _art[terrain]
		var size := tex.get_size()
		var center := BoardVisualSort.cell_to_local(cell, float(steps))
		ci.draw_texture(tex, center + Vector2(-size.x * 0.5, Pick.HALF_H - size.y))
		return
	# Painted placeholder: soft per-cell variation so the plains read hand-made.
	var n := _hash(cell)
	var tint := top.lightened(0.06 * n) if terrain != "water" else top.lightened(0.04 * n)
	ci.draw_colored_polygon(lifted, tint)
	if terrain == "golden_plains" and n > 0.72:
		var c := BoardVisualSort.cell_to_local(cell, float(steps))
		ci.draw_line(c + Vector2(-4, 2), c + Vector2(-2, -4), Color("a89048"), 1.0)
		ci.draw_line(c + Vector2(3, 3), c + Vector2(5, -3), Color("a89048"), 1.0)
	elif terrain == "water":
		var c := BoardVisualSort.cell_to_local(cell, float(steps))
		ci.draw_line(c + Vector2(-8, -1 + 3 * n), c + Vector2(6, -1 + 3 * n), Color(1, 1, 1, 0.22), 1.0)
	var edge := Color(0, 0, 0, 0.06)
	ci.draw_polyline(PackedVector2Array([lifted[0], lifted[1], lifted[2], lifted[3], lifted[0]]), edge, 1.0)


func _draw_exit(ci: Node2D, cell: Vector2i, dir: Vector2i) -> void:
	var c := Pick.cell_center(zone, cell)
	var screen_dir := Vector2(float(dir.x - dir.y) * Pick.HALF_W, float(dir.x + dir.y) * Pick.HALF_H).normalized()
	var side := Vector2(-screen_dir.y, screen_dir.x)
	var tip := c + screen_dir * 9.0
	ci.draw_colored_polygon(PackedVector2Array([tip, c - screen_dir * 3.0 + side * 6.0, c - screen_dir * 3.0 - side * 6.0]), EXIT_COLOR)


static func _hash(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000) / 1000.0
