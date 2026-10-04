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

## Default star. The player picks ★1–★5 per run (Mauro 29 Sep 2026: "every
## star should be a lvl of difficult"); loot, XP and Still fragments use the
## picked `star`.
const STAR := 1
const MAX_STAR := 5
## Foe toughness per star: [HP multiplier, damage multiplier].
## PROVISIONAL — the Blueprint leaves Stasis HP / dmg Open; these are Claude's
## proposal that Mauro green-lit by asking for star difficulty. Tune freely.
## ★3–★5 retuned 4 Oct 2026 for the role AI (Mauro: "make them stronger to hit
## 80 65 50"): dungeon sim, party of 4 AI heroes, 40 runs: 83% / 68% / 48%.
## ★5 lowered the same day (Mauro: "5 stars dungeon are way too powerful, can we
## lower them a little bit"): [8.9, 5.05] → [8.0, 4.75], party of 4: 67% (30
## runs). Same base as ★4; the ★5 boss specials still make it harder.
const STAR_SCALE := {1: [1.0, 1.0], 2: [1.4, 1.2], 3: [6.9, 4.75], 4: [7.95, 4.75], 5: [8.0, 4.75]}
## Dungeon party (Mauro 1 Oct 2026): ★1 is for 1 player, ★2 for 2, ★3–★5
## for a full party of 4. Monsters are tuned for that party whoever enters
## ("allowed but brutal"). PARTY_SCALE = [hp, damage] on top of STAR_SCALE.
## PROVISIONAL — tuned with tests/sim_dungeons.gd.
const PARTY_FOR_STAR := {1: 1, 2: 2, 3: 4, 4: 4, 5: 4}
const PARTY_SCALE := {1: [1.0, 1.0], 2: [4.0, 2.8], 4: [3.2, 1.6]}
const MAX_PARTY := 4
## Dev balance tool only (tests/sim_dungeons.gd): star → [hp, damage] used
## instead of STAR_SCALE. Empty in the game.
static var star_scale_override: Dictionary = {}
const PLAYER_SEAT := 0
const ENEMY_SEAT := 1
## Strike card owner. Not the portrait. See the note above.
const STRIKE_CARD_CLASS := "ironjaw"
const STRIKE_CARD := "strike"
const TRASH_COUNT := 3
## Room 1 pack sizes (Mauro's answers, 29 Sep 2026).
const PACK_SMALL := 4
const PACK_BIG := 5
const FoeKits := preload("res://backend/foe_kits.gd")
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
## Door packages (Mauro's "Stasis bosses + room-1 packs" sheet + answers,
## 29 Sep 2026). Names are the sheet's. `trash` is always 2 brutes, 1
## skirmisher, then 2 casters; Room 1 fields 2 brute + 1 skirmish + 1 caster at
## Stasis 1–2 and all 5 from Stasis 3. `art` is the stand-in painting (the
## nearest body); casters use a recoloured copy (art/stasis/foes/caster_*.png)
## until real caster art exists (Open).
const DOORS := {
	"crosshaven": {
		"door": "Threshgate",
		"boss": "Sheaf Sovereign",
		"boss_art": "warden_of_the_sheaves",
		# Mauro 2 Oct 2026: same boss and door; at 5 stars he takes his 5-star form.
		"boss_art_5": "sheaf_sovereign",
		"boss_attack": "Thresh",
		"trash": [
			{"name": "Plaza Guard", "role": "brute", "attack": "Hit", "art": "scarecrow_drudge"},
			{"name": "Riot Club", "role": "brute", "attack": "Hit", "art": "threshling"},
			{"name": "Watch Mastiff", "role": "skirmish", "attack": "Poke", "art": "grain_hound"},
			{"name": "Scribe Bolt", "role": "caster", "attack": "Bolt", "art": "caster_scribe_bolt"},
			{"name": "Bell Chanter", "role": "caster", "attack": "Bolt", "art": "caster_bell_chanter"},
		],
	},
	"brinewake": {
		"door": "Tidehold",
		"boss": "Tide-Lord Brineclaw",
		"boss_art": "captain_brineclaw",
		"boss_art_5": "brineclaw_sovereign",
		"boss_attack": "Claw",
		"trash": [
			{"name": "Silt Raider", "role": "brute", "attack": "Hit", "art": "silt_raider"},
			{"name": "Hawser Thug", "role": "brute", "attack": "Hit", "art": "brine_gullkin"},
			{"name": "Dock Crab", "role": "skirmish", "attack": "Poke", "art": "tide_skitter"},
			{"name": "Gullkin Hex", "role": "caster", "attack": "Bolt", "art": "caster_gullkin_hex"},
			{"name": "Tide Adept", "role": "caster", "attack": "Bolt", "art": "caster_tide_adept"},
		],
	},
	"slagcrown": {
		"door": "Ashmarch",
		"boss": "Slagheart (Caldera Crown)",
		"boss_art": "slagheart_the_emberbrute",
		"boss_art_5": "slagheart_caldera_crown",
		"boss_attack": "Slam",
		"trash": [
			{"name": "Cinder Imp", "role": "brute", "attack": "Hit", "art": "cinder_imp"},
			{"name": "Slag Mite", "role": "brute", "attack": "Hit", "art": "slag_mite"},
			{"name": "Ash Stalker", "role": "skirmish", "attack": "Poke", "art": "ash_stalker"},
			{"name": "Ember Cantor", "role": "caster", "attack": "Bolt", "art": "caster_ember_cantor"},
			{"name": "Kiln Voice", "role": "caster", "attack": "Bolt", "art": "caster_kiln_voice"},
		],
	},
	"windmere": {
		"door": "Galevault",
		"boss": "Serra White-Spire Regent",
		"boss_art": "serra_the_gale_sentinel",
		"boss_attack": "Shard",
		"trash": [
			{"name": "Ice Warden", "role": "brute", "attack": "Hit", "art": "frost_wisp"},
			{"name": "Spire Foot", "role": "brute", "attack": "Hit", "art": "gustling"},
			{"name": "Pack Wolf", "role": "skirmish", "attack": "Poke", "art": "gale_skitter"},
			{"name": "White Adept", "role": "caster", "attack": "Bolt", "art": "caster_white_adept"},
			{"name": "Gale Chanter", "role": "caster", "attack": "Bolt", "art": "caster_gale_chanter"},
		],
	},
	"stormspire": {
		"door": "Coilgate",
		"boss": "High Coilspire",
		"boss_art": "tyrant_coilspire",
		"boss_attack": "Arc",
		"trash": [
			{"name": "Coil Brute", "role": "brute", "attack": "Hit", "art": "sparkin"},
			{"name": "Grid Warden", "role": "brute", "attack": "Hit", "art": "coil_tick"},
			{"name": "Spark Hound", "role": "skirmish", "attack": "Poke", "art": "volt_mote"},
			{"name": "Arc Adept", "role": "caster", "attack": "Bolt", "art": "caster_arc_adept"},
			{"name": "High Cantor", "role": "caster", "attack": "Bolt", "art": "caster_high_cantor"},
		],
	},
}

const RUN_SCENE := "res://scenes/stasis_run.tscn"
const FIGHT_SCENE := "res://scenes/stasis_fight.tscn"

static var biome_id: String = ""
static var class_id: String = ""
static var room: String = "a"
static var foe_index: int = 0
## Difficulty picked for this run (1–5).
static var star: int = STAR
## Party heroes in seat order; index 0 is the player (class_id). Empty = solo.
## ai_seats: seats an AI companion plays ("Fill with AI").
static var party_classes: Array[String] = []
static var ai_seats: Array[int] = []
## -1 keeps the class base HP (Mauro 30 Sep 2026: class base HP). Room B carries whatever Room A left.
static var player_hp: int = -1
## End-of-run window (ui/combat_result.gd): clock, turns and beaten foes
## across both rooms.
static var run_started_msec: int = 0
static var run_turns: int = 0
static var run_foes: Array = []


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
	star = STAR
	player_hp = -1
	run_started_msec = Time.get_ticks_msec()
	run_turns = 0
	run_foes = []
	return true


static func clear_run_party() -> void:
	party_classes.clear()
	ai_seats.clear()


static func clear_run() -> void:
	star = STAR
	biome_id = ""
	class_id = ""
	room = "a"
	foe_index = 0
	player_hp = -1
	MobileHub.pending_biome_id = ""


static func set_star(value: int) -> void:
	star = clampi(value, 1, MAX_STAR)


static func hp_mult(for_star: int = -1) -> float:
	var s := clampi(star if for_star < 1 else for_star, 1, MAX_STAR)
	return float(_star_scale(s)[0]) * float(PARTY_SCALE[party_for_star(s)][0])


static func dmg_mult(for_star: int = -1) -> float:
	var s := clampi(star if for_star < 1 else for_star, 1, MAX_STAR)
	return float(_star_scale(s)[1]) * float(PARTY_SCALE[party_for_star(s)][1])


static func _star_scale(s: int) -> Array:
	return star_scale_override.get(s, STAR_SCALE[s])


## Heroes a star is tuned for (1, 2 or 4).
static func party_for_star(for_star: int = -1) -> int:
	return int(PARTY_FOR_STAR[clampi(star if for_star < 1 else for_star, 1, MAX_STAR)])


## Heroes actually entering: the picked party, else the solo player.
static func party_size() -> int:
	return clampi(maxi(party_classes.size(), 1), 1, MAX_PARTY)


static func set_party(classes: Array, ai: Array = []) -> void:
	party_classes.clear()
	for id in classes:
		var c := SpellKits.normalize_class_id(str(id))
		if SpellKits.is_roster_class(c) and party_classes.size() < MAX_PARTY:
			party_classes.append(c)
	ai_seats.clear()
	for seat in ai:
		if int(seat) > 0 and int(seat) < party_classes.size():
			ai_seats.append(int(seat))
	if not party_classes.is_empty():
		class_id = party_classes[0]


static func scaled_hp(base: int, for_star: int = -1) -> int:
	return maxi(roundi(float(base) * hp_mult(for_star)), 1)


static func scaled_attack(base: int, for_star: int = -1) -> int:
	return maxi(roundi(float(base) * dmg_mult(for_star)), 0)


## "★3" plus the door name, for banners and the result window.
static func star_label(for_star: int = -1) -> String:
	return "★%d" % clampi(star if for_star < 1 else for_star, 1, MAX_STAR)


static func ready_to_fight() -> bool:
	return MobileHub.is_biome_id(biome_id) and SpellKits.is_roster_class(class_id) and DOORS.has(biome_id)


static func door_name(map_id: String = "") -> String:
	return str(_door(map_id).get("door", ""))


static func boss_name(map_id: String = "") -> String:
	return str(_door(map_id).get("boss", ""))


static func trash_names(map_id: String = "", for_star: int = -1) -> Array[String]:
	var names: Array[String] = []
	for entry in pack(map_id, for_star):
		names.append(str(entry.get("name", "")))
	return names


## Room 1 pack for a star: Stasis 1–2 = 2 brutes + skirmisher + 1 caster,
## Stasis 3+ = 3 melee + 2 casters (Mauro's answers, 29 Sep 2026).
static func pack(map_id: String = "", for_star: int = -1) -> Array:
	var all: Array = _door(map_id).get("trash", [])
	var s := clampi(star if for_star < 1 else for_star, 1, MAX_STAR)
	var count := PACK_BIG if s >= 3 else PACK_SMALL
	return all.slice(0, mini(count, all.size()))


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
		return "%s %s · Room B · %s" % [door, star_label(), boss_name()]
	return "%s %s · Room A · %s" % [door, star_label(), " · ".join(trash_names())]


## One-line ribbon for the fight screen: door, star, room and foe count.
static func room_ribbon() -> String:
	var door := door_name(biome_id)
	if room == "b":
		return "%s %s · Room B · %s" % [door, star_label(), boss_name()]
	return "%s %s · Room A · %d foes" % [door, star_label(), trash_names().size()]


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
		cells = cells + extra_spawns(biome_id, room, cells, foes.size() + 1 - cells.size())
	if cells.size() < foes.size() + 1:
		return {}
	var heroes := party_size()
	if heroes > 1:
		return _party_fight_config(cells, foes, heroes)
	var roster: Array = []
	var positions: Array = []
	var player := {"seat": PLAYER_SEAT, "facing": "N"}
	if player_hp >= 0:
		player["hp"] = player_hp
	# Worn gear counts in Stasis (Mauro 29 Sep 2026).
	# The socketed XII Still rides into this fight (consumed when it ends).
	var gear := GearBag.load_saved().fight_gear(true)
	if not (gear["worn"] as Array).is_empty() or not (gear["heroes"] as Dictionary).is_empty() or gear.has("still"):
		player["gear"] = gear
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
			"foe_kit": entry.get("foe_kit", []),
			"role": str(entry.get("role", "")),
			"door": biome_id,
			"dmg_mult": dmg_mult(),
			"max_ap": int(entry.get("max_ap", 6)),
			"max_mp": 3,
			"sprite": art_path(str(entry.get("art", ""))),
			# Room B's foe is the door boss: the board draws it bigger, with an aura.
			"boss": room == "b",
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
		# Higher Init acts first, tie = coin flip (Mauro 29 Sep 2026).
		"first_by_init": true,
	}


## Party run: heroes in seats 0..P-1 (team 0) around the player's spawn,
## monsters from seat P. Every hero wears the phone's loadout for now (one
## device); online parties will send each player's own gear.
static func _party_fight_config(cells: Array, foes: Array, heroes: int) -> Dictionary:
	var hero_cells := party_cells(biome_id, room, cells[0], heroes, cells.slice(1))
	if hero_cells.size() < heroes:
		return {}
	var gear := GearBag.load_saved().fight_gear(true)
	var roster: Array = []
	var positions: Array = []
	for seat in heroes:
		var rec := {"seat": seat, "facing": "N"}
		if seat == 0 and player_hp >= 0:
			rec["hp"] = player_hp
		if not (gear["worn"] as Array).is_empty() or not (gear["heroes"] as Dictionary).is_empty():
			var g: Dictionary = gear.duplicate(true)
			if seat > 0:
				g.erase("still")
			rec["gear"] = g
		roster.append(rec)
		positions.append(hero_cells[seat])
	for i in foes.size():
		var entry: Dictionary = foes[i]
		positions.append(cells[i + 1])
		roster.append({
			"seat": heroes + i,
			"name": str(entry.get("name", "")),
			"max_hp": int(entry.get("hp", 1)),
			"hp": int(entry.get("hp", 1)),
			"attack_base": int(entry.get("attack_base", 0)),
			"attack_name": str(entry.get("attack", "")),
			"facing": "S",
			"spells": [STRIKE_CARD],
			"foe_kit": entry.get("foe_kit", []),
			"role": str(entry.get("role", "")),
			"door": biome_id,
			"dmg_mult": dmg_mult(),
			"max_ap": int(entry.get("max_ap", 6)),
			"max_mp": 3,
			"sprite": art_path(str(entry.get("art", ""))),
			"boss": room == "b",
		})
	var classes: Array = party_classes.duplicate()
	classes.append(STRIKE_CARD_CLASS)
	var seed := _seed_for(biome_id, room, 0)
	return {
		"map_id": biome_id,
		"cell_tags": tags_path(biome_id, room),
		"classes": classes,
		"party_size": heroes,
		"skip_deploy": true,
		"positions": positions,
		"seed": seed,
		"elev_seed": seed,
		"stasis_roster": roster,
		"first_by_init": true,
	}


## Standable ground next to the player's spawn for the other heroes
## (nearest first, never on a foe spawn).
static func party_cells(map_id: String, room_id: String, start: Vector2i, count: int, avoid: Array) -> Array:
	var tags := CellTagMap.load_file(tags_path(map_id, room_id))
	var paint: Dictionary = tags.get("paint_only", {})
	var map := str(tags.get("map_id", map_id))
	var ok := {}
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		if str(rec.get("terrain", "")) != "ground" or CellTagMap.props_block_move(paint.get(pos, []), map, pos):
			continue
		ok[pos] = true
	var out: Array = [start]
	var ring: Array = ok.keys()
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _cheb(a, start)
		var db := _cheb(b, start)
		return da < db if da != db else (a.y * 100 + a.x) < (b.y * 100 + b.x))
	for pos in ring:
		if out.size() >= count:
			break
		if pos == start or avoid.has(pos):
			continue
		out.append(pos)
	return out


## Extra foe spawns when a room lists fewer than the pack: standable open
## ground near the listed foe spawns, at least 5 from the player's spawn and
## not touching another spawn. Deterministic (same room = same cells).
static func extra_spawns(map_id: String, room_id: String, taken: Array, count: int) -> Array:
	var tags := CellTagMap.load_file(tags_path(map_id, room_id))
	var paint: Dictionary = tags.get("paint_only", {})
	var map := str(tags.get("map_id", map_id))
	var foes: Array = taken.slice(1)
	var center := Vector2.ZERO
	for c in foes:
		center += Vector2(c)
	if not foes.is_empty():
		center /= float(foes.size())
	var candidates: Array = []
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		if str(rec.get("terrain", "")) != "ground":
			continue
		if CellTagMap.props_block_move(paint.get(pos, []), map, pos):
			continue
		if not taken.is_empty() and _cheb(pos, taken[0]) < 5:
			continue
		candidates.append(pos)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a).distance_squared_to(center)
		var db := Vector2(b).distance_squared_to(center)
		return da < db if da != db else (a.y * 100 + a.x) < (b.y * 100 + b.x))
	var out: Array = []
	var used: Array = taken.duplicate()
	for pos in candidates:
		if out.size() >= count:
			break
		var clear := true
		for other in used:
			if _cheb(pos, other) < 2:
				clear = false
				break
		if clear:
			out.append(pos)
			used.append(pos)
	return out


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


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
			"art": boss_art_for(door, star),
			"role": "boss",
			"foe_kit": FoeKits.boss_kit(biome_id, star),
			"max_ap": FoeKits.boss_ap(star),
			"hp": scaled_hp(PROVISIONAL_BOSS_HP),
			"attack_base": scaled_attack(PROVISIONAL_BOSS_ATTACK),
		}]
	var out: Array = []
	for entry in pack(biome_id):
		var rec: Dictionary = entry
		var role := str(rec.get("role", "brute"))
		var hp := scaled_hp(PROVISIONAL_TRASH_HP)
		if role == "caster":
			hp = maxi(roundi(float(hp) * float(FoeKits.CASTER_HP_PCT) / 100.0), 1)
		out.append({
			"name": str(rec.get("name", "Trash")),
			"attack": str(rec.get("attack", "Hit")),
			"art": str(rec.get("art", "")),
			"role": role,
			"foe_kit": FoeKits.ROLE_KITS.get(role, ["foe.brute_hit"]),
			"hp": hp,
			"attack_base": scaled_attack(PROVISIONAL_TRASH_ATTACK),
		})
	return out


## The door's boss painting; a 5-star run shows the 5-star form when the door has one.
static func boss_art_for(door: Dictionary, stars: int) -> String:
	if stars >= 5 and str(door.get("boss_art_5", "")) != "":
		return str(door.get("boss_art_5", ""))
	return str(door.get("boss_art", ""))


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
