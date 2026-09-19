extends RefCounted
class_name HostValidate

## Phase E host-validate contract. Shape + ownership only.
## CombatSim.submit remains the combat authority. This module does not
## implement networking, rolls, or legality (range / AP / walk gates).

const INTENT_TYPES := [
	"end_turn",
	"face",
	"move",
	"cast",
	"place",
	"reposition",
	"ready",
	"confirm",
]

const COMBAT_TYPES := ["end_turn", "face", "move", "cast"]
const DEPLOY_TYPES := ["place", "reposition", "ready", "confirm"]
const FACE_DIRS := ["N", "E", "S", "W"]

## Host owns match seed and the d100. Client must not send a roll.
const HOST_OWNS_SEED := true
const HOST_OWNS_RNG := true
const CLIENT_MAY_SEND_ROLL := false
const CLIENT_PATH_AUTHORITATIVE := false


static func validate_intent(intent: Dictionary) -> Dictionary:
	if intent.is_empty():
		return _fail("missing_type")
	if _has_client_roll(intent):
		return _fail("client_must_not_roll")
	var kind := str(intent.get("type", "")).strip_edges().to_lower()
	if kind == "":
		return _fail("missing_type")
	if not INTENT_TYPES.has(kind):
		return _fail("unknown_intent")
	if intent.has("seat") and int(intent["seat"]) not in [0, 1]:
		return _fail("bad_seat")
	match kind:
		"face":
			var dir := str(intent.get("dir", "")).strip_edges().to_upper()
			if not FACE_DIRS.has(dir):
				return _fail("missing_dir")
		"move", "place", "reposition":
			if not intent.has("to"):
				return _fail("missing_destination")
		"cast":
			if str(intent.get("spell", "")).strip_edges() == "":
				return _fail("missing_spell")
			if not intent.has("to"):
				return _fail("missing_destination")
		"ready", "confirm":
			if not intent.has("seat"):
				return _fail("missing_seat")
	return _ok()


static func validate_match_config(config: Dictionary, fixture: bool = false) -> Dictionary:
	if _has_client_roll(config):
		return _fail("client_must_not_roll")
	# Scripted rolls are a CombatSim test/setup hook, not a live client channel.
	if config.has("rolls") and not fixture:
		return _fail("client_must_not_roll")
	return _ok()


static func _has_client_roll(payload: Dictionary) -> bool:
	for key in ["roll", "hit_roll", "rng", "rng_state", "client_roll"]:
		if payload.has(key):
			return true
	return false


static func _ok() -> Dictionary:
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
	}


static func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
	}
