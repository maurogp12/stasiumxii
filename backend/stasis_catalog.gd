extends RefCounted
class_name StasisCatalog

## Mobile-only Stasis content. Not for PC `main`.
## Luca Garza overnight 2026-09-25 unparked dungeon doors for the phone APK.
## Biome ids stay the Locked five. Door / boss / trash names are the Proposed
## package (Stasis-1 bosses & rooms, 2026-09-25). Boss 4H/5H art is out of scope.
##
## Grammar from that sheet is Locked structure: exactly 2 rooms
## (A trash pack → B boss). HP and attack_base below are provisional Open
## playtest numbers. They are not Locked, and they are not a Soft Lock stamp.
## Balance has not confirmed them. Player kits stay the Locked cards
## (80 HP, SpellKits damage). Do not copy these foe numbers into kits.gd.
##
## Strike is only on the Ironjaw kit, so a foe's class_id stays that card's
## owner. The portrait is the package crop under art/stasis/foes/. The pawn
## does not draw the Ironjaw sheet.

const PLAYER_SEAT := 0
const ENEMY_SEAT := 1
## Strike card owner. Not the portrait. See the note above.
const STRIKE_CARD_CLASS := "ironjaw"
const STRIKE_CARD := "strike"
const TRASH_COUNT := 3
const ART_ROOT := "res://art/stasis/foes/"
const MAP_ROOT := "res://art/maps/stasis_v1/"

# Provisional Open (playtest). Not Locked kit law.
# Attack base is before the Locked facing multiplier (front/side ×1.00, back ×1.20).
const PROVISIONAL_TRASH_HP := 22
const PROVISIONAL_TRASH_ATTACK := 6
const PROVISIONAL_BOSS_HP := 56
const PROVISIONAL_BOSS_ATTACK := 10

## Proposed door package. `attack` is a coach label for the Strike card,
## not a new spell id. `art` is the package-sheet crop, not an Open kit.
const DOORS := {
	"crosshaven": {
		"door": "Threshgate",
		"boss": "Warden of the Sheaves",
		"boss_art": "warden_of_the_sheaves",
		"boss_attack": "Sheaf Cleave",
		"trash": [
			{"name": "Scarecrow Drudge", "attack": "Straw Swipe", "art": "scarecrow_drudge"},
			{"name": "Grain Hound", "attack": "Grain Bite", "art": "grain_hound"},
			{"name": "Threshling", "attack": "Flail", "art": "threshling"},
		],
	},
	"brinewake": {
		"door": "Tidehold",
		"boss": "Captain Brineclaw",
		"boss_art": "captain_brineclaw",
		"boss_attack": "Claw Rake",
		"trash": [
			{"name": "Tide Skitter", "attack": "Tide Nip", "art": "tide_skitter"},
			{"name": "Silt Raider", "attack": "Silt Jab", "art": "silt_raider"},
			{"name": "Brine Gullkin", "attack": "Gull Peck", "art": "brine_gullkin"},
		],
	},
	"slagcrown": {
		"door": "Ashmarch",
		"boss": "Slagheart the Emberbrute",
		"boss_art": "slagheart_the_emberbrute",
		"boss_attack": "Ember Slam",
		"trash": [
			{"name": "Cinder Imp", "attack": "Cinder Jab", "art": "cinder_imp"},
			{"name": "Ash Stalker", "attack": "Ash Rake", "art": "ash_stalker"},
			{"name": "Slag Mite", "attack": "Mite Bite", "art": "slag_mite"},
		],
	},
	"windmere": {
		"door": "Galevault",
		"boss": "Serra the Gale Sentinel",
		"boss_art": "serra_the_gale_sentinel",
		"boss_attack": "Gale Cut",
		"trash": [
			{"name": "Gale Skitter", "attack": "Skitter Dash", "art": "gale_skitter"},
			{"name": "Gustling", "attack": "Gust Slap", "art": "gustling"},
			{"name": "Frost Wisp", "attack": "Frost Nip", "art": "frost_wisp"},
		],
	},
	"stormspire": {
		"door": "Coilgate",
		"boss": "Tyrant Coilspire",
		"boss_art": "tyrant_coilspire",
		"boss_attack": "Coil Lash",
		"trash": [
			{"name": "Sparkin", "attack": "Spark Jab", "art": "sparkin"},
			{"name": "Volt Mote", "attack": "Volt Nip", "art": "volt_mote"},
			{"name": "Coil Tick", "attack": "Tick Bite", "art": "coil_tick"},
		],
	},
}

const RUN_SCENE := "res://scenes/stasis_run.tscn"
const FIGHT_SCENE := "res://scenes/stasis_fight.tscn"

static var biome_id: String = ""
static var class_id: String = ""
static var room: String = "a"
static var foe_index: int = 0
## -1 keeps the Locked 80. Room B carries whatever Room A left.
static var player_hp: int = -1


static func begin(map_id: String) -> bool:
	var id := map_id.strip_edges().to_lower()
	if not MobileHub.is_biome_id(id):
		biome_id = ""
		class_id = ""
		room = "a"
		foe_index = 0
		player_hp = -1
		return false
	biome_id = id
	class_id = ""
	room = "a"
	foe_index = 0
	player_hp = -1
	return true


static func clear_run() -> void:
	biome_id = ""
	class_id = ""
	room = "a"
	foe_index = 0
	player_hp = -1
	MobileHub.pending_biome_id = ""


static func ready_to_fight() -> bool:
	return MobileHub.is_biome_id(biome_id) and SpellKits.is_roster_class(class_id) and DOORS.has(biome_id)


static func door_name(map_id: String = "") -> String:
	return str(_door(map_id).get("door", ""))


static func boss_name(map_id: String = "") -> String:
	return str(_door(map_id).get("boss", ""))


static func trash_names(map_id: String = "") -> Array[String]:
	var names: Array[String] = []
	for entry in _door(map_id).get("trash", []):
		if typeof(entry) == TYPE_DICTIONARY:
			names.append(str(entry.get("name", "")))
	return names


static func art_path(art_id: String) -> String:
	return ART_ROOT + "%s.png" % art_id.strip_edges()


static func tags_path(map_id: String = "", room_id: String = "") -> String:
	var id := biome_id if map_id == "" else map_id.strip_edges().to_lower()
	var which := room_id
	if which == "":
		which = room if id == biome_id else "a"
	if which != "b":
		which = "a"
	return MAP_ROOT + "%s_room_%s_15x15_tags.json" % [id, which]


static func current_foe() -> Dictionary:
	var entries := _room_entries()
	if entries.is_empty():
		return {"name": "", "attack": "", "hp": 1, "attack_base": 0, "boss": room == "b", "art": ""}
	var entry: Dictionary = entries[0]
	entry["boss"] = room == "b"
	return entry


static func room_banner() -> String:
	var door := door_name(biome_id)
	if room == "b":
		return "%s · Room B · %s" % [door, boss_name()]
	return "%s · Room A · %s" % [door, " · ".join(trash_names())]


static func provisional_line() -> String:
	if room == "b":
		return "Provisional Open playtest — %d HP, attack base %d before facing. Not Locked." % [PROVISIONAL_BOSS_HP, PROVISIONAL_BOSS_ATTACK]
	return "Provisional Open playtest — each trash %d HP, attack base %d before facing. Not Locked." % [PROVISIONAL_TRASH_HP, PROVISIONAL_TRASH_ATTACK]


static func continue_caption() -> String:
	if room == "b":
		return "Finish"
	return "Enter Room B"


## After a player win. Room A is one combat, so the next step is Room B.
## "cleared" ends the gate. There is no trash 1/3 → 2/3 → 3/3 chain.
static func advance_after_win() -> String:
	if room == "b":
		return "cleared"
	room = "b"
	foe_index = 0
	return "next"


static func carry_player_hp(hp: int) -> void:
	player_hp = maxi(hp, 0)


static func fight_config(positions_override: Array = []) -> Dictionary:
	if not ready_to_fight():
		return {}
	var cells := spawn_cells(biome_id, room)
	if positions_override.size() >= 2 and cells.size() >= 2:
		cells[0] = positions_override[0]
		cells[1] = positions_override[1]
	elif positions_override.size() >= 2:
		cells = positions_override.duplicate()
	var foes := _room_entries()
	if cells.size() < foes.size() + 1:
		return {}
	var roster: Array = []
	var positions: Array = []
	var player := {"seat": PLAYER_SEAT, "facing": "N"}
	if player_hp >= 0:
		player["hp"] = player_hp
	roster.append(player)
	positions.append(cells[0])
	for i in foes.size():
		var entry: Dictionary = foes[i]
		positions.append(cells[i + 1])
		roster.append({
			"seat": ENEMY_SEAT + i,
			"name": str(entry.get("name", "")),
			"max_hp": int(entry.get("hp", 1)),
			"hp": int(entry.get("hp", 1)),
			"attack_base": int(entry.get("attack_base", 0)),
			"attack_name": str(entry.get("attack", "")),
			"facing": "S",
			"spells": [STRIKE_CARD],
			"sprite": art_path(str(entry.get("art", ""))),
		})
	var seed := _seed_for(biome_id, room, 0)
	return {
		"map_id": biome_id,
		"cell_tags": tags_path(biome_id, room),
		"classes": [class_id, STRIKE_CARD_CLASS],
		"skip_deploy": true,
		"positions": positions,
		"seed": seed,
		"elev_seed": seed,
		# Provisional foe numbers live only in this payload.
		"stasis_roster": roster,
	}


static func spawn_cells(map_id: String, room_id: String = "") -> Array:
	var path := tags_path(map_id, room_id)
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for item in (parsed as Dictionary).get("spawns", []):
		if item is Array and (item as Array).size() >= 2:
			var pair: Array = item
			out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out


## South cell then north cell, same column, both ground. For a melee smoke test.
static func melee_pair(map_id: String) -> Array:
	var lookup := {}
	for cell in _preferred_cells(map_id):
		lookup[cell] = true
	for cell in lookup.keys():
		var south: Vector2i = cell + Vector2i(0, 1)
		if lookup.has(south):
			return [south, cell]
	return []


static func _room_entries() -> Array:
	var door := _door(biome_id)
	if room == "b":
		return [{
			"name": str(door.get("boss", "")),
			"attack": str(door.get("boss_attack", "Heavy Blow")),
			"art": str(door.get("boss_art", "")),
			"hp": PROVISIONAL_BOSS_HP,
			"attack_base": PROVISIONAL_BOSS_ATTACK,
		}]
	var out: Array = []
	for entry in door.get("trash", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = entry
		out.append({
			"name": str(rec.get("name", "Trash")),
			"attack": str(rec.get("attack", "Swipe")),
			"art": str(rec.get("art", "")),
			"hp": PROVISIONAL_TRASH_HP,
			"attack_base": PROVISIONAL_TRASH_ATTACK,
		})
	return out


static func _door(map_id: String) -> Dictionary:
	var id := biome_id if map_id == "" else map_id.strip_edges().to_lower()
	var raw: Variant = DOORS.get(id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func _preferred_cells(map_id: String) -> Array:
	var tags := CellTagMap.load_file(tags_path(map_id))
	var ground: Array[Vector2i] = []
	var walkable: Array[Vector2i] = []
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		if pos.x < 0 or pos.y < 0:
			continue
		var terrain := str(rec.get("terrain", "ground"))
		if terrain == "lava":
			continue
		walkable.append(pos)
		if terrain == "ground" and int(rec.get("elevation", 0)) == 0:
			ground.append(pos)
	if ground.size() >= 2:
		return ground
	return walkable


static func _seed_for(map_id: String, room_id: String, index: int) -> int:
	var n := 17011
	var text := "%s:%s:%d" % [map_id, room_id, index]
	for i in text.length():
		n = int((n * 33 + text.unicode_at(i)) % 1000003)
	return n + 1
