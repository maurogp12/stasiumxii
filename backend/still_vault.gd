class_name StillVault
extends RefCounted

## XII Stills (Mauro 9 Oct 2026, locked list of 14). Stasis chests roll
## fragments (★1–2: 1, ★3–4: 2, ★5: 3, random of the 14), inside the same
## 5 loot clears a day. Fragments live in the account bank, any class, never
## expire. 12 of the SAME Still forge it into the one socket (socket must be
## empty). The socketed Still goes into the next Stasis or online Koliseo
## fight (never hot-seat) as Intact or Overwound and is destroyed by that fight.
## Overwound is the stronger form plus a drawback. Triggers are events, never
## a turn number. Gear / level AP-MP bonuses are never touched.

const _TestLoadout := preload("res://backend/test_loadout.gd")
const IDS: Array[String] = [
	"steadfast", "tide", "hourglass_fist", "hourglass_step", "rewind",
	"long_shadow", "withering_sand", "shatterglass", "tolling_bell",
	"bleeding_hour", "mirror_hour", "held_hour", "bound_hour", "gathered_sand",
]
## Tapped from the button beside Pass Turn. The other ten stay on the corner card.
const ACTIVATED: Array[String] = ["bleeding_hour", "mirror_hour", "bound_hour"]
const NAMES := {
	"steadfast": "Steadfast",
	"tide": "Tide",
	"hourglass_fist": "Hourglass Fist",
	"hourglass_step": "Hourglass Step",
	"rewind": "Rewind",
	"long_shadow": "Long Shadow",
	"withering_sand": "Withering Sand",
	"shatterglass": "Shatterglass",
	"tolling_bell": "Tolling Bell",
	"bleeding_hour": "Bleeding Hour",
	"mirror_hour": "Mirror Hour",
	"held_hour": "Held Hour",
	"bound_hour": "Bound Hour",
	"gathered_sand": "Gathered Sand",
}
const FORGE_COST := 12
const MODES: Array[String] = ["intact", "overwound"]
## Fragments per chest by Stasis star.
const CHEST_FRAGMENTS := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3}
## Vault of Aeons colours.
const COLORS := {
	"steadfast": Color(0.55, 0.62, 0.72),
	"tide": Color(0.20, 0.72, 0.78),
	"hourglass_fist": Color(0.86, 0.42, 0.18),
	"hourglass_step": Color(0.95, 0.78, 0.28),
	"rewind": Color(0.45, 0.78, 0.95),
	"long_shadow": Color(0.42, 0.28, 0.62),
	"withering_sand": Color(0.72, 0.55, 0.28),
	"shatterglass": Color(0.75, 0.88, 0.95),
	"tolling_bell": Color(0.85, 0.72, 0.28),
	"bleeding_hour": Color(0.72, 0.16, 0.22),
	"mirror_hour": Color(0.55, 0.78, 0.92),
	"held_hour": Color(0.62, 0.40, 0.78),
	"bound_hour": Color(0.35, 0.55, 0.42),
	"gathered_sand": Color(0.82, 0.68, 0.40),
}
## Short lines plus built (every locked Still is in the fight).
const EFFECTS := {
	"steadfast": {"intact": "First Stun becomes −3 AP, not a skipped turn", "overwound": "First Stun ignored; other debuffs last +1 turn", "built": true},
	"tide": {"intact": "First 2 debuffs are removed as they land", "overwound": "Next 3 turns start by clearing debuffs, then heals −25%", "built": true},
	"hourglass_fist": {"intact": "+2 AP, −1 MP all fight", "overwound": "+3 AP, −2 MP; AP may pass 8", "built": true},
	"hourglass_step": {"intact": "+2 MP, −1 AP all fight", "overwound": "+3 MP, −2 AP; MP may pass 5", "built": true},
	"rewind": {"intact": "First 30%+ loss in one enemy turn refunds half next turn", "overwound": "Refunds all of it; allies cannot heal you after that", "built": true},
	"long_shadow": {"intact": "First hit from 4+ tiles: +2 MP next turn", "overwound": "First 3 such hits: +2 MP (past 5); adjacent foes +10% damage", "built": true},
	"withering_sand": {"intact": "First nearby enemy heal: next hit on them adds half (max 15)", "overwound": "Bonus equals the full heal (max 25); you gain no shields", "built": true},
	"shatterglass": {"intact": "First hit on a shield breaks the whole shield", "overwound": "Hits deal double to shields; you gain no shields", "built": true},
	"tolling_bell": {"intact": "First enemy to turn Invisible within 5 tiles is revealed", "overwound": "Every such enemy is revealed; your hits deal −10%", "built": true},
	"bleeding_hour": {"intact": "Once, on your turn: lose 20% max HP (stop at 1), gain +2 AP", "overwound": "Lose 30% max HP (stop at 1), gain +3 AP (past 8); no heals until next turn ends", "built": true},
	"mirror_hour": {"intact": "Once, 2 AP: swap with a visible fighter within 4 tiles", "overwound": "Free swap; an enemy faces away; you lose remaining MP", "built": true},
	"held_hour": {"intact": "First hit echoes half its damage on the target's next turn", "overwound": "First hit deals 0 now and double later, unless they hit you first", "built": true},
	"bound_hour": {"intact": "Once, 2 AP: take 50% of an ally's damage for 3 of their turns", "overwound": "All fight, you take 60%; break past 4 tiles costs you both 1 AP", "built": true},
	"gathered_sand": {"intact": "Store 15% of damage taken (max 15); your next hit releases it", "overwound": "Store 25% (max 25); no heals while any is stored", "built": true},
}

## One sentence per mode (Mauro: fewer words, useful info).
const PLAIN := {
	"steadfast": {"intact": "The first Stun on you each fight becomes −3 AP that turn instead of a skipped turn.", "overwound": "The first Stun on you is ignored, but every other debuff on you lasts one extra turn."},
	"tide": {"intact": "The first two debuffs on you each fight are removed the moment they land.", "overwound": "After your first debuff, your next three turns start by clearing every debuff on you, then heals on you are 25% weaker."},
	"hourglass_fist": {"intact": "You have +2 AP and −1 MP for the whole fight.", "overwound": "You have +3 AP and −2 MP for the whole fight, and AP can go past 8."},
	"hourglass_step": {"intact": "You have +2 MP and −1 AP for the whole fight.", "overwound": "You have +3 MP and −2 AP for the whole fight, and MP can go past 5."},
	"rewind": {"intact": "The first time you lose 30% or more HP in one enemy turn, you regain half of it at your next turn.", "overwound": "You regain all of that HP, but allies cannot heal you for the rest of the fight."},
	"long_shadow": {"intact": "The first hit an enemy lands on you from 4 or more tiles gives you +2 MP next turn.", "overwound": "The first three such hits each give +2 MP next turn, even past 5, but adjacent enemies deal 10% more damage to you."},
	"withering_sand": {"intact": "The first time an enemy within 4 tiles is healed, your next hit on that enemy deals bonus damage equal to half the heal (max 15).", "overwound": "That bonus equals the full heal (max 25), but you cannot gain shields this fight."},
	"shatterglass": {"intact": "Your first hit on a shielded enemy breaks the whole shield.", "overwound": "Every hit you land on a shield deals double damage to that shield, but you cannot gain shields this fight."},
	"tolling_bell": {"intact": "The first enemy that turns Invisible within 5 tiles of you is revealed immediately.", "overwound": "Every enemy that turns Invisible within 5 tiles is revealed immediately, but your hits deal 10% less damage."},
	"bleeding_hour": {"intact": "Once per fight, on your turn, lose 20% of your max HP, stopping at 1, and gain +2 AP.", "overwound": "Lose 30% of your max HP, stopping at 1, and gain +3 AP, even past 8, and you cannot be healed until your next turn ends."},
	"mirror_hour": {"intact": "Once per fight, on your turn, spend 2 AP to swap places with a visible fighter within 4 tiles.", "overwound": "The swap costs no AP, an enemy you swap ends facing away from you, and you lose your remaining MP."},
	"held_hour": {"intact": "Your first hit echoes: half its damage hits again at the start of the target's next turn.", "overwound": "Your first hit deals no damage now and double damage at the start of the target's next turn, but it is lost if they hit you first."},
	"bound_hour": {"intact": "Once per fight, on your turn, spend 2 AP to take half the damage an ally within 4 tiles takes, for 3 of their turns.", "overwound": "The bind lasts the whole fight and you take 60% of their damage, but if either of you ends a turn more than 4 tiles apart it breaks and you both lose 1 AP."},
	"gathered_sand": {"intact": "15% of the damage you take is stored, up to 15, and your next hit releases it all as bonus damage, once per fight.", "overwound": "You store 25%, up to 25, but you cannot be healed while any of it is stored."},
}
## How Stills work, in four steps (shown in the Inventory and the Vault).
const HOW_TO: Array[String] = [
	"1. Stasis chests drop Still fragments.",
	"2. 12 fragments of the same Still forge that Still into your Still socket.",
	"3. Choose Intact (the safe form) or Overwound (stronger, with a drawback).",
	"4. It powers your next Stasis or online Koliseo fight, then it breaks.",
]
const ICON_DIR := "res://art/ui/stills/"

static var save_path: String = "user://stills.json"

var fragments: Dictionary = {}  # id → count
var socket: String = ""
var mode: String = "intact"
## TEMPORARY balance-test kit: fragments granted per id (backend/test_loadout.gd).
var test_grant: Dictionary = {}


static func display_name(id: String) -> String:
	return str(NAMES.get(id, id.capitalize()))


## Plain sentence for a Still's mode, with the not-built note.
static func plain(id: String, mode: String) -> String:
	return str((PLAIN.get(id, {}) as Dictionary).get(mode, ""))


## Painted icon: the forged hourglass, or a fragment shard.
static func icon_path(id: String, fragment: bool = false) -> String:
	return "%sstill_%s%s.png" % [ICON_DIR, id, "_fragment" if fragment else ""]


static func icon(id: String, fragment: bool = false) -> Texture2D:
	var path := icon_path(id, fragment)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## How many Stills these fragments forge, and how many more the next one needs.
static func forge_summary(count: int) -> String:
	if count >= FORGE_COST:
		var n := count / FORGE_COST
		return "Ready to forge (enough fragments for %d)." % n
	return "%d more to forge one." % (FORGE_COST - count)


static func is_id(id: String) -> bool:
	return IDS.has(id)


static func is_activated(id: String) -> bool:
	return ACTIVATED.has(id)


static func load_saved() -> StillVault:
	ProgressEpoch.ensure()
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
