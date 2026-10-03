extends SceneTree

## WP12: one Crosshaven plane, no chunk overlap, no black fade between towns.
## Run: godot --headless --path . -s res://tests/run_wp12_tests.gd

const WorldPlane := preload("res://backend/world_plane.gd")
const Maps := preload("res://backend/world_map.gd")
const Walk := preload("res://backend/world_walk.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_plane()
	_test_walk_and_camera()
	_test_save()
	print("wp12 tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_plane() -> void:
	var opened: Dictionary = Maps.load_default()
	eq(bool(opened.get("ok", false)), true, "Crosshaven map loads")
	if not bool(opened.get("ok", false)):
		return
	var map: WorldMap = opened["map"]
	var lay: Dictionary = WorldPlane.layout(map)
	eq(bool(lay.get("ok", false)), true, "exit links agree and no chunk overlaps (%s / %s)" % [str(lay.get("conflicts", [])), str(lay.get("overlaps", []))])
	var offsets: Dictionary = lay.get("offsets", {})
	eq(offsets.get("crosshaven_crossroads", Vector2i(1, 1)), Vector2i.ZERO, "Crossroads sits at (0, 0)")
	eq(offsets.size(), map.zones.size(), "every chunk has an origin")
	var overlaps: Array = lay.get("overlaps", [])
	eq(overlaps.is_empty(), true, "no two chunks share a cell")
	var sw: Vector2i = offsets["crosshaven_road_southwest"]
	var ww: Vector2i = offsets["crosshaven_westwatch"]
	var west: Vector2i = offsets["crosshaven_road_west"]
	eq(sw.y > 0 and sw.x < 0, true, "the south-west road leaves the south-west side (%s)" % str(sw))
	eq(ww.x < sw.x and ww.y >= sw.y, true, "Westwatch sits south-west of that road (%s)" % str(ww))
	eq(_rects_hit(sw, 32, 32, west, 36, 24), false, "road_southwest no longer covers road_west")
	var touch: Array = WorldPlane.touching(map, offsets, "crosshaven_crossroads")
	eq(touch.has("crosshaven_road_north"), true, "the north road touches the Crossroads")
	eq(touch.has("crosshaven_road_southwest"), true, "the south-west road touches the Crossroads")
	var there: Dictionary = Walk.find_path(map, "crosshaven_crossroads", Vector2i(22, 18), "crosshaven_northgate", Vector2i(20, 12))
	eq(bool(there.get("ok", false)), true, "a path still reaches Northgate")
	var ford: Dictionary = Walk.find_path(map, "crosshaven_crossroads", Vector2i(22, 18), "crosshaven_westwatch", Vector2i(16, 10))
	eq(bool(ford.get("ok", false)), true, "a path still reaches Westwatch")


func _rects_hit(a: Vector2i, aw: int, ah: int, b: Vector2i, bw: int, bh: int) -> bool:
	return a.x < b.x + bw and b.x < a.x + aw and a.y < b.y + bh and b.y < a.y + ah


func _test_walk_and_camera() -> void:
	var w := _spawn()
	eq(w.transition_count, 0, "startup does not count as a later enter_zone")
	eq(w.neighbours.get_child_count() > 0, true, "touching neighbours are loaded at the Crossroads")
	eq(w.ground.call("marker_dir", Vector2i(18, 0)), Vector2i.ZERO, "a walkable edge hides its exit arrow")
	var floor_id := str(Art.pick_tile(w.zone, Vector2i(20, 0))["floor"])
	eq(floor_id.begins_with("dirt_road_edge"), false, "the north road does not grow a grass edge (%s)" % floor_id)
	eq(w._chunk_at(Vector2i(-4, -8)).is_empty(), true, "the plate-field still sits where no chunk exists")
	var before: int = w.transition_count
	var fades := 0
	var prev: Vector2 = w.camera.position
	var worst := 0.0
	var hopped := false
	w.walk_to_zone("crosshaven_northgate", Vector2i(20, 12), "run")
	var guard := 0
	while (w.walker.is_moving() or not w._route.is_empty()) and guard < 8000:
		var alpha := float(w._fade.color.a)
		if alpha > 0.01:
			fades += 1
		w.walker.advance(0.05)
		w._process(0.05)
		var delta: float = w.camera.position.distance_to(prev)
		if delta > worst:
			worst = delta
		if guard > 2 and delta > 96.0:
			hopped = true
		prev = w.camera.position
		guard += 1
	eq(w.zone.zone_id, "crosshaven_northgate", "the walk arrives in Northgate")
	eq(w.walker.cell, Vector2i(20, 12), "the walk stops on the Northgate square")
	eq(w.transition_count, before, "Northgate did not call enter_zone")
	eq(w.seam_count > 0, true, "the edge was a seam")
	eq(fades, 0, "the edge did not black-fade")
	eq(hopped, false, "camera position stays continuous (worst step %.1f px)" % worst)
	var band_town: String = w.level_band
	var music_town: String = w.music_id
	eq(band_town != "", true, "Northgate has a level band")
	w.walk_to_zone("crosshaven_stoneford", Vector2i(16, 16), "run")
	guard = 0
	while (w.walker.is_moving() or not w._route.is_empty()) and guard < 12000:
		if float(w._fade.color.a) > 0.01:
			fades += 1
		w.walker.advance(0.05)
		w._process(0.05)
		var step: float = w.camera.position.distance_to(prev)
		if guard > 2 and step > 96.0:
			hopped = true
		prev = w.camera.position
		guard += 1
	eq(w.zone.zone_id, "crosshaven_stoneford", "the walk arrives in Stoneford")
	eq(w.walker.cell, Vector2i(16, 16), "the walk stops on the Stoneford square")
	eq(w.transition_count, before, "Stoneford did not call enter_zone")
	eq(fades, 0, "the ring did not black-fade")
	eq(hopped, false, "camera stays continuous through Stoneford")
	eq(w.music_id != "", true, "music id is set (%s)" % w.music_id)
	eq(w.level_band != "", true, "level band is set (%s)" % w.level_band)
	# Crossroads is level 1. Northgate is 10–20. Crossing back retargets the band.
	w.walk_to_zone("crosshaven_crossroads", Vector2i(22, 18), "run")
	guard = 0
	while (w.walker.is_moving() or not w._route.is_empty()) and guard < 8000:
		w.walker.advance(0.05)
		guard += 1
	eq(w.zone.zone_id, "crosshaven_crossroads", "the walk returns to the Crossroads")
	eq(w.level_band != band_town or w.music_id != music_town, true, "band or music changes between town and heart (%s / %s)" % [w.level_band, w.music_id])
	eq(w.camera.limit_right - w.camera.limit_left > 2000, true, "camera limits cover more than one chunk")
	w.free()


func _test_save() -> void:
	var path := "user://pc_progress.json"
	var backup := ""
	var had := FileAccess.file_exists(path)
	if had:
		backup = FileAccess.get_file_as_string(path)
	var w := _spawn()
	w.enter_zone("crosshaven_stoneford", Vector2i(16, 16), false)
	w.remember_place()
	var id: String = w.zone.zone_id
	var cell: Vector2i = w.walker.cell
	w.free()
	var again := _spawn()
	eq(again.zone.zone_id, "crosshaven_crossroads", "a headless launch still starts at the Crossroads")
	eq(again.restore_place(), true, "restore_place returns the saved cell")
	eq(again.zone.zone_id, id, "save/load keeps the zone")
	eq(again.walker.cell, cell, "save/load keeps the cell")
	var hero := Progress.new()
	eq(hero.world_zone, id, "the save file stores the zone")
	eq(hero.world_cell, cell, "the save file stores the cell")
	again.free()
	if had:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _spawn() -> Node2D:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	return w


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
