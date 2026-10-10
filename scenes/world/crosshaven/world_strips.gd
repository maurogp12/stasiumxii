extends RefCounted

## Loads one world hero: the painted walk and idle of a class
## (`units/painted_looks.gd`, built by build_tools/pc_characters).
##
## Gaits: walk and run share the painted walk sheet; run plays it faster with
## a longer stride. idle is the painted idle loop. Every gait has the four
## facings n, e, s, w. e (down-right) is the art S sheet and n (up-right) the
## art E sheet; s and w draw those sheets mirrored (`flipped`), so only two
## sheets per kind are in memory. Only the class passed to load_class loads.
##
## Numbers come from PcCharacterSpecs.WORLD: one draw scale per class, and
## per gait `fps` and `stride` before the walker's hero pace scales.
## `stride` is world pixels traveled in one full loop of that gait, so ground
## speed is stride * fps / frame_count and the feet keep up with the art.

const Painted := preload("res://units/painted_looks.gd")
const DIRS := ["n", "e", "s", "w"]
const GAITS := ["walk", "run", "idle"]

var class_id := ""
var scale := 0.33
## Draw offset of the walk/idle cell for e (centred sprite). Mirrors share it.
var pivot := Vector2(0, -72)
var _world := {}
var _cell := Vector2i.ZERO
var _cell_pivot := Vector2i.ZERO
var _count := {}
var _sheets := {}
var _idle_cells := {}


func load_class(id: String) -> void:
	class_id = id.strip_edges().to_lower()
	_world = Painted.world(class_id)
	_sheets.clear()
	_count.clear()
	_idle_cells.clear()
	_cell = Painted.cell_of(class_id, "walk")
	_cell_pivot = Painted.pivot_of(class_id, "walk", "e")
	scale = float(_world.get("draw_scale", 0.33))
	pivot = _offset_for(_cell, _cell_pivot)
	if _world.is_empty():
		return
	for kind in ["walk", "idle"]:
		var art := {}
		for letter in ["S", "E"]:
			var tex := Painted.sheet(class_id, kind, letter)
			if tex != null:
				art[letter] = tex
		_sheets[kind] = art
		_count[kind] = Painted.frame_count(class_id, kind)


static func _offset_for(cell: Vector2i, ground: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * 0.5 - float(ground.x), float(cell.y) * 0.5 - float(ground.y))


func _kind(gait: String) -> String:
	return "idle" if gait == "idle" else "walk"


func has_gait(gait: String) -> bool:
	var art: Dictionary = _sheets.get(_kind(gait), {})
	return art.size() == 2


## The sheet a facing draws (before the mirror). s and w share e and n.
func texture(gait: String, dir: String) -> Texture2D:
	var art: Dictionary = _sheets.get(_kind(gait), {})
	return art.get(Painted.art_letter(dir), null)


## True when this facing draws its sheet mirrored (s and w).
func flipped(dir: String) -> bool:
	return Painted.mirrored(dir)


## Single idle cell (frame 0) for a stand-in that cannot play a strip.
func idle(dir: String) -> Texture2D:
	var key := Painted.art_letter(dir)
	if _idle_cells.has(key):
		return _idle_cells[key]
	var tex := texture("idle", dir)
	if tex == null:
		return null
	var piece := AtlasTexture.new()
	piece.atlas = tex
	piece.region = Rect2(Vector2.ZERO, Vector2(_cell))
	_idle_cells[key] = piece
	return piece


func frame_size(_gait: String) -> Vector2i:
	return _cell


func frame_size_of(_gait: String, _dir: String) -> Vector2i:
	return _cell


func draw_scale(_gait: String, _dir: String) -> float:
	return scale


## Centred-sprite offset that puts the ground point on the node. A mirrored
## facing flips the drawn rect around its centre, so its offset x flips too.
func draw_pivot(_gait: String, dir: String) -> Vector2:
	if flipped(dir):
		return Vector2(-pivot.x, pivot.y)
	return pivot


func frame_count(gait: String, _dir: String = "s") -> int:
	return int(_count.get(_kind(gait), 1))


func fps_of(gait: String, _dir: String = "s") -> float:
	var row: Dictionary = _world.get(gait, {})
	return float(row.get("fps", 8.0))


func stride_of(gait: String, _dir: String = "s") -> float:
	if gait == "idle":
		return 0.0
	var row: Dictionary = _world.get(gait, {})
	return float(row.get("stride", 24.0))


func speed_of(gait: String, dir: String = "s") -> float:
	var count := maxi(1, frame_count(gait, dir))
	return fps_of(gait, dir) * stride_of(gait, dir) / float(count)


## World px one planted foot travels in one walk cycle (measured on the art).
func foot_stride() -> float:
	return float(_world.get("foot_stride", 0.0))


## On-screen height above the ground at zoom 1.
func height() -> float:
	return float(_world.get("height", 0.0))
