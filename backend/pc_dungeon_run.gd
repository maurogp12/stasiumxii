extends RefCounted

## One PC dungeon run: room A (pack) then room B (boss), solo for now.
## Preload. No global class. Builds the CombatSim room configs, carries the
## run state between rooms and pays out a win through pc_rewards, pc_progress
## XP and pc_missions (clear_dungeon). A loss pays nothing.
##
## XP (spec 4.8, Proposed): dungeon_win share (balance_inputs, 27%) of
## xp_to_next(L) x star x pace(player level). L is the run level: the hero's
## level clamped into the dungeon's band. Star is 1 (stars are not built).
## Coins and items: pc_rewards.roll("dungeon", ...), the dungeon's own table.

const Dungeons = preload("res://backend/world_dungeons.gd")
const Monsters = preload("res://backend/pc_monsters.gd")
const Rewards = preload("res://backend/pc_rewards.gd")
const BALANCE_PATH := "res://data/world/balance_inputs.json"
const CURVE_PATH := "res://data/world/level_curve.json"
const RUN_FORMAT := "stasium.dungeon_run"
const MAX_STAR := 5
## Mobile: Stasis clear XP is 60 x star (hero_progress.gd). PC keeps its
## level-curve base XP (4.8) and multiplies it by the star the same way.
const XP_STAR_LINEAR := true
## Loot gates by star, as mobile's gear sources (gear_bag.gd FAMILIES):
## Normal from ★1, Rare from ★3, Legendary from ★5 or the boss. PC set parts
## are regular / rare; PC has no Legendary tier for a level 1-10 band (epics
## and relics start at level 40), so the ★5 Legendary slot is a Mystery Box.
const RARE_FROM_STAR := 3
const LEGENDARY_FROM_STAR := 5

var dungeon: Dictionary = {}
var run_doc: Dictionary = {}
var monsters = null
var level := 1
var hero_class := "kestrel"
var hero_name := ""
var room_index := 0
var result := ""
var star := 1
## Tests only: start each room with this HP (-1 keeps the full 80).
var hero_hp := -1
var errors: Array = []
var _rooms: Array = []


## Builds a run for a built dungeon, or {ok: false, errors}.
static func create(dungeon_id: String, hero_level: int, class_id: String, display_name: String = "", star_pick: int = 1) -> Dictionary:
	var run = new()
	var loaded: Dictionary = Dungeons.load_default()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "errors": loaded.get("errors", ["dungeons"])}
	run.dungeon = loaded["dungeons"].by_id(dungeon_id)
	if run.dungeon.is_empty():
		return {"ok": false, "errors": ["unknown dungeon %s" % dungeon_id]}
	if str(run.dungeon.get("status", "")) != "built":
		return {"ok": false, "errors": ["%s is not built yet" % dungeon_id]}
	var mon: Dictionary = Monsters.load_default()
	if not bool(mon.get("ok", false)):
		return {"ok": false, "errors": mon.get("errors", ["monsters"])}
	run.monsters = mon["monsters"]
	run.level = clampi(hero_level, int(run.dungeon["level_min"]), int(run.dungeon["level_max"]))
	run.hero_class = class_id if SpellKits.is_roster_class(class_id) else SpellKits.CLASS_KESTREL
	run.hero_name = display_name
	run.star = clampi(star_pick, 1, MAX_STAR)
	run._load_run_doc()
	if not run.errors.is_empty():
		return {"ok": false, "errors": run.errors}
	return {"ok": true, "errors": [], "run": run}


## Entry check shown on the door panel. Party is solo for now.
static func entry_check(row: Dictionary, hero_level: int, party_size: int = 1) -> Dictionary:
	var lo := int(row.get("level_min", 1))
	var hi := int(row.get("level_max", 1))
	if str(row.get("status", "")) != "built":
		return {"ok": false, "reason": "not_built", "text": "The way down is not open yet."}
	if party_size < int((row.get("party", {}) as Dictionary).get("min", 1)) or party_size > int((row.get("party", {}) as Dictionary).get("max", 4)):
		return {"ok": false, "reason": "party", "text": "Party must be 1 to 4."}
	if hero_level < lo:
		return {"ok": false, "reason": "too_low", "text": "Level %d needed. You are level %d." % [lo, hero_level]}
	if hero_level > hi:
		return {"ok": true, "reason": "above_band", "text": "You are above this band (levels %d-%d). Monsters stay at level %d." % [lo, hi, hi]}
	return {"ok": true, "reason": "", "text": "Level %d. You can enter." % hero_level}


func room_count() -> int:
	return _rooms.size()


func room(index: int) -> Dictionary:
	if index < 0 or index >= _rooms.size():
		return {}
	return (_rooms[index] as Dictionary).duplicate(true)


func current_room() -> Dictionary:
	return room(room_index)


func is_last_room() -> bool:
	return room_index >= _rooms.size() - 1


## CombatSim.reset_match config for a room. The hero starts each room at full HP.
func combat_config(index: int = -1, seed: int = -1) -> Dictionary:
	var at := room_index if index < 0 else index
	var spec := room(at)
	if spec.is_empty():
		return {}
	var tags := _read_tags(str(spec.get("tags", "")))
	var cells: Array = []
	for raw in tags.get("cells", []):
		var rec: Dictionary = raw
		cells.append({
			"pos": Vector2i(int(rec["x"]), int(rec["y"])),
			"terrain": str(rec.get("terrain", "ground")),
			"elevation": int(rec.get("elevation", 0)),
			"paint_only": (rec.get("paint_only", []) as Array).duplicate(),
			"blocks": bool(rec.get("blocks", false)),
			"special": str(rec.get("special", "")),
		})
	var hero_at: Dictionary = spec.get("hero", {})
	var pads: Dictionary = run_doc.get("pads", {})
	var mons: Array = []
	var summons := {}
	var pack: Array = pack_for(spec, star)
	for raw in pack:
		var m: Dictionary = raw
		var stats: Dictionary = monsters.stats_at(str(m["monster"]), level, star)
		stats["pos"] = Vector2i(int(m["x"]), int(m["y"]))
		stats["facing"] = str(m.get("facing", "S"))
		mons.append(stats)
		var sig: Dictionary = stats.get("signature", {})
		if not sig.is_empty():
			var summon_id := str(sig.get("summon", ""))
			if summon_id != "":
				summons[summon_id] = monsters.stats_at(summon_id, level, star)
	var size := tags.get("size", [12, 12]) as Array
	var config := {
		"board_size": int(size[0]) if size.size() > 0 else 12,
		"dungeon": {
			"dungeon_id": str(dungeon["id"]),
			"room_id": str(spec["id"]),
			"room_name": str(spec.get("name", "")),
			"star": star,
			"kind": str(spec.get("kind", "pack")),
			"cells": cells,
			"pad_heal": int(pads.get("amount", 0)) if str(pads.get("effect", "")) == "heal" else 0,
			"pad_thaw": bool(pads.get("thaw", false)),
			"pad_thaw_text": str(pads.get("thaw_text", "The rune pad thaws {name}: no MP lost.")),
			"view": (run_doc.get("view", {}) as Dictionary).duplicate(true) if typeof(run_doc.get("view", {})) == TYPE_DICTIONARY else {},
			"hero": {
				"class_id": hero_class,
				"name": hero_name,
				"pos": Vector2i(int(hero_at.get("x", 0)), int(hero_at.get("y", 0))),
				"facing": str(hero_at.get("facing", "N")),
			},
			"monsters": mons,
			"summons": summons,
		},
	}
	if hero_hp > 0:
		(config["dungeon"]["hero"] as Dictionary)["hp"] = hero_hp
	if seed >= 0:
		config["seed"] = seed
	return config


## The room's pack for a star: the packs entry with the highest key at or
## below the star; `monsters` when the room has no packs.
static func pack_for(spec: Dictionary, for_star: int) -> Array:
	var packs: Variant = spec.get("packs", {})
	var best := 0
	var out: Array = spec.get("monsters", [])
	if typeof(packs) == TYPE_DICTIONARY:
		for key in (packs as Dictionary).keys():
			var k := int(key)
			if k <= for_star and k > best:
				best = k
				out = packs[key]
	return out


## A line of the run file's `text` block (stairs, victory, return, ...),
## with {dungeon}, {boss} (text.boss_star5 at ★5), {town} and {star} filled in. `fallback` when absent.
func text(key: String, fallback: String = "") -> String:
	var block: Dictionary = run_doc.get("text", {}) if typeof(run_doc.get("text", {})) == TYPE_DICTIONARY else {}
	var line := str(block.get(key, fallback))
	var boss := str(dungeon.get("boss", ""))
	if star >= MAX_STAR and str(block.get("boss_star5", "")) != "":
		boss = str(block["boss_star5"])
	return line.format({"dungeon": str(dungeon.get("name", "")), "boss": boss, "town": str(block.get("town", "")), "star": star})


## Room won: step on. Returns true when another room follows.
func advance() -> bool:
	if is_last_room():
		result = "win"
		return false
	room_index += 1
	return true


func lose() -> void:
	result = "lose"


## XP for a win at this run level (before premium), from the 4.8 formula.
func win_xp(hero_level: int) -> int:
	var balance: Dictionary = _read_json(BALANCE_PATH)
	var curve: Dictionary = _read_json(CURVE_PATH)
	var share := float((balance.get("xp_share_of_step", {}) as Dictionary).get("dungeon_win", 0.0))
	var need := 0.0
	var steps: Array = curve.get("xp_to_next", [])
	if steps.is_empty():
		return 0
	need = float(steps[clampi(level - 1, 0, steps.size() - 1)])
	var pace := float(curve.get("pace_start", 1.0)) * pow(float(curve.get("pace_ratio", 1.0)), float(maxi(hero_level, 1) - 1))
	var base := int(round(share * need * pace))
	if XP_STAR_LINEAR:
		return base * star
	var stars: Array = balance.get("stars", [1.0])
	var star_mult := float(stars[clampi(star - 1, 0, stars.size() - 1)]) if not stars.is_empty() else 1.0
	return int(round(share * need * star_mult * pace))


## Pays a won run into the hero. `progress` is pc_progress, `missions` is
## pc_missions (or null). Returns the summary the result panel shows.
func pay_out(progress, missions, rng: RandomNumberGenerator, persist: bool = true) -> Dictionary:
	var summary := {
		"dungeon_id": str(dungeon.get("id", "")),
		"name": str(dungeon.get("name", "")),
		"result": result,
		"xp": 0,
		"coins": 0,
		"items": [],
		"level_ups": [],
		"missions": [],
		"granted": {},
	}
	if result != "win" or progress == null:
		return summary
	var catalog: Dictionary = Rewards.load_default()
	var drop := {"coins": 0, "items": []}
	if bool(catalog.get("ok", false)):
		drop = catalog["rewards"].roll("dungeon", {
			"dungeon_id": str(dungeon["id"]),
			"level": level,
			"stars": star,
			"class_id": hero_class,
			"zone_id": str((dungeon.get("door", {}) as Dictionary).get("zone_id", "")),
		}, rng)
	drop["items"] = star_loot(catalog.get("rewards", null), drop.get("items", []), rng)
	var xp := win_xp(int(progress.level))
	summary["xp"] = xp
	summary["coins"] = int(drop.get("coins", 0))
	summary["items"] = (drop.get("items", []) as Array).duplicate(true)
	summary["level_ups"] = progress.add_xp(xp)
	summary["granted"] = progress.grant({"coins": summary["coins"], "items": summary["items"]})
	if missions != null:
		summary["missions"] = missions.on_dungeon_won(str(dungeon["id"]), progress)
	summary["star"] = star
	if progress.has_method("note_dungeon_star"):
		summary["new_best_star"] = progress.note_dungeon_star(str(dungeon["id"]), star)
	if persist:
		progress.save()
	return summary


## Star gate on the dungeon roll: no Rare part below ★3; at ★5 one Rare part
## and one Mystery Box (the Legendary slot) are guaranteed.
func star_loot(catalog, items: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for raw in items:
		var item: Dictionary = raw
		if str(item.get("rarity", "regular")) == "rare" and star < RARE_FROM_STAR:
			item = item.duplicate()
			item["rarity"] = "regular"
		out.append(item)
	if star >= LEGENDARY_FROM_STAR and catalog != null:
		var has_rare := false
		var has_box := false
		for item in out:
			has_rare = has_rare or str(item.get("rarity", "")) == "rare"
			has_box = has_box or str(item.get("item_id", "")) == "mystery_box"
		if not has_rare:
			var rare: Dictionary = catalog._part_drop(catalog._dungeon_part_set(catalog._dungeon(str(dungeon["id"])), {"class_id": hero_class}, rng), "rare", rng)
			if str(rare.get("item_id", "")) != "":
				out.append(rare)
		if not has_box:
			out.append(catalog._box_item())
	return out


func _load_run_doc() -> void:
	var path := str(dungeon.get("run", ""))
	run_doc = _read_json(path)
	if str(run_doc.get("format", "")) != RUN_FORMAT:
		errors.append("run file %s" % path)
		return
	if str(run_doc.get("dungeon", "")) != str(dungeon["id"]):
		errors.append("run file names another dungeon")
	_rooms = (run_doc.get("rooms", []) as Array).duplicate(true)
	if _rooms.size() != int(dungeon.get("rooms", 2)):
		errors.append("run has %d rooms, the door says %d" % [_rooms.size(), int(dungeon.get("rooms", 2))])
	for spec in _rooms:
		var tags := _read_tags(str(spec.get("tags", "")))
		if tags.is_empty():
			errors.append("room %s tags missing" % spec.get("id", "?"))
		var all_packs: Array = (spec.get("monsters", []) as Array).duplicate()
		for p in (spec.get("packs", {}) as Dictionary).values():
			all_packs.append_array(p)
		for m in all_packs:
			if not monsters.has(str(m.get("monster", ""))):
				errors.append("room %s names unknown monster %s" % [spec.get("id", "?"), m.get("monster", "")])


static func _read_tags(path: String) -> Dictionary:
	return _read_json(path)


static func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
