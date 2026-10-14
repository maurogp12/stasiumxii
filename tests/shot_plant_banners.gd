extends SceneTree

## Phone frame of Bastion's Plant banners on slagcrown.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_plant_banners.gd -- /opt/cursor/artifacts/plant_banners before.png --mobile-frame
## Pass --show-cap on the readable banners to also save the grey button and the hover card.

var _dir := "/opt/cursor/artifacts/plant_banners"
var _file := "before.png"
var _show_cap := false
var _frames := 0
var _phase := 0
var _banner_cell := Vector2i.ZERO
var _bastion_cell := Vector2i.ZERO
var _kestrel_cell := Vector2i.ZERO
var _banners: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var positional: Array[String] = []
	for arg in args:
		var text := str(arg)
		if text == "--show-cap":
			_show_cap = true
			continue
		if text.begins_with("-"):
			continue
		positional.append(text)
	if positional.size() >= 1:
		_dir = positional[0]
	if positional.size() >= 2:
		_file = positional[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	if not args.has("--mobile-frame"):
		push_error("pass --mobile-frame so the board is the phone layout")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 360:
		push_error("plant banner shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	var hud: CombatHUD = board._hud
	if _phase == 0:
		if not _boot(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera(false)
		if board.has_method("_center_on_cell"):
			board._center_on_cell(_banner_cell)
		board._framed_cell = _bastion_cell
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 16:
			return false
		if not _banners_drawn(board):
			return true
		if not _save(_file):
			return true
		if not _show_cap:
			return true
		if not _cast_to_cap(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		if hud != null:
			hud.focus_fighter(_class_seat(sim, "bastion"))
			hud.show_spell_tooltip(SpellKits.PLANT)
			hud._layout_chrome()
		_phase = 2
		_frames = 0
		return false
	if _frames < 12:
		return false
	var tip := hud.tooltip_caption().replace("\n", " | ") if hud != null else ""
	print("PLANT CAP tooltip=%s" % tip)
	var kit: Dictionary = SpellKits.spell(SpellKits.PLANT)
	var lone := int(kit.get("plant_turns", 0))
	var per := int(kit.get("plants_per_turn", 0))
	var dur := "Dur %d turn" % lone if lone == 1 else "Dur %d turns" % lone
	if not tip.contains(dur) or not tip.contains("Max %d per turn" % per):
		push_error("Plant tooltip missing the kit duration or cap: %s" % tip)
		return true
	var reason := ""
	if hud != null:
		var snap: Dictionary = sim.snapshot()
		var unit: Dictionary = {}
		for raw in snap.get("units", []):
			if typeof(raw) == TYPE_DICTIONARY and str(raw.get("class_id", "")) == "bastion":
				unit = raw
		reason = CombatHUD.plant_button_reason(unit, snap, false)
	print("PLANT CAP reason=%s" % reason)
	if reason != "max %d" % per:
		push_error("Plant button reason is not the kit cap: %s" % reason)
		return true
	_save("plant_cap.png")
	return true


func _banners_drawn(board: Node) -> bool:
	var vfx: Node = board.get("_vfx")
	if vfx == null:
		push_error("board has no vfx director")
		return false
	var linger: Dictionary = vfx.get("_linger")
	var found := 0
	for key in linger.keys():
		if not str(key).begins_with("plant_banner:"):
			continue
		found += 1
		var node: Node = linger[key]
		if node is CanvasItem:
			var item := node as CanvasItem
			print("BANNER %s scale=%.3f alpha=%.3f" % [str(key), item.scale.x, item.modulate.a])
	if found < 4:
		push_error("expected 4 plant banners, drew %d" % found)
		return false
	return true


func _save(file_name: String) -> bool:
	var path := _dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("PLANT SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if err != OK:
		push_error("could not save %s" % path)
		return false
	return true


func _boot(sim: Node) -> bool:
	var spot := _cluster(sim)
	if spot.is_empty():
		push_error("no slagcrown run for the banners")
		return false
	_banners = spot["banners"]
	_bastion_cell = spot["bastion"]
	_kestrel_cell = spot["kestrel"]
	_banner_cell = _banners[1]
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [_bastion_cell, _kestrel_cell],
	})
	var guard := 0
	while int(sim.snapshot().get("active_seat", -1)) != _class_seat(sim, "bastion") and guard < 4:
		sim.submit({"type": "end_turn"})
		guard += 1
	sim._plant_tiles.clear()
	for cell in _banners:
		sim._plant_tiles.append({
			"pos": cell,
			"turns": 3,
			"owner_seat": _class_seat(sim, "bastion"),
			"push_resist": true,
		})
	print("PLANT CLUSTER banners=%s bastion=%s kestrel=%s" % [_banners, _bastion_cell, _kestrel_cell])
	return true


## Four banners in a row. Bastion stands on the second. Kestrel stands on the
## tile visually behind the first, which is the cloth a tall banner covers.
func _cluster(sim: Node) -> Dictionary:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(2, n - 2):
		for x in range(2, n - 6):
			var banners: Array = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y), Vector2i(x + 3, y)]
			var behind := Vector2i(x, y - 1)
			var on_flag := Vector2i(x + 1, y)
			if not _open(sim, behind) or not _open(sim, on_flag):
				continue
			var clear := true
			for cell in banners:
				if not _open(sim, cell):
					clear = false
					break
			if not clear or behind == on_flag:
				continue
			return {"banners": banners, "bastion": on_flag, "kestrel": behind}
	return {}


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"


func _cast_to_cap(sim: Node) -> bool:
	var seat := _class_seat(sim, "bastion")
	var actor := Vector2i(-1, -1)
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) == seat:
			actor = unit["pos"]
	var kit: Dictionary = SpellKits.spell(SpellKits.PLANT)
	var cap := int(kit.get("plants_per_turn", 3))
	var placed := 0
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(n):
		for x in range(n):
			if placed >= cap:
				break
			var cell := Vector2i(x, y)
			if cell == actor:
				continue
			var result: Dictionary = sim.submit({"type": "cast", "spell": "plant", "to": cell, "seat": seat})
			if bool(result.get("ok", false)):
				placed += 1
		if placed >= cap:
			break
	if placed < cap:
		push_error("could only plant %d of %d" % [placed, cap])
		return false
	return true


func _class_seat(sim: Node, class_id: String) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id:
			return int(unit.get("seat", -1))
	return -1
