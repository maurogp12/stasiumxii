extends Node2D
class_name VfxDirector

## View-only combat VFX. Listens through BoardView.play, never through CombatSim rules.
## Displacement beats share the existing input lock and stay within 0.6s.
## Floating numbers, sparks, and shakes do not add lock time. The turn clock is never paused.

signal debug_beat(beat_name: String)

const _Router := preload("res://vfx/vfx_router.gd")
const _Spark := preload("res://vfx/vfx_spark.gd")
const _Number := preload("res://vfx/vfx_number.gd")
const _Puff := preload("res://vfx/vfx_puff.gd")
const _Motes := preload("res://vfx/vfx_motes.gd")
const _Projectile := preload("res://vfx/vfx_projectile.gd")
const _Ring := preload("res://vfx/vfx_ring.gd")
const _Status := preload("res://vfx/vfx_status.gd")

@export var reduce_shake: bool = false

## Tests set this so a headless SceneTree can still spawn pooled effects.
var allow_headless: bool = false

static var _force_reduce: int = -1

var _board: Node2D
var _pools: Dictionary = {}
var _linger: Dictionary = {}
var _recycle: Dictionary = {}
var _block_until_msec: int = 0
var _shake_base: Vector2 = Vector2.ZERO
var _shake_amp: float = 0.0
var _shake_dur: float = 0.0
var _shake_t: float = 0.0
var _shaking: bool = false
var _motion: Tween
var _debug_index: int = 0
var _readout: Label
var _readout_tween: Tween


static func reduce_shake_enabled(instance_flag: bool = false) -> bool:
	if _force_reduce == 1 or instance_flag:
		return true
	if _force_reduce == 0:
		return false
	if ProjectSettings.has_setting("stasium/view/reduce_shake"):
		return bool(ProjectSettings.get_setting("stasium/view/reduce_shake"))
	return false


static func set_reduce_shake(enabled: bool) -> void:
	_force_reduce = 1 if enabled else 0


static func clear_reduce_shake() -> void:
	_force_reduce = -1


static func shake_pixels(wants: bool, instance_flag: bool = false) -> float:
	if not wants or reduce_shake_enabled(instance_flag):
		return 0.0
	return VfxBudget.SHAKE_PX


func bind_board(board: Node2D) -> void:
	_board = board
	if board != null:
		_shake_base = board.position


func _ready() -> void:
	_build_pools()
	_build_readout()
	_prewarm()


func play(events: Array, snapshot: Dictionary = {}) -> float:
	return _emit(events, snapshot, true, false)


func play_debug(events: Array) -> float:
	return _emit(events, {}, false, true)


func is_blocking() -> bool:
	return Time.get_ticks_msec() < _block_until_msec


func linger_count() -> int:
	return _linger.size()


func pool_size(kind: String) -> int:
	var pool: Variant = _pools.get(kind, [])
	return pool.size() if pool is Array else 0


func active_count() -> int:
	var count := 0
	for kind in _pools.keys():
		for node in _pools[kind]:
			if node != null and bool(node.get("in_use")):
				count += 1
	return count


func dismiss_all() -> void:
	for key in _linger.keys():
		var node: Node = _linger[key]
		if node != null and is_instance_valid(node) and node.has_method("release"):
			node.release()
	_linger.clear()
	_kill_motion()
	_stop_shake(true)


func sync_snapshot(snapshot: Dictionary) -> void:
	if _suppressed() or snapshot.is_empty():
		return
	var wanted: Dictionary = {}
	_want_tokens(wanted, snapshot.get("shade_tokens", []), "shade", VfxPalette.GLOAM_RIM, 0.35)
	_want_tokens(wanted, snapshot.get("plant_tiles", []), "plant", VfxPalette.BASTION, 0.0)
	_want_tokens(wanted, snapshot.get("blocked_tiles", []), "wall", VfxPalette.BASTION_BLACK, 0.0)
	for unit in snapshot.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = unit
		if not bool(rec.get("alive", true)):
			continue
		var seat := int(rec.get("seat", -1))
		var cell := _Router.cell_of(rec.get("pos", Vector2i.ZERO))
		if int(rec.get("stun_remaining", 0)) > 0 or bool(rec.get("stunned", false)):
			wanted["stun:%d" % seat] = {"pool": "status", "status": "stun", "seat": seat, "cell": cell}
		if int(rec.get("burn_remaining", 0)) > 0:
			wanted["burn:%d" % seat] = {"pool": "status", "status": "burn", "seat": seat, "cell": cell}
		if int(rec.get("shield", 0)) > 0:
			wanted["shield:%d" % seat] = {"pool": "status", "status": "shield", "seat": seat, "cell": cell, "tint": VfxPalette.MENDER}
		_want_count(wanted, rec, "marks", seat, cell, VfxPalette.KESTREL)
		_want_count(wanted, rec, "impact", seat, cell, VfxPalette.IRONJAW)
		_want_count(wanted, rec, "aegis", seat, cell, VfxPalette.BASTION)
		_want_count(wanted, rec, "umbral", seat, cell, VfxPalette.GLOAM_RIM)
		_want_count(wanted, rec, "pulse", seat, cell, VfxPalette.MENDER)
		_want_count(wanted, rec, "hit_immunity", seat, cell, VfxPalette.MENDER)
		_want_count(wanted, rec, "exit_tax", seat, cell, VfxPalette.BASTION)
		if bool(rec.get("skip_next_mp", false)):
			wanted["skip_next_mp:%d" % seat] = {"pool": "status", "status": "skip_next_mp", "seat": seat, "cell": cell, "tint": VfxPalette.MENDER_DEEP}
		if bool(rec.get("invisible", false)):
			wanted["invisible:%d" % seat] = {"pool": "status", "status": "invisible", "seat": seat, "cell": cell, "tint": VfxPalette.GLOAM_RIM}
	var stale: Array = []
	for key in _linger.keys():
		if not wanted.has(key):
			stale.append(key)
	for key in stale:
		_dismiss_linger(str(key))
	for key in wanted.keys():
		_ensure_linger(str(key), wanted[key])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_play_next_debug()
		get_viewport().set_input_as_handled()


func _play_next_debug() -> void:
	var beats: Array = _Router.debug_beats()
	if beats.is_empty():
		return
	var beat: Dictionary = beats[_debug_index % beats.size()]
	_debug_index += 1
	play_debug(beat.get("events", []))
	_show_readout(str(beat.get("name", "vfx")))
	debug_beat.emit(str(beat.get("name", "vfx")))


func _emit(events: Array, snapshot: Dictionary, lock_input: bool, ghost_motion: bool) -> float:
	if _suppressed():
		return 0.0
	var recipes: Array = _Router.assign_stacks(_Router.recipes_for(events, snapshot))
	var block := _Router.blocking_sec(recipes)
	if lock_input and block > 0.0:
		_block_until_msec = Time.get_ticks_msec() + int(block * 1000.0)
	_kill_motion()
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn(item, ghost_motion)
	var sync := snapshot.has("units") or snapshot.has("shade_tokens") or snapshot.has("plant_tiles") or snapshot.has("blocked_tiles")
	if sync:
		sync_snapshot(snapshot)
	return block


func _suppressed() -> bool:
	if allow_headless:
		return false
	var net := get_node_or_null("/root/NetSession")
	if net != null and net.has_method("is_dedicated") and bool(net.call("is_dedicated")):
		return true
	return DisplayServer.get_name() == "headless"


func _spawn(spec: Dictionary, ghost_motion: bool) -> void:
	match str(spec.get("id", "")):
		"spark":
			_play_burst("spark", spec, true)
		"puff":
			_play_burst("puff", spec, false)
		"motes":
			_play_burst("motes", spec, true)
		"number":
			_play_number(spec)
		"projectile":
			_play_projectile(spec)
		"ring":
			_play_ring(spec, false)
		"slide":
			_play_slide(spec, ghost_motion)
		"jolt":
			_play_nudge(spec, ghost_motion, false)
		"bounce":
			_play_nudge(spec, ghost_motion, true)
		"chevron":
			_play_chevron(spec)
		"status_on":
			_ensure_linger(_status_key(spec), spec)
		"status_off":
			_dismiss_linger(_status_key(spec))
		"status_pulse":
			_pulse_status(spec)
		"status_flash":
			_play_status_flash(spec)
		"shake":
			_start_shake(float(spec.get("amplitude", 0.0)), float(spec.get("duration", VfxBudget.SHAKE_SEC)))
		"death":
			_play_death(spec)
		"winner":
			_play_winner(spec)
		"lava_todo":
			pass
		_:
			pass


func _play_burst(kind: String, spec: Dictionary, chest: bool) -> void:
	var node := _acquire(kind)
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var at := _body_pos(int(spec.get("seat", -1)), cell, chest)
	var payload := {
		"pos": at,
		"tint": spec.get("tint", VfxPalette.KESTREL_AIR),
		"alpha": float(spec.get("alpha", 1.0)),
		"z": _z_air(cell),
	}
	if spec.has("amount"):
		payload["amount"] = int(spec["amount"])
	node.play(payload)


func _play_number(spec: Dictionary) -> void:
	var node := _acquire("number")
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var at := _body_pos(int(spec.get("seat", -1)), cell, false)
	at += VfxBudget.HEAD_OFFSET
	at.y -= VfxBudget.NUMBER_STACK_PX * float(int(spec.get("stack", 0)))
	node.position = at
	node.z_as_relative = false
	node.z_index = 900
	node.play(spec)


func _play_projectile(spec: Dictionary) -> void:
	var node := _acquire("projectile")
	var from_cell := _Router.cell_of(spec.get("from", Vector2i.ZERO))
	var to_cell := _Router.cell_of(spec.get("to", from_cell))
	node.play({
		"from": _pos_cell(from_cell),
		"to": _pos_cell(to_cell),
		"arc": float(spec.get("arc", 0.0)),
		"overshoot": float(spec.get("overshoot", 0.0)),
		"duration": float(spec.get("duration", 0.2)),
		"tint": spec.get("tint", VfxPalette.KESTREL_AIR),
		"width": float(spec.get("width", 3.0)),
		"z": _z_air(to_cell),
	})


func _play_ring(spec: Dictionary, track: bool) -> void:
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var payload := spec.duplicate()
	payload["pos"] = _pos_cell(cell)
	payload["z"] = _z_ground(cell)
	if bool(spec.get("linger", false)) or track:
		_ensure_linger(_ring_key(spec), payload)
		return
	var node := _acquire("ring")
	node.play(payload)


func _play_slide(spec: Dictionary, ghost_motion: bool) -> void:
	var from_pos := _pos_cell(_Router.cell_of(spec.get("from", Vector2i.ZERO)))
	var to_pos := _pos_cell(_Router.cell_of(spec.get("to", Vector2i.ZERO)))
	var mover := _motion_node(spec, ghost_motion, from_pos)
	_motion = create_tween()
	_motion.tween_property(mover, "position", to_pos, float(spec.get("block", VfxBudget.BLOCK_SLIDE))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.finished.connect(_puff_at.bind(to_pos, spec.get("tint", VfxPalette.IRONJAW_DUST)), CONNECT_ONE_SHOT)


func _play_nudge(spec: Dictionary, ghost_motion: bool, spark: bool) -> void:
	var from_pos := _pos_cell(_Router.cell_of(spec.get("from", Vector2i.ZERO)))
	var attempted := _pos_cell(_Router.cell_of(spec.get("attempted", Vector2i.ZERO)))
	var delta := attempted - from_pos
	var dir := delta.normalized() if delta.length_squared() > 1.0 else Vector2(1, 0.5).normalized()
	var pawn := _motion_node(spec, ghost_motion, from_pos)
	var origin := pawn.position
	var out := origin + dir * float(spec.get("distance", 4.0))
	var block := float(spec.get("block", VfxBudget.BLOCK_JOLT))
	_motion = create_tween()
	_motion.tween_property(pawn, "position", out, block * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(pawn, "position", origin, block * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if spark:
		_spark_at(out, spec.get("tint", VfxPalette.KESTREL_AIR))


func _play_chevron(spec: Dictionary) -> void:
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var at := _body_pos(int(spec.get("seat", -1)), cell, false)
	var from_pos := _pos_cell(_Router.cell_of(spec.get("from", Vector2i.ZERO)))
	var aim := at - from_pos
	if aim.length_squared() < 1.0:
		aim = Vector2(1, 0.5)
	aim = aim.normalized()
	var node := _acquire("status")
	node.set("follow", Callable())
	node.play({
		"status": "chevron",
		"pos": at + aim * 18.0 + Vector2(0, -16),
		"aim": aim,
		"tint": spec.get("tint", VfxPalette.KESTREL_AIR),
		"life": 0.32,
		"z": _z_air(cell),
	})


func _play_death(spec: Dictionary) -> void:
	var seat := int(spec.get("seat", -1))
	var pawn := _pawn(seat)
	var at := pawn.position if pawn != null else Vector2.ZERO
	var cause := str(spec.get("cause", "damage"))
	var tint := Color(0.55, 0.52, 0.48, 0.85)
	if cause == "burn":
		tint = VfxPalette.BURN
	_puff_at(at + Vector2(0, -8), tint)
	var ring := _acquire("ring")
	ring.play({
		"pos": at,
		"tint": VfxPalette.EMBER if cause == "burn" else Color(0.75, 0.72, 0.7),
		"linger": false,
		"life": 0.36,
		"style": "crack" if cause == "burn" else "",
		"z": 30,
	})


func _play_winner(spec: Dictionary) -> void:
	var seat := int(spec.get("seat", -1))
	var pawn := _pawn(seat)
	var tint := VfxPalette.BASTION
	var cell := Vector2i.ZERO
	if pawn != null:
		if "class_id" in pawn:
			tint = VfxPalette.class_tint(str(pawn.class_id))
		if "grid_position" in pawn:
			cell = pawn.grid_position
	var node := _acquire("ring")
	var pos := pawn.position if pawn != null else _pos_cell(cell)
	node.play({
		"pos": pos,
		"tint": tint,
		"linger": false,
		"life": 0.45,
		"swirl": 0.0,
		"z": _z_ground(cell),
	})


func _play_status_flash(spec: Dictionary) -> void:
	var node := _acquire("status")
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var seat := int(spec.get("seat", -1))
	node.set("follow", _follow_seat.bind(seat) if seat >= 0 else Callable())
	node.play({
		"status": str(spec.get("status", "slash")),
		"pos": _body_pos(seat, cell, false),
		"tint": spec.get("tint", VfxPalette.KESTREL_AIR),
		"life": float(spec.get("life", 0.28)),
		"count": int(spec.get("count", 1)),
		"z": _z_air(cell),
	})


func _pulse_status(spec: Dictionary) -> void:
	var key := _status_key(spec)
	if not _linger.has(key):
		return
	var node: Node = _linger[key]
	if node != null and is_instance_valid(node) and node.has_method("pulse"):
		node.pulse(0.3)


func _start_shake(amplitude: float, duration: float) -> void:
	if _board == null:
		return
	var pixels := shake_pixels(amplitude > 0.0, reduce_shake)
	if pixels <= 0.0:
		return
	if _shaking and pixels < _shake_amp:
		return
	if _shaking:
		_board.position = _shake_base
	_shake_base = _board.position
	_shake_amp = pixels
	_shake_dur = duration
	_shake_t = 0.0
	_shaking = true
	set_process(true)


func _process(delta: float) -> void:
	if not _shaking or _board == null:
		set_process(false)
		return
	_shake_t += delta
	if _shake_t >= _shake_dur:
		_stop_shake(true)
		return
	var fade := 1.0 - (_shake_t / _shake_dur)
	var spin := Vector2(sin(_shake_t * 60.0), cos(_shake_t * 60.0))
	_board.position = _shake_base + spin * _shake_amp * fade


func _stop_shake(restore: bool) -> void:
	_shaking = false
	if restore and _board != null:
		_board.position = _shake_base
	set_process(false)


func _motion_node(spec: Dictionary, ghost_motion: bool, origin: Vector2) -> Node2D:
	var pawn := _pawn(int(spec.get("seat", -1))) if not ghost_motion else null
	if pawn != null:
		pawn.position = origin
		return pawn
	var node := _acquire("ring")
	node.play({
		"pos": origin,
		"tint": spec.get("tint", VfxPalette.IRONJAW_DUST),
		"linger": false,
		"life": float(spec.get("block", 0.2)) + 0.12,
		"z": 20,
	})
	node.position = origin
	return node


func _ensure_linger(key: String, spec: Dictionary) -> void:
	if key == "" or key.ends_with(":-1") or key.ends_with(":-999"):
		return
	var pool_name := "ring"
	if str(spec.get("pool", "")) != "":
		pool_name = str(spec.get("pool", pool_name))
	elif str(spec.get("status", "")) != "":
		pool_name = "status"
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	var payload := spec.duplicate()
	payload["pos"] = _body_pos(int(spec.get("seat", -1)), cell, false) if pool_name == "status" else _pos_cell(cell)
	var style := str(spec.get("style", ""))
	var standing := pool_name == "status" or style == "slab" or style == "figure"
	payload["z"] = _z_air(cell) if standing else _z_ground(cell)
	payload["linger"] = true
	if _linger.has(key):
		var existing: Node = _linger[key]
		if existing != null and is_instance_valid(existing) and bool(existing.get("in_use")):
			if existing.has_method("retarget"):
				existing.retarget(payload)
			if bool(spec.get("flare", false)) and existing.has_method("pulse"):
				existing.pulse(0.25)
			return
	var node := _acquire(pool_name)
	if pool_name == "status":
		var seat := int(spec.get("seat", -1))
		node.set("follow", _follow_seat.bind(seat) if seat >= 0 else Callable())
	node.play(payload)
	if bool(spec.get("dim", false)):
		node.modulate.a = 0.4
	_linger[key] = node


func _dismiss_linger(key: String) -> void:
	if not _linger.has(key):
		return
	var node: Node = _linger[key]
	_linger.erase(key)
	if node != null and is_instance_valid(node) and node.has_method("dismiss"):
		node.dismiss()


func _status_key(spec: Dictionary) -> String:
	var status := str(spec.get("status", ""))
	if status in ["shade", "plant", "wall"]:
		var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
		return "%s:%d,%d" % [status, cell.x, cell.y]
	return "%s:%d" % [status, int(spec.get("seat", -1))]


func _ring_key(spec: Dictionary) -> String:
	var tint: Color = spec.get("tint", VfxPalette.GLOAM)
	var kind := "wall"
	if tint.is_equal_approx(VfxPalette.GLOAM_RIM):
		kind = "shade"
	elif tint.is_equal_approx(VfxPalette.BASTION) and float(spec.get("swirl", 0.0)) > 0.0:
		kind = "shade"
	elif tint.is_equal_approx(VfxPalette.BASTION):
		kind = "plant"
	var cell := _Router.cell_of(spec.get("cell", Vector2i.ZERO))
	return "%s:%d,%d" % [kind, cell.x, cell.y]


func _want_tokens(wanted: Dictionary, raw: Variant, kind: String, tint: Color, swirl: float) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var cell := _Router.cell_of(rec.get("pos", Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))))
		var key := "%s:%d,%d" % [kind, cell.x, cell.y]
		var style := ""
		if kind == "shade":
			style = "figure"
		elif kind == "plant":
			style = "sigil"
		elif kind == "wall":
			style = "slab"
		wanted[key] = {
			"pool": "ring",
			"cell": cell,
			"tint": tint,
			"linger": true,
			"swirl": swirl,
			"style": style,
			"turns": int(rec.get("turns", 0)),
			"dim": kind == "plant" and rec.has("push_resist") and not bool(rec.get("push_resist", true)),
		}


func _puff_at(at: Vector2, tint: Color) -> void:
	if _suppressed():
		return
	var node := _acquire("puff")
	node.play({"pos": at, "tint": tint, "alpha": 0.75, "z": 40})


func _spark_at(at: Vector2, tint: Color) -> void:
	var node := _acquire("spark")
	node.play({"pos": at, "tint": tint, "z": 50})


func _follow_seat(seat: int) -> Vector2:
	var pawn := _pawn(seat)
	if pawn != null:
		return pawn.position
	return Vector2.ZERO


func _body_pos(seat: int, cell: Vector2i, chest: bool) -> Vector2:
	var pawn := _pawn(seat)
	var at := pawn.position if pawn != null else _pos_cell(cell)
	if chest:
		at += VfxBudget.CHEST_OFFSET
	return at


func _pos_cell(cell: Vector2i) -> Vector2:
	if _board != null and _board.has_method("_cell_to_local"):
		return _board.call("_cell_to_local", cell)
	return BoardVisualSort.cell_to_local(cell, 0.0)


func _elev(cell: Vector2i) -> float:
	if _board != null and _board.has_method("_elev_at"):
		return float(_board.call("_elev_at", cell))
	return 0.0


func _z_ground(cell: Vector2i) -> int:
	return BoardVisualSort.tile_z_index(cell, _elev(cell)) + 1


func _z_air(cell: Vector2i) -> int:
	return BoardVisualSort.unit_z_index(cell, _elev(cell)) + 2


func _pawn(seat: int) -> Node2D:
	if seat < 0 or _board == null or not ("pawns_by_seat" in _board):
		return null
	var map: Variant = _board.get("pawns_by_seat")
	if typeof(map) != TYPE_DICTIONARY or not map.has(seat):
		return null
	var pawn: Variant = map[seat]
	if pawn is Node2D and is_instance_valid(pawn):
		return pawn
	return null


func _build_pools() -> void:
	_add_pool("spark", _Spark, VfxBudget.POOL_SPARK)
	_add_pool("number", _Number, VfxBudget.POOL_NUMBER)
	_add_pool("puff", _Puff, VfxBudget.POOL_PUFF)
	_add_pool("motes", _Motes, VfxBudget.POOL_MOTE)
	_add_pool("projectile", _Projectile, VfxBudget.POOL_PROJECTILE)
	_add_pool("ring", _Ring, VfxBudget.POOL_RING)
	_add_pool("status", _Status, VfxBudget.POOL_STATUS)


func _add_pool(kind: String, script: Script, count: int) -> void:
	var pool: Array = []
	for i in count:
		var node := script.new() as Node2D
		node.name = "%s_%d" % [kind, i]
		add_child(node)
		pool.append(node)
	_pools[kind] = pool


func _acquire(kind: String) -> Node2D:
	var pool: Array = _pools.get(kind, [])
	for node in pool:
		if node != null and not bool(node.get("in_use")):
			return node
	var index := int(_recycle.get(kind, 0))
	_recycle[kind] = index + 1
	var recycled: Node2D = pool[index % pool.size()]
	_drop_linger_node(recycled)
	if recycled.has_method("release"):
		recycled.release()
	return recycled


func _drop_linger_node(node: Node) -> void:
	var stale: Array = []
	for key in _linger.keys():
		if _linger[key] == node:
			stale.append(key)
	for key in stale:
		_linger.erase(key)


func _want_count(wanted: Dictionary, rec: Dictionary, field: String, seat: int, cell: Vector2i, tint: Color) -> void:
	var count := int(rec.get(field, 0))
	if count <= 0:
		return
	wanted["%s:%d" % [field, seat]] = {
		"pool": "status",
		"status": field,
		"seat": seat,
		"cell": cell,
		"count": count,
		"tint": tint,
	}


func _prewarm() -> void:
	for kind in _pools.keys():
		for node in _pools[kind]:
			if node.has_method("prewarm"):
				node.prewarm()
	for kind in _pools.keys():
		for node in _pools[kind]:
			if node.has_method("release"):
				node.release()


func _kill_motion() -> void:
	if _motion != null and is_instance_valid(_motion):
		_motion.kill()
	_motion = null


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(16, 12)
	_readout.visible = false
	_readout.add_theme_font_size_override("font_size", 18)
	_readout.add_theme_color_override("font_color", VfxPalette.MENDER_CREAM)
	_readout.add_theme_color_override("font_outline_color", VfxPalette.NUMBER_OUTLINE)
	_readout.add_theme_constant_override("outline_size", 4)
	layer.add_child(_readout)


func _show_readout(text: String) -> void:
	if _readout == null:
		return
	if _readout_tween != null and is_instance_valid(_readout_tween):
		_readout_tween.kill()
	_readout.text = "VFX  %s    F9 next" % text
	_readout.visible = true
	_readout_tween = create_tween()
	_readout_tween.tween_interval(1.5)
	_readout_tween.tween_callback(_hide_readout)


func _hide_readout() -> void:
	if _readout != null:
		_readout.visible = false
