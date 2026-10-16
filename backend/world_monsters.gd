extends RefCounted

## Open-world monster packs and rare world bosses (data/world/world_monsters.json).
## Preload. No global class. Pure logic, so a server can run it later: the
## world scene only draws what this decides.
##
## - packs: placed per chunk on walkable, non-safe cells; size 2-10 from the
##   depth's size weights; levels from the chunk's depth inside the zone band;
##   respawn after rules.respawn_s.
## - fights: fight_config() cuts a square board of world cells round the pack
##   for CombatSim's dungeon mode (the same engine as the PC dungeons).
## - rewards: pack_rewards() scales the spec 4.8 world fight with pack size;
##   world_drop() is the one seam to the gear branch's pc_gear.
## - bosses: BossClock rolls spawns while a boss's condition holds, despawns
##   when it ends or times out, and keeps a cooldown per boss.
##
## Rule (Mauro): open-world monsters are never dungeon monsters
## (reuse_conflicts() is the check; run_world_mobs_tests.gd runs it).

const PATH := "res://data/world/world_monsters.json"
const FORMAT := "stasium.world_monsters"
const FORMAT_VERSION := 1
const DUNGEON_MONSTERS := "res://data/world/dungeon_monsters.json"
const DUNGEON_ART_ROOT := "res://art/pc/dungeons"
const CURVE_PATH := "res://data/world/level_curve.json"
const BALANCE_PATH := "res://data/world/balance_inputs.json"
const GEAR_PATH := "res://backend/pc_gear.gd"
const MAX_PACK := 10
const MIN_PACK := 2
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "notes", "scaling", "rules", "rewards", "size_weights", "zones", "monsters", "bosses", "boss_loot"]
const MONSTER_KEYS: Array[String] = ["id", "name", "zone", "role", "level_min", "level_max", "hp", "ap", "mp", "attack", "signature", "signature2", "art", "map_scale", "boss"]
const BOSS_KEYS: Array[String] = ["condition", "chunks", "level", "escort", "roll_per_minute", "cooldown_s", "timeout_s", "banner", "leave_text", "trophy", "title", "aura"]
const CONDITION_KEYS: Array[String] = ["time", "weather", "season"]
const TIMES: Array[String] = ["night", "dawn", "day", "dusk"]
## Weather words a boss may ask for. rain / wind / cloud / clear map to the
## crosshaven_weather.gd looks; fog, storm and snow have no look yet.
const WEATHER_WORDS := {
	"clear": ["clear"],
	"cloud": ["light_cloud"],
	"rain": ["light_rain"],
	"wind": ["wind"],
	"fog": ["fog"],
	"storm": ["storm"],
	"snow": ["snow"],
}
const SIZE_BANDS := {"2-4": [2, 4], "5-7": [5, 7], "8-10": [8, 10]}

var doc: Dictionary = {}
var _by_id: Dictionary = {}
var _zones: Dictionary = {}
var _chunk_zone: Dictionary = {}


static func load_default() -> Dictionary:
	return load_path(PATH)


static func load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(["world monster file is missing"])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail(["world monster file must be a JSON object"])
	return load_document(parsed)


static func load_document(raw: Dictionary) -> Dictionary:
	var book = new()
	var errors: Array = []
	book._read(raw, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "errors": [], "book": book}


# ------------------------------------------------------------------ lookups

func ids() -> Array:
	var out: Array = []
	for row in doc.get("monsters", []):
		out.append(str(row["id"]))
	return out


func boss_ids() -> Array:
	var out: Array = []
	for row in doc.get("bosses", []):
		out.append(str(row["id"]))
	return out


func has(monster_id: String) -> bool:
	return _by_id.has(monster_id)


func row(monster_id: String) -> Dictionary:
	return (_by_id.get(monster_id, {}) as Dictionary).duplicate(true)


func rule(key: String, fallback: Variant = null) -> Variant:
	return (doc.get("rules", {}) as Dictionary).get(key, fallback)


func zone_cfg(zone_id: String) -> Dictionary:
	return (_zones.get(zone_id, {}) as Dictionary).duplicate(true)


func zone_of_chunk(chunk_id: String) -> String:
	return str(_chunk_zone.get(chunk_id, ""))


func chunk_cfg(chunk_id: String) -> Dictionary:
	var zid := zone_of_chunk(chunk_id)
	if zid == "":
		return {}
	return ((_zones[zid] as Dictionary).get("chunks", {}) as Dictionary).get(chunk_id, {})


func art_path(zone_id: String) -> String:
	return str((_zones.get(zone_id, {}) as Dictionary).get("art", ""))


func bosses_in(zone_id: String) -> Array:
	var out: Array = []
	for b in doc.get("bosses", []):
		if str(b.get("zone", "")) == zone_id:
			out.append((b as Dictionary).duplicate(true))
	return out


## Combat stats at a level (the dungeon scaling rule), in the shape
## CombatSim._make_monster reads.
func stats_at(monster_id: String, level: int) -> Dictionary:
	var r: Dictionary = _by_id.get(monster_id, {})
	if r.is_empty():
		return {}
	var lo := int(r["level_min"])
	var at := clampi(level, lo, int(r["level_max"]))
	var steps := float(at - lo)
	var sc: Dictionary = doc.get("scaling", {})
	var hp_mult := 1.0 + float(sc.get("hp_per_level", 0.0)) * steps
	var dmg_mult := 1.0 + float(sc.get("damage_per_level", 0.0)) * steps
	var attack: Dictionary = (r["attack"] as Dictionary).duplicate(true)
	attack["damage"] = maxi(int(round(float(attack["damage"]) * dmg_mult)), 1)
	var out := {
		"monster": monster_id,
		"name": str(r["name"]),
		"level": at,
		"hp": maxi(int(round(float(r["hp"]) * hp_mult)), 1),
		"ap": int(r["ap"]),
		"mp": int(r["mp"]),
		"attack": attack,
		"boss": str(r.get("role", "")) == "boss",
		"art": str(r.get("art", monster_id)),
		"element": str(attack.get("element", "earth")),
		"world": true,
	}
	for key in ["signature", "signature2"]:
		if r.has(key):
			var sig: Dictionary = (r[key] as Dictionary).duplicate(true)
			if sig.has("hp"):
				sig["hp"] = maxi(int(round(float(sig["hp"]) * dmg_mult)), 1)
			out[key] = sig
	return out


# ------------------------------------------------------------------ levels and sizes

## [lo, hi] pack levels for a chunk: its depth placed inside the zone band.
## `levels` is world_levels.gd (zone_for_chunk). Empty for a chunk with no packs.
func chunk_levels(levels, chunk_id: String) -> Array:
	var zid := zone_of_chunk(chunk_id)
	if zid == "" or levels == null:
		return []
	var zone: Dictionary = levels.zone_for_chunk(chunk_id)
	if zone.is_empty():
		return []
	var lmin := int(zone["level_min"])
	var lmax := int(zone["level_max"])
	var depths: Dictionary = zone.get("depth", {})
	var dmin := 999
	var dmax := -1
	for c in ((_zones[zid] as Dictionary).get("chunks", {}) as Dictionary).keys():
		var d := int(depths.get(c, 0))
		dmin = mini(dmin, d)
		dmax = maxi(dmax, d)
	var mine := int(depths.get(chunk_id, dmin))
	var t := 0.0 if dmax <= dmin else float(mine - dmin) / float(dmax - dmin)
	var centre := int(floor(float(lmin) + t * float(lmax - lmin)))
	var lo := centre - 1
	var hi := centre + 1
	if lo < lmin:
		hi += lmin - lo
		lo = lmin
	if hi > lmax:
		lo -= hi - lmax
		hi = lmax
	return [clampi(lo, lmin, lmax), clampi(hi, lmin, lmax)]


func chunk_depth(levels, chunk_id: String) -> int:
	if levels == null:
		return 0
	var zone: Dictionary = levels.zone_for_chunk(chunk_id)
	return int((zone.get("depth", {}) as Dictionary).get(chunk_id, 0))


## {"2-4": w, "5-7": w, "8-10": w} for a depth.
func size_weights(depth: int) -> Dictionary:
	var rows: Array = doc.get("size_weights", [])
	for r in rows:
		if depth <= int(r["depth_max"]):
			return (r["weights"] as Dictionary).duplicate()
	return (rows[-1]["weights"] as Dictionary).duplicate() if not rows.is_empty() else {"2-4": 1}


func roll_size(depth: int, rng: RandomNumberGenerator) -> int:
	var w := size_weights(depth)
	var total := 0.0
	for k in w.keys():
		total += float(w[k])
	var x := rng.randf() * total
	var band: Array = [2, 4]
	for k in ["2-4", "5-7", "8-10"]:
		if not w.has(k):
			continue
		x -= float(w[k])
		if x < 0.0:
			band = SIZE_BANDS[k]
			break
	return rng.randi_range(int(band[0]), int(band[1]))


## One pack for a chunk: members [{monster, level}], sorted leader first.
## 30% of packs are one kind (the leader's); the rest mix the chunk's pool.
func make_pack(levels, chunk_id: String, rng: RandomNumberGenerator, size: int = -1) -> Dictionary:
	var cfg := chunk_cfg(chunk_id)
	var pool: Dictionary = cfg.get("pool", {})
	if pool.is_empty():
		return {}
	var band := chunk_levels(levels, chunk_id)
	var n := size if size > 0 else roll_size(chunk_depth(levels, chunk_id), rng)
	n = clampi(n, MIN_PACK, mini(MAX_PACK, int(cfg.get("max_size", MAX_PACK))) if size <= 0 else MAX_PACK)
	var leader := _weighted_key(pool, rng)
	var mono := rng.randf() < 0.3
	var members: Array = []
	for i in n:
		var kind := leader if (i == 0 or mono) else _weighted_key(pool, rng)
		members.append({"monster": kind, "level": rng.randi_range(int(band[0]), int(band[1]))})
	# Every mixed pack of 3+ has at least one melee body, so ranged packs
	# have something in front.
	if not mono and n >= 3 and not _has_melee(members):
		for k in pool.keys():
			if str(row(str(k)).get("role", "")) != "ranged":
				members[n - 1]["monster"] = str(k)
				break
	return describe_pack(members)


## Size, level range and total level (the hover plate) for a member list.
func describe_pack(members: Array) -> Dictionary:
	var lo := 999
	var hi := 0
	var total := 0
	var counts := {}
	for m in members:
		var lv := int(m["level"])
		lo = mini(lo, lv)
		hi = maxi(hi, lv)
		total += lv
		counts[str(m["monster"])] = int(counts.get(str(m["monster"]), 0)) + 1
	return {"members": members.duplicate(true), "size": members.size(), "level_min": lo, "level_max": hi, "total_level": total, "counts": counts}


func plate_lines(pack: Dictionary, hero_level: int) -> Dictionary:
	var parts: Array = []
	var counts: Dictionary = pack.get("counts", {})
	for k in counts.keys():
		parts.append("%s ×%d" % [str(row(str(k)).get("name", k)), int(counts[k])])
	var lv := "Lv %d" % int(pack["level_min"]) if int(pack["level_min"]) == int(pack["level_max"]) else "Lv %d–%d" % [int(pack["level_min"]), int(pack["level_max"])]
	var head := "%s  ·  %s" % [str(pack.get("boss_name", "Pack of %d" % int(pack["size"]))), lv]
	return {
		"title": head,
		"total": "Total Lv %d" % int(pack["total_level"]),
		"members": ", ".join(parts),
		"red": is_red(pack, hero_level),
	}


func is_red(pack: Dictionary, hero_level: int) -> bool:
	return int(pack.get("level_max", 0)) >= hero_level + int(rule("red_above", 5))


# ------------------------------------------------------------------ placement

## Cells packs may not stand on in a zone chunk: everything in a chunk with
## no packs (the Crossroads, the towns), and cells within safe_radius of an
## exit, a gate, an NPC, a dungeon door or building, a point of interest or
## the spawn. `npc_cells`, `door_cells` are Vector2i arrays the caller has.
func forbidden_cells(z: WorldZone, npc_cells: Array = [], door_cells: Array = []) -> Dictionary:
	var out := {}
	var r := int(rule("safe_radius", 2))
	var marks: Array = []
	for e in z.exits:
		if (e as Dictionary).has("x"):
			marks.append(Vector2i(int(e["x"]), int(e["y"])))
		# A seam (an exit along a whole edge) is covered by the edge margin;
		# a narrow exit (a gate, a path) keeps its safe radius.
		if ((e as Dictionary).get("links", []) as Array).size() > 4:
			continue
		for l in (e as Dictionary).get("links", []):
			var fr: Dictionary = (l as Dictionary).get("from", {})
			marks.append(Vector2i(int(fr.get("x", -9)), int(fr.get("y", -9))))
	for p in z.points_of_interest:
		if (p as Dictionary).has("x"):
			marks.append(Vector2i(int(p["x"]), int(p["y"])))
	marks.append(z.spawn)
	marks.append_array(npc_cells)
	marks.append_array(door_cells)
	for m in marks:
		var c: Vector2i = m
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out[c + Vector2i(dx, dy)] = true
	# The chunk edge too, so a pack never stands on a seam.
	# A thin strip chunk (8 cells or less across) keeps a 1-cell margin there.
	var my := 1 if z.height <= 8 else 2
	var mx := 1 if z.width <= 8 else 2
	for x in range(z.width):
		for k in my:
			out[Vector2i(x, k)] = true
			out[Vector2i(x, z.height - 1 - k)] = true
	for y in range(z.height):
		for k in mx:
			out[Vector2i(k, y)] = true
			out[Vector2i(z.width - 1 - k, y)] = true
	return out


func spawn_ok(z: WorldZone, cell: Vector2i, forbidden: Dictionary) -> bool:
	return z.in_bounds(cell) and z.passable_at(cell) and not forbidden.has(cell)


## Up to `want` body cells round a home cell: free, walkable, same height as
## the home, not forbidden, not taken. Home first, then the nearest ring.
func body_cells(z: WorldZone, home: Vector2i, want: int, forbidden: Dictionary, taken: Dictionary) -> Array:
	var out: Array = []
	var spread := int(rule("pack_spread", 2))
	var ring: Array = []
	for dy in range(-spread, spread + 1):
		for dx in range(-spread, spread + 1):
			ring.append(Vector2i(dx, dy))
	ring.sort_custom(func(a, b): return absi(a.x) + absi(a.y) < absi(b.x) + absi(b.y) or (absi(a.x) + absi(a.y) == absi(b.x) + absi(b.y) and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var h := z.height_at(home)
	for d in ring:
		if out.size() >= want:
			break
		var c: Vector2i = home + d
		if not spawn_ok(z, c, forbidden) or taken.has(c) or z.height_at(c) != h:
			continue
		out.append(c)
	return out


## Places a chunk's packs. Returns [{id, chunk, home, cells, pack}] with each
## body on its own cell; a pack keeps a 3-cell gap to other packs.
func place_packs(z: WorldZone, levels, rng: RandomNumberGenerator, forbidden: Dictionary, count: int = -1) -> Array:
	var cfg := chunk_cfg(z.zone_id)
	if cfg.is_empty():
		return []
	var n := count if count >= 0 else int(cfg.get("packs", 4))
	var out: Array = []
	var taken := {}
	var tries := 0
	var bodies := int(rule("visible_bodies", 6))
	while out.size() < n and tries < 400:
		tries += 1
		var home := Vector2i(rng.randi_range(1, z.width - 2), rng.randi_range(1, z.height - 2))
		if not spawn_ok(z, home, forbidden) or taken.has(home):
			continue
		var pack := make_pack(levels, z.zone_id, rng)
		if pack.is_empty():
			break
		var cells := body_cells(z, home, mini(int(pack["size"]), bodies), forbidden, taken)
		if cells.size() < mini(int(pack["size"]), bodies):
			continue
		for c in cells:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					taken[c + Vector2i(dx, dy)] = true
		out.append({"id": "%s#%d" % [z.zone_id, out.size()], "chunk": z.zone_id, "home": home, "cells": cells, "pack": pack})
	return out


## One wander step for a pack: a new home within wander_radius of `anchor`
## whose body cells all fit. Returns the new {home, cells} or {} to stay.
func wander(z: WorldZone, entry: Dictionary, anchor: Vector2i, rng: RandomNumberGenerator, forbidden: Dictionary, taken: Dictionary) -> Dictionary:
	var r := int(rule("wander_radius", 3))
	var want: int = (entry["cells"] as Array).size()
	for i in 8:
		var home := anchor + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
		if not spawn_ok(z, home, forbidden) or taken.has(home):
			continue
		var cells := body_cells(z, home, want, forbidden, taken)
		if cells.size() == want:
			return {"home": home, "cells": cells}
	return {}


# ------------------------------------------------------------------ fights

## CombatSim dungeon-mode config for a world fight: a size x size board of the
## world cells round the pack (board cell b = world cell origin + b). A cell is
## walkable when the world cell is passable, inside the chunk and at the pack's
## height; everything else blocks. The hero starts on the board cell nearest
## where they stand; the monsters on the pack's own cells, then the nearest
## free reachable cells at least 2 from the hero. `hero` is {class_id, name,
## pos (world cell), hp}. Returns {} when no fair board fits.
func fight_config(z: WorldZone, entry: Dictionary, hero: Dictionary, seed: int = -1, extra_blocked: Array = []) -> Dictionary:
	var n := int(rule("board_size", 14))
	var home: Vector2i = entry["home"]
	var origin := home - Vector2i(n / 2, n / 2)
	origin.x = clampi(origin.x, 0, maxi(z.width - n, 0))
	origin.y = clampi(origin.y, 0, maxi(z.height - n, 0))
	var base_h := z.height_at(home)
	var blocked_world := {}
	for c in extra_blocked:
		blocked_world[c] = true
	var walk := {}
	var cells: Array = []
	for by in n:
		for bx in n:
			var b := Vector2i(bx, by)
			var w := origin + b
			var ok := z.in_bounds(w) and z.passable_at(w) and z.height_at(w) == base_h and not blocked_world.has(w)
			if ok:
				walk[b] = true
			cells.append({"pos": b, "terrain": "ground", "elevation": 0, "paint_only": [], "blocks": not ok, "special": ""})
	var members: Array = (entry["pack"] as Dictionary)["members"]
	var hero_world: Vector2i = hero.get("pos", home + Vector2i(0, 3))
	var hero_b := _nearest_walk(walk, hero_world - origin, n)
	if hero_b == Vector2i(-1, -1):
		return {}
	var reach := _flood(walk, hero_b, n)
	var used := {hero_b: true}
	var spots: Array = []
	# Dofus-style placement: the pack spreads round its home with a free cell
	# between bodies where the board allows, and keeps 3+ cells from the hero
	# (2 on a cramped board).
	var centre := home - origin
	var free: Array = reach.keys()
	free.sort_custom(func(a, b): return _cheb(a, centre) < _cheb(b, centre) or (_cheb(a, centre) == _cheb(b, centre) and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for pass_i in 3:
		var gap := 2 if pass_i == 0 else 1
		var keep := 3 if pass_i < 2 else 2
		spots.clear()
		used = {hero_b: true}
		for i in members.size():
			var pick := Vector2i(-1, -1)
			for c in free:
				if used.has(c) or _cheb(c, hero_b) < keep:
					continue
				var near := false
				for o in spots:
					if _cheb(o, c) < gap:
						near = true
						break
				if not near:
					pick = c
					break
			if pick == Vector2i(-1, -1):
				break
			used[pick] = true
			spots.append(pick)
		if spots.size() == members.size():
			break
	if spots.size() < members.size():
		return {}
	var mons: Array = []
	var summons := {}
	for i in members.size():
		var m: Dictionary = members[i]
		var stats := stats_at(str(m["monster"]), int(m["level"]))
		stats["pos"] = spots[i]
		stats["facing"] = _face(spots[i], hero_b)
		mons.append(stats)
		var sig: Dictionary = stats.get("signature", {})
		if str(sig.get("summon", "")) != "":
			summons[str(sig["summon"])] = stats_at(str(sig["summon"]), int(m["level"]))
	var config := {
		"board_size": n,
		"dungeon": {
			"dungeon_id": "world_" + zone_of_chunk(z.zone_id),
			"room_id": "world_" + z.zone_id,
			"room_name": str(entry.get("title", "")),
			"star": 1,
			"kind": "world",
			"cells": cells,
			"pad_heal": 0,
			"pad_thaw": false,
			"view": {"floor": {"world": true}},
			"hero": {
				"class_id": str(hero.get("class_id", "kestrel")),
				"name": str(hero.get("name", "")),
				"pos": hero_b,
				"facing": _face(hero_b, spots[0]),
			},
			"monsters": mons,
			"summons": summons,
		},
		"world_origin": origin,
		"world_zone": z.zone_id,
	}
	if int(hero.get("hp", 0)) > 0:
		(config["dungeon"]["hero"] as Dictionary)["hp"] = int(hero["hp"])
	if seed >= 0:
		config["seed"] = seed
	return config


static func _nearest_walk(walk: Dictionary, want: Vector2i, n: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for c in walk.keys():
		var d := absi(c.x - want.x) + absi(c.y - want.y)
		if d < bd or (d == bd and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			bd = d
			best = c
	return best


static func _flood(walk: Dictionary, start: Vector2i, n: int) -> Dictionary:
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = c + d
			if walk.has(nx) and not seen.has(nx):
				seen[nx] = true
				q.append(nx)
	return seen


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _face(from: Vector2i, to: Vector2i) -> String:
	var d := to - from
	if absi(d.x) >= absi(d.y):
		return "E" if d.x > 0 else "W"
	return "S" if d.y > 0 else "N"


# ------------------------------------------------------------------ rewards

## (n / base_pack) ^ size_exponent.
func size_mult(n: int) -> float:
	var rw: Dictionary = doc.get("rewards", {})
	return pow(float(maxi(n, 1)) / float(rw.get("base_pack", 3)), float(rw.get("size_exponent", 0.8)))


func drop_mult(n: int) -> float:
	return 1.0 + float((doc.get("rewards", {}) as Dictionary).get("drop_per_extra", 0.12)) * float(maxi(n, 1) - 1)


## XP and coins for beating a pack at hero_level (before premium), from the
## spec 4.8 world fight (share x xp_to_next(group level) x pace(hero) x level
## gap), times size_mult. Group level = the pack's top level.
func pack_rewards(pack: Dictionary, hero_level: int, curve: Dictionary = {}, balance: Dictionary = {}) -> Dictionary:
	if curve.is_empty():
		curve = _read_json(CURVE_PATH)
	if balance.is_empty():
		balance = _read_json(BALANCE_PATH)
	var steps: Array = curve.get("xp_to_next", [])
	var group := int(pack.get("level_max", 1))
	var need := float(steps[clampi(group - 1, 0, steps.size() - 1)]) if not steps.is_empty() else 0.0
	var pace := float(curve.get("pace_start", 1.0)) * pow(float(curve.get("pace_ratio", 1.0)), float(maxi(hero_level, 1) - 1))
	var share := float((balance.get("xp_share_of_step", {}) as Dictionary).get("world_fight", 0.035))
	var gap := _gap(hero_level, group, balance)
	var n := int(pack.get("size", 1))
	var coins_doc: Dictionary = (_read_json("res://data/world/rewards.json").get("coins", {}) as Dictionary)
	var coin_one := float(coins_doc.get("world_base", 3)) + float(coins_doc.get("world_per_level", 1.5)) * float(group)
	var mult := size_mult(n)
	var boss := bool(pack.get("boss", false))
	var boss_mult := 3.0 if boss else 1.0
	return {
		"xp": maxi(int(round(share * need * pace * gap * mult * boss_mult)), 1),
		"coins": maxi(int(round(coin_one * mult * boss_mult)), 1),
		"size_mult": mult,
		"drop_mult": drop_mult(n),
		"gap": gap,
	}


static func _gap(player_level: int, group_level: int, balance: Dictionary) -> float:
	var g: Dictionary = balance.get("level_gap", {})
	var below := player_level - group_level
	if below >= 10:
		return float(g.get("below_10_or_more", 0.1))
	if below >= 6:
		return float(g.get("below_6_to_9", 0.5))
	if below >= 0:
		return 1.0
	return 1.0 + minf(float(-below) * float(g.get("above_per_level", 0.05)), float(g.get("above_cap", 0.25)))


## The zone row pc_rewards uses for a pack's world drop (rewards.json zones).
func reward_zone(zone_id: String, level: int) -> String:
	for r in (_zones.get(zone_id, {}) as Dictionary).get("reward_rows", []):
		if level <= int(r["level_max"]):
			return str(r["zone"])
	return ""


## Rolls a won pack's loot: the world set part (pc_rewards world_part_chance
## x drop_mult), the gear seam, and for a boss its chest, the epic chance and
## the trophy. `catalog` is pc_rewards (or null).
func roll_loot(pack: Dictionary, zone_id: String, class_id: String, catalog, rng: RandomNumberGenerator) -> Array:
	var items: Array = []
	var n := int(pack.get("size", 1))
	var level := int(pack.get("level_max", 1))
	if catalog != null:
		var chance := float(catalog._doc.get("world_part_chance", 0.03)) * drop_mult(n)
		if rng.randf() < chance:
			var set_def: Dictionary = catalog._pick_zone_set({"zone_id": reward_zone(zone_id, level), "class_id": class_id}, "world", rng)
			if not set_def.is_empty():
				items.append(catalog._part_drop(set_def, "regular", rng))
	var tier := str((doc.get("boss_loot", {}) as Dictionary).get("chest_zone", "")) if bool(pack.get("boss", false)) else ""
	var gear: Variant = world_drop(level, rng, n, tier, catalog)
	if typeof(gear) == TYPE_DICTIONARY and not (gear as Dictionary).is_empty():
		items.append(gear)
	if bool(pack.get("boss", false)):
		items.append_array(boss_loot(pack, class_id, catalog, rng))
	return items


## A boss's extra loot: a guaranteed chest part from the next zone's world
## row (rare at chest_rare_chance), epic_chance at the zone dungeon's
## star_drops pools (none for a dungeon without them), and the trophy.
func boss_loot(pack: Dictionary, class_id: String, catalog, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var bl: Dictionary = doc.get("boss_loot", {})
	var b := row(str(pack.get("boss_id", "")))
	var info: Dictionary = b.get("boss", {})
	if catalog != null:
		var set_def: Dictionary = catalog._pick_zone_set({"zone_id": str(bl.get("chest_zone", "")), "class_id": class_id}, "world", rng)
		if not set_def.is_empty():
			var rarity := "rare" if rng.randf() < float(bl.get("chest_rare_chance", 0.25)) else "regular"
			var part: Dictionary = catalog._part_drop(set_def, rarity, rng)
			part["chest"] = true
			out.append(part)
		if rng.randf() < float(bl.get("epic_chance", 0.03)):
			var dungeon: Dictionary = catalog._dungeon(str(bl.get("epic_from_dungeon", "")))
			var pools: Array = []
			for g in (dungeon.get("star_drops", {}) as Dictionary).get("groups", []):
				for p in (g as Dictionary).get("pools", []):
					pools.append(p)
			if not pools.is_empty():
				var pool: Dictionary = pools[rng.randi() % pools.size()]
				var idsx: Array = catalog._star_pool_ids(pool)
				if not idsx.is_empty():
					var picked := str(idsx[rng.randi() % idsx.size()])
					out.append({"item_id": picked, "rarity": str(pool.get("rarity", "regular")), "count": 1, "epic": true})
	var trophy: Dictionary = info.get("trophy", {})
	if not trophy.is_empty():
		out.append({"trophy": str(trophy.get("id", "")), "name": str(trophy.get("name", "")), "title": str(info.get("title", "")), "count": 1})
	return out


## THE gear seam (one place). The sibling gear branch (claude/pc-mobile-gear)
## adds pc_rewards.roll_world_drop(zone_level, rng, chance=-1, tier="")
## (a wrapper of pc_gear.roll_world_drop) with a base chance of
## rewards.json gear.world_chance (0.08 a win). This calls it when it exists,
## with the pack-size chance world_chance x (1 + 0.12 (n - 1)) and a boss's
## tier row; otherwise (this branch) it drops nothing. `catalog` is the
## pc_rewards instance (or null); gear_override is for tests.
const GEAR_WORLD_CHANCE := 0.08
static var gear_override: Object = null


func world_drop(zone_level: int, rng: RandomNumberGenerator, pack_size: int = 1, tier: String = "", catalog = null) -> Variant:
	var gear: Object = gear_override
	if gear == null and catalog != null and (catalog as Object).has_method("roll_world_drop"):
		gear = catalog
	if gear == null and ResourceLoader.exists(GEAR_PATH):
		var script: Variant = load(GEAR_PATH)
		if script is GDScript and (script as GDScript).get_script_method_list().any(func(m): return str(m.get("name", "")) == "roll_world_drop"):
			gear = script
	if gear == null or not gear.has_method("roll_world_drop"):
		return {}
	var base := GEAR_WORLD_CHANCE
	if catalog != null and typeof(catalog.get("_doc")) == TYPE_DICTIONARY:
		base = float(((catalog._doc as Dictionary).get("gear", {}) as Dictionary).get("world_chance", GEAR_WORLD_CHANCE))
	var chance := base * drop_mult(pack_size)
	var got: Variant = gear.call("roll_world_drop", zone_level, rng, chance, tier)
	return got if typeof(got) == TYPE_DICTIONARY else {}


# ------------------------------------------------------------------ bosses

## "night" 21-5, "dawn" 5-7, "dusk" 18-21, else "day" (hours 0..24).
static func time_word(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 21.0 or h < 5.0:
		return "night"
	if h < 7.0:
		return "dawn"
	if h >= 18.0:
		return "dusk"
	return "day"


## env: {hour: float, weather: String (a crosshaven_weather id), season: String}.
## Every listed key must hold; inside a key any listed word may.
static func condition_holds(condition: Dictionary, env: Dictionary) -> bool:
	if condition.is_empty():
		return false
	if condition.has("time"):
		if not (condition["time"] as Array).has(time_word(float(env.get("hour", 12.0)))):
			return false
	if condition.has("weather"):
		var now := str(env.get("weather", "clear"))
		var any := false
		for w in condition["weather"]:
			if (WEATHER_WORDS.get(str(w), [str(w)]) as Array).has(now):
				any = true
		if not any:
			return false
	if condition.has("season"):
		if not (condition["season"] as Array).has(str(env.get("season", ""))):
			return false
	return true


## The boss pack: the boss at its level plus its escort (at the zone top).
## Total never above MAX_PACK (escort trimmed if the data asks for more).
func boss_pack(boss_id: String) -> Dictionary:
	var b := row(boss_id)
	var info: Dictionary = b.get("boss", {})
	var lv := int(info.get("level", b.get("level_min", 1)))
	var members: Array = [{"monster": boss_id, "level": lv}]
	for e in info.get("escort", []):
		for i in int(e.get("count", 1)):
			if members.size() >= MAX_PACK:
				break
			members.append({"monster": str(e["monster"]), "level": maxi(lv - 2, 1)})
	var pack := describe_pack(members)
	pack["boss"] = true
	pack["boss_id"] = boss_id
	pack["boss_name"] = str(b.get("name", boss_id))
	return pack


## Most enemies a boss fight can hold: the pack plus every summon it may call.
func boss_fight_cap(boss_id: String) -> int:
	var pack := boss_pack(boss_id)
	var sig: Dictionary = row(boss_id).get("signature", {})
	var extra := int(sig.get("cap_total", 0)) if str(sig.get("kind", "")) == "summon" else 0
	return int(pack["size"]) + extra


class BossClock extends RefCounted:
	## Per-boss state for one zone: spawn rolls while the condition holds,
	## despawn on condition end or timeout, cooldown after either.
	var book = null
	var zone_id := ""
	## boss_id -> {up: bool, up_s: float, cooldown_until: float, chunk, cell}
	var state := {}
	var now_s := 0.0
	var _acc := {}

	func _init(the_book = null, zid: String = "") -> void:
		book = the_book
		zone_id = zid
		if book != null:
			for id in book.boss_ids():
				if str(book.row(id).get("zone", "")) == zone_id:
					state[id] = {"up": false, "up_s": 0.0, "cooldown_until": 0.0, "chunk": "", "cell": Vector2i(-1, -1)}
					_acc[id] = 0.0

	func is_up(boss_id: String) -> bool:
		return bool((state.get(boss_id, {}) as Dictionary).get("up", false))

	func up_ids() -> Array:
		return state.keys().filter(func(id): return is_up(id))

	## Advance by `seconds` of play in the zone under `env`. Returns events
	## [{type: "spawn"|"despawn", boss, reason}]. A spawn rolls once per full
	## in-condition minute with roll_per_minute.
	func tick(seconds: float, env: Dictionary, rng: RandomNumberGenerator) -> Array:
		var events: Array = []
		now_s += seconds
		for id in state.keys():
			var s: Dictionary = state[id]
			var info: Dictionary = book.row(id).get("boss", {})
			var holds: bool = book.condition_holds(info.get("condition", {}), env)
			if bool(s["up"]):
				s["up_s"] = float(s["up_s"]) + seconds
				if not holds:
					events.append(_down(id, "condition"))
				elif float(s["up_s"]) >= float(info.get("timeout_s", 1800)):
					events.append(_down(id, "timeout"))
				continue
			if not holds or now_s < float(s["cooldown_until"]):
				_acc[id] = 0.0
				continue
			_acc[id] = float(_acc[id]) + seconds
			while float(_acc[id]) >= 60.0:
				_acc[id] = float(_acc[id]) - 60.0
				if rng.randf() < float(info.get("roll_per_minute", 0.0)):
					events.append(spawn(id, "roll"))
					break
		return events

	func spawn(boss_id: String, reason: String = "forced") -> Dictionary:
		var s: Dictionary = state.get(boss_id, {})
		if s.is_empty():
			return {}
		s["up"] = true
		s["up_s"] = 0.0
		_acc[boss_id] = 0.0
		var chunks: Array = (book.row(boss_id).get("boss", {}) as Dictionary).get("chunks", [])
		s["chunk"] = str(chunks[0]) if not chunks.is_empty() else ""
		return {"type": "spawn", "boss": boss_id, "reason": reason, "chunk": s["chunk"]}

	## A boss beaten or gone: down, then the cooldown.
	func _down(boss_id: String, reason: String) -> Dictionary:
		var s: Dictionary = state[boss_id]
		s["up"] = false
		s["up_s"] = 0.0
		s["cell"] = Vector2i(-1, -1)
		s["cooldown_until"] = now_s + float((book.row(boss_id).get("boss", {}) as Dictionary).get("cooldown_s", 14400))
		return {"type": "despawn", "boss": boss_id, "reason": reason}

	func defeated(boss_id: String) -> Dictionary:
		if not state.has(boss_id):
			return {}
		return _down(boss_id, "defeated")


## Expected minutes of in-condition play to see a boss once (1 / p).
func expected_minutes(boss_id: String) -> float:
	var p := float((row(boss_id).get("boss", {}) as Dictionary).get("roll_per_minute", 0.0))
	return INF if p <= 0.0 else 1.0 / p


# ------------------------------------------------------------------ the no-reuse rule

## Every way a world monster or boss reuses a dungeon monster: a shared id,
## display name or art id, or an art path / sheet under the dungeon art.
## Returns ["<world id>: <why>", ...]; empty when the rule holds.
func reuse_conflicts(dungeon_doc: Dictionary = {}) -> Array:
	if dungeon_doc.is_empty():
		dungeon_doc = _read_json(DUNGEON_MONSTERS)
	var ids := {}
	var names := {}
	var arts := {}
	for m in dungeon_doc.get("monsters", []):
		ids[str(m.get("id", "")).to_lower()] = true
		names[str(m.get("name", "")).to_lower()] = true
		arts[str(m.get("art", m.get("id", ""))).to_lower()] = true
		var si: Variant = m.get("stand_in", {})
		if typeof(si) == TYPE_DICTIONARY and (si as Dictionary).has("art"):
			arts[str(si["art"]).to_lower()] = true
	var out: Array = []
	var rows: Array = (doc.get("monsters", []) as Array) + (doc.get("bosses", []) as Array)
	for r in rows:
		var id := str(r["id"])
		if ids.has(id.to_lower()):
			out.append("%s: id is a dungeon monster id" % id)
		if names.has(str(r["name"]).to_lower()):
			out.append("%s: name is a dungeon monster name" % id)
		var art := str(r.get("art", id)).to_lower()
		if arts.has(art) or ids.has(art):
			out.append("%s: art is a dungeon monster's art" % id)
		if art.find(DUNGEON_ART_ROOT.trim_prefix("res://")) >= 0:
			out.append("%s: art path is under the dungeon art" % id)
	for z in _zones.values():
		var ap := str((z as Dictionary).get("art", ""))
		if ap.begins_with(DUNGEON_ART_ROOT):
			out.append("%s: art kit is a dungeon kit" % str(z.get("zone", "")))
	return out


# ------------------------------------------------------------------ reading

func _read(raw: Dictionary, errors: Array) -> void:
	doc = raw.duplicate(true)
	if str(raw.get("format", "")) != FORMAT or int(raw.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("format must be %s v%d" % [FORMAT, FORMAT_VERSION])
		return
	for k in raw.keys():
		if not DOC_KEYS.has(str(k)):
			errors.append("unknown key %s" % k)
	for list_key in ["monsters", "bosses"]:
		for r in raw.get(list_key, []):
			if typeof(r) != TYPE_DICTIONARY:
				errors.append("%s rows must be objects" % list_key)
				continue
			var m: Dictionary = r
			for k in m.keys():
				if not MONSTER_KEYS.has(str(k)):
					errors.append("%s: unknown key %s" % [m.get("id", "?"), k])
			for need in ["id", "name", "zone", "role", "level_min", "level_max", "hp", "ap", "mp", "attack", "art"]:
				if not m.has(need):
					errors.append("%s: missing %s" % [m.get("id", "?"), need])
			var id := str(m.get("id", ""))
			if _by_id.has(id):
				errors.append("%s: id repeats" % id)
			_by_id[id] = m
			if list_key == "bosses":
				var info: Dictionary = m.get("boss", {})
				if info.is_empty():
					errors.append("%s: a boss needs a boss block" % id)
				for k in info.keys():
					if not BOSS_KEYS.has(str(k)):
						errors.append("%s: unknown boss key %s" % [id, k])
				var cond: Dictionary = info.get("condition", {})
				if cond.is_empty():
					errors.append("%s: a boss needs a condition" % id)
				for k in cond.keys():
					if not CONDITION_KEYS.has(str(k)):
						errors.append("%s: unknown condition %s" % [id, k])
				for t in cond.get("time", []):
					if not TIMES.has(str(t)):
						errors.append("%s: unknown time %s" % [id, t])
				for w in cond.get("weather", []):
					if not WEATHER_WORDS.has(str(w)):
						errors.append("%s: unknown weather %s" % [id, w])
	for z in raw.get("zones", []):
		var zid := str(z.get("zone", ""))
		_zones[zid] = z
		for c in (z.get("chunks", {}) as Dictionary).keys():
			_chunk_zone[str(c)] = zid
			for k in ((z["chunks"][c] as Dictionary).get("pool", {}) as Dictionary).keys():
				if not _by_id.has(str(k)):
					errors.append("%s pool names unknown monster %s" % [c, k])
	for b in raw.get("bosses", []):
		for e in (b.get("boss", {}) as Dictionary).get("escort", []):
			if not _by_id.has(str(e.get("monster", ""))):
				errors.append("%s escort names unknown monster %s" % [b.get("id", "?"), e.get("monster", "")])
		var sig: Dictionary = b.get("signature", {})
		if str(sig.get("summon", "")) != "" and not _by_id.has(str(sig["summon"])):
			errors.append("%s summons unknown monster %s" % [b.get("id", "?"), sig["summon"]])


func _weighted_key(pool: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in pool.keys():
		total += float(pool[k])
	var x := rng.randf() * total
	var keys := pool.keys()
	keys.sort()
	for k in keys:
		x -= float(pool[k])
		if x < 0.0:
			return str(k)
	return str(keys[-1])


func _has_melee(members: Array) -> bool:
	for m in members:
		if str(row(str(m["monster"])).get("role", "")) != "ranged":
			return true
	return false


static func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "book": null}


## Pays a won pack into the hero (`progress` is pc_progress). A loss pays
## nothing. Returns the summary the result panel shows.
func pay_out(pack: Dictionary, zone_id: String, result: String, progress, rng: RandomNumberGenerator, persist: bool = true) -> Dictionary:
	var summary := {"result": result, "xp": 0, "coins": 0, "items": [], "trophies": [], "level_ups": [], "granted": {}, "size": int(pack.get("size", 0)), "boss": bool(pack.get("boss", false))}
	if result != "win" or progress == null:
		return summary
	var rewards := pack_rewards(pack, int(progress.level))
	var Rewards: GDScript = load("res://backend/pc_rewards.gd")
	var loaded: Dictionary = Rewards.load_default()
	var catalog = loaded["rewards"] if bool(loaded.get("ok", false)) else null
	var items: Array = roll_loot(pack, zone_id, str(progress.hero_class), catalog, rng)
	var gear: Array = []
	for it in items:
		if (it as Dictionary).has("trophy"):
			summary["trophies"].append(it)
		else:
			gear.append(it)
	summary["xp"] = int(rewards["xp"])
	summary["coins"] = int(rewards["coins"])
	summary["items"] = gear
	summary["level_ups"] = progress.add_xp(int(rewards["xp"]))
	summary["granted"] = progress.grant({"coins": summary["coins"], "items": gear.filter(func(i): return str((i as Dictionary).get("item_id", "")) != "")})
	if persist:
		progress.save()
	return summary
