extends Node2D
class_name ProtoTileView

## Proposed prototype presentation only. Not used by the live duel BoardTile.

const TILE_WIDTH := 64
const TILE_HEIGHT := 32
const HALF_W := 32.0
const HALF_H := 16.0

var tile: ProtoBoardTile
var highlight: String = ""
var path_index: int = -1


func setup(data: ProtoBoardTile) -> void:
	tile = data
	position = iso_origin(data.grid_pos)
	z_index = ElevationZSort.z_index_for_tile(data.grid_pos, data.elevation)
	queue_redraw()


static func iso_origin(grid_pos: Vector2i) -> Vector2:
	return Vector2((grid_pos.x - grid_pos.y) * HALF_W, (grid_pos.x + grid_pos.y) * HALF_H)


func pillar_height() -> float:
	return tile.elevation * ElevationZSort.PROPOSED_PIXELS_PER_LEVEL


func top_points() -> PackedVector2Array:
	var h := pillar_height()
	return PackedVector2Array([
		Vector2(0, -HALF_H - h),
		Vector2(HALF_W, -h),
		Vector2(0, HALF_H - h),
		Vector2(-HALF_W, -h),
	])


func contains_local(point: Vector2) -> bool:
	var pts := top_points()
	return _point_in_diamond(point, pts)


func _draw() -> void:
	if tile == null:
		return
	var h := pillar_height()
	var fill := _terrain_color()
	if highlight == "reach":
		fill = fill.lerp(Color(0.25, 0.85, 1.0), 0.72)
	elif highlight == "path":
		fill = Color(0.98, 0.84, 0.22)
	elif highlight == "origin":
		fill = Color(1.0, 0.93, 0.38)
	elif highlight == "dest":
		fill = Color(0.98, 0.48, 0.20)

	if h > 0.5:
		var left := PackedVector2Array([
			Vector2(-HALF_W, 0),
			Vector2(0, HALF_H),
			Vector2(0, HALF_H - h),
			Vector2(-HALF_W, -h),
		])
		var right := PackedVector2Array([
			Vector2(0, HALF_H),
			Vector2(HALF_W, 0),
			Vector2(HALF_W, -h),
			Vector2(0, HALF_H - h),
		])
		draw_colored_polygon(left, fill.darkened(0.28))
		draw_colored_polygon(right, fill.darkened(0.18))

	var top := top_points()
	draw_colored_polygon(top, fill)
	var outline := PackedVector2Array(top)
	outline.append(top[0])
	var line := Color(0.18, 0.10, 0.12, 0.95)
	if not tile.walkable:
		line = Color(0.55, 0.12, 0.10)
	draw_polyline(outline, line, 1.4, true)

	var font := ThemeDB.fallback_font
	var label := _abbrev()
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	draw_string(font, Vector2(-size.x * 0.5, -h + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.10, 0.08, 0.10))


func _terrain_color() -> Color:
	match tile.terrain_type:
		TerrainDef.Kind.MUD:
			return Color(0.55, 0.32, 0.14)
		TerrainDef.Kind.WATER:
			return Color(0.18, 0.46, 0.82)
		TerrainDef.Kind.LAVA:
			return Color(0.92, 0.18, 0.08)
		_:
			var even := (tile.grid_pos.x + tile.grid_pos.y) % 2 == 0
			if even:
				return Color(0.78, 0.74, 0.62)
			return Color(0.86, 0.82, 0.70)


func _abbrev() -> String:
	var letter := "G"
	match tile.terrain_type:
		TerrainDef.Kind.MUD:
			letter = "M"
		TerrainDef.Kind.WATER:
			letter = "W"
		TerrainDef.Kind.LAVA:
			letter = "L"
	if is_equal_approx(tile.elevation, 0.0):
		return letter
	if is_equal_approx(tile.elevation, 0.5):
		return "%s½" % letter
	if is_equal_approx(tile.elevation, floor(tile.elevation)):
		return "%s%d" % [letter, int(tile.elevation)]
	return "%s%.1f" % [letter, tile.elevation]


func _point_in_diamond(point: Vector2, pts: PackedVector2Array) -> bool:
	var min_x := pts[3].x
	var max_x := pts[1].x
	var min_y := pts[0].y
	var max_y := pts[2].y
	if point.x < min_x or point.x > max_x or point.y < min_y or point.y > max_y:
		return false
	var cx := 0.0
	var cy := (min_y + max_y) * 0.5
	var nx := absf(point.x - cx) / HALF_W
	var ny := absf(point.y - cy) / HALF_H
	return nx + ny <= 1.02
