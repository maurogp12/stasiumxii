class_name StillVault
extends RefCounted

## XII Stills on mobile (Mauro 29 Sep 2026, "How you get Still fragments" +
## the build plan doc). Stasis chests roll fragments (★1–2: 1, ★3–4: 2,
## ★5: 3, random of the 12), inside the same 5 loot clears a day. Fragments
## live in the account bank, any class, never expire. 12 of the SAME Still
## forge it into the one socket (socket must be empty). The socketed Still
## goes into the next Stasis or online Koliseo fight (never hot-seat) as
## Intact or Overwound and is destroyed by that fight.
## Stride (Locked, Mauro): Intact +1 AP +1 MP the whole fight (cap 8/5).
## Overwound +4 AP +2 MP for your first 2 turns over whatever you have (breaks
## the cap), then a crack debuff −1 AP −2 MP on your 3rd turn, then normal.
## Gear / level AP-MP bonuses are never touched.

const _TestLoadout := preload("res://backend/test_loadout.gd")
const IDS: Array[String] = [
	"opening", "stride", "cut", "mercy", "guard", "quiet",
	"root", "ember", "tide", "silence", "crown", "end",
]
const FORGE_COST := 12
const MODES: Array[String] = ["intact", "overwound"]
## Fragments per chest by Stasis star.
const CHEST_FRAGMENTS := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3}
## Vault of Aeons colours.
const COLORS := {
	"opening": Color(1.0, 0.72, 0.22), "stride": Color(0.78, 0.86, 1.0), "cut": Color(0.86, 0.16, 0.18),
	"mercy": Color(1.0, 0.52, 0.78), "guard": Color(0.28, 0.52, 1.0), "quiet": Color(0.62, 0.36, 0.95),
	"root": Color(0.36, 0.78, 0.30), "ember": Color(1.0, 0.56, 0.12), "tide": Color(0.16, 0.78, 0.74),
	"silence": Color(0.95, 0.96, 1.0), "crown": Color(1.0, 0.86, 0.40), "end": Color(0.30, 0.28, 0.34),
}
## Display text + whether the effect is built yet (others: next update).
const EFFECTS := {
	"opening": {"intact": "You act first, whatever the Init", "overwound": "Act first (+ extra turn after round 1: next update)", "built": true},
	"stride": {"intact": "+1 AP +1 MP all fight (cap 8/5)", "overwound": "+4 AP +2 MP turns 1–2 (over the cap), then −1 AP −2 MP on turn 3", "built": true},
	"cut": {"intact": "First HIT +4 Neutral", "overwound": "First HIT +10 Neutral", "built": true},
	"mercy": {"intact": "First heal +8", "overwound": "First heal +16 and Cleanse", "built": true},
	"guard": {"intact": "First HIT taken −25%", "overwound": "First HIT taken ignored", "built": true},
	"quiet": {"intact": "Untargetable until you spend AP", "overwound": "Invisible until AP or turn end", "built": false},
	"root": {"intact": "Adjacent walk enemy −1 MP next turn", "overwound": "That enemy cannot walk next turn", "built": false},
	"ember": {"intact": "First damaging spell +4", "overwound": "+4, and that target burns 4 on its next turn", "built": true},
	"tide": {"intact": "First push +1 tile", "overwound": "First push +2 tiles", "built": false},
	"silence": {"intact": "Enemy 4+ AP spell on you costs +1 AP", "overwound": "That spell fizzles, they keep AP", "built": false},
	"crown": {"intact": "Online Koliseo win: +1 extra trophy", "overwound": "+1 trophy and a gold crown glow", "built": true},
	"end": {"intact": "Once: a lethal hit leaves you at 1 HP", "overwound": "Same (+ attacker pushed 1: next update)", "built": true},
}

static var save_path: String = "user://stills.json"

var fragments: Dictionary = {}  # id → count
var socket: String = ""
var mode: String = "intact"
## TEMPORARY balance-test kit: fragments granted per id (backend/test_loadout.gd).
var test_grant: Dictionary = {}


static func display_name(id: String) -> String:
	return id.capitalize()


static func is_id(id: String) -> bool:
	return IDS.has(id)


static func load_saved() -> StillVault:
	var vault := StillVault.new()
	if not FileAccess.file_exists(save_path):
		return _with_test_loadout(vault)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return vault
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		vault.from_dict(parsed)
	return _with_test_loadout(vault)


static func _with_test_loadout(vault: StillVault) -> StillVault:
	if save_path == _TestLoadout.DEFAULT_STILL_PATH and _TestLoadout.sync_vault(vault):
		vault.save()
	return vault


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"fragments": fragments, "socket": socket, "mode": mode, "test_grant": test_grant}, "\t"))
	return true


func from_dict(data: Dictionary) -> void:
	fragments = {}
	var raw: Variant = data.get("fragments", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			if is_id(str(id)) and int(raw[id]) > 0:
				fragments[str(id)] = int(raw[id])
	socket = str(data.get("socket", ""))
	if not is_id(socket):
		socket = ""
	mode = str(data.get("mode", "intact"))
	if not MODES.has(mode):
		mode = "intact"
	test_grant = {}
	var raw_grant: Variant = data.get("test_grant", {})
	if typeof(raw_grant) == TYPE_DICTIONARY:
		for id in raw_grant:
			if is_id(str(id)):
				test_grant[str(id)] = int(raw_grant[id])


func count(id: String) -> int:
	return int(fragments.get(id, 0))


## A loot-paying Stasis clear. `pick` returns 0..1 (tests pass fixed values).
func roll_chest(star: int, pick: Callable = Callable()) -> Array:
	var out: Array = []
	var n := int(CHEST_FRAGMENTS.get(clampi(star, 1, 5), 1))
	for i in n:
		var r := float(pick.call()) if pick.is_valid() else randf()
		var id := IDS[mini(int(r * IDS.size()), IDS.size() - 1)]
		fragments[id] = count(id) + 1
		out.append(id)
	return out


func can_forge(id: String) -> Dictionary:
	if not is_id(id):
		return {"ok": false, "reason": "unknown_still"}
	if socket != "":
		return {"ok": false, "reason": "socket_full"}
	if count(id) < FORGE_COST:
		return {"ok": false, "reason": "needs_12"}
	return {"ok": true, "reason": ""}


func forge(id: String) -> Dictionary:
	var gate := can_forge(id)
	if not bool(gate["ok"]):
		return gate
	fragments[id] = count(id) - FORGE_COST
	if int(fragments[id]) <= 0:
		fragments.erase(id)
	socket = id
	mode = "intact"
	return {"ok": true, "reason": "", "still": id}


func set_mode(next: String) -> Dictionary:
	if not MODES.has(next):
		return {"ok": false, "reason": "unknown_mode"}
	if socket == "":
		return {"ok": false, "reason": "socket_empty"}
	mode = next
	return {"ok": true, "reason": ""}


## What a fight receives; empty when nothing is socketed.
func fight_still() -> Dictionary:
	if socket == "":
		return {}
	return {"id": socket, "mode": mode}


## The fight that carries the Still destroys it.
func consume() -> String:
	var used := socket
	socket = ""
	mode = "intact"
	return used


static func clean(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var id := str(raw.get("id", ""))
	var m := str(raw.get("mode", "intact"))
	if not is_id(id) or not MODES.has(m):
		return {}
	return {"id": id, "mode": m}
