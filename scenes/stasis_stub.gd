extends Control
class_name StasisStub

## Placeholder Stasis run. Names the biome and can draw that biome's
## existing 15×15 tags as a non-combat preview. No dungeon layout, loot,
## keys, trash, or boss. Back returns to the hub.

var _auto_launch: bool = true
var _biome_id: String = ""
var _title: Label
var _blurb: Label
var _status: Label
var _preview: TagsPreview
var _tags_ok: bool = false
var _tags_path: String = ""
var _board_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_biome_id = MobileHub.pending_biome_id.strip_edges().to_lower()
	_build()
	_apply_biome(_biome_id)


func biome_id() -> String:
	return _biome_id


func title_text() -> String:
	if _title == null:
		return ""
	return _title.text


func status_text() -> String:
	if _status == null:
		return ""
	return _status.text


func tags_ok() -> bool:
	return _tags_ok


func loaded_tags_path() -> String:
	return _tags_path


func board_size() -> Vector2i:
	return _board_size


func preview_cells() -> int:
	if _preview == null:
		return 0
	return _preview.cell_count()


func back_to_hub() -> void:
	if not _auto_launch:
		return
	get_tree().change_scene_to_file(MobileHub.MOBILE_HUB)


func _apply_biome(map_id: String) -> void:
	_tags_ok = false
	_tags_path = ""
	_board_size = Vector2i.ZERO
	if _preview != null:
		_preview.clear_board()
	if not MobileHub.is_biome_id(map_id):
		_title.text = "Stasis"
		_blurb.text = "Stub run. No rooms, loot, or combat."
		_status.text = "Stasis coming soon. Open a biome door from the hub."
		return
	var id := map_id.strip_edges().to_lower()
	_title.text = "%s Stasis" % MobileHub.title_of(id)
	_blurb.text = CellTagMap.blurb_of(id)
	_tags_path = MobileHub.tags_path(id)
	var tags := CellTagMap.load_file(_tags_path)
	var width := int(tags.get("width", 0))
	var height := int(tags.get("height", 0))
	if bool(tags.get("ok", false)) and width == 15 and height == 15:
		_tags_ok = true
		_board_size = Vector2i(width, height)
		_preview.set_tags(tags)
		_status.text = "Stasis coming soon. Room 1 can load this 15×15 tags board later. This preview is not a fight."
		return
	_status.text = "Stasis coming soon. This biome's tags board did not load."


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(_title)

	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(_blurb)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	col.add_child(_status)

	_preview = TagsPreview.new()
	_preview.custom_minimum_size = Vector2(0, 240)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_preview)

	var back := Button.new()
	back.text = "Back to hub"
	back.custom_minimum_size = Vector2(0, 72)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	back.add_theme_stylebox_override("normal", _back_style(false))
	back.add_theme_stylebox_override("hover", _back_style(true))
	back.add_theme_stylebox_override("pressed", _back_style(true))
	back.add_theme_stylebox_override("focus", _back_style(true))
	back.pressed.connect(back_to_hub)
	col.add_child(back)


func _back_style(lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.24, 0.18) if lit else Color(0.18, 0.16, 0.14)
	style.border_color = Color(0.93, 0.78, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


class TagsPreview extends Control:
	## Flat squares from the ship tags file. Colors are BoardTile.fill_color
	## (the same terrain fills the duel board uses under its art). Not a fight.

	var _colors: Dictionary = {}
	var _width: int = 0
	var _height: int = 0


	func _ready() -> void:
		if not resized.is_connected(queue_redraw):
			resized.connect(queue_redraw)


	func cell_count() -> int:
		return _colors.size()


	func clear_board() -> void:
		_colors.clear()
		_width = 0
		_height = 0
		queue_redraw()


	func set_tags(tags: Dictionary) -> void:
		_colors.clear()
		_width = int(tags.get("width", 0))
		_height = int(tags.get("height", 0))
		var probe := BoardTile.new()
		for item in tags.get("cells", []):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = item
			var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
			if pos.x < 0 or pos.y < 0:
				continue
			probe.terrain_type = str(rec.get("terrain", "ground"))
			probe.grid_position = pos
			_colors[pos] = probe.fill_color()
		probe.free()
		queue_redraw()


	func _draw() -> void:
		if _width <= 0 or _height <= 0 or size.x <= 1.0 or size.y <= 1.0:
			return
		var gap := 1.0
		var cell := minf((size.x - gap * float(_width - 1)) / float(_width), (size.y - gap * float(_height - 1)) / float(_height))
		if cell <= 0.0:
			return
		var board := Vector2(cell * float(_width) + gap * float(_width - 1), cell * float(_height) + gap * float(_height - 1))
		var origin := (size - board) * 0.5
		for key in _colors.keys():
			var pos: Vector2i = key
			var at := origin + Vector2(float(pos.x) * (cell + gap), float(pos.y) * (cell + gap))
			draw_rect(Rect2(at, Vector2(cell, cell)), _colors[key])
