extends SceneTree

## PC open world hero input: run on demand, stamina, the stamina bar, and a
## click sweep that every walkable cell takes a click at wide window sizes.
## Run:
##   godot --headless --path . -s res://tests/run_world_hero_input_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const HeroStamina := preload("res://scenes/world/crosshaven/hero_stamina.gd")

const SWEEP_ZONES := [
	"crosshaven_road_north",
	"crosshaven_crossroads",
	"crosshaven_northgate",
	"crosshaven_westwatch",
]
const SWEEP_SIZES := [Vector2i(1280, 768), Vector2i(1920, 1080)]

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


func _spawn() -> Node2D:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.set_process(false)
	return w


func _run() -> void:
	_test_stamina_unit()
	var w := _spawn()
	await process_frame
	_test_auto_walks(w)
	_test_double_click(w)
	_test_shift(w)
	_test_r_toggle(w)
	_test_drain_and_threshold(w)
	_test_regen(w)
	_test_bar(w)
	_test_npc_speed(w)
	_test_building_cover(w)
	await _test_north_road_pace(w)
	await _test_click_sweep(w)
	w.queue_free()
	print("world hero input tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _step(w: Node2D, seconds: float, dt: float = 0.05) -> void:
	var n := int(round(seconds / dt))
	for i in n:
		w.walker.advance(dt)
		w.tick_run(dt)


func _far_goal(w: Node2D) -> Vector2i:
	# A long walkable target so the hero keeps moving for the whole drain.
	var zone: WorldZone = w.zone
	var best := zone.spawn
	var best_len := 0
	for y in range(0, zone.height, 2):
		for x in range(0, zone.width, 2):
			var c := Vector2i(x, y)
			if not w._stand_free(c):
				continue
			var res: Dictionary = WorldWalk.find_path(w.map, zone.zone_id, zone.spawn, zone.zone_id, c, null, w._extra_blocked())
			var length := int(res.get("length", 0))
			if bool(res.get("ok", false)) and length > best_len:
				best_len = length
				best = c
	return best


func _home(w: Node2D) -> void:
	w.walker.place(w.zone, w.zone.spawn)
	w._route.clear()
	w._last_click_ms = 0
	w._shift_down = false
	w._click_run = false
	w.run_mode = false
	w.stamina.reset()
	w.tick_run(0.0)


func _key(w: Node2D, code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = down
	ev.shift_pressed = down and code == KEY_SHIFT
	root.push_input(ev)


func _test_stamina_unit() -> void:
	var s = HeroStamina.new()
	check(is_equal_approx(s.value, 1.0) and s.can_run(), "stamina starts full")
	check(is_equal_approx(HeroStamina.RUN_SECONDS, 8.0), "about 8 s of running from full")
	check(is_equal_approx(HeroStamina.REGEN_SECONDS, 6.0), "empty to full in about 6 s")
	check(is_equal_approx(HeroStamina.REGEN_DELAY, 1.0), "regen waits 1 s")
	check(is_equal_approx(HeroStamina.RESUME_AT, 0.2), "run resumes above 20%")
	for i in 40:
		s.tick(0.1, true)
	check(absf(s.value - 0.5) < 0.001, "4 s of running spends half (%.3f)" % s.value)
	for i in 40:
		s.tick(0.1, true)
	check(s.value <= 0.0 and s.winded and not s.can_run(), "8 s of running empties and winds")
	s.tick(0.9, false)
	check(s.value <= 0.0, "no regen inside the 1 s delay")
	s.tick(0.2, false)
	check(absf(s.value - 0.1 / 6.0) < 0.001, "regen starts after the delay (%.4f)" % s.value)
	for i in 10:
		s.tick(0.1, false)
	check(s.winded and s.value < 0.2, "still winded at %.2f" % s.value)
	for i in 3:
		s.tick(0.1, false)
	check(not s.winded and s.can_run(), "runs again once above 20%% (%.2f)" % s.value)
	s.reset()
	s.tick(0.1, true)
	for i in 10:
		s.tick(0.1, false)
	check(s.value < 1.0, "a run pause shorter than the delay does not refill")
	s.value = 0.0
	s._since_run = 1.0
	for i in 60:
		s.tick(0.1, false)
	check(is_equal_approx(s.value, 1.0), "6 s of rest after the delay fills from empty")


func _test_auto_walks(w: Node2D) -> void:
	_home(w)
	var goal := _far_goal(w)
	var res: Dictionary = w.walk_to(goal)
	check(bool(res.get("ok", false)) and int(res.get("length", 0)) >= 14, "a long click path (%d steps)" % int(res.get("length", 0)))
	check(w.walker.pace == "walk", "a long single click walks, no auto-run")
	_step(w, 0.5)
	check(w.walker.shown_pace() == "walk", "still walking mid-path")
	_home(w)
	w.walker.walk(_line(w, 16), "auto")
	check(w.walker.pace == "walk", "walker 'auto' walks a 16-step line")
	_home(w)


func _line(w: Node2D, n: int) -> Array[Vector2i]:
	var res: Dictionary = WorldWalk.find_path(w.map, w.zone.zone_id, w.zone.spawn, w.zone.zone_id, _far_goal(w), null, w._extra_blocked())
	var out: Array[Vector2i] = []
	var path: Array = res.get("path", [])
	for i in range(1, mini(path.size(), n + 1)):
		out.append(Vector2i(int(path[i]["x"]), int(path[i]["y"])))
	return out


func _test_double_click(w: Node2D) -> void:
	_home(w)
	var goal := _far_goal(w)
	w.walk_to(goal)
	check(w.walker.pace == "walk", "first click walks")
	w.walk_to(goal)
	check(w.walker.pace == "run", "double-click runs")
	_step(w, 0.3)
	check(w.walker.shown_pace() == "run", "double-click run shows the run strip")
	_home(w)
	w.walk_to(goal)
	w._last_click_ms = Time.get_ticks_msec() - 1000
	w.walk_to(goal)
	check(w.walker.pace == "walk", "two slow clicks still walk")
	_home(w)


func _test_shift(w: Node2D) -> void:
	_home(w)
	var goal := _far_goal(w)
	_key(w, KEY_SHIFT, true)
	check(w._shift_down, "Shift press is tracked")
	w.walk_to(goal)
	check(w.walker.pace == "run", "Shift-click runs")
	_key(w, KEY_SHIFT, false)
	check(not w._shift_down, "Shift release is tracked")
	_home(w)
	w.walk_to(goal)
	_step(w, 0.3)
	check(w.walker.shown_pace() == "walk", "plain click walks")
	_key(w, KEY_SHIFT, true)
	_step(w, 0.3)
	check(w.walker.shown_pace() == "run", "holding Shift while moving runs")
	_key(w, KEY_SHIFT, false)
	_step(w, 0.3)
	check(w.walker.shown_pace() == "walk", "letting go of Shift walks again")
	_home(w)


func _test_r_toggle(w: Node2D) -> void:
	_home(w)
	var goal := _far_goal(w)
	_key(w, KEY_R, true)
	_key(w, KEY_R, false)
	check(w.run_mode, "R turns run mode on")
	check(w._hud_label.text.contains("R run (on)"), "HUD shows run mode on")
	w.walk_to(goal)
	check(w.walker.pace == "run", "run mode runs a single click")
	_key(w, KEY_R, true)
	_key(w, KEY_R, false)
	check(not w.run_mode, "R turns run mode off")
	_step(w, 0.3)
	check(w.walker.shown_pace() == "walk", "run mode off drops to walk mid-path")
	_home(w)


func _test_drain_and_threshold(w: Node2D) -> void:
	_home(w)
	w.set_run_mode(true)
	var goal := _far_goal(w)
	w.walk_to(goal)
	var ran := 0.0
	while w.walker.is_moving() and w.stamina.can_run() and ran < 20.0:
		_step(w, 0.05)
		ran += 0.05
		if not w.walker.is_moving():
			w.walk_to(w.zone.spawn if w.walker.cell != w.zone.spawn else goal)
	check(ran > 7.5 and ran < 8.6, "continuous running empties stamina in about 8 s (%.2f s)" % ran)
	check(w.stamina.winded, "empty stamina winds the hero")
	if not w.walker.is_moving():
		w.walk_to(w.zone.spawn if w.walker.cell != w.zone.spawn else goal)
	_step(w, 0.2)
	check(w.walker.pace == "walk" and w.walker.shown_pace() == "walk", "winded hero drops to walk in run mode")
	var guard := 0
	while w.stamina.value <= 0.19 and guard < 400:
		if not w.walker.is_moving():
			w.walk_to(w.zone.spawn if w.walker.cell != w.zone.spawn else goal)
		_step(w, 0.05)
		guard += 1
	check(w.walker.pace == "walk", "still walking just under 20%")
	while w.stamina.value <= 0.21 and guard < 600:
		if not w.walker.is_moving():
			w.walk_to(w.zone.spawn if w.walker.cell != w.zone.spawn else goal)
		_step(w, 0.05)
		guard += 1
	if not w.walker.is_moving():
		w.walk_to(w.zone.spawn if w.walker.cell != w.zone.spawn else goal)
	_step(w, 0.1)
	check(w.walker.pace == "run", "run mode runs again above 20%% (%.2f)" % w.stamina.value)
	_home(w)


func _test_regen(w: Node2D) -> void:
	_home(w)
	w.stamina.value = 0.0
	w.stamina.winded = true
	w.stamina._since_run = 0.0
	_step(w, 0.95)
	check(w.stamina.value <= 0.0, "idle hero does not refill inside the delay")
	_step(w, 3.05)
	check(absf(w.stamina.value - 0.5) < 0.02, "idle refill is half after 3 s (%.3f)" % w.stamina.value)
	_step(w, 3.0)
	check(is_equal_approx(w.stamina.value, 1.0), "idle refill is full 6 s after the delay")
	# Walking also refills.
	w.stamina.value = 0.4
	w.stamina._since_run = 1.0
	w.walk_to(_far_goal(w))
	_step(w, 1.2)
	check(w.walker.is_moving() and w.walker.shown_pace() == "walk", "walking while refilling")
	check(absf(w.stamina.value - 0.6) < 0.02, "walking refills at the same rate (%.3f)" % w.stamina.value)
	_home(w)


func _test_bar(w: Node2D) -> void:
	_home(w)
	var bar: Control = w.stamina_bar
	check(bar != null, "HUD has a stamina bar")
	check(not bar.visible, "bar hides when full and not running")
	check(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bar never eats clicks")
	check(bar.position.x <= 60.0 and bar.position.y <= 200.0, "bar sits by the top-left info block")
	var text_bottom: float = w._hud_label.position.y + w._hud_label.get_minimum_size().y
	check(bar.position.y >= text_bottom, "bar clears the info text (%.0f vs text bottom %.0f)" % [bar.position.y, text_bottom])
	var box := bar.get_theme_stylebox("panel") as StyleBoxFlat
	check(box != null and box.border_color.is_equal_approx(Color(0.72, 0.58, 0.32)), "bar uses the HUD card border")
	w.set_run_mode(true)
	w.walk_to(_far_goal(w))
	_step(w, 0.2)
	check(bar.visible, "bar shows while running, even near full")
	_step(w, 2.0)
	var fill: ColorRect = w._stamina_fill
	var inner := bar.size.x - 6.0
	check(absf(fill.size.x - inner * w.stamina.value) < 0.5, "fill tracks stamina (%.1f of %.1f)" % [fill.size.x, inner])
	w.set_run_mode(false)
	_step(w, 0.3)
	check(bar.visible, "bar stays while stamina refills")
	w.walker.place(w.zone, w.zone.spawn)
	_step(w, 4.0)
	check(not bar.visible and w.stamina.is_full(), "bar hides again once full and idle")
	_home(w)


## NPC walkers keep their own art speed; the hero pace and run mode never reach them.
func _test_npc_speed(w: Node2D) -> void:
	_home(w)
	var npcs: Array = []
	for node in w.npcs_root.get_children():
		if not node.is_queued_for_deletion() and node.get("art") != null:
			npcs.append(node)
	check(npcs.size() > 0, "Crossroads has NPC nodes (%d)" % npcs.size())
	var before := {}
	for node in npcs:
		before[node] = node.Art.walk_speed(node.art)
		check(node.get_script() != w.walker.get_script(), "%s is not driven by the hero walker" % str(node.npc_id))
	w.set_run_mode(true)
	w.walk_to(_far_goal(w))
	_step(w, 1.0)
	for node in npcs:
		check(is_equal_approx(node.Art.walk_speed(node.art), before[node]), "%s walk speed unchanged by hero run (%.1f)" % [str(node.npc_id), before[node]])
	w.set_run_mode(false)
	_home(w)


## Hero deep behind a big building: the building fades to 0.45 at its own
## depth. It used to drop to just above the hero, under the ground rows and
## props in front of the hero, and vanish.
func _test_building_cover(w: Node2D) -> void:
	_home(w)
	var zone: WorldZone = w.zone
	var tall: Node2D = null
	var deep := Vector2i(-1, -1)
	var deep_gap := -1
	for p in w.props_root.get_children():
		if p.cover_rect.size.y <= 70.0:
			continue
		var south: Vector2i = p.south_cell
		for y in zone.height:
			for x in zone.width:
				var c := Vector2i(x, y)
				if not w._stand_free(c):
					continue
				var feet: Vector2 = w.props_root.to_local(w.to_global(w.walker._cell_pos(c)))
				if not p.hides_feet(feet):
					continue
				var gap := (south.x + south.y) - (c.x + c.y)
				if gap > deep_gap:
					deep_gap = gap
					deep = c
					tall = p
	check(tall != null and deep_gap >= 3, "found a big building with a hero cell %d rows behind it" % deep_gap)
	if tall == null:
		return
	w.walker.place(zone, deep)
	var covered: bool = w._cover_children(w.props_root, w.walker.position, w.walker.z_index, [])
	var south: Vector2i = tall.south_cell
	check(covered, "the hero at %s counts as covered by %s" % [str(deep), str(tall.prop_type)])
	check(tall.visible, "the building stays drawn")
	check(is_equal_approx(tall.modulate.a, 0.45), "the building fades to 0.45 (%.2f)" % tall.modulate.a)
	check(tall.z_index == tall.base_z, "the building keeps its own depth (%d vs base %d)" % [tall.z_index, tall.base_z])
	var o: Vector2i = w._origin_of(zone.zone_id)
	var ground_top: int = w.ground.row_z(o.x + o.y + south.x + south.y)
	check(tall.z_index > ground_top, "the building sorts above the ground at its foot (%d > %d)" % [tall.z_index, ground_top])
	var hero_row: int = o.x + o.y + deep.x + deep.y
	for r in range(hero_row + 1, o.x + o.y + south.x + south.y + 1):
		if tall.z_index <= w.ground.row_z(r):
			check(false, "ground row %d sorts over the faded building" % r)
			break
	check(tall.z_index > w.walker.z_index, "the faded building still draws over the hero behind it")
	w.walker.place(zone, zone.spawn)
	w._cover_children(w.props_root, w.walker.position, w.walker.z_index, [])
	check(is_equal_approx(tall.modulate.a, 1.0) and tall.z_index == tall.base_z, "the building is opaque again once the hero leaves")
	_home(w)


## Mauro's clip: North Road (15,11) to (20,11) took about 13 s. Re-clicks
## restarted the ease-in from 20% speed, and the cells near Northgate did not
## take a click at all. Now a single walk is under 4 s and a re-click keeps pace.
func _test_north_road_pace(w: Node2D) -> void:
	w.enter_zone("crosshaven_road_north", Vector2i(15, 11), false)
	await process_frame
	_home(w)
	w.walker.place(w.zone, Vector2i(15, 11))
	w._last_click_ms = 0
	var res: Dictionary = w.walk_to(Vector2i(20, 11))
	check(bool(res.get("ok", false)), "North Road (15,11) to (20,11) has a path")
	var t := 0.0
	while w.walker.is_moving() and t < 30.0:
		_step(w, 0.05)
		t += 0.05
	check(w.walker.cell == Vector2i(20, 11), "hero reaches (20,11)")
	check(t < 4.0, "five North Road cells take under 4 s at walk (%.2f s)" % t)
	# Start-up: at cruise within 0.7 s, any facing (was over 2 s east/west).
	var started := 0
	for goal in [Vector2i(20, 11), Vector2i(15, 16), Vector2i(10, 11), Vector2i(15, 6)]:
		w.walker.place(w.zone, Vector2i(15, 11))
		w._last_click_ms = 0
		var go: Dictionary = w.walk_to(goal)
		if not bool(go.get("ok", false)) or int(go.get("length", 0)) < 4:
			continue
		started += 1
		_step(w, 0.7)
		var t0: float = w.walker._traveled
		_step(w, 0.1)
		var v: float = (w.walker._traveled - t0) / 0.1
		check(w.walker.shown_pace() == "walk", "a single click toward %s walks" % str(goal))
		check(v > w.walker._cruise * 0.95, "at cruise 0.7 s after a start toward %s (%.1f of %.1f px/s)" % [str(goal), v, w.walker._cruise])
	check(started >= 2, "start-up checked in %d directions" % started)
	# Re-click while moving (slow, so not a double-click): speed stays at cruise.
	w.walker.place(w.zone, Vector2i(15, 11))
	w._last_click_ms = 0
	w.walk_to(Vector2i(20, 11))
	_step(w, 1.0)
	w._last_click_ms = 0
	w.walk_to(Vector2i(21, 11))
	check(w.walker.pace == "walk", "a slow re-click keeps walking")
	_step(w, 0.05)
	var moved: float = w.walker._traveled
	check(moved > w.walker.speed_of("walk") * 0.05 * 0.9, "a re-click keeps cruise speed, no fresh ease-in (%.2f px in 0.05 s)" % moved)
	# stop() ends on the cell he is on, not with a snap to the path end.
	w.walker.place(w.zone, Vector2i(15, 11))
	w._last_click_ms = 0
	w.walk_to(Vector2i(20, 11))
	_step(w, 0.4)
	w.walker.stop()
	_step(w, 3.0)
	var at: Vector2 = w.walker._cell_pos(w.walker.cell)
	check(not w.walker.is_moving() and w.walker.cell.x < 20, "stop halts short of the goal (%s)" % str(w.walker.cell))
	check(w.walker.position.distance_to(at) < 0.5, "stop leaves the sprite on its cell")
	# The old pick bug: these cells sit at world x + y < 0 and ranked below -1.
	var origin: Vector2i = w._origin_of("crosshaven_road_north")
	var c := Vector2i(5, 1)
	check(origin.x + origin.y + c.x + c.y < 0, "test cell is on a negative diagonal")
	var hit: Dictionary = w._pick_world(Vector2(BoardVisualSort.cell_to_local(origin + c, 0.0)))
	check(not hit.is_empty() and hit["cell"] == c, "negative-diagonal cell picks")
	_home(w)


## Click every walkable cell at its screen point and expect a path to that cell.
func _test_click_sweep(w: Node2D) -> void:
	var keep := root.size
	for size in SWEEP_SIZES:
		root.size = size
		await process_frame
		for zid in SWEEP_ZONES:
			w.enter_zone(zid, w.map.zone(zid).spawn, false)
			await process_frame
			check(w.zone != null and w.zone.zone_id == zid, "sweep enters %s" % zid)
			if w.zone == null or w.zone.zone_id != zid:
				continue
			await _sweep_zone(w, size)
	root.size = keep
	await process_frame


func _sweep_zone(w: Node2D, size: Vector2i) -> void:
	var zone: WorldZone = w.zone
	var zid := zone.zone_id
	var home: Vector2i = zone.spawn
	var origin: Vector2i = w._origin_of(zid)
	w.walker.place(zone, home)
	var reach: Dictionary = w.reachable_here()
	var total := 0
	var hidden := 0
	var pocket := 0
	var bad: Array = []
	var bad_pocket: Array = []
	for y in zone.height:
		for x in zone.width:
			var c := Vector2i(x, y)
			if c == home or not w._stand_free(c):
				continue
			total += 1
			var local := Vector2(BoardVisualSort.cell_to_local(origin + c, float(zone.height_at(c))))
			# Centre first, then toward each corner: a raised cell in front may
			# cover the centre but leave part of the diamond showing.
			var aim := Vector2.INF
			for off in [Vector2.ZERO, Vector2(0, -9), Vector2(18, 0), Vector2(-18, 0), Vector2(0, 9)]:
				var hit: Dictionary = w._pick_world(local + off)
				if not hit.is_empty() and hit["zone"] == zone and hit["cell"] == c:
					aim = local + off
					break
			if aim == Vector2.INF:
				hidden += 1
				continue
			w.walker.place(zone, home)
			w._route.clear()
			w._last_click_ms = 0
			w.bad_click_cell = Vector2i(-1, -1)
			w.camera.position = aim
			w.camera.reset_smoothing()
			w.camera.force_update_scroll()
			var canvas: Vector2 = w.get_canvas_transform() * w.to_global(aim)
			var win: Vector2 = root.get_final_transform() * canvas
			var move := InputEventMouseMotion.new()
			move.position = win
			move.global_position = win
			root.push_input(move)
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			down.position = win
			down.global_position = win
			root.push_input(down)
			var up: InputEventMouseButton = down.duplicate()
			up.pressed = false
			root.push_input(up)
			var q: Array = w.walker._queue
			var dest: Variant = q.back() if not q.is_empty() else null
			if reach.has(c):
				if w.hover_cell != c or w._hover_unreachable or dest != c or w.zone.zone_id != zid or not w._route.is_empty():
					bad.append(c)
			else:
				# Walkable but sealed off right now (an NPC in the only gap).
				pocket += 1
				var near: Vector2i = w.nearest_reachable(c)
				if not w._hover_unreachable or w.bad_click_cell != c or near.x < 0 or dest != near:
					bad_pocket.append(c)
	print("  sweep %s %s: %d walkable, %d clicked, %d hidden behind raised cells, %d sealed" % [zid, size, total, total - hidden, hidden, pocket])
	check(total > 50, "%s at %s has walkable cells (%d)" % [zid, size, total])
	check(hidden * 50 < total, "%s at %s: under 2%% of cells hidden (%d)" % [zid, size, hidden])
	check(bad.is_empty(), "%s at %s: every reachable cell takes a click (%d of %d missed, first %s)" % [zid, size, bad.size(), total, str(bad.slice(0, 6))])
	check(bad_pocket.is_empty(), "%s at %s: a sealed cell shows red, an X, and walks to the nearest reachable cell (%d bad, first %s)" % [zid, size, bad_pocket.size(), str(bad_pocket.slice(0, 6))])
	w.walker.place(zone, home)
	await process_frame
