extends Node2D
class_name ProtoPawn

## Phase B+ prototype view. Proposed — not Locked.
## z_index is draw order only — gameplay elevation is the tile's elevation.

var grid_position: Vector2i = Vector2i.ZERO
var facing: String = "E"
var kind: String = "pawn"

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}


func place(cell: Vector2i, tile: BoardTileData, occupant_kind: String = "pawn") -> void:
	grid_position = cell
	kind = occupant_kind
	var elev := 0.0 if tile == null else tile.elevation
	var world := ProtoBoard.iso_world(cell) if tile == null else tile.world_position
	position = world + Vector2(0.0, ZSortHelper.visual_y_offset(elev))
	var bias := ZSortHelper.UNIT_DRAW_BIAS if kind == "pawn" else ZSortHelper.UNIT_DRAW_BIAS * 0.5
	z_index = ZSortHelper.draw_order_index(world, elev, bias)
	queue_redraw()


func set_facing(dir: String) -> void:
	if dir == "" or dir == facing:
		return
	facing = dir
	queue_redraw()


func _draw() -> void:
	if kind == "blocker":
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(12, -8), Vector2(0, 4), Vector2(-12, -8)
		]), Color(0.28, 0.26, 0.30))
		draw_circle(Vector2(0, -10), 7.0, Color(0.38, 0.36, 0.40))
		return
	draw_circle(Vector2(0, -14), 11.0, Color(0.28, 0.62, 0.78))
	draw_arc(Vector2(0, -14), 11.0, 0.0, TAU, 24, Color(0.08, 0.10, 0.14), 1.6, true)
	var pointer: Vector2 = FACING_ISO.get(facing, Vector2(20, 10))
	var tip := Vector2(0, -14) + pointer.normalized() * 18.0
	draw_line(Vector2(0, -14), tip, Color(0.08, 0.10, 0.14), 2.0, true)
	draw_circle(tip, 2.4, Color(0.08, 0.10, 0.14))
	var font := ThemeDB.fallback_font
	var label := "Pawn"
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(-size.x * 0.5, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.08, 0.1))
