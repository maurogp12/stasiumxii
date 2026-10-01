extends SceneTree

## Visual settings: toggles, presets, and the on-disk store.
## Run: godot --headless --path . -s res://tests/run_visual_settings_tests.gd

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
	world.queue_free()
	print("visual settings tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
