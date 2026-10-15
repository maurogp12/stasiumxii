extends SceneTree

## Real fight scene, not the sim alone. Phone clip on 0.1.199: Ironjaw stands
## on the tile next to the yellow landing (6,0) and Gloam's name is five
## straight steps away. Flare must leave that Gloam hidden. A finished Ambush
## hold used to keep drawing him on the older tile after the burst had
## measured a closer one.
##
## xvfb-run godot --rendering-driver opengl3 --path . -s res://tests/shot_flare_five.gd

var _phase := "boot"
var _frames := 0
var _board: Node
var _failed := false


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 900:
		_fail("timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _play_five():
			return true
		_phase = "pinned"
		_frames = 0
		return false
	if _phase == "pinned":
		if not _play_pinned():
			return true
		print("FLARE FIVE ok")
		return true
	return true


func _play_five() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var landing := Vector2i(6, 0)
	var ironjaw := Vector2i(6, 1)
	var gloam := Vector2i(6, 5)
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [ironjaw, gloam],
		"gloam_invisible": true,
	})
	sim._unit_by_seat(0)["spell_elements"] = {"strike": "air", "shoulder": "fire", "crush": "fire", "advance": "air"}
	if sim.manhattan(landing, sim._unit_by_seat(1)["pos"]) != 5:
		return _fail("setup is not 5 straight steps")
	var first: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": landing, "seat": 0})
	if not bool(first.get("ok", false)):
		return _fail("Strike into (6,0) failed: %s" % str(first.get("reason", "")))
	var second: Dictionary = sim.submit({"type": "cast", "spell": "shoulder", "to": landing, "seat": 0})
	if not bool(second.get("ok", false)):
		return _fail("Shoulder into (6,0) failed: %s" % str(second.get("reason", "")))
	var blend := {}
	for event in second.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "blend":
			blend = event
	if str(blend.get("blend", "")) != "flare":
		return _fail("expected Flare, got %s" % str(blend.get("blend", "")))
	if blend.get("to", Vector2i(-1, -1)) != landing:
		return _fail("Flare landing %s is not the yellow tile" % str(blend.get("to", "")))
	if not (blend.get("revealed", []) as Array).is_empty():
		return _fail("Flare listed a reveal at 5 steps")
	if not bool(sim._unit_by_seat(1).get("invisible", false)):
		return _fail("sim revealed Gloam 5 straight steps from (6,0)")
	var coach := str(second.get("snapshot", {}).get("coach", ""))
	if not coach.contains("(6,0)"):
		return _fail("coach missing the landing: %s" % coach)
	if coach.contains("Fade cooldown"):
		return _fail("Fade cooldown fired at 5 steps: %s" % coach)
	_board.select_tile(landing)
	_board._rebuild_pawns()
	_board._refresh()
	var selected = _board.selected_tile
	if selected == null or selected.grid_position != landing:
		return _fail("yellow tile is %s, not (6,0)" % str(selected.grid_position if selected != null else "none"))
	var pawn: Pawn = _board.pawns_by_seat[1]
	if pawn == null:
		return _fail("Gloam pawn missing")
	if pawn.visible or not pawn.invisible:
		return _fail("Gloam is drawn revealed at %s, %s steps from the yellow tile" % [pawn.grid_position, sim.manhattan(landing, pawn.grid_position)])
	if pawn.unit_name != "Gloam":
		return _fail("name tag is %s" % pawn.unit_name)
	print("FIVE hidden at %s, yellow %s, coach [%s]" % [gloam, selected.grid_position, coach])
	return true


## Gloam's real tile is 2 steps from the landing, so Flare reveals him. The
## picture is pinned on the tile five steps away, the way a finished Ambush
## hold used to freeze the body. The name has to land on the measured tile.
func _play_pinned() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var landing := Vector2i(6, 0)
	var stale := Vector2i(6, 5)
	var measured := Vector2i(6, 2)
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(6, 1), stale],
		"gloam_invisible": true,
	})
	sim._unit_by_seat(0)["spell_elements"] = {"strike": "air", "shoulder": "fire", "crush": "fire", "advance": "air"}
	_board._rebuild_pawns()
	_board._refresh()
	var pawn: Pawn = _board.pawns_by_seat[1]
	# The last tile Ironjaw saw, before Gloam stepped closer while hidden.
	pawn.grid_position = stale
	pawn.position = _board._cell_to_local(stale)
	pawn.visible = false
	pawn.invisible = true
	sim._unit_by_seat(1)["pos"] = measured
	sim._unit_by_seat(1)["invisible"] = true
	var first: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": landing, "seat": 0})
	if not bool(first.get("ok", false)):
		return _fail("pinned Strike failed: %s" % str(first.get("reason", "")))
	var second: Dictionary = sim.submit({"type": "cast", "spell": "shoulder", "to": landing, "seat": 0})
	if not bool(second.get("ok", false)):
		return _fail("pinned Shoulder failed: %s" % str(second.get("reason", "")))
	if bool(sim._unit_by_seat(1).get("invisible", true)):
		return _fail("Flare did not reveal the measured tile (6,2)")
	if sim.manhattan(landing, sim._unit_by_seat(1)["pos"]) != 2:
		return _fail("measured tile moved")
	# The arrival tween is finished. The hold flag is all that is left.
	_board._ambush_hold_seat = 1
	_board._ambush_hold_cell = stale
	_board._ambush_hold_pos = _board._cell_to_local(stale)
	_board._ambush_hold_facing = "S"
	_board._ambush_hold_event = {"type": "hit", "spell": "ambush", "seat": 1}
	_board._ambush_open_seat = -1
	_board._ambush_arrival_tween = null
	_board._busy = true
	_board._hop_seat = 1
	_board._walk_tween = null
	_board.select_tile(landing)
	_board._refresh()
	pawn = _board.pawns_by_seat[1]
	var drawn: Vector2i = pawn.grid_position
	var steps: int = sim.manhattan(landing, drawn)
	print("PINNED drawn %s steps %s visible %s invisible %s" % [drawn, steps, pawn.visible, pawn.invisible])
	if not pawn.visible or pawn.invisible:
		return _fail("revealed Gloam is not drawn")
	if pawn.unit_name != "Gloam":
		return _fail("revealed name is %s" % pawn.unit_name)
	if drawn != measured:
		return _fail("Gloam is drawn on %s (%s steps from the yellow tile), not the measured tile %s" % [drawn, steps, measured])
	if pawn.position.distance_to(_board._cell_to_local(measured)) > 1.0:
		return _fail("name tag is not on the measured tile")
	if steps > 4:
		return _fail("revealed Gloam is still %s steps from the yellow landing" % steps)
	var selected = _board.selected_tile
	if selected == null or selected.grid_position != landing:
		return _fail("yellow landing moved")
	return true


func _fail(message: String) -> bool:
	if not _failed:
		push_error(message)
		print("FAIL %s" % message)
		_failed = true
	return false
