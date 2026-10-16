extends Node2D

## An open-world pack fight (package Z1). The board is the world: a square of
## the world cells round the pack (world_monsters.fight_config), drawn over a
## picture of those very cells taken just before the swap, so the hero fights
## on the field, orchard or mill where the pack stood (Dofus / Wakfu style).
## Same CombatSim dungeon mode, board view, HUD and monster AI as the PC
## dungeons. Win pays XP, coins and loot (world_monsters.pay_out); a loss
## pays nothing and sends the hero to the zone's safe point.
##
## Launched by WorldFightLauncher.enter from the map. Run directly for capture:
##   godot --path . res://scenes/world/monster/world_fight.tscn -- --mob-capture fight|still [--size 3] [--boss thresher_stag] [--level 6] [--class kestrel]

signal fight_finished(result: String, summary: Dictionary)

const Launcher := preload("res://scenes/world/monster/world_fight_launcher.gd")
const Mobs := preload("res://backend/world_monsters.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Levels := preload("res://backend/world_levels.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const Props := preload("res://scenes/world/dungeon/dungeon_props.gd")

var ctx: Dictionary = {}
var book = null
var progress = null
var manifest: Dictionary = {}
var summary: Dictionary = {}
var result := ""
var board: Node2D
var capture := ""
var finished := false
var _overlay: CanvasLayer
var _title: Label
var _sub: Label
var _roster: RichTextLabel
var _fade: ColorRect
var _banner: Label
var _result_panel: PanelContainer
var _result_body: RichTextLabel
var _return_button: Button
var _media := ""


func _ready() -> void:
	board = $BoardView
	ctx = Launcher.take_pending()
	_read_capture_args()
	var loaded: Dictionary = Mobs.load_default()
	book = loaded["book"] if bool(loaded.get("ok", false)) else null
	progress = Progress.new()
	if ctx.is_empty():
		ctx = _capture_ctx()
	_build_overlay()
	if book == null or (ctx.get("config", {}) as Dictionary).is_empty():
		push_error("World fight failed to start")
		_show_result("lose", {})
		return
	manifest = Art.manifest(book.art_path(str(ctx.get("zone_id", "stoneford"))))
	board.autoplay = bool(ctx.get("autoplay", false))
	if _arg("--pace", "") != "":
		board.autoplay_pace = float(_arg("--pace", "0.35"))
	board.room_over.connect(_on_room_over)
	call_deferred("_begin")


func _begin() -> void:
	board.start_room(ctx["config"], manifest)
	_apply_world_backdrop()
	var pack: Dictionary = ctx.get("pack", {})
	_title.text = str(pack.get("boss_name", "Pack of %d" % int(pack.get("size", 0))))
	_sub.text = "Lv %d–%d  ·  Total Lv %d  ·  %s" % [int(pack.get("level_min", 1)), int(pack.get("level_max", 1)), int(pack.get("total_level", 0)), str(ctx.get("place", "Stoneford"))]
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	if bool(pack.get("boss", false)):
		_banner.text = str(ctx.get("boss_banner", ""))
		_banner.visible = _banner.text != ""
		get_tree().create_timer(2.2).timeout.connect(func(): _banner.visible = false)
	if capture == "still":
		await get_tree().create_timer(1.6).timeout
		await _grab(_arg("--name", "world_fight.png"))
		get_tree().quit()


## The picture of the world cells (taken by the map before the swap) under
## the board: its pixel `cell00` is board cell (0, 0)'s centre.
func _apply_world_backdrop() -> void:
	var img: Variant = ctx.get("backdrop", null)
	var bd: Node2D = board.get("_backdrop")
	if bd == null:
		return
	if img is Image and not (img as Image).is_empty():
		bd.set("tex", ImageTexture.create_from_image(img))
		bd.set("cell00", ctx.get("backdrop_cell00", Vector2.ZERO))
		bd.set("tex_scale", float(ctx.get("backdrop_scale", 1.0)))
	else:
		# Fallback (headless, or no picture): the zone-themed board, a painted
		# field ground drawn under the grid.
		bd.set("tex", _field_texture())
		bd.set("cell00", Vector2(512, 160))
		bd.set("tex_scale", 1.0)
	bd.queue_redraw()
	board._fit_board_camera()


static func _field_texture() -> Texture2D:
	var img := Image.create(1024, 600, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	for y in 600:
		for x in 1024:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(0.42 + 0.12 * n, 0.55 + 0.12 * n, 0.2 + 0.05 * n))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if _roster == null or finished:
		return
	var snap: Dictionary = sim_node().snapshot()
	if not snap.has("dungeon"):
		return
	var lines: PackedStringArray = []
	lines.append("[b]Round %d[/b]" % int((snap["dungeon"] as Dictionary).get("round", 1)))
	var shown := 0
	for unit in snap.get("units", []):
		if not unit.has("monster") or not bool(unit.get("alive", false)):
			continue
		shown += 1
		if shown > 10:
			break
		var active := int(unit.get("seat", -1)) == int(snap.get("active_seat", -1))
		lines.append("%s%s  [color=#e8b0a0]%d/%d[/color]" % ["▶ " if active else "", str(unit.get("name", "")), int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	_roster.text = "\n".join(lines)


func _on_room_over(r: String) -> void:
	board.end_room()
	result = r
	summary = book.pay_out(ctx.get("pack", {}), str(ctx.get("zone_id", "stoneford")), r, progress, RandomNumberGenerator.new(), capture == "")
	_show_result(r, summary)
	fight_finished.emit(r, summary)
	if bool(ctx.get("autoplay", false)):
		await get_tree().create_timer(float(_arg("--result-secs", "4.0"))).timeout
		_on_return()


func _show_result(r: String, data: Dictionary) -> void:
	finished = true
	result = r
	var lines: PackedStringArray = []
	if r == "win":
		lines.append("[font_size=30][color=#f5d27a]Victory![/color][/font_size]")
		lines.append("%s beaten." % str((ctx.get("pack", {}) as Dictionary).get("boss_name", "The pack of %d is" % int(data.get("size", 0)))))
		lines.append("")
		lines.append("XP [b]+%d[/b]" % int(data.get("xp", 0)))
		lines.append("Crypto Coins [b]+%d[/b]" % int(data.get("coins", 0)))
		for raw in data.get("items", []):
			var item: Dictionary = raw
			var label := str(item.get("item_id", ""))
			var def: Dictionary = progress.item_def(label) if progress != null else {}
			if not def.is_empty():
				label = str(def.get("name", label))
			lines.append("%s [color=#c9b98f](%s)[/color]%s" % [label, str(item.get("rarity", "regular")), "  [color=#f5d27a]chest[/color]" if bool(item.get("chest", false)) else ""])
		for t in data.get("trophies", []):
			lines.append("[color=#f5d27a]Trophy: %s  ·  title \"%s\"[/color]" % [str(t.get("name", "")), str(t.get("title", ""))])
		for up in data.get("level_ups", []):
			lines.append("[color=#9fe08a]Level up! Level %d[/color]" % int((up as Dictionary).get("level", 0)))
	else:
		lines.append("[font_size=30][color=#e07a6a]Defeated[/color][/font_size]")
		lines.append("You are carried back to safety. No rewards this time.")
	_result_body.text = "\n".join(lines)
	_result_panel.visible = true


func _on_return() -> void:
	if not _result_panel.visible:
		return
	_result_panel.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	await tw.finished
	if capture != "":
		get_tree().quit()
		return
	Launcher.finish(get_tree(), ctx, result if result != "" else "lose", summary)


func result_text() -> String:
	return _result_body.text if _result_body != null else ""


## Capture / direct run: a pack (or a boss) on a real world board of the
## chunk the data names, without a map picture (the fallback board).
func _capture_ctx() -> Dictionary:
	if book == null:
		return {}
	var lv := Levels.load_default()
	var levels = lv["levels"] if bool(lv.get("ok", false)) else null
	var atlas_loaded: Dictionary = Atlas.load_default()
	if not bool(atlas_loaded.get("ok", false)):
		return {}
	var atlas = atlas_loaded["atlas"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_arg("--seed", "7"))
	var boss_id := _arg("--boss", "")
	var chunk := _arg("--chunk", "crosshaven_stoneford_fields")
	var pack: Dictionary
	if boss_id != "":
		pack = book.boss_pack(boss_id)
		chunk = str(((book.row(boss_id).get("boss", {}) as Dictionary).get("chunks", [chunk]) as Array)[0])
	else:
		pack = book.make_pack(levels, chunk, rng, int(_arg("--size", "3")))
	var z: WorldZone = atlas.map_for_chunk(chunk).zone(chunk)
	var forbidden: Dictionary = book.forbidden_cells(z)
	var placed: Array = book.place_packs(z, levels, rng, forbidden, 1)
	if placed.is_empty():
		return {}
	var entry: Dictionary = placed[0]
	entry["pack"] = pack
	entry["cells"] = book.body_cells(z, entry["home"], mini(int(pack["size"]), 6), forbidden, {})
	var cls := _arg("--class", "kestrel")
	var config: Dictionary = book.fight_config(z, entry, {"class_id": cls, "pos": (entry["home"] as Vector2i) + Vector2i(0, 4)}, int(_arg("--seed", "7")))
	progress.level = maxi(int(progress.level), int(_arg("--level", str(int(pack.get("level_max", 1))))))
	return {"config": config, "pack": pack, "zone_id": book.zone_of_chunk(chunk), "chunk_id": chunk, "autoplay": capture != "", "place": z.zone_id, "boss_banner": str((book.row(boss_id).get("boss", {}) as Dictionary).get("banner", "")) if boss_id != "" else ""}


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "WorldFightOverlay"
	_overlay.layer = 20
	add_child(_overlay)
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
	_banner = _label(28, Color(0.96, 0.86, 0.6))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 90
	_banner.visible = false
	_overlay.add_child(_banner)
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
	_return_button.text = "Back to the map"
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


func _read_capture_args() -> void:
	capture = _arg("--mob-capture", "")
	if capture != "":
		var look := VisualSettings.new()
		look.apply_preset("Full")
	_media = OS.get_environment("MOBS_MEDIA")
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


func sim_node() -> Node:
	return get_node("/root/CombatSim")
