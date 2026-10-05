extends Node2D

## A PC dungeon run scene: room A (the pack), a short stair transition, room
## B (the boss), then the result. Win pays through pc_rewards, pc_progress XP
## and pc_missions (clear_dungeon); a loss pays nothing. Either way the hero
## goes back to town on the door cell (DungeonLauncher.finish).
##
## Launched by DungeonLauncher.enter from the door. Run directly for capture:
##   godot --path . res://scenes/world/dungeon/dungeon_run.tscn -- --dungeon-capture stills|showcase|run [--class kestrel]

signal run_finished(result: String, summary: Dictionary)

const Launcher := preload("res://scenes/world/dungeon/dungeon_launcher.gd")
const Run := preload("res://backend/pc_dungeon_run.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Missions := preload("res://backend/pc_missions.gd")
const MonsterPawn := preload("res://scenes/world/dungeon/monster_pawn.gd")
const Fx := preload("res://scenes/world/dungeon/dungeon_fx.gd")

var ctx: Dictionary = {}
var run = null
var progress = null
var missions = null
var manifest: Dictionary = {}
var summary: Dictionary = {}
var board: Node2D
var capture := ""
var finished := false
var _overlay: CanvasLayer
var _title: Label
var _sub: Label
var _roster: RichTextLabel
var _fade: ColorRect
var _stair_label: Label
var _result_panel: PanelContainer
var _result_body: RichTextLabel
var _return_button: Button
var _media := ""


func _ready() -> void:
	board = $BoardView
	ctx = Launcher.take_pending()
	_read_capture_args()
	if ctx.is_empty():
		ctx = {"dungeon_id": "old_granary_cellar", "level": 1, "class_id": _arg("--class", "kestrel"), "star": int(_arg("--star", "1")), "autoplay": capture != "", "return_zone": "crosshaven_stoneford", "return_cell": Vector2i(16, 11)}
	progress = Progress.new()
	var level := int(ctx.get("level", progress.level))
	var made: Dictionary = Run.create(str(ctx.get("dungeon_id", "")), level, str(ctx.get("class_id", "kestrel")), str(ctx.get("name", "")), int(ctx.get("star", 1)))
	if not bool(made.get("ok", false)):
		push_error("Dungeon run failed to start: %s" % [made.get("errors", [])])
		_build_overlay()
		_show_result("lose", {"name": "Dungeon", "error": true})
		return
	run = made["run"]
	if int(ctx.get("hero_hp", -1)) > 0:
		run.hero_hp = int(ctx["hero_hp"])
	var loaded: Dictionary = Missions.load_default()
	if bool(loaded.get("ok", false)):
		missions = loaded["missions"]
		missions.reconcile(progress)
	manifest = Art.manifest(str(run.run_doc.get("art", "")))
	board.autoplay = bool(ctx.get("autoplay", false))
	board.room_over.connect(_on_room_over)
	_build_overlay()
	if capture == "showcase":
		call_deferred("_showcase")
		return
	if capture == "rewards":
		call_deferred("_rewards_still")
		return
	if capture == "room":
		call_deferred("_room_clip")
		return
	call_deferred("_begin")


func _begin() -> void:
	await _start_room(0, true)
	if capture == "stills":
		board.autoplay = false
		await get_tree().create_timer(1.5).timeout
		await _grab(_arg("--a-name", "03_room_a_monsters.png"))
		run.room_index = 1
		board.end_room()
		await _start_room(1, false)
		board.autoplay = true
		# A hero turn with no banner up; at ★5 wait for his toxic pools.
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 40000:
			await get_tree().create_timer(0.25).timeout
			var snap: Dictionary = sim_node().snapshot()
			var ready: bool = int(snap.get("active_seat", -1)) == 0 and not board._busy and not bool(snap.get("match_over", false))
			if run.star >= 5 and ((snap.get("dungeon", {}) as Dictionary).get("pools", []) as Array).is_empty():
				ready = false
			if ready:
				break
		board.autoplay = false
		await get_tree().create_timer(0.6).timeout
		await _grab(_arg("--b-name", "04_room_b_ratking.png"))
		get_tree().quit()


func _start_room(index: int, first: bool) -> void:
	run.room_index = index
	var spec: Dictionary = run.room(index)
	var seed := int(ctx.get("seed", -1))
	var config: Dictionary = run.combat_config(index, seed + index if seed >= 0 else -1)
	board.start_room(config, manifest)
	_title.text = "%s\n%s" % [str(run.dungeon.get("name", "")), str(spec.get("name", ""))]
	_sub.text = "★%d  ·  Room %s of %d  ·  Level %d" % [run.star, "A" if index == 0 else "B", run.room_count(), run.level]
	if first:
		_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	await tw.finished


func _process(_delta: float) -> void:
	if _roster == null or run == null or finished:
		return
	var snap: Dictionary = sim_node().snapshot()
	if not snap.has("dungeon"):
		return
	var lines: PackedStringArray = []
	var info: Dictionary = snap["dungeon"]
	lines.append("[b]Round %d[/b]" % int(info.get("round", 1)))
	for unit in snap.get("units", []):
		if not unit.has("monster"):
			continue
		if not bool(unit.get("alive", false)):
			continue
		var name := str(unit.get("name", ""))
		var active := int(unit.get("seat", -1)) == int(snap.get("active_seat", -1))
		lines.append("%s%s  [color=#e8b0a0]%d/%d[/color]" % ["▶ " if active else "", name, int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	var pads := int(info.get("pad_heal", 0))
	if pads > 0:
		lines.append("[color=#f2c46a]Glowing pads: +%d HP when your turn starts on one[/color]" % pads)
	_roster.text = "\n".join(lines)


func _on_room_over(result: String) -> void:
	board.end_room()
	if result == "win" and run.advance():
		await _stairs()
		await _start_room(run.room_index, false)
		return
	if result == "win":
		summary = run.pay_out(progress, missions, RandomNumberGenerator.new())
	else:
		run.lose()
		summary = run.pay_out(progress, missions, RandomNumberGenerator.new())
		if progress != null:
			progress.save()
	_show_result(run.result, summary)
	run_finished.emit(run.result, summary)
	if bool(ctx.get("autoplay", false)):
		await get_tree().create_timer(4.5).timeout
		_on_return()


## Short transition between rooms: fade, the stairs line, fade in.
func _stairs() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	await tw.finished
	_stair_label.text = "Down the old stairs, deeper under the granary..."
	_stair_label.visible = true
	await get_tree().create_timer(1.3).timeout
	_stair_label.visible = false


func _show_result(result: String, data: Dictionary) -> void:
	finished = true
	var lines: PackedStringArray = []
	if result == "win":
		lines.append("[font_size=30][color=#f5d27a]Victory!  ★%d[/color][/font_size]" % int(data.get("star", run.star if run != null else 1)))
		lines.append("%s is cleared at ★%d. The Ratking is down." % [str(data.get("name", "")), int(data.get("star", 1))])
		if bool(data.get("new_best_star", false)):
			lines.append("[color=#f5d27a]New best: ★%d[/color]" % int(data.get("star", 1)))
		lines.append("")
		lines.append("XP [b]+%d[/b]" % int(data.get("xp", 0)))
		lines.append("Crypto Coins [b]+%d[/b]" % int(data.get("coins", 0)))
		for raw in data.get("items", []):
			var item: Dictionary = raw
			var label := str(item.get("item_id", ""))
			if progress != null:
				var def: Dictionary = progress.item_def(label)
				if not def.is_empty():
					label = str(def.get("name", label))
			lines.append("%s [color=#c9b98f](%s)[/color]" % [label, str(item.get("rarity", "regular"))])
		for up in data.get("level_ups", []):
			lines.append("[color=#9fe08a]Level up! Level %d[/color]" % int((up as Dictionary).get("level", 0)))
		for mission_id in data.get("missions", []):
			var m: Dictionary = missions.mission(str(mission_id)) if missions != null else {}
			lines.append("[color=#9fd0ff]Mission done: %s[/color]" % str(m.get("name", mission_id)))
	else:
		lines.append("[font_size=30][color=#e07a6a]Defeated[/color][/font_size]")
		lines.append("The cellar drives you out. No rewards this time.")
	lines.append("")
	lines.append("You climb back up to the granary door in Stoneford.")
	_result_body.text = "\n".join(lines)
	_result_panel.visible = true


func _on_return() -> void:
	if not _result_panel.visible:
		return
	_result_panel.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	await tw.finished
	if capture != "":
		get_tree().quit()
		return
	Launcher.finish(get_tree(), ctx, str(run.result) if run != null else "lose", summary)


func result_text() -> String:
	return _result_body.text if _result_body != null else ""


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "DungeonOverlay"
	_overlay.layer = 20
	add_child(_overlay)
	# Right column (the HUD's second seat card is hidden in dungeon rooms).
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -330
	top.offset_right = -14
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	_overlay.add_child(top)
	_title = _label(20, Color(0.98, 0.84, 0.5))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_title)
	_sub = _label(14, Color(0.85, 0.8, 0.7))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_sub)
	_roster = RichTextLabel.new()
	_roster.bbcode_enabled = true
	_roster.fit_content = true
	_roster.scroll_active = false
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.custom_minimum_size = Vector2(316, 60)
	_roster.add_theme_font_size_override("normal_font_size", 14)
	_roster.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	_roster.add_theme_constant_override("outline_size", 4)
	_roster.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	top.add_child(_roster)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.01, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)
	_stair_label = _label(26, Color(0.96, 0.82, 0.55))
	_stair_label.set_anchors_preset(Control.PRESET_CENTER)
	_stair_label.offset_left = -400
	_stair_label.offset_right = 400
	_stair_label.visible = false
	_overlay.add_child(_stair_label)
	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -260
	_result_panel.offset_right = 260
	_result_panel.offset_top = -200
	_result_panel.offset_bottom = 200
	_result_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.96)
	style.border_color = Color(0.93, 0.76, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_result_panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(_result_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_result_panel.add_child(col)
	_result_body = RichTextLabel.new()
	_result_body.bbcode_enabled = true
	_result_body.fit_content = true
	_result_body.scroll_active = false
	_result_body.custom_minimum_size = Vector2(460, 240)
	_result_body.add_theme_font_size_override("normal_font_size", 17)
	col.add_child(_result_body)
	_return_button = Button.new()
	_return_button.name = "Return"
	_return_button.text = "Return to Stoneford"
	_return_button.custom_minimum_size = Vector2(240, 46)
	_return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_return_button.pressed.connect(_on_return)
	col.add_child(_return_button)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Capture ---------------------------------------------------------------

func _read_capture_args() -> void:
	capture = _arg("--dungeon-capture", "")
	_media = OS.get_environment("GRANARY_MEDIA")
	if _media == "":
		_media = "user://"


func _arg(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == flag and i + 1 < args.size():
			return str(args[i + 1])
	return fallback


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(_media.path_join(file_name))


## Monster showcase: the three granary monsters side by side on the cellar
## floor, each playing idle, walk, attack, hit, summon (the Ratking) and death.
func _showcase() -> void:
	await _start_room(0, true)
	board.end_room()
	board.autoplay = false
	board.set_process(false)
	sim_node().set_process(false)
	board.get_node("Units").visible = false
	_roster.visible = false
	$HUD.visible = false
	var stage := Node2D.new()
	stage.name = "Showcase"
	board.add_child(stage)
	var cast := [["granary_rat", Vector2i(3, 8), false], ["sling_rat", Vector2i(4, 6), false], ["the_ratking", Vector2i(6, 5), true], ["scarecrow_drudge", Vector2i(8, 3), false],
		["radioactive_rat", Vector2i(5, 9), false], ["radioactive_sling_rat", Vector2i(7, 8), false], ["radioactive_ratking", Vector2i(9, 6), true]]
	var shown: Array = []
	for row in cast:
		var p := MonsterPawn.new()
		p.bind_art(manifest, str(row[0]), bool(row[2]))
		stage.add_child(p)
		var stats: Dictionary = run.monsters.stats_at(str(row[0]), 1)
		p.apply_snapshot({"pos": row[1], "name": str(stats["name"]), "class_id": str(row[0]), "facing": "S", "seat": 1, "hp": int(stats["hp"]), "max_hp": int(stats["hp"]), "alive": true}, -1)
		p.position = board._cell_to_local(row[1])
		p.z_as_relative = false
		p.z_index = BoardVisualSort.unit_z_index(row[1])
		shown.append(p)
	var cam: Camera2D = board._camera
	var mid: Vector2 = board._cell_to_local(Vector2i(6, 6))
	cam.position = mid + Vector2(0, -40)
	cam.zoom = Vector2(1.45, 1.45)
	_title.text = "Old Granary Cellar\nMonsters"
	_sub.text = "Granary Rat · Sling Rat · Scarecrow Drudge · The Ratking\n★5: Radioactive Rat · Radioactive Sling Rat · Radioactive Ratking"
	await get_tree().create_timer(2.0).timeout
	for face in ["E", "N", "W", "S"]:
		for p in shown:
			p.set_facing(face)
		await get_tree().create_timer(1.1).timeout
	for p in shown:
		p.begin_path_walk()
	await get_tree().create_timer(2.0).timeout
	for p in shown:
		p.end_path_walk()
	await get_tree().create_timer(0.6).timeout
	var target_at: Vector2 = board._cell_to_local(Vector2i(2, 11)) + Vector2(0, -20)
	for p in shown:
		p.play_view_plan({"attack": true, "aim": Vector2(-30, 15)})
		if str(p.monster_id).contains("sling"):
			var kind := "sling_pebble_radioactive" if str(p.monster_id).begins_with("radioactive") else "sling_pebble"
			Fx.throw(board, manifest, kind, p.position + p.release_offset(), target_at, true, 900, p.release_sec())
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.9).timeout
	for p in shown:
		p.play_view_plan({"hit": true, "away": Vector2(20, -10)})
		await get_tree().create_timer(0.8).timeout
	shown[2].play_view_plan({"cast": true, "strip": "summon"})
	shown[6].play_view_plan({"cast": true, "strip": "summon"})
	await get_tree().create_timer(1.8).timeout
	for p in shown:
		p.alive = false
		p.play_view_plan({"death": true})
		await get_tree().create_timer(1.1).timeout
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()


## Capture: one room played by the hero bot for --secs seconds.
func _room_clip() -> void:
	var index := int(_arg("--room", "0"))
	await _start_room(index, true)
	await get_tree().create_timer(float(_arg("--secs", "15"))).timeout
	get_tree().quit()


## Capture: the result screen of a won run at the picked star.
func _rewards_still() -> void:
	board.autoplay = false
	await _start_room(1, true)
	board.end_room()
	run.result = "win"
	summary = run.pay_out(progress, missions, RandomNumberGenerator.new(), false)
	_show_result("win", summary)
	await get_tree().create_timer(0.8).timeout
	await _grab("rewards_star%d.png" % run.star)
	get_tree().quit()


func sim_node() -> Node:
	return get_node("/root/CombatSim")
