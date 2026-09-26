extends RefCounted
class_name StasisCatalog

## Mobile-only Stasis content. Not for PC `main`.
## Luca Garza overnight 2026-09-25 unparked dungeon doors for the phone APK.
## Biome ids stay the Locked five. Door / boss / trash names are the Proposed
## package (user table 2026-09-26). Boss 4H/5H art is out of scope.
##
## HP and attack_base below are provisional Open playtest numbers.
## They are not Locked, and they are not a Soft Lock stamp.
## Balance has not confirmed them. Player kits stay the Locked cards
## (80 HP, SpellKits damage). Do not copy these foe numbers into kits.gd.

const PLAYER_SEAT := 0
const ENEMY_SEAT := 1
## Ironjaw body so CombatSim can resolve a range-1 Strike. The AI offers only
## that card. Advance / Shoulder / Crush are not part of the dungeon kit.
const STAND_IN_CLASS := "ironjaw"
const STAND_IN_SPELL := "strike"
const TRASH_COUNT := 3

# Provisional Open (playtest). Not Locked kit law.
# Attack base is before the Locked facing multiplier (front/side ×1.00, back ×1.20).
const PROVISIONAL_TRASH_HP := 22
const PROVISIONAL_TRASH_ATTACK := 6
const PROVISIONAL_BOSS_HP := 56
const PROVISIONAL_BOSS_ATTACK := 10

## Proposed door package. `attack` is a coach label for the stand-in Strike,
## not a new spell id.
const DOORS := {
	"crosshaven": {
		"door": "Threshgate",
		"boss": "Warden of the Sheaves",
		"boss_attack": "Sheaf Cleave",
		"trash": [
			{"name": "Scarecrow Drudge", "attack": "Straw Swipe"},
			{"name": "Grain Hound", "attack": "Grain Bite"},
			{"name": "Threshling", "attack": "Flail"},
		],
	},
	"brinewake": {
		"door": "Tidehold",
		"boss": "Captain Brineclaw",
		"boss_attack": "Claw Rake",
		"trash": [
			{"name": "Tide Skitter", "attack": "Tide Nip"},
			{"name": "Silt Raider", "attack": "Silt Jab"},
			{"name": "Brine Gullkin", "attack": "Gull Peck"},
		],
	},
	"slagcrown": {
		"door": "Ashmarch",
		"boss": "Slagheart the Emberbrute",
		"boss_attack": "Ember Slam",
		"trash": [
			{"name": "Cinder Imp", "attack": "Cinder Jab"},
			{"name": "Ash Stalker", "attack": "Ash Rake"},
			{"name": "Slag Mite", "attack": "Mite Bite"},
		],
	},
	"windmere": {
		"door": "Galevault",
		"boss": "Serra the Gale Sentinel",
		"boss_attack": "Gale Cut",
		"trash": [
			{"name": "Gale Skitter", "attack": "Skitter Dash"},
			{"name": "Gustling", "attack": "Gust Slap"},
			{"name": "Frost Wisp", "attack": "Frost Nip"},
		],
	},
	"stormspire": {
		"door": "Coilgate",
		"boss": "Tyrant Coilspire",
		"boss_attack": "Coil Lash",
		"trash": [
			{"name": "Sparkin", "attack": "Spark Jab"},
			{"name": "Volt Mote", "attack": "Volt Nip"},
			{"name": "Coil Tick", "attack": "Tick Bite"},
		],
	},
}

const RUN_SCENE := "res://scenes/stasis_run.tscn"
const FIGHT_SCENE := "res://scenes/stasis_fight.tscn"

static var biome_id: String = ""
static var class_id: String = ""
static var room: String = "a"
static var foe_index: int = 0
## -1 keeps the Locked 80. A later foe in the same run carries the remainder.
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


static func current_foe() -> Dictionary:
	var door := _door(biome_id)
	if room == "b":
		return {
			"name": str(door.get("boss", "")),
			"attack": str(door.get("boss_attack", "Heavy Blow")),
			"hp": PROVISIONAL_BOSS_HP,
			"attack_base": PROVISIONAL_BOSS_ATTACK,
			"boss": true,
		}
	var trash: Array = door.get("trash", [])
	var entry: Dictionary = {}
	if foe_index >= 0 and foe_index < trash.size() and typeof(trash[foe_index]) == TYPE_DICTIONARY:
		entry = trash[foe_index]
	return {
		"name": str(entry.get("name", "Trash")),
		"attack": str(entry.get("attack", "Swipe")),
		"hp": PROVISIONAL_TRASH_HP,
		"attack_base": PROVISIONAL_TRASH_ATTACK,
		"boss": false,
	}


static func room_banner() -> String:
	var foe := current_foe()
	var door := door_name(biome_id)
	if room == "b":
		return "%s · Room B · %s" % [door, foe["name"]]
	return "%s · Room A · %s (%d/%d)" % [door, foe["name"], foe_index + 1, TRASH_COUNT]


static func provisional_line() -> String:
	var foe := current_foe()
	return "Provisional Open playtest — %d HP, attack base %d before facing. Not Locked." % [int(foe["hp"]), int(foe["attack_base"])]


static func continue_caption() -> String:
	if room == "b":
		return "Finish"
	if foe_index >= TRASH_COUNT - 1:
		return "Enter Room B"
	return "Next foe"


## After a player win. "next" starts another duel. "cleared" ends the gate.
static func advance_after_win() -> String:
	if room == "b":
		return "cleared"
	foe_index += 1
	if foe_index >= TRASH_COUNT:
		room = "b"
		foe_index = 0
	return "next"


static func carry_player_hp(hp: int) -> void:
	player_hp = maxi(hp, 0)


static func fight_config(positions_override: Array = []) -> Dictionary:
	if not ready_to_fight():
		return {}
	var cells := positions_override
	if cells.size() < 2:
		cells = spawn_cells(biome_id)
	if cells.size() < 2:
		return {}
	var foe := current_foe()
	var player := {"seat": PLAYER_SEAT, "facing": "N"}
	if player_hp >= 0:
		player["hp"] = player_hp
	var seed := _seed_for(biome_id, room, foe_index)
	return {
		"map_id": biome_id,
		"classes": [class_id, STAND_IN_CLASS],
		"skip_deploy": true,
		"positions": [cells[0], cells[1]],
		"seed": seed,
		"elev_seed": seed,
		# Provisional foe numbers live only in this payload.
		"stasis_roster": [
			player,
			{
				"seat": ENEMY_SEAT,
				"name": foe["name"],
				"max_hp": foe["hp"],
				"hp": foe["hp"],
				"attack_base": foe["attack_base"],
				"attack_name": foe["attack"],
				"facing": "S",
				"spells": [STAND_IN_SPELL],
			},
		],
	}


static func spawn_cells(map_id: String) -> Array:
	var cells := _preferred_cells(map_id)
	if cells.is_empty():
		return []
	var player: Vector2i = _nearest(cells, Vector2i(7, 12))
	var enemy: Vector2i = _nearest_except(cells, Vector2i(7, 2), player)
	if player == enemy:
		return []
	return [player, enemy]


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


static func _door(map_id: String) -> Dictionary:
	var id := biome_id if map_id == "" else map_id.strip_edges().to_lower()
	var raw: Variant = DOORS.get(id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func _preferred_cells(map_id: String) -> Array:
	var tags := CellTagMap.load_file(CellTagMap.tags_path_for(map_id))
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


static func _nearest(cells: Array, goal: Vector2i) -> Vector2i:
	var best: Vector2i = cells[0]
	var best_score := 1 << 30
	for cell in cells:
		var pos: Vector2i = cell
		var score := absi(pos.x - goal.x) + absi(pos.y - goal.y)
		if score < best_score or (score == best_score and (pos.y < best.y or (pos.y == best.y and pos.x < best.x))):
			best = pos
			best_score = score
	return best


static func _nearest_except(cells: Array, goal: Vector2i, blocked: Vector2i) -> Vector2i:
	var pool: Array[Vector2i] = []
	for cell in cells:
		var pos: Vector2i = cell
		if pos != blocked:
			pool.append(pos)
	if pool.is_empty():
		return blocked
	return _nearest(pool, goal)


static func _seed_for(map_id: String, room_id: String, index: int) -> int:
	var n := 17011
	var text := "%s:%s:%d" % [map_id, room_id, index]
	for i in text.length():
		n = int((n * 33 + text.unicode_at(i)) % 1000003)
	return n + 1
