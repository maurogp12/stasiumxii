extends Node2D

## One walk-through decor sprite. It never blocks. Ground decals sit just above
## the floor; everything else y-sorts with props.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")

## Hero is 0.33, about 40px tall. Sunflowers land at his shoulder. Grass,
## flowers, mushrooms and small bushes stay between ankle and knee.
const TALL_PLANT_SCALE := 0.58
const LOW_PLANT_SCALE := 0.50

var decor_type := ""
## Kit sprite drawn for this decor. Same as decor_type except in the snow.
var art_id := ""
## Town snow on this cell (Northgate is 1). Set before setup.
var snow_cover := 0.0
var core := false
## A lamp glow: shown at night only, so it keeps its _process in performance mode.
var night_only := false:
	set(value):
		night_only = value
		if value:
			set_process(true)
var base_z := 0
var cover_rect := Rect2()
## True while an NPC (not the hero) stands behind this decor and it is faded.
var covering_npc := false
var _groundish := false
var _art: Dictionary = {}
var _sway: AnimatedSprite2D


func setup(zone: WorldZone, record: Dictionary) -> void:
	decor_type = str(record["type"])
	var cell := Vector2i(int(record["x"]), int(record["y"]))
	position = BoardVisualSort.cell_to_local(cell, float(zone.height_at(cell))) + Vector2(0, Pick.HALF_H)
	z_as_relative = false
	_groundish = decor_type.begins_with("decal_") or decor_type == "lilypads_a" or decor_type == "ford_stones"
	base_z = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + (1 if _groundish else 2)
	z_index = base_z
	core = _is_core(zone, cell)
	art_id = decor_type
	if snow_cover >= 0.5:
		art_id = Art.snow_decor_id(decor_type, cell)
	_art = Art.texture("props", art_id) if art_id != "" else {}
	# Snow swaps keep the plant's scale; the snow kit art is painted for it.
	var plant := _plant_scale(decor_type)
	scale = Vector2(plant, plant)
	if not _art.is_empty():
		var size := Art.size_of(_art) * plant
		cover_rect = Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	_apply_theme_tint(zone.zone_id)
	if VisualSettings.still():
		# Performance mode: a still plant, and no _process unless it is a lamp glow.
		set_process(night_only)
	elif not _groundish and core and art_id == decor_type:
		_sway = Art.make_loop(decor_type + "_sway")
		if _sway != null:
			_sway.visible = false
			add_child(_sway)
	queue_redraw()


func _apply_theme_tint(zone_id: String) -> void:
	if zone_id.find("westwatch") >= 0:
		if decor_type.find("bush") >= 0 or decor_type.find("tuft") >= 0 or decor_type.find("flower") >= 0:
			modulate = Color(0.52, 0.44, 0.64)
		elif decor_type.find("mushroom") >= 0:
			modulate = Color(0.78, 0.70, 0.86)
	elif zone_id.find("southbridge") >= 0 and (decor_type.find("reed") >= 0 or decor_type.find("mushroom") >= 0):
		modulate = Color(0.72, 0.78, 0.58)
	elif zone_id.find("eastmarch") >= 0 and decor_type.find("rock") >= 0:
		modulate = Color(0.95, 0.90, 0.78)


func _plant_scale(kind: String) -> float:
	match kind:
		"sunflowers_tall", "sunflowers_tall_b":
			return TALL_PLANT_SCALE
		"flowers_a", "flowers_b", "flowers_c", "flowers_d", \
		"grass_tuft_a", "grass_tuft_b", "grass_tuft_tall_a", \
		"tuft_a", "tuft_b", \
		"mushrooms_a", "mushrooms_b", \
		"bush_small_a", "bush_small_b", \
		"reeds_a", "reeds_b", \
		"rock_small_c", "rock_small_d":
			return LOW_PLANT_SCALE
		_:
			return 1.0


func _is_core(zone: WorldZone, cell: Vector2i) -> bool:
	if zone.terrain_at(cell) == "dirt_road":
		return true
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n: Vector2i = cell + step
		if zone.in_bounds(n) and zone.terrain_at(n) == "dirt_road":
			return true
	for prop in zone.props:
		var origin: Dictionary = prop.get("origin", {})
		var ox := int(origin.get("x", prop["footprint"][0]["x"]))
		var oy := int(origin.get("y", prop["footprint"][0]["y"]))
		if absi(ox - cell.x) + absi(oy - cell.y) <= 3:
			return true
	return false


## Same as the prop: fade over the hero, or over an NPC of the current chunk
## (`npc_feet` holds [feet, z] pairs). Returns true when the hero is behind.
func update_cover(walker_pos: Vector2, _walker_z: int, npc_feet: Array = []) -> bool:
	covering_npc = false
	if _groundish or cover_rect.size.y < 40.0:
		return false
	var hero := hides_feet(walker_pos)
	# Over the hero or an NPC the prop keeps its own depth and only fades.
	# Its depth already sorts it over whoever stands behind it. Dropping to
	# just above the hero sank a big building under the ground tiles and the
	# props in front of it, so it vanished instead of fading to 0.45.
	var top := base_z
	for pair in npc_feet:
		if hides_feet(pair[0]):
			covering_npc = true
			top = maxi(top, int(pair[1]) + 1)
	if hero or covering_npc:
		z_index = top
		modulate.a = 0.45
	else:
		z_index = base_z
		modulate.a = 1.0
	return hero


func hides_feet(feet: Vector2) -> bool:
	if _groundish or cover_rect.size.y < 40.0:
		return false
	var local := feet - position
	return cover_rect.grow(4).has_point(local) and local.y < -20.0


func has_sway() -> bool:
	return _sway != null


func _process(_delta: float) -> void:
	if night_only:
		modulate.a = 1.0 if _lamp_hour() else 0.0
	if _sway == null:
		return
	var on := VisualSettings.current != null and VisualSettings.current.enabled("animations")
	if _sway.visible != on:
		_sway.visible = on
		queue_redraw()


func _lamp_hour() -> bool:
	var host := get_parent()
	if host != null:
		host = host.get_parent()
	if host == null:
		return false
	var weather_node: Object = host.get("weather")
	if weather_node == null:
		return false
	var hour := float(weather_node.get("time_of_day"))
	return hour < 7.0 or hour >= 16.0


func _draw() -> void:
	if night_only and modulate.a < 0.01:
		return
	if _sway != null and _sway.visible:
		return
	if _art.is_empty():
		return
	var size := Art.size_of(_art)
	Art.draw_at(self, _art, Vector2(-size.x * 0.5, -size.y))
