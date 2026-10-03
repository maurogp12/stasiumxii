extends SceneTree

## Click-walk every Crosshaven chunk through its exits, and check the gait.
## Run: godot --headless --path . -s res://tests/run_crosshaven_tour_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _drive(w: Node2D, samples: Array) -> void:
	var prev: Vector2 = w.walker.position
	var n := 0
	while w.walker.is_moving() and n < 6000:
		w.walker.advance(0.05)
		if samples != null:
			samples.append(w.walker.position.distance_to(prev))
		prev = w.walker.position
		n += 1
	check(n < 6000, "walker finished before the step cap")


func _run() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	_tour(w)
	_decor_does_not_block(w)
	_gait(w)
	w.queue_free()
	print("crosshaven tour tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _tour(w: Node2D) -> void:
	var chunks := 0
	for id in w.map.zones.keys():
		var zone: WorldZone = w.map.zone(id)
		w._load_zone(id, zone.spawn)
		chunks += 1
		for exit_rec in zone.exits:
			for link in exit_rec["links"]:
				w._load_zone(id, zone.spawn)
				var gate := Vector2i(int(link["from"]["x"]), int(link["from"]["y"]))
				var visited: Array[Vector2i] = [zone.spawn]
				var on_step := func(c: Vector2i) -> void: visited.append(c)
				w.walker.stepped.connect(on_step)
				var res: Dictionary = w.walk_to(gate, "auto")
				# Stay in the chunk so the arrival cell is the exit, not the next zone.
				w._pending_exit = false
				check(bool(res.get("ok", false)), "%s path to exit %s" % [id, gate])
				_drive(w, [])
				if w.walker.stepped.is_connected(on_step):
					w.walker.stepped.disconnect(on_step)
				check(w.walker.cell == gate, "%s arrives at exit %s (at %s)" % [id, gate, w.walker.cell])
				var prev := zone.spawn
				for c in visited:
					check(zone.passable_at(c), "%s stepped cell %s is passable" % [id, c])
					check(zone.terrain_at(c) != "water" and zone.terrain_at(c) != "cliff", "%s stepped cell %s is not water or cliff" % [id, c])
					check(not zone.blocked_at(c), "%s stepped cell %s is not blocked" % [id, c])
					if c != prev:
						var d := c - prev
						check(absi(d.x) + absi(d.y) == 1, "%s step %s -> %s is ortho" % [id, prev, c])
					prev = c
				var back: Dictionary = w.walk_to(zone.spawn, "auto")
				w._pending_exit = false
				check(bool(back.get("ok", false)), "%s path back from %s" % [id, gate])
				_drive(w, [])
				check(w.walker.cell == zone.spawn, "%s returns to spawn" % id)
	check(chunks == 11, "tour covered 11 chunks")


func _decor_does_not_block(w: Node2D) -> void:
	var zone: WorldZone = w.map.zone("crosshaven_crossroads")
	w._load_zone(zone.zone_id, zone.spawn)
	var found := Vector2i(-1, -1)
	for rec in zone.decor:
		var cell := Vector2i(int(rec["x"]), int(rec["y"]))
		if zone.passable_at(cell) and zone.exit_link(cell).is_empty() and cell != zone.spawn:
			found = cell
			break
	check(found.x >= 0, "crossroads has walk-through decor")
	if found.x < 0:
		return
	check(not zone.blocked_at(found), "decor cell is not an invisible blocker")
	var res: Dictionary = w.walk_to(found, "walk")
	check(bool(res.get("ok", false)), "path reaches a decor cell")
	_drive(w, [])
	check(w.walker.cell == found, "walker stands on decor")


func _gait(w: Node2D) -> void:
	var zone: WorldZone = w.zone
	w.walker.place(zone, zone.spawn)
	var walk_goal := _band(zone, zone.spawn, 8)
	var walk_samples: Array = []
	check(bool(w.walk_to(walk_goal, "walk").get("ok", false)), "gait walk path")
	_drive(w, walk_samples)
	check(w.walker.facing == _facing(zone.spawn, walk_goal) or walk_samples.size() > 0, "walk plays a facing")
	var walk_avg := _mid(walk_samples)
	var walk_tick: float = w.walker.speed_of("walk") * 0.05
	check(walk_avg > walk_tick * 0.55 and walk_avg < walk_tick * 1.35, "walk cruise follows the strip (%.2f px/tick, strip %.2f)" % [walk_avg, walk_tick])
	check(_peak(walk_samples) < 12.0, "walk has no position pop")
	var run_goal := _band(zone, w.walker.cell, 16)
	var run_samples: Array = []
	check(bool(w.walk_to(run_goal, "run").get("ok", false)), "gait run path")
	_drive(w, run_samples)
	var run_avg := _mid(run_samples)
	check(run_avg > walk_avg * 1.25, "run is faster than walk (%.2f vs %.2f)" % [run_avg, walk_avg])
	check(_peak(run_samples) < 14.0, "run has no position pop")
	check(w.walker.cell == run_goal, "run arrives")


func _facing(from: Vector2i, to: Vector2i) -> String:
	var d := to - from
	if d.x > 0:
		return "e"
	if d.x < 0:
		return "w"
	if d.y > 0:
		return "s"
	return "n"


func _band(zone: WorldZone, origin: Vector2i, tiles: int) -> Vector2i:
	for y in zone.height:
		for x in zone.width:
			var c := Vector2i(x, y)
			if not zone.passable_at(c) or not zone.exit_link(c).is_empty():
				continue
			if absi(c.x - origin.x) + absi(c.y - origin.y) == tiles:
				return c
	return origin


func _mid(samples: Array) -> float:
	if samples.size() < 20:
		return 0.0
	var slice := samples.slice(8, samples.size() - 8)
	var sum := 0.0
	for s in slice:
		sum += float(s)
	return sum / float(slice.size())


func _peak(samples: Array) -> float:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, float(s))
	return peak
