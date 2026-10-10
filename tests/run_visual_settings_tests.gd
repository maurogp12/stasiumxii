extends SceneTree

## Visual settings: toggles, presets, and the on-disk store.
## Run: godot --headless --path . -s res://tests/run_visual_settings_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

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


func _run() -> void:
	var fresh := VisualSettings.new()
	fresh.apply_preset("Full")
	for flag in VisualSettings.FLAGS:
		check(fresh.enabled(flag), "full starts with %s" % flag)
	fresh.set_flag("weather", false)
	check(not fresh.enabled("weather"), "weather toggles off")
	check(fresh.preset == "Custom", "mixed flags are a custom preset")
	fresh.set_flag("weather", true)
	check(fresh.enabled("weather") and fresh.preset == "Full", "weather toggles back on")
	var reloaded := VisualSettings.new()
	check(reloaded.enabled("weather") and reloaded.preset == "Full", "full persists after a new load")
	reloaded.apply_preset("Minimal")
	var after := VisualSettings.new()
	for flag in VisualSettings.FLAGS:
		check(not after.enabled(flag), "minimal persists %s off" % flag)
	after.apply_preset("Reduced")
	check(after.enabled("animations") and after.enabled("decor"), "reduced keeps motion and clutter")
	check(not after.enabled("weather") and not after.enabled("post_fx") and not after.enabled("sway_shadows"), "reduced drops weather, grade, and shadow sway")
	var world: Node2D = WORLD.instantiate()
	world.instant_transitions = true
	root.add_child(world)
	world.settings.apply_preset("Minimal")
	check(not world.decor_root.visible, "minimal hides decor")
	check(not world.weather.visuals_enabled, "minimal hides weather particles")
	world.settings.apply_preset("Reduced")
	var saw_core := false
	var fill_visible := false
	for d in world.decor_root.get_children():
		if d.core:
			saw_core = saw_core or d.visible
		elif d.visible:
			fill_visible = true
	check(saw_core, "reduced keeps decor along roads and buildings")
	check(not fill_visible, "reduced hides open-field decor")
	world.settings.apply_preset("Full")
	check(world.decor_root.visible, "full shows decor again")
	check(world.weather.visuals_enabled, "full shows weather again")
	world.visuals.show_panel()
	check(world.visuals.visible, "visual sheet opens")
	world.visuals.hide_panel()
	check(not world.visuals.visible, "visual sheet closes")
	world.settings.apply_preset("Full")
	check(bool(world.fx.call("effect_on", "post_fx")), "full shows bloom")
	check(bool(world.fx.call("effect_on", "sway_shadows")), "full shows contact shadows")
	check(bool(world.fx.call("effect_on", "animations")), "full shows ambient motion")
	world.settings.set_flag("post_fx", false)
	check(not bool(world.fx.call("effect_on", "post_fx")), "post fx hides the grade")
	world.settings.set_flag("sway_shadows", false)
	check(not bool(world.fx.call("effect_on", "sway_shadows")), "sway hides contact shadows")
	world.settings.apply_preset("Full")
	world.queue_free()
	await process_frame
	await _test_performance()
	print("visual settings tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# --- Performance mode ---------------------------------------------------

const GUIDE_CELL := Vector2i(24, 18)


func _test_performance() -> void:
	var keep_prompted := VisualSettings.new().performance_prompted
	_test_performance_store()
	_test_weak_machine()
	var w := _world()
	w.settings.apply_preset("Full")
	_settle(w)
	check(not w.settings.performance, "performance mode starts off")
	check(_snapshot_full(w), "full mode runs every ambient system")
	await w.enter_zone("crosshaven_northgate", Vector2i(20, 14), false)
	w._sync_snowfall(true)
	check(_has_water(w) and _ripple_moves(w), "full: the Northgate sea ripples")
	check(w._snow.visible, "full: snow falls in Northgate")
	await w.enter_zone("crosshaven_crossroads", w.map.zone("crosshaven_crossroads").spawn, false)
	w.settings.set_performance(true)
	_settle(w)
	_check_still(w, "after the switch")
	await _check_northgate_still(w)
	w.settings.set_performance(false)
	_settle(w)
	check(not Art.lite, "off: the 2x masters come back")
	check(_snapshot_full(w), "off: every ambient system comes back")
	# Restart: the switch is saved and a new world starts still.
	w.settings.set_performance(true)
	w.queue_free()
	await process_frame
	var reread := VisualSettings.new()
	check(reread.performance, "performance mode persists in the store")
	var w2 := _world()
	_settle(w2)
	check(w2.settings.performance, "a restarted world reads performance mode")
	_check_still(w2, "after a restart")
	_check_talk(w2)
	await _check_click_walk(w2)
	_check_offer_once(w2)
	w2.settings.apply_preset("Full")
	check(not w2.settings.performance, "the Full preset turns performance mode off")
	w2.queue_free()
	await process_frame
	var tidy := VisualSettings.new()
	tidy.apply_preset("Full")
	tidy.performance_prompted = keep_prompted
	tidy.save_store()


func _test_performance_store() -> void:
	var s := VisualSettings.new()
	s.apply_preset("Full")
	check(not s.enabled(VisualSettings.PERFORMANCE) and s.enabled(VisualSettings.MOTION), "full: performance off, motion on")
	var seen: Array = []
	s.flag_changed.connect(func(flag, on): seen.append([flag, on]))
	s.set_performance(true)
	check(s.enabled(VisualSettings.PERFORMANCE) and not s.enabled(VisualSettings.MOTION), "performance on stops motion")
	check(seen.has([VisualSettings.PERFORMANCE, true]) and seen.has([VisualSettings.MOTION, false]), "the switch tells binders (performance and motion)")
	check(s.preset == "Full" and s.enabled("decor") and s.enabled("post_fx"), "performance keeps the preset look (decor, grade)")
	var again := VisualSettings.new()
	check(again.performance, "performance mode is saved")
	again.set_flag(VisualSettings.PERFORMANCE, false)
	check(not VisualSettings.new().performance, "turning it off is saved too")


func _test_weak_machine() -> void:
	var gib := 1024 * 1024 * 1024
	var strong := {"cores": 8, "ram": 16 * gib, "gpu_type": RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "gpu_name": "GeForce"}
	check(VisualSettings.weak_reasons(strong).is_empty(), "8 cores, 16 GB, a discrete GPU is not weak")
	check(not VisualSettings.weak_reasons({"cores": 2, "ram": 16 * gib}).is_empty(), "2 cores looks weak")
	check(not VisualSettings.weak_reasons({"cores": 8, "ram": 4 * gib}).is_empty(), "4 GB of RAM looks weak")
	check(not VisualSettings.weak_reasons({"cores": 8, "ram": 16 * gib, "gpu_type": RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU}).is_empty(), "an integrated GPU looks weak")
	check(not VisualSettings.weak_reasons({"cores": 8, "ram": 16 * gib, "gpu_name": "llvmpipe (LLVM 15)"}).is_empty(), "software graphics look weak")


func _world() -> Node2D:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	return w


func _settle(w: Node2D) -> void:
	if w.ground != null:
		w.ground._process(0.0)


func _all_props(w: Node2D) -> Array:
	var out: Array = w.props_root.get_children()
	for host in w.neighbours.get_children():
		var props: Node = host.get_node_or_null("Props")
		if props != null:
			out.append_array(props.get_children())
	return out


func _all_decor(w: Node2D) -> Array:
	var out: Array = w.decor_root.get_children()
	for host in w.neighbours.get_children():
		var decor: Node = host.get_node_or_null("Decor")
		if decor != null:
			out.append_array(decor.get_children())
	return out


func _live_loops(w: Node2D) -> int:
	var n := 0
	for p in _all_props(w):
		n += int(p.live_loops())
	return n


func _swaying_decor(w: Node2D) -> int:
	var n := 0
	for d in _all_decor(w):
		if d.has_sway():
			n += 1
	return n


func _has_water(w: Node2D) -> bool:
	return not (w.ground._water_rows as Dictionary).is_empty()


func _ripple_moves(w: Node2D) -> bool:
	var frames := {}
	var g: Node2D = w.ground
	for i in 3:
		g._process(0.0)
		frames[g._ripple_frame] = true
		OS.delay_msec(260)
	return frames.size() > 1


func _snapshot_full(w: Node2D) -> bool:
	var ok := true
	var parts := {
		"critters": w.fx.critter_count() > 0,
		"air": w.fx.air_on(),
		"clouds": w.fx.clouds_on(),
		"tree sway": _live_loops(w) > 0,
		"plant sway": _swaying_decor(w) > 0,
		"ripple": _ripple_moves(w) or not _has_water(w),
		"weather motion": w.weather.motion_enabled,
		"2x art": not Art.lite,
		"npc roam": _npcs_roam(w),
	}
	for key in parts.keys():
		if not bool(parts[key]):
			print("  full mode is missing: ", key)
			ok = false
	return ok


func _npcs_roam(w: Node2D) -> bool:
	var any := false
	for node in w.npcs_root.get_children():
		if node.roam_enabled:
			any = true
	return any


func _check_still(w: Node2D, when: String) -> void:
	check(Art.lite, "%s: the 1x art is loaded" % when)
	var scaled := true
	for p in w.props_root.get_children():
		var art: Dictionary = p._art
		if not art.is_empty() and float(art["scale"]) != 1.0:
			scaled = false
	check(scaled, "%s: props draw the 1x files at scale 1" % when)
	check(_live_loops(w) == 0, "%s: no tree, mill or smoke loop plays (%d)" % [when, _live_loops(w)])
	check(_swaying_decor(w) == 0, "%s: bushes and flowers are still (%d)" % [when, _swaying_decor(w)])
	check(w.fx.critter_count() == 0, "%s: no birds or critters (%d)" % [when, w.fx.critter_count()])
	check(not w.fx.air_on(), "%s: no leaves or pollen" % when)
	check(not w.fx.clouds_on(), "%s: no cloud shadows" % when)
	check(bool(w.fx.call("effect_on", "post_fx")), "%s: the grade stays" % when)
	check(bool(w.fx.call("effect_on", "sway_shadows")), "%s: contact shadows stay (still drawings)" % when)
	check(w.decor_root.visible, "%s: decor stays" % when)
	if _has_water(w):
		check(not _ripple_moves(w), "%s: the sea ripple and glint hold still" % when)
		check(w.ground._ripple_frame == 0, "%s: the water keeps its first ripple frame (drawn, not blank)" % when)
	w.weather.set_weather("light_rain")
	w.weather.settle()
	check(not w.weather.particles_on(), "%s: no rain particles" % when)
	check(w.weather.current_tint() != w.weather.daylight_color(), "%s: the rain tint stays" % when)
	w.weather.set_weather("clear")
	w.weather.settle()
	var still := true
	var slow := true
	for node in w.npcs_root.get_children():
		if node.roam_enabled:
			still = false
		if not is_equal_approx(float(node.idle_rate), 0.5):
			slow = false
	check(w.npcs_root.get_child_count() > 0 and still, "%s: NPCs stay at their posts" % when)
	check(slow, "%s: NPCs play a slow idle" % when)


func _check_northgate_still(w: Node2D) -> void:
	await w.enter_zone("crosshaven_northgate", Vector2i(20, 14), false)
	_settle(w)
	w._sync_snowfall(true)
	check(float(w.snow_level) > 0.5, "Northgate: the snow level still cools the grade")
	check(not w._snow.visible, "Northgate: no falling snow")
	_check_still(w, "in Northgate")
	check(_has_water(w), "Northgate has sea to hold still")
	await w.enter_zone("crosshaven_crossroads", w.map.zone("crosshaven_crossroads").spawn, false)
	_settle(w)


func _check_talk(w: Node2D) -> void:
	var guide: Node2D = w._npc_node("crossroads_guide")
	check(guide != null, "performance: the Guide is at the Crossroads")
	if guide == null:
		return
	check(guide.cell == GUIDE_CELL, "performance: the Guide stands at the post")
	w._approach_npc(w.npc_book.by_id("crossroads_guide"))
	_drive(w)
	check(w.dialogue.is_open(), "performance: the Guide still talks")
	check(str(guide.facing) != "" and str(guide.anim) == "talk", "performance: the Guide turns and gestures")
	w.dialogue.close()


func _check_click_walk(w: Node2D) -> void:
	root.size = Vector2i(1280, 720)
	w.walker.place(w.zone, w.zone.spawn)
	w._route.clear()
	w._last_click_ms = 0
	await process_frame
	var reach: Dictionary = w.reachable_here()
	var target := Vector2i(-1, -1)
	for c in [w.zone.spawn + Vector2i(-3, 0), w.zone.spawn + Vector2i(0, 3), w.zone.spawn + Vector2i(0, -3), w.zone.spawn + Vector2i(-2, 2)]:
		if reach.has(c) and w._npc_at(c).is_empty():
			target = c
			break
	check(target.x >= 0, "performance: a reachable cell near the spawn")
	if target.x < 0:
		return
	var local: Vector2 = BoardVisualSort.cell_to_local(w._origin_of(w.zone.zone_id) + target, float(w.zone.height_at(target)))
	w.camera.position = local
	w.camera.reset_smoothing()
	w.camera.force_update_scroll()
	await process_frame
	var canvas: Vector2 = w.get_canvas_transform() * w.to_global(local)
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
	check(w.hover_cell == target, "performance: the hover follows the mouse (%s, want %s)" % [w.hover_cell, target])
	check(w.walker.is_moving(), "performance: a click starts a walk")
	_drive(w)
	check(w.walker.cell == target, "performance: the hero walks to the clicked cell (%s)" % w.walker.cell)


func _check_offer_once(w: Node2D) -> void:
	var gib := 1024 * 1024 * 1024
	var weak := {"cores": 2, "ram": 4 * gib}
	var strong := {"cores": 8, "ram": 16 * gib}
	w.settings.performance_prompted = false
	w.settings.set_performance(false)
	check(not w.offer_performance(strong), "no offer on a strong machine")
	check(not w.visuals.offer_visible(), "no prompt on a strong machine")
	check(w.offer_performance(weak), "a weak machine gets the offer")
	check(w.visuals.offer_visible(), "the one-time prompt shows")
	check(w.visuals.offer_label.text.contains("2 CPU cores"), "the prompt says why")
	w.visuals.offer_no.pressed.emit()
	check(not w.visuals.visible and not w.settings.performance, "No thanks closes it and leaves the world moving")
	check(not w.offer_performance(weak), "the offer does not come back")
	check(not VisualSettings.new().should_offer_performance(weak), "the offer stays answered after a restart")
	w.settings.performance_prompted = false
	check(w.offer_performance(weak), "a fresh install offers again")
	w.visuals.offer_yes.pressed.emit()
	check(w.settings.performance and not w.visuals.visible, "Turn on switches performance mode on")
	_check_still(w, "after Turn on")


func _drive(w: Node2D) -> void:
	var n := 0
	while w.walker.is_moving() and n < 4000:
		w.walker.advance(0.05)
		n += 1
