extends SceneTree

## Phase E host-validate contract checks.
## Run: godot --headless --path . -s res://tests/run_host_validate_tests.gd

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	_run()
	print("Host-validate tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_contract_stamps()
	_test_intent_shape()
	_test_client_must_not_roll()
	_test_submit_stays_identical()
	_test_seed_host_owned()


func _test_contract_stamps() -> void:
	eq(HostValidate.HOST_OWNS_SEED, true, "seed is host-owned")
	eq(HostValidate.HOST_OWNS_RNG, true, "RNG is host-owned")
	eq(HostValidate.CLIENT_MAY_SEND_ROLL, false, "client may not send a roll")
	eq(HostValidate.CLIENT_PATH_AUTHORITATIVE, false, "intent.path is not authoritative")
	eq(HostValidate.INTENT_TYPES.has("move"), true, "move is a shared Intent type")
	eq(HostValidate.INTENT_TYPES.has("cast"), true, "cast is a shared Intent type")
	eq(HostValidate.INTENT_TYPES.has("end_turn"), true, "end_turn is a shared Intent type")
	eq(HostValidate.DEPLOY_TYPES.has("place"), true, "place is a deploy Intent")
	var src := FileAccess.get_file_as_string("res://backend/host_validate.gd")
	eq(src.contains("MultiplayerSynchronizer"), false, "host_validate does not invent MultiplayerSynchronizer")
	eq(src.contains("rpc"), false, "host_validate does not invent RPC")
	var md := FileAccess.get_file_as_string("res://MIGRATION_PHASE_E.md")
	truthy(md.contains("submit(intent)"), "Phase E doc keeps submit identical")
	truthy(md.contains("host-owned") or md.contains("host owns"), "Phase E doc names host-owned seed/RNG")
	truthy(md.contains("listen-host") or md.contains("listen host"), "Phase E doc names listen-host proto")
	truthy(md.contains("ENet") or md.contains("enet"), "Phase E doc names ENet transport")


func _test_intent_shape() -> void:
	eq(HostValidate.validate_intent({"type": "end_turn"})["ok"], true, "end_turn envelope is legal")
	eq(HostValidate.validate_intent({"type": "face", "dir": "N"})["ok"], true, "face N is legal")
	eq(HostValidate.validate_intent({"type": "move", "to": Vector2i(2, 2)})["ok"], true, "move dest is legal")
	eq(HostValidate.validate_intent({"type": "cast", "spell": "shoulder", "to": Vector2i(1, 0)})["ok"], true, "cast envelope is legal")
	eq(HostValidate.validate_intent({"type": "place", "seat": 0, "to": Vector2i(1, 1)})["ok"], true, "place envelope is legal")
	eq(HostValidate.validate_intent({"type": "ready", "seat": 1})["ok"], true, "ready envelope is legal")
	eq(HostValidate.validate_intent({})["reason"], "missing_type", "empty intent is missing_type")
	eq(HostValidate.validate_intent({"type": "dash"})["reason"], "unknown_intent", "unknown type is unknown_intent")
	eq(HostValidate.validate_intent({"type": "face"})["reason"], "missing_dir", "face without dir is missing_dir")
	eq(HostValidate.validate_intent({"type": "move"})["reason"], "missing_destination", "move without to is missing_destination")
	eq(HostValidate.validate_intent({"type": "cast", "to": Vector2i(1, 0)})["reason"], "missing_spell", "cast without spell is missing_spell")
	eq(HostValidate.validate_intent({"type": "ready"})["reason"], "missing_seat", "ready without seat is missing_seat")
	eq(HostValidate.validate_intent({"type": "end_turn", "seat": 3})["reason"], "bad_seat", "seat 3 is bad_seat")


func _test_client_must_not_roll() -> void:
	eq(HostValidate.validate_intent({"type": "cast", "spell": "strike", "to": Vector2i(1, 0), "roll": 12})["reason"], "client_must_not_roll", "intent.roll is rejected")
	eq(HostValidate.validate_intent({"type": "cast", "spell": "strike", "to": Vector2i(1, 0), "hit_roll": 12})["reason"], "client_must_not_roll", "intent.hit_roll is rejected")
	eq(HostValidate.validate_match_config({"seed": 1, "roll": 4})["reason"], "client_must_not_roll", "config.roll is rejected")
	eq(HostValidate.validate_match_config({"seed": 1, "rolls": [1]})["reason"], "client_must_not_roll", "live config.rolls is rejected")
	eq(HostValidate.validate_match_config({"seed": 1, "rolls": [1]}, true)["ok"], true, "fixture rolls stay allowed")
	eq(HostValidate.validate_match_config({"seed": 1, "elev_seed": 1})["ok"], true, "host seed/elev_seed is legal")


func _test_submit_stays_identical() -> void:
	# Same Intent CombatSim already accepts. Host-validate is a gate, not a new API.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
	})
	var move := {"type": "move", "to": Vector2i(2, 1)}
	eq(HostValidate.validate_intent(move)["ok"], true, "host-validate accepts the move Intent")
	var moved: Dictionary = _sim.submit(move)
	eq(moved["ok"], true, "CombatSim.submit still accepts that same move Intent")

	var face := {"type": "face", "dir": "S"}
	eq(HostValidate.validate_intent(face)["ok"], true, "host-validate accepts the face Intent")
	eq(_sim.submit(face)["ok"], true, "CombatSim.submit still accepts that same face Intent")

	var end_turn := {"type": "end_turn"}
	eq(HostValidate.validate_intent(end_turn)["ok"], true, "host-validate accepts end_turn")
	eq(_sim.submit(end_turn)["ok"], true, "CombatSim.submit still accepts end_turn")

	var cast := {"type": "cast", "spell": "shoulder", "to": Vector2i(1, 1)}
	eq(HostValidate.validate_intent(cast)["ok"], true, "host-validate accepts the cast Intent")
	# Ironjaw is now active after end_turn; range from (6,6) to (1,1) is illegal.
	# Shape is identical — CombatSim still owns the range reject.
	var cast_result: Dictionary = _sim.submit(cast)
	eq(cast_result["illegal"], true, "CombatSim still owns cast legality")
	truthy(str(cast_result["reason"]) in ["out_of_range", "no_target"], "cast reject is still CombatSim, not host-validate")


func _test_seed_host_owned() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 42, "elev_seed": 42, "skip_deploy": true, "flat_board": true})
	eq(snap["seed"], 42, "snapshot.seed is the host seed")
	eq(snap["elev_seed"], 42, "snapshot.elev_seed is the host elev_seed")
	eq(snap["match_config"]["seed"], 42, "match_config.seed is host-owned")
	eq(snap["networking"], false, "networking stays OFF")
	eq(snap.has("last_events"), true, "snapshot still carries last_events for a future host broadcast")


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
