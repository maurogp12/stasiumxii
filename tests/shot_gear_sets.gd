extends SceneTree

## 2400×1080 review shots: each class wearing its Legendary set, plus one crit.
## godot --rendering-driver opengl3 -s res://tests/shot_gear_sets.gd -- <dir>

const LEGENDARY := {
	"bastion": "oathgrave",
	"kestrel": "ravenmourn",
	"ironjaw": "tyrantjaw",
	"gloam": "gravewhisper",
	"mender": "hallowmourn",
}

var _dir := "/opt/cursor/artifacts/gear_sets"
var _frames := 0
var _phase := 0
var _class_index := 0
var _classes: Array[String] = []
var _screen: Control
var _crit_text := ""
var _crit_seen := 0
var _floater_at := Vector2.ZERO
var _nudged := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	GearBag.save_path = "user://shot_gear_sets.json"
	var bag := GearBag.new()
	bag.save()
	_classes = GearBag.CLASS_IDS.duplicate()
	_dump_tables()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		push_error("gear-set shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_show_class()
		return false
	if _phase == 1:
		if _frames < 6:
			return false
		_save_class()
		return false
	if _phase == 2:
		return _combat_boot()
	if _phase == 3:
		return _combat_capture()
	return true


func _show_class() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
	var cid := _classes[_class_index]
	var fam := str(LEGENDARY[cid])
	_screen = (load("res://scenes/gear_screen.gd") as Script).new()
	_screen.name = "GearShot"
	root.add_child(_screen)
	var result: Dictionary = _screen._bag.debug_equip_set(cid, fam)
	_screen._refresh()
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.text.begins_with("Debug review"):
			label.visible = false
		if str(child.name).begins_with("DebugSet_"):
			child.visible = false
	print("EQUIP %s %s ok=%s header=%s" % [cid, fam, result.get("ok", false), _screen.header_text()])
	for slot in GearBag.SLOTS:
		var button := _screen.find_child("Slot_" + slot, true, false)
		print("SLOT %s %s" % [slot, button.text if button != null else "MISSING"])
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.visible:
			print("BONUS %s" % label.text.replace("\n", " "))
	if not bool(result.get("ok", false)):
		push_error("debug equip failed for %s" % cid)
	_phase = 1
	_frames = 0


func _save_class() -> void:
	var cid := _classes[_class_index]
	var fam := str(LEGENDARY[cid])
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized gear to 2400x1080")
	var path := _dir.path_join("gear_%s.png" % cid)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	var header := str(_screen.header_text())
	if not header.contains(SpellKits.display_name(cid)):
		push_error("gear header is not %s: %s" % [cid, header])
	var weapon := _screen.find_child("Slot_weapon", true, false)
	var set_name := str(GearBag.FAMILIES[fam]["name"])
	if weapon == null or not str(weapon.text).contains(set_name):
		push_error("weapon slot is not %s" % set_name)
	var saw_five := false
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.text.contains("5pc:") and label.text.contains("+1 AP +1 MP"):
			saw_five = true
	if not saw_five:
		push_error("%s set panel is missing the Legendary 5pc line" % cid)
	_class_index += 1
	if _class_index < _classes.size():
		_phase = 0
		_frames = 0
		return
	_screen.queue_free()
	_screen = null
	change_scene_to_file("res://main.tscn")
	_phase = 2
	_frames = 0


func _combat_boot() -> bool:
	if _frames < 2:
		return false
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	var pair := _pair(sim)
	if pair.size() < 2:
		push_error("no open Mark Shot pair")
		return true
	sim.reset_match({
		"seed": 1,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": pair,
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1, 1],
	})
	var bag := GearBag.new()
	var equipped: Dictionary = bag.debug_equip_set("kestrel", "ravenmourn")
	if not bool(equipped.get("ok", false)):
		push_error("combat debug equip failed")
		return true
	var kite: Dictionary = sim._unit_by_seat(0)
	sim._apply_gear(kite, bag.fight_gear(false, "kestrel"))
	print("CRIT_CHANCE %s" % kite.get("crit", 0))
	var hit: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": pair[1], "seat": 0})
	print("MARK %s" % JSON.stringify(hit))
	if not bool(hit.get("ok", false)):
		push_error("Mark Shot did not resolve")
		return true
	var crit_event := false
	for event in hit.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and bool(event.get("crit", false)):
			crit_event = true
			print("CRIT_EVENT damage=%s text_mult=%s" % [event.get("damage", 0), event.get("crit_mult", 0)])
	if not crit_event:
		push_error("Mark Shot event was not a crit")
		return true
	board._rebuild_pawns()
	board._refresh()
	if board._camera != null:
		board._camera.zoom = Vector2(1.8, 1.8)
		board._center_on_cell(pair[1])
	board._arm_vfx(hit.get("events", []))
	_phase = 3
	_frames = 0
	_crit_seen = 0
	_nudged = false
	return false


func _combat_capture() -> bool:
	var board := current_scene.get_node_or_null("BoardView")
	var found := _find_crit(board if board != null else root)
	if found != "":
		_crit_text = found
		_crit_seen += 1
		if not _nudged and board != null and board._camera != null and _floater_at.y < 220.0:
			var zoom_y := maxf(board._camera.zoom.y, 0.01)
			var delta := (320.0 - _floater_at.y) / zoom_y
			board._camera.position.y -= delta
			_nudged = true
			_crit_seen = 0
			print("NUDGE camera by %.1f toward y=320" % delta)
	# The hit stamp covers the number for ~0.3s. The number stays up through the rise.
	if _crit_seen < 8:
		if _frames > 180:
			push_error("crit floater never appeared")
			_save_combat()
			return true
		return false
	_save_combat()
	return true


func _save_combat() -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized combat to 2400x1080")
	var path := _dir.path_join("crit_mark_shot.png")
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s floater=%s" % [path, image.get_width(), image.get_height(), err, _crit_text])


func _find_crit(node: Node) -> String:
	if node == null:
		return ""
	var text := str(node.get("_text")) if "_text" in node else ""
	if text.contains("CRIT") and node is CanvasItem and (node as CanvasItem).visible and (node as CanvasItem).modulate.a > 0.5:
		_floater_at = (node as CanvasItem).get_global_transform_with_canvas().origin
		print("FLOATER %s alpha=%.2f at=%s" % [text, (node as CanvasItem).modulate.a, _floater_at])
		return text
	for child in node.get_children():
		var found := _find_crit(child)
		if found != "":
			return found
	return ""


func _pair(sim: Node) -> Array:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(4, n - 4):
		for x in range(4, n - 7):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 3, y)
			if _open(sim, a) and _open(sim, b):
				print("PAIR %s %s" % [a, b])
				return [a, b]
	return []


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"


func _dump_tables() -> void:
	for fam in GearBag.FAMILY_ORDER:
		var spec: Dictionary = GearBag.FAMILIES[fam]
		var totals := {"hp": 0, "mastery": 0, "resist": 0, "init": 0, "crit": 0}
		var lines: PackedStringArray = PackedStringArray()
		for slot in GearBag.SLOTS:
			var item_id := GearBag.item_id_for(fam, slot)
			var part: Dictionary = GearBag.PARTS[item_id]
			for key in totals.keys():
				totals[key] = int(totals[key]) + int(part.get(key, 0))
			lines.append("%s mas=%s hp=%s res=%s init=%s crit=%s" % [slot, part.get("mastery", 0), part.get("hp", 0), part.get("resist", 0), part.get("init", 0), part.get("crit", 0)])
		print("TABLE %s %s %s owner=%s budget=%d totals hp=%d mas=%d res=%d init=%d crit=%d" % [
			fam, spec["name"], spec["rarity"], spec["owner"] if str(spec["owner"]) != "" else "any",
			GearBag.budget_points(fam), totals["hp"], totals["mastery"], totals["resist"], totals["init"], totals["crit"],
		])
		for line in lines:
			print("  PART %s" % line)
		for tier in [2, 4, 5]:
			print("  BONUS %d %s" % [tier, spec["bonus"][tier]])
