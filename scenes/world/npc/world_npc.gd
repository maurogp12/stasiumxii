extends Node2D

## One open-world NPC. Painted role art from `art/characters/world/npc/<role>/`
## (see npc_sprites.gd): idle loop by default, talk once when the hero opens
## the dialogue, walk and work for the NPCs that move (spec 4.5a Movement,
## npc_roam.gd). A role with no painted folder falls back to the old stand-in:
## a class world sprite with a role tint. The art strips are not edited.
## Y-sorted with props using BoardVisualSort.UNIT_Z_BIAS.

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Art := preload("res://scenes/world/npc/npc_sprites.gd")
const Roam := preload("res://scenes/world/npc/npc_roam.gd")

## Stand-in only, for a role with no painted folder.
const ROLE_CLASS := {
	"warden": "bastion",
	"trader": "mender",
	"door_keeper": "ironjaw",
	"guide": "kestrel",
	"herald": "kestrel",
	"banker": "mender",
	"elder": "bastion",
	"smith": "ironjaw",
	"fisher": "kestrel",
	"farmer": "mender",
	"woodcutter": "ironjaw",
	"archivist": "gloam",
	"ferry_captain": "kestrel",
	"forge_master": "ironjaw",
	"fen_guide": "gloam",
	"hermit": "gloam",
	"seer": "gloam",
	"last_watcher": "bastion",
	"coil_engineer": "kestrel",
}
## Stand-in only, for a role with no painted folder.
const ROLE_TINT := {
	"warden": Color("d7c4a1"),
	"trader": Color("e2b15a"),
	"door_keeper": Color("c46a4a"),
	"guide": Color("f2e6c9"),
	"herald": Color("e8d27a"),
	"banker": Color("8fd0c6"),
	"elder": Color("c9b7e0"),
	"smith": Color("e07a3d"),
	"fisher": Color("7eb6d8"),
	"farmer": Color("b7c86a"),
	"woodcutter": Color("a9845a"),
	"archivist": Color("9aa6d6"),
	"ferry_captain": Color("6fbfc4"),
	"forge_master": Color("e25b3a"),
	"fen_guide": Color("8aaa62"),
	"hermit": Color("6e8f72"),
	"seer": Color("c9a0d8"),
	"last_watcher": Color("7a6ea8"),
	"coil_engineer": Color("9ec4e6"),
}

## A post NPC turns to the hero inside this many cells (Manhattan).
const NOTICE_CELLS := 4
## Seconds a mover waits before it tries a blocked step again.
const RETRY_SEC := 0.6
## Blocked tries before a mover drops its target and picks another.
const RETRY_LIMIT := 3

var npc_id := ""
var role := ""
var display_name := ""
## Logical cell. A mover takes the next cell at the half-way point of a step.
var cell := Vector2i.ZERO
## Post cell from npcs.json.
var home := Vector2i.ZERO
## World step letter (n, e, s, w). See npc_sprites.gd for the art letters.
var facing := "s"
var home_facing := "s"
## post, patrol or wander (npc_roam.gd).
var behaviour := "post"
## Painted art, or empty when this role uses the tinted stand-in.
var art: Dictionary = {}
## Anim on screen: idle, walk, talk, or the role's work anim.
var anim := "idle"
var mark := ""
## False keeps a mover at its post (tests and captures may set this).
var roam_enabled := true

var _zone: WorldZone
var _sprite: Sprite2D
var _strips = null
var _bob := 0.0
var _plate: Node2D
var _opaque_top := 0
var _frame := 0
var _anim_t := 0.0
var _rng := RandomNumberGenerator.new()
## The world. Answers npc_cell_free(npc, cell) and npc_hero_cell(npc).
var _host: Object = null
var _allowed: Dictionary = {}
var _spots: Array = []
var _stops: Array[Vector2i] = []
var _stop_i := 0
var _path: Array[Vector2i] = []
var _step_from := Vector2i.ZERO
var _step_to := Vector2i.ZERO
var _step_t := 0.0
var _stepping := false
var _wait := 0.0
var _retries := 0
var _held := false
var _arrive_face := ""
var _notice_t := 0.0


func set_mark(next: String) -> void:
	if next != "!" and next != "?":
		next = ""
	if mark == next:
		return
	mark = next
	_sync_plate()


## Name plate drawn on a canvas layer above the grade, so fog does not wash it out.
## The label is centred in the backing. The backing's bottom edge stays a fixed
## screen distance above the sprite's visible head.
class NamePlate extends Node2D:
	const FONT_SIZE := 16
	const PAD := 5.0
	const HEAD_GAP := 7.0

	var plate_text := ""
	var mark := ""
	## Screen y of the sprite's visible head, relative to this plate's origin.
	var head_y := 0.0
	## Text as of the last redraw request.
	var drawn_text := ""

	func backing_rect() -> Rect2:
		var label := label_rect()
		return Rect2(label.position - Vector2(PAD, PAD), label.size + Vector2(PAD * 2.0, PAD * 2.0))

	func label_rect() -> Rect2:
		var font := ThemeDB.fallback_font
		var size := font.get_string_size(plate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var ascent := font.get_ascent(FONT_SIZE)
		var descent := font.get_descent(FONT_SIZE)
		var base := baseline_y()
		return Rect2(Vector2(-size.x * 0.5, base - ascent), Vector2(size.x, ascent + descent))

	func baseline_y() -> float:
		var font := ThemeDB.fallback_font
		var descent := font.get_descent(FONT_SIZE)
		return head_y - HEAD_GAP - descent - PAD

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var box := backing_rect()
		var label := label_rect()
		draw_rect(box, Color(0.09, 0.07, 0.05, 0.9), true)
		draw_rect(box, Color(1.0, 0.95, 0.84, 0.95), false, 1.5)
		draw_string(font, Vector2(label.position.x, baseline_y()), plate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 0.97, 0.9))
		if mark == "":
			return
		var mark_size := 22
		var mark_width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size).x
		var center := Vector2(0, box.position.y - 16.0)
		draw_circle(center, 13.0, Color(0.1, 0.07, 0.04, 0.92))
		var mark_color := Color(1.0, 0.84, 0.22) if mark == "!" else Color(0.65, 0.9, 1.0)
		var mark_base := center.y + font.get_ascent(mark_size) * 0.35
		draw_string(font, Vector2(center.x - mark_width * 0.5, mark_base), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size, mark_color)


func setup(zone: WorldZone, record: Dictionary, plates: CanvasLayer = null) -> void:
	npc_id = str(record.get("id", ""))
	role = str(record.get("role", ""))
	display_name = str(record.get("name", ""))
	var at: Dictionary = record.get("cell", {})
	cell = Vector2i(int(at.get("x", 0)), int(at.get("y", 0)))
	home = cell
	facing = str(record.get("facing", "S")).to_lower()
	home_facing = facing
	name = "Npc_%s" % npc_id
	_zone = zone
	_rng.seed = hash(npc_id)
	z_as_relative = false
	z_index = _base_z(cell)
	position = Pick.cell_center(zone, cell)
	art = Art.load_role(role)
	behaviour = Roam.behaviour_for(role) if not art.is_empty() else Roam.POST
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if art.is_empty():
		_strips = Strips.new()
		_strips.load_class(str(ROLE_CLASS.get(role, "kestrel")))
		_sprite.offset = _strips.pivot
		_sprite.scale = Vector2.ONE * _strips.scale
		_sprite.modulate = ROLE_TINT.get(role, Color.WHITE)
	else:
		var frame: Vector2i = art["frame"]
		var pivot: Vector2 = art["pivot"]
		_sprite.offset = Vector2(float(frame.x) * 0.5 - pivot.x, float(frame.y) * 0.5 - pivot.y)
		_sprite.scale = Vector2.ONE * Art.DRAW_SCALE_1X
		_opaque_top = int(art.get("head_top", 0))
	add_child(_sprite)
	# Stagger first moves so a town does not set off in step.
	_wait = _rng.randf_range(2.0, 5.0)
	_apply_idle()
	queue_redraw()
	_mount_plate(plates)


func is_painted() -> bool:
	return not art.is_empty()


## Let this NPC move. `host` is the world: it answers npc_cell_free(npc, cell)
## and npc_hero_cell(npc). `forbidden` holds cells a mover never enters;
## `no_dwell` holds cells it may cross but never pauses on.
func attach_host(host: Object, forbidden: Dictionary, no_dwell: Dictionary = {}) -> void:
	_host = host
	var radius := Roam.radius_for(behaviour)
	_allowed = Roam.area(_zone, home, radius, forbidden)
	_spots = []
	_stops = []
	if behaviour == Roam.WANDER:
		_spots = Roam.pause_spots(_zone, home, _allowed, no_dwell)
	elif behaviour == Roam.PATROL:
		_stops = Roam.patrol_stops(_zone, home, _allowed, no_dwell)
		_stop_i = 0


## Cells a mover may stand on (empty for a post NPC with no host).
func allowed_cells() -> Dictionary:
	return _allowed


func pause_spots() -> Array:
	return _spots


func patrol_stops() -> Array[Vector2i]:
	return _stops


func is_walking() -> bool:
	return _stepping


## Standing still at home, a pause spot or a patrol stop (not mid-route).
func is_dwelling() -> bool:
	return not _stepping and _path.is_empty()


func is_held() -> bool:
	return _held


## The cells this NPC blocks: its cell, plus the far cell of a step.
func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = [cell]
	if _stepping:
		if not out.has(_step_from):
			out.append(_step_from)
		if not out.has(_step_to):
			out.append(_step_to)
	return out


## The cell this NPC will stand on once its current step ends.
func stop_cell() -> Vector2i:
	return _step_to if _stepping else cell


## The hero is coming to talk. Finish the current step, then stand still.
func hold() -> void:
	_held = true
	_path.clear()


## Face the hero and play the talk gesture once. Stays held until release().
func talk_to(dir: String) -> void:
	_held = true
	_path.clear()
	if _stepping:
		_finish_step()
	face(dir)
	if not art.is_empty() and (art["anims"] as Dictionary).has("talk"):
		_set_anim("talk")


## The dialogue closed. Pause a moment, then go back to the routine.
func release() -> void:
	if not _held:
		return
	_held = false
	_wait = _rng.randf_range(1.0, 2.0)
	if anim != "idle" and not _stepping:
		_set_anim("idle")


func face(dir: String) -> void:
	var next := dir.to_lower()
	if next != "n" and next != "e" and next != "s" and next != "w":
		return
	facing = next
	if art.is_empty():
		_apply_idle()
	else:
		_show_frame()


## Advance this NPC by `delta` seconds. _process calls it; tests call it directly.
func tick(delta: float) -> void:
	if art.is_empty():
		_bob += delta
		_sprite.position = Vector2(0, sin(_bob * 2.2) * 1.5)
		return
	_tick_anim(delta)
	if _stepping:
		_tick_step(delta)
		return
	if _held:
		return
	if behaviour == Roam.POST or _host == null or not roam_enabled:
		_notice_hero(delta)
		return
	if not _path.is_empty():
		_try_step(delta)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_pick_target()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	tick(delta)
	_sync_plate()


func _tick_anim(delta: float) -> void:
	var spec: Dictionary = (art["anims"] as Dictionary).get(anim, {})
	if spec.is_empty():
		return
	_anim_t += delta
	var per := 1.0 / float(spec["fps"])
	var frames := int(spec["frames"])
	var moved := false
	while _anim_t >= per:
		_anim_t -= per
		_frame += 1
		moved = true
		if _frame >= frames:
			if bool(spec["loop"]):
				_frame = 0
			else:
				# A one-shot (talk) ends on idle.
				_set_anim("idle")
				return
	if moved:
		_show_frame()


func _set_anim(next: String) -> void:
	if art.is_empty() or not (art["anims"] as Dictionary).has(next):
		next = "idle"
	anim = next
	_frame = 0
	_anim_t = 0.0
	_show_frame()


func _show_frame() -> void:
	if _sprite == null or art.is_empty():
		return
	var anims: Dictionary = art["anims"]
	var spec: Dictionary = anims.get(anim, anims["idle"])
	var source := Art.source_for(art, facing)
	var tex: Texture2D = (spec["tex"] as Dictionary).get(str(source["src"]), null)
	if tex == null:
		return
	var count := int(spec["frames"])
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Art.frame_rect(art, clampi(_frame, 0, count - 1))
	_sprite.flip_h = bool(source["flip"])


## A post NPC turns to the hero when the hero is close, and back to its
## post facing when the hero leaves.
func _notice_hero(delta: float) -> void:
	if _host == null or not _host.has_method("npc_hero_cell"):
		return
	_notice_t -= delta
	if _notice_t > 0.0:
		return
	_notice_t = 0.25
	var hero: Vector2i = _host.npc_hero_cell(self)
	var want := home_facing
	if hero.x >= 0 and Roam.manhattan(hero, cell) <= NOTICE_CELLS and hero != cell:
		want = Roam.face_toward(cell, hero)
	if want != "" and want != facing:
		face(want)


func _pick_target() -> void:
	_retries = 0
	_arrive_face = ""
	var target := home
	if behaviour == Roam.WANDER:
		var choices: Array = []
		for spot in _spots:
			if (spot["cell"] as Vector2i) != cell:
				choices.append(spot)
		if choices.is_empty():
			_wait = 3.0
			return
		var pick: Dictionary = choices[_rng.randi_range(0, choices.size() - 1)]
		target = pick["cell"]
		_arrive_face = str(pick["face"])
	elif behaviour == Roam.PATROL:
		if _stops.size() < 2:
			# No room for a loop (a post on a ledge or a jetty): look around
			# in place now and then.
			var look := str(art.get("work", ""))
			if look != "" and anim != look:
				_set_anim(look)
				var spec: Dictionary = (art["anims"] as Dictionary)[look]
				_wait = float(spec["frames"]) / float(spec["fps"])
			else:
				_set_anim("idle")
				_wait = _rng.randf_range(4.0, 7.0)
			return
		_stop_i = (_stop_i + 1) % _stops.size()
		target = _stops[_stop_i]
		if target == cell:
			_wait = 1.0
			return
	_path = Roam.path(_allowed, cell, target)
	if _path.is_empty():
		_wait = 2.0


func _try_step(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	var next: Vector2i = _path[0]
	var free := true
	if _host != null and _host.has_method("npc_cell_free"):
		free = bool(_host.npc_cell_free(self, next))
	if not free:
		_retries += 1
		_wait = RETRY_SEC
		if anim != "idle":
			_set_anim("idle")
		if _retries >= RETRY_LIMIT:
			# Try another spot. Keep the old route if nothing else is open,
			# so a walker never settles on a lane cell.
			var keep := _path.duplicate()
			var keep_face := _arrive_face
			_pick_target()
			if _path.is_empty():
				_path = keep
				_arrive_face = keep_face
				_wait = RETRY_SEC
		return
	_retries = 0
	_path.pop_front()
	_step_from = cell
	_step_to = next
	_step_t = 0.0
	_stepping = true
	facing = Roam.step_letter(next - cell)
	if anim != "walk":
		_set_anim("walk")
	else:
		_show_frame()


func _tick_step(delta: float) -> void:
	var a: Vector2 = Pick.cell_center(_zone, _step_from)
	var b: Vector2 = Pick.cell_center(_zone, _step_to)
	var span := maxf(a.distance_to(b), 1.0)
	var speed := maxf(Art.walk_speed(art), 8.0)
	_step_t = minf(1.0, _step_t + delta * speed / span)
	position = a.lerp(b, _step_t)
	if _step_t >= 0.5 and cell != _step_to:
		_move_cell(_step_to)
	if _step_t >= 1.0:
		_finish_step()


func _finish_step() -> void:
	_move_cell(_step_to)
	position = Pick.cell_center(_zone, _step_to)
	_stepping = false
	if _held:
		_set_anim("idle")
		return
	if not _path.is_empty():
		return
	_arrive()


func _arrive() -> void:
	var work := str(art.get("work", ""))
	if behaviour == Roam.WANDER:
		if _arrive_face != "" and work != "":
			face(_arrive_face)
			_set_anim(work)
			_wait = _rng.randf_range(4.0, 7.0)
		else:
			face(home_facing if cell == home else facing)
			_set_anim("idle")
			_wait = _rng.randf_range(2.5, 4.5)
	elif behaviour == Roam.PATROL:
		if cell == home:
			face(home_facing)
		if work != "":
			_set_anim(work)
			var spec: Dictionary = (art["anims"] as Dictionary)[work]
			_wait = float(spec["frames"]) / float(spec["fps"]) + _rng.randf_range(0.5, 1.5)
		else:
			_set_anim("idle")
			_wait = _rng.randf_range(1.5, 3.0)
	else:
		_set_anim("idle")


func _move_cell(next: Vector2i) -> void:
	if next == cell:
		return
	var raise := z_index - _base_z(cell)
	cell = next
	z_index = clampi(_base_z(cell) + raise, -4096, 4096)


func _base_z(c: Vector2i) -> int:
	return (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS


func _exit_tree() -> void:
	if _plate != null and is_instance_valid(_plate):
		_plate.queue_free()
		_plate = null


func _mount_plate(plates: CanvasLayer) -> void:
	if plates == null:
		return
	var plate := NamePlate.new()
	plate.plate_text = display_name
	plate.name = "Plate_%s" % npc_id
	plates.add_child(plate)
	_plate = plate
	_sync_plate()


func _sync_plate() -> void:
	if _plate == null or not is_inside_tree():
		return
	var canvas := get_global_transform_with_canvas()
	_plate.position = canvas.origin
	# Moving the plate is a transform change. Only a new head height, mark or
	# name changes what it draws, so it redraws only then, not every frame.
	var head := canvas.basis_xform(Vector2(0.0, _head_local_y())).y
	if _plate.head_y != head or _plate.mark != mark or _plate.drawn_text != _plate.plate_text:
		_plate.head_y = head
		_plate.mark = mark
		_plate.drawn_text = _plate.plate_text
		_plate.queue_redraw()


## Visible head in this NPC's local space. Painted art uses the highest idle
## row of the role, so the plate does not bob with each frame.
func _head_local_y() -> float:
	if _sprite == null:
		return 0.0
	var tex_h := 160.0
	if _sprite.region_enabled:
		tex_h = _sprite.region_rect.size.y
	elif _sprite.texture != null:
		tex_h = float(_sprite.texture.get_height())
	return _sprite.position.y + _sprite.scale.y * (_sprite.offset.y - tex_h * 0.5 + float(_opaque_top))


func _measure_opaque_top() -> void:
	_opaque_top = 0
	if _sprite == null or _sprite.texture == null:
		return
	var image := _sprite.texture.get_image()
	if image == null or image.is_empty():
		return
	var origin := Vector2i.ZERO
	var size := image.get_size()
	if _sprite.region_enabled:
		var region := _sprite.region_rect
		origin = Vector2i(int(region.position.x), int(region.position.y))
		size = Vector2i(maxi(int(region.size.x), 0), maxi(int(region.size.y), 0))
	for y in size.y:
		var row := origin.y + y
		if row < 0 or row >= image.get_height():
			continue
		for x in size.x:
			var col := origin.x + x
			if col < 0 or col >= image.get_width():
				continue
			if image.get_pixel(col, row).a > 0.2:
				_opaque_top = y
				return


func _apply_idle() -> void:
	if _sprite == null:
		return
	if not art.is_empty():
		_set_anim("idle")
		_sync_plate()
		return
	if _strips == null:
		return
	var tex: Texture2D = _strips.idle(facing)
	if tex == null:
		tex = _strips.texture("walk", facing)
	_sprite.texture = tex
	if tex != null and _strips.frame_count("walk", facing) > 1 and _strips.idle(facing) == null:
		var frame: Vector2i = _strips.frame_size("walk")
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(0, 0, frame.x, frame.y)
	else:
		_sprite.region_enabled = false
	_measure_opaque_top()
	_sync_plate()


## The painted strips carry their own contact shadow. The stand-in keeps the
## drawn ellipse.
func _draw() -> void:
	if not art.is_empty():
		return
	var shadow := PackedVector2Array()
	var steps := 10
	for i in steps:
		var a := float(i) / float(steps) * TAU
		shadow.append(Vector2(cos(a) * 14.0, sin(a) * 5.0 + 4.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
