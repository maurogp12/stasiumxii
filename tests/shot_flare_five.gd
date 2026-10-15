extends SceneTree

const LOG := preload("res://ui/battle_log.gd")

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
		_phase = "stuck"
		_frames = 0
		return false
	if _phase == "stuck":
		if not _play_stuck_seat():
			return true
		_phase = "walking"
		_frames = 0
		return false
	if _phase == "walking":
		if not _play_live_walk():
			return true
		_phase = "clip_far"
		_frames = 0
		return false
	if _phase == "clip_far":
		if not _play_clip_panel(Vector2i(9, 9), true):
			return true
		_phase = "clip_near"
		_frames = 0
		return false
	if _phase == "clip_near":
		if not _play_clip_panel(Vector2i(9, 8), false):
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
	if not coach.contains("2 AP"):
		return _fail("the revealing cast is Shoulder, 2 AP: %s" % coach)
	if coach.contains("Fade cooldown"):
		return _fail("Fade cooldown fired at 5 steps: %s" % coach)
	var hang_coach := str(first.get("snapshot", {}).get("coach", ""))
	if not hang_coach.contains("3 AP") or hang_coach.contains("Fade cooldown"):
		return _fail("the 3 AP hang must not reveal: %s" % hang_coach)
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


## 0.1.200 phone clip. Strike (3 AP) hangs at (6,0). Shoulder (2 AP) is the
## Flare. Gloam's measured cell is 4 straight steps from that landing, so
## Fade ends. The picture was still the pre-Fade tile, 5 steps away, because
## an Ambush open-seat flag outlived its arrival tween.
func _play_stuck_seat() -> bool:
	return _play_revealed_on_measured(false)


## Same clip while the hidden step's walk tween is still running. The name
## has to land on the cell Flare measured, not the tile the tween was painting.
func _play_live_walk() -> bool:
	return _play_revealed_on_measured(true)


func _play_revealed_on_measured(live_walk: bool) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var landing := Vector2i(6, 0)
	var stale := Vector2i(6, 5)
	var measured := Vector2i(6, 4)
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(6, 1), measured],
		"gloam_invisible": true,
	})
	sim._unit_by_seat(0)["spell_elements"] = {"strike": "air", "shoulder": "fire", "crush": "fire", "advance": "air"}
	if sim.manhattan(landing, measured) != 4:
		return _fail("measured cell is not 4 straight steps from (6,0)")
	if sim.manhattan(landing, stale) != 5:
		return _fail("stale cell is not 5 straight steps from (6,0)")
	_board._rebuild_pawns()
	_board._refresh()
	var pawn: Pawn = _board.pawns_by_seat[1]
	pawn.grid_position = stale
	pawn.position = _board._cell_to_local(stale)
	pawn.visible = false
	pawn.invisible = true
	var hang: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": landing, "seat": 0})
	if not bool(hang.get("ok", false)):
		return _fail("clip Strike failed: %s" % str(hang.get("reason", "")))
	var hang_coach := str(hang.get("snapshot", {}).get("coach", ""))
	if not hang_coach.contains("(6,0)") or not hang_coach.contains("3 AP") or hang_coach.contains("Fade cooldown"):
		return _fail("Strike hang coach: %s" % hang_coach)
	if not bool(sim._unit_by_seat(1).get("invisible", false)):
		return _fail("the first element, hanging on Ironjaw, revealed Gloam")
	_board._ambush_hold_seat = 1
	_board._ambush_hold_cell = stale
	_board._ambush_hold_pos = _board._cell_to_local(stale)
	_board._ambush_hold_facing = "S"
	_board._ambush_hold_event = {"type": "hit", "spell": "ambush", "seat": 1}
	_board._ambush_open_seat = 1
	_board._ambush_arrival_tween = null
	if live_walk:
		_board._busy = true
		_board._hop_seat = 1
		_board._stop_walk_tween()
		_board._walk_tween = _board.create_tween()
		_board._walk_tween.tween_interval(30.0)
		if not _board._walk_tween.is_running():
			return _fail("walk tween was not live before the reveal refresh")
	else:
		_board._busy = false
		_board._hop_seat = -1
		_board._walk_tween = null
	var flare: Dictionary = sim.submit({"type": "cast", "spell": "shoulder", "to": landing, "seat": 0})
	if not bool(flare.get("ok", false)):
		return _fail("clip Shoulder failed: %s" % str(flare.get("reason", "")))
	var coach := str(flare.get("snapshot", {}).get("coach", ""))
	if not coach.contains("(6,0)") or not coach.contains("2 AP") or not coach.contains("Fade cooldown"):
		return _fail("Shoulder Flare coach: %s" % coach)
	if bool(sim._unit_by_seat(1).get("invisible", true)):
		return _fail("Flare did not reveal Gloam 4 straight steps from (6,0)")
	if sim.manhattan(landing, sim._unit_by_seat(1)["pos"]) != 4:
		return _fail("measured tile is no longer 4 steps from the landing")
	_board.select_tile(landing)
	_board._refresh()
	pawn = _board.pawns_by_seat[1]
	var drawn: Vector2i = pawn.grid_position
	var steps: int = sim.manhattan(landing, drawn)
	print("CLIP live_walk %s drawn %s steps %s" % [live_walk, drawn, steps])
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


## Shoulder into empty (9, 4). Five straight steps keeps the model hidden
## and the card on "Invisible 3". Four straight steps reveals both together,
## on the cell Flare measured, even if a finished Ambush hold is still open.
func _play_clip_panel(gloam_at: Vector2i, stay_hidden: bool) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var landing := Vector2i(9, 4)
	var stale := Vector2i(9, 9)
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(9, 5), gloam_at],
		"gloam_invisible": true,
	})
	sim._unit_by_seat(0)["spell_elements"] = {"strike": "air", "shoulder": "fire", "crush": "fire", "advance": "air"}
	sim._unit_by_seat(1)["invisible_turns"] = 3
	var steps: int = sim.manhattan(landing, gloam_at)
	if steps != (5 if stay_hidden else 4):
		return _fail("(9,4) distance is %s" % steps)
	_board._rebuild_pawns()
	_board._refresh()
	var hang: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": landing, "seat": 0})
	if not bool(hang.get("ok", false)):
		return _fail("(9,4) Strike failed: %s" % str(hang.get("reason", "")))
	var flare: Dictionary = sim.submit({"type": "cast", "spell": "shoulder", "to": landing, "seat": 0})
	if not bool(flare.get("ok", false)):
		return _fail("(9,4) Shoulder failed: %s" % str(flare.get("reason", "")))
	var coach := str(flare.get("snapshot", {}).get("coach", ""))
	if not coach.contains("(9,4)") or coach.contains("[0"):
		return _fail("(9,4) coach: %s" % coach)
	var logged := str(LOG.text(sim.snapshot().get("battle_log", []), sim.snapshot()))
	if logged.contains("[0,1,0]") or logged.contains("[0, 1, 0]") or logged.contains("[0"):
		return _fail("(9,4) log prefix: %s" % logged)
	var pawn: Pawn = _board.pawns_by_seat[1]
	# Drawn solid on the far tile, with the arrival flag still open. That
	# pair used to show the body and leave the card on Invisible.
	pawn.grid_position = stale
	pawn.position = _board._cell_to_local(stale)
	pawn.visible = true
	pawn.invisible = false
	pawn._ambush_strike_visible = true
	_board._ambush_open_seat = 1
	_board._ambush_hold_seat = 1
	_board._ambush_hold_cell = stale
	_board._ambush_hold_pos = _board._cell_to_local(stale)
	_board._ambush_arrival_tween = null
	_board._ambush_contact_armed = false
	_board.select_tile(landing)
	_board._refresh()
	pawn = _board.pawns_by_seat[1]
	var card := _gloam_card()
	print("CLIP94 hidden %s drawn %s visible %s invisible %s card [%s]" % [stay_hidden, pawn.grid_position, pawn.visible, pawn.invisible, card])
	if stay_hidden:
		if not bool(sim._unit_by_seat(1).get("invisible", false)):
			return _fail("sim revealed Gloam 5 steps from (9,4)")
		if int(sim._unit_by_seat(1).get("invisible_turns", 0)) != 3:
			return _fail("Invisible clock is %s" % str(sim._unit_by_seat(1).get("invisible_turns", 0)))
		if pawn.visible or not pawn.invisible:
			return _fail("Gloam is drawn while the card says Invisible")
		if pawn.grid_position != gloam_at:
			return _fail("hidden Gloam is drawn on %s, not %s" % [pawn.grid_position, gloam_at])
		if not card.contains("Invisible 3"):
			return _fail("card lost Invisible 3: %s" % card)
		return true
	if bool(sim._unit_by_seat(1).get("invisible", true)):
		return _fail("sim left Gloam hidden 4 steps from (9,4)")
	if not pawn.visible or pawn.invisible:
		return _fail("revealed Gloam is not drawn")
	if pawn.grid_position != gloam_at:
		return _fail("revealed Gloam is drawn on %s, not the measured tile %s" % [pawn.grid_position, gloam_at])
	if pawn.position.distance_to(_board._cell_to_local(gloam_at)) > 1.0:
		return _fail("revealed name is not on the measured tile")
	if card.contains("Invisible"):
		return _fail("card still says Invisible after the reveal: %s" % card)
	return true


func _gloam_card() -> String:
	var hud: CombatHUD = _board._hud
	if hud == null or hud._ironjaw_body == null:
		return ""
	return hud._ironjaw_body.text


func _fail(message: String) -> bool:
	if not _failed:
		push_error(message)
		print("FAIL %s" % message)
		_failed = true
	return false
