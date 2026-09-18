extends Node2D
class_name ProtoTile

## Phase B+ prototype view. Proposed — not Locked.
## z_index is draw order only — gameplay elevation is data.elevation.

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

var data: BoardTileData
var highlight: String = ""
var cost_label: int = -1


func bind(tile: BoardTileData) -> void:
	data = tile
	position = tile.world_position + Vector2(0.0, ZSortHelper.visual_y_offset(tile.elevation))
	z_index = ZSortHelper.draw_order_index(tile.world_position, tile.elevation, 0.0)
	queue_redraw()


func set_highlight(kind: String, shown_cost: int = -1) -> void:
	highlight = kind
	cost_label = shown_cost
	queue_redraw()


func contains_local_point(local: Vector2) -> bool:
	# Diamond hit test in this node's local space (already elevation-shifted).
	var hx := TILE_WIDTH / 2.0
	var hy := TILE_HEIGHT / 2.0
	return (absf(local.x) / hx) + (absf(local.y) / hy) <= 1.0


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -TILE_HEIGHT / 2.0),
		Vector2(TILE_WIDTH / 2.0, 0),
		Vector2(0, TILE_HEIGHT / 2.0),
		Vector2(-TILE_WIDTH / 2.0, 0),
	])
	var color := _terrain_color()
	if highlight == "move":
		color = color.lerp(Color(0.40, 0.82, 0.95, 1.0), 0.62)
	elif highlight == "path":
		color = color.lerp(Color(1.0, 0.88, 0.28, 1.0), 0.70)
	elif highlight == "blocked":
		color = color.lerp(Color(0.55, 0.18, 0.18, 1.0), 0.45)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.16, 0.12, 0.14, 0.95), 1.2, true)

	if data != null and data.elevation > 0.04:
		var font := ThemeDB.fallback_font
		var elev_text := "%s" % _elev_text(data.elevation)
		var size := font.get_string_size(elev_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font, Vector2(-size.x * 0.5, -2), elev_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.12, 0.08, 0.08, 0.8))
	if cost_label >= 0:
		var font := ThemeDB.fallback_font
		var txt := str(cost_label)
		var size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(-size.x * 0.5, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.08, 0.1, 0.95))


func _terrain_color() -> Color:
	if data == null:
		return Color(0.7, 0.7, 0.7)
	var checker := (data.grid_position.x + data.grid_position.y) % 2 == 0
	var color := Color(0.62, 0.74, 0.48)
	match data.terrain_type:
		TerrainCatalog.Type.GROUND:
			color = Color(0.58, 0.72, 0.44) if checker else Color(0.50, 0.66, 0.38)
		TerrainCatalog.Type.MUD:
			color = Color(0.50, 0.36, 0.22) if checker else Color(0.42, 0.28, 0.16)
		TerrainCatalog.Type.WATER:
			color = Color(0.32, 0.58, 0.82) if checker else Color(0.24, 0.50, 0.74)
		TerrainCatalog.Type.LAVA:
			color = Color(0.86, 0.32, 0.14) if checker else Color(0.72, 0.18, 0.10)
	# Higher tiles read slightly lighter. Visual only.
	if data.elevation > 0.04:
		color = color.lightened(minf(data.elevation * 0.12, 0.28))
	return color


func _elev_text(elev: float) -> String:
	if is_equal_approx(elev, snappedf(elev, 1.0)):
		return "+%d" % int(round(elev))
	return "+%.1f" % elev
