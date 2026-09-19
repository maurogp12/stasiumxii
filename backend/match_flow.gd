class_name MatchFlow
extends RefCounted

## Phase A match flow. Owned by CombatSim.
## Locked: simultaneous local both-ready deploy, then Turn 1 combat.
## Proposed (shipped live): seed-sampled ~6-cell blobs replace #31 border halves.
## Networking OFF. No fog. No deploy timer. One fighter per seat.

enum Phase {
	DEPLOYMENT,
	TURN_1,
}

const BOARD_SIZE := 8
const SEAT_0 := 0
const SEAT_1 := 1
const BLOB_SIZE := 6
const MIN_ZONE_CHEBYSHEV := 3
const PREFERRED_ZONE_CHEBYSHEV_MIN := 4
const PREFERRED_ZONE_CHEBYSHEV_MAX := 6
const HUG_EDGE_CELLS := 2

## Director-stamped Locked 8×8 crop of Mauro's 12×12 (fixed, not random).
## Seeded on CombatSim.reset_match / WalkBoard init. Godot paints snapshot().tiles.
## PHASE_A_DEMO_TILES is phase_a_demo_tiles() — all 64 cells, integer z.
##
## Crop origin (row 2, col 2) on the 12×12. Terrain 0/1/2/3 = G/M/W/L.
## z ladder: z1→0, z2→1, z3→2, z4→3. Max climb 1 / drop 2 (no z1→z3 hop).
##
##     0  1  2  3  4  5  6  7
##   0 G3 G3 M3 W2 L2 W1 W1 M1
##   1 M3 G3 M2 W2 L2 L1 L1 M0
##   2 W3 M3 M2 W2 L2 L1 W1 M0
##   3 W3 W2 W2 W2 W2 W2 M1 G1
##   4 W1 W1 W2 W2 W2 M2 M2 G2
##   5 M1 M1 M1 M1 M2 M2 G3 G3
##   6 G0 G0 G1 M1 G1 G2 G3 G3
##   7 G0 G0 G0 G0 G1 G1 G2 G3
const PHASE_A_DEMO_MAP := "phase_a_fixed"
const PHASE_A_CROP_ORIGIN_ROW := 2
const PHASE_A_CROP_ORIGIN_COL := 2
const MAURO_MAP_SIZE := 12
const _TERRAIN_NAMES := ["ground", "mud", "water", "lava"]
## Mauro's 12×12, row-major tokens (terrain digit + z label).
const MAURO_12X12 := [
	"0z1 0z1 0z2 1z3 2z4 3z4 3z3 1z2 0z2 0z3 0z3 0z3",
	"0z1 0z2 0z3 0z4 1z4 3z4 3z3 1z2 0z2 0z2 0z2 0z2",
	"2z3 1z3 0z4 0z4 1z4 2z3 3z3 2z2 2z2 1z2 0z2 0z1",
	"3z4 2z4 1z4 0z4 1z3 2z3 3z3 3z2 3z2 1z1 0z1 0z1",
	"3z4 3z4 2z4 1z4 1z3 2z3 3z3 3z2 2z2 1z1 0z1 0z1",
	"3z4 2z4 2z4 2z3 2z3 2z3 2z3 2z3 1z2 0z2 0z2 0z1",
	"2z3 2z3 2z2 2z2 2z3 2z3 2z3 1z3 1z3 0z3 0z3 0z3",
	"1z2 1z2 1z2 1z2 1z2 1z2 1z3 1z3 0z4 0z4 1z4 1z4",
	"1z1 1z1 0z1 0z1 0z2 1z2 0z2 0z3 0z4 0z4 1z4 2z4",
	"1z1 1z1 0z1 0z1 0z1 0z1 0z2 0z2 0z3 0z4 1z4 2z4",
	"2z1 1z1 0z1 0z1 0z1 0z1 0z1 0z2 0z2 0z4 1z4 1z4",
	"3z1 2z1 0z1 0z1 0z1 0z1 0z1 0z1 0z2 0z4 0z4 0z4",
]

var phase: int = Phase.DEPLOYMENT
var board_size: int = BOARD_SIZE
## Last seat that placed or readied. Not a turn gate during deploy.
var last_seat: int = SEAT_0
var ready: Dictionary = {}
var placed: Dictionary = {}
var locked: Dictionary = {}
var zones: Dictionary = {}
var zone_distance: int = 0
var zone_seed: int = 0
var zone_preferred: bool = false


func _init() -> void:
	reset()


func reset(seed: int = 0, config: Dictionary = {}) -> void:
	phase = Phase.DEPLOYMENT
	board_size = int(config.get("board_size", BOARD_SIZE))
	last_seat = SEAT_0
	ready = {SEAT_0: false, SEAT_1: false}
	placed = {SEAT_0: false, SEAT_1: false}
	locked = {SEAT_0: false, SEAT_1: false}
	zone_seed = seed
	zone_distance = 0
	zone_preferred = false
	zones = {SEAT_0: [] as Array[Vector2i], SEAT_1: [] as Array[Vector2i]}
	if config.has("deploy_zones"):
		_apply_config_zones(config["deploy_zones"])
	else:
		var sampled: Dictionary = sample_zone_pair(seed, board_size)
		_set_zone(SEAT_0, sampled["zones"][0])
		_set_zone(SEAT_1, sampled["zones"][1])
		zone_distance = int(sampled.get("distance", 0))
		zone_preferred = bool(sampled.get("preferred", false))


func phase_name() -> String:
	if phase == Phase.TURN_1:
		return "TURN_1"
	return "DEPLOYMENT"


func is_deployment() -> bool:
	return phase == Phase.DEPLOYMENT


func is_combat() -> bool:
	return phase == Phase.TURN_1


func combat_enabled() -> bool:
	return phase == Phase.TURN_1


func is_ready(seat: int) -> bool:
	return bool(ready.get(seat, false))


func is_placed(seat: int) -> bool:
	return bool(placed.get(seat, false))


func is_locked(seat: int) -> bool:
	return bool(locked.get(seat, false))


func both_ready() -> bool:
	return bool(ready.get(SEAT_0, false)) and bool(ready.get(SEAT_1, false))


func mark_placed(seat: int) -> void:
	placed[seat] = true
	last_seat = seat


func can_ready(seat: int) -> bool:
	if phase != Phase.DEPLOYMENT:
		return false
	if bool(ready.get(seat, false)):
		return false
	return bool(placed.get(seat, false))


func mark_ready(seat: int) -> Dictionary:
	if phase != Phase.DEPLOYMENT:
		return _fail("wrong_phase")
	if bool(ready.get(seat, false)):
		return _fail("already_ready")
	if not bool(placed.get(seat, false)):
		return _fail("units_not_placed")
	ready[seat] = true
	locked[seat] = true
	last_seat = seat
	if both_ready():
		begin_turn_1()
	return {"ok": true, "reason": "", "seat": seat, "both_ready": both_ready()}


func begin_turn_1() -> void:
	phase = Phase.TURN_1
	locked[SEAT_0] = true
	locked[SEAT_1] = true
	last_seat = SEAT_0


func skip_to_combat() -> void:
	placed[SEAT_0] = true
	placed[SEAT_1] = true
	ready[SEAT_0] = true
	ready[SEAT_1] = true
	begin_turn_1()


## Gate: phase, zone membership, in-bounds, not occupied. Simultaneous: no turn gate.
func place_gate(seat: int, cell: Vector2i, occupant_seat: int = -1) -> Dictionary:
	if phase != Phase.DEPLOYMENT:
		return _fail("wrong_phase")
	if bool(ready.get(seat, false)) or bool(locked.get(seat, false)):
		return _fail("side_locked")
	if not in_bounds(cell):
		return _fail("out_of_bounds")
	if not is_in_zone(seat, cell):
		var out := _fail("outside_zone")
		out["zone_kind"] = zone_kind(seat, cell)
		return out
	if occupant_seat >= 0 and occupant_seat != seat:
		return _fail("occupied")
	return {"ok": true, "reason": "", "zone_kind": ""}


func zone_kind(seat: int, cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "out_of_bounds"
	if is_in_zone(seat, cell):
		return ""
	var other := SEAT_1 if seat == SEAT_0 else SEAT_0
	if is_in_zone(other, cell):
		return "wrong_zone"
	return "outside"


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


func is_in_zone(seat: int, cell: Vector2i) -> bool:
	for owned: Vector2i in zone_cells(seat):
		if owned == cell:
			return true
	return false


func zone_cells(seat: int) -> Array[Vector2i]:
	var raw: Variant = zones.get(seat, [])
	var out: Array[Vector2i] = []
	for cell in raw:
		out.append(cell as Vector2i)
	return out


## Director-stamped Locked 8×8 crop. Applies all 64 cells onto a WalkBoard.
static func seed_phase_a_demo(board) -> void:
	for row in phase_a_demo_tiles():
		board.set_tile(row["pos"], row["terrain"], int(row["elevation"]))


## PHASE_A_DEMO_TILES — 64-cell Locked crop at origin (row 2, col 2).
static func phase_a_demo_tiles() -> Array:
	var out := []
	var grid: Array = parse_mauro_12x12()
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var src: Dictionary = grid[PHASE_A_CROP_ORIGIN_ROW + y][PHASE_A_CROP_ORIGIN_COL + x]
			out.append({
				"pos": Vector2i(x, y),
				"terrain": src["terrain"],
				"elevation": int(src["elevation"]),
			})
	return out


static func parse_mauro_12x12() -> Array:
	var grid := []
	for line in MAURO_12X12:
		var row := []
		for token in str(line).split(" ", false):
			row.append(parse_mauro_token(token))
		grid.append(row)
	return grid


static func parse_mauro_token(token: String) -> Dictionary:
	var raw := token.strip_edges()
	var terrain_idx := 0
	var z_label := 1
	if raw.length() >= 1:
		terrain_idx = clampi(int(raw.substr(0, 1)), 0, 3)
	var z_at := raw.find("z")
	if z_at >= 0 and z_at + 1 < raw.length():
		z_label = clampi(int(raw.substr(z_at + 1)), 1, 4)
	return {
		"terrain": str(_TERRAIN_NAMES[terrain_idx]),
		"elevation": z_label - 1,
	}


static func phase_a_crop_has_terrain(name: String) -> bool:
	for row in phase_a_demo_tiles():
		if str(row.get("terrain", "")) == name:
			return true
	return false


static func phase_a_crop_elevations() -> Array:
	var seen := {}
	for row in phase_a_demo_tiles():
		seen[int(row.get("elevation", 0))] = true
	var out := []
	for z in seen.keys():
		out.append(int(z))
	out.sort()
	return out


func legal_place_cells(seat: int, occupant_at: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if phase != Phase.DEPLOYMENT:
		return out
	if bool(ready.get(seat, false)) or bool(locked.get(seat, false)):
		return out
	for cell in zone_cells(seat):
		var occupant := -1
		if occupant_at.is_valid():
			occupant = int(occupant_at.call(cell))
		if bool(place_gate(seat, cell, occupant).get("ok", false)):
			out.append(cell)
	return out


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"phase_name": phase_name(),
		"ready": ready.duplicate(true),
		"both_ready": both_ready(),
		"simultaneous": true,
		"zone_split": "seeded_random_blobs",
		"legal_cells": "sampled_blob_6",
		"deploy_zone_gen": "proposed_random_blobs",
		"deploy_blob_size": BLOB_SIZE,
		"deploy_min_chebyshev": MIN_ZONE_CHEBYSHEV,
		"deploy_zone_distance": zone_distance,
		"deploy_zone_preferred": zone_preferred,
		"deploy_zone_seed": zone_seed,
		"combat_enabled": combat_enabled(),
		"walk_enabled": combat_enabled(),
		"end_turn_enabled": combat_enabled(),
		"positions_locked": phase == Phase.TURN_1,
		"networking": false,
		"deploy": "locked",
		"open_deploy": ["fog", "hidden_enemy", "deploy_timer", "multi_unit"],
		"last_seat": last_seat,
	}


## Seed-based pair of ~6-cell blobs. Prefers opening Chebyshev 4–6; accepts 3+.
static func sample_zone_pair(seed: int, board_size: int = BOARD_SIZE) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var acceptable: Dictionary = {}
	for _i in range(320):
		var blob_a: Array[Vector2i] = _generate_blob(rng, board_size)
		var blob_b: Array[Vector2i] = _generate_blob(rng, board_size)
		var reason := pair_reject_reason(blob_a, blob_b, board_size)
		if reason != "":
			continue
		var distance := min_chebyshev_between(blob_a, blob_b)
		var candidate := {
			"ok": true,
			"reason": "",
			"zones": {0: blob_a, 1: blob_b},
			"distance": distance,
			"preferred": distance >= PREFERRED_ZONE_CHEBYSHEV_MIN and distance <= PREFERRED_ZONE_CHEBYSHEV_MAX,
			"fallback": false,
		}
		if bool(candidate["preferred"]):
			return candidate
		if acceptable.is_empty():
			acceptable = candidate
	if not acceptable.is_empty():
		return acceptable
	var fallback_a: Array[Vector2i] = _rect_blob(Vector2i(0, 2), 2, 3)
	var fallback_b: Array[Vector2i] = _rect_blob(Vector2i(6, 2), 2, 3)
	return {
		"ok": true,
		"reason": "",
		"zones": {0: fallback_a, 1: fallback_b},
		"distance": min_chebyshev_between(fallback_a, fallback_b),
		"preferred": true,
		"fallback": true,
	}


## Reject overlapping blobs, same-edge camping, or opening Chebyshev below 3.
static func pair_reject_reason(blob_a: Array[Vector2i], blob_b: Array[Vector2i], board_size: int = BOARD_SIZE) -> String:
	if blob_a.is_empty() or blob_b.is_empty():
		return "empty"
	if blobs_overlap(blob_a, blob_b):
		return "overlap"
	if shares_hugging_edge(blob_a, blob_b, board_size):
		return "same_edge"
	if min_chebyshev_between(blob_a, blob_b) < MIN_ZONE_CHEBYSHEV:
		return "min_chebyshev"
	return ""


static func blobs_overlap(blob_a: Array[Vector2i], blob_b: Array[Vector2i]) -> bool:
	for cell_a: Vector2i in blob_a:
		for cell_b: Vector2i in blob_b:
			if cell_a == cell_b:
				return true
	return false


static func min_chebyshev_between(blob_a: Array[Vector2i], blob_b: Array[Vector2i]) -> int:
	var best := 999
	for cell_a: Vector2i in blob_a:
		for cell_b: Vector2i in blob_b:
			best = mini(best, chebyshev(cell_a, cell_b))
	return best


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func hugging_edges(cells: Array[Vector2i], board_size: int = BOARD_SIZE) -> Array[String]:
	var north := 0
	var east := 0
	var south := 0
	var west := 0
	var last := board_size - 1
	for cell: Vector2i in cells:
		if cell.y == 0:
			north += 1
		if cell.y == last:
			south += 1
		if cell.x == last:
			east += 1
		if cell.x == 0:
			west += 1
	var out: Array[String] = []
	if north >= HUG_EDGE_CELLS:
		out.append("N")
	if east >= HUG_EDGE_CELLS:
		out.append("E")
	if south >= HUG_EDGE_CELLS:
		out.append("S")
	if west >= HUG_EDGE_CELLS:
		out.append("W")
	return out


static func shares_hugging_edge(blob_a: Array[Vector2i], blob_b: Array[Vector2i], board_size: int = BOARD_SIZE) -> bool:
	var edges_a := hugging_edges(blob_a, board_size)
	var edges_b := hugging_edges(blob_b, board_size)
	for edge in edges_a:
		if edges_b.has(edge):
			return true
	return false


static func has_interior_cell(cells: Array[Vector2i], board_size: int = BOARD_SIZE) -> bool:
	for cell: Vector2i in cells:
		if not is_border_cell(cell, board_size):
			return true
	return false


static func is_contiguous_blob(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var pending: Array[Vector2i] = [cells[0]]
	var seen := {cells[0]: true}
	while not pending.is_empty():
		var cursor: Vector2i = pending.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cursor + step
			if seen.has(nxt):
				continue
			var owned := false
			for cell: Vector2i in cells:
				if cell == nxt:
					owned = true
					break
			if owned:
				seen[nxt] = true
				pending.append(nxt)
	return seen.size() == cells.size()


static func is_filled_rect(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	for cell: Vector2i in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var width := max_x - min_x + 1
	var height := max_y - min_y + 1
	if width * height != cells.size():
		return false
	return (width == 2 and height == 3) or (width == 3 and height == 2)


## 1-deep map border ring. #31 baseline reference; live zones are sampled blobs.
static func border_ring(board_size: int = BOARD_SIZE) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board_size <= 0:
		return out
	for x in range(board_size):
		out.append(Vector2i(x, 0))
		if board_size > 1:
			out.append(Vector2i(x, board_size - 1))
	for y in range(1, board_size - 1):
		out.append(Vector2i(0, y))
		if board_size > 1:
			out.append(Vector2i(board_size - 1, y))
	return out


static func is_border_cell(cell: Vector2i, board_size: int = BOARD_SIZE) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size or cell.y >= board_size:
		return false
	return cell.x == 0 or cell.y == 0 or cell.x == board_size - 1 or cell.y == board_size - 1


## Seat 0 owns south (incl. SW/SE) + west exclusive of corners. #31 reference only.
static func owns_south_west_half(cell: Vector2i, board_size: int = BOARD_SIZE) -> bool:
	if not is_border_cell(cell, board_size):
		return false
	if cell.y == board_size - 1:
		return true
	if cell.x == 0 and cell.y > 0 and cell.y < board_size - 1:
		return true
	return false


## Seat 1 owns north (incl. NW/NE) + east exclusive of corners. #31 reference only.
static func owns_north_east_half(cell: Vector2i, board_size: int = BOARD_SIZE) -> bool:
	return is_border_cell(cell, board_size) and not owns_south_west_half(cell, board_size)


static func zone_cells_for(seat: int, board_size: int = BOARD_SIZE) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in border_ring(board_size):
		if seat == SEAT_0 and owns_south_west_half(cell, board_size):
			out.append(cell)
		elif seat == SEAT_1 and owns_north_east_half(cell, board_size):
			out.append(cell)
	return out


static func _generate_blob(rng: RandomNumberGenerator, board_size: int) -> Array[Vector2i]:
	if rng.randi_range(0, 1) == 0:
		var rect: Array[Vector2i] = _random_rect_blob(rng, board_size)
		if rect.size() == BLOB_SIZE:
			return rect
	var organic: Array[Vector2i] = _grow_organic_blob(rng, board_size)
	if organic.size() == BLOB_SIZE:
		return organic
	return _random_rect_blob(rng, board_size)


static func _random_rect_blob(rng: RandomNumberGenerator, board_size: int) -> Array[Vector2i]:
	var wide := rng.randi_range(0, 1) == 0
	var width := 3 if wide else 2
	var height := 2 if wide else 3
	var max_x := board_size - width
	var max_y := board_size - height
	if max_x < 0 or max_y < 0:
		return []
	var origin := Vector2i(rng.randi_range(0, max_x), rng.randi_range(0, max_y))
	return _rect_blob(origin, width, height)


static func _rect_blob(origin: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			out.append(Vector2i(origin.x + x, origin.y + y))
	return out


static func _grow_organic_blob(rng: RandomNumberGenerator, board_size: int) -> Array[Vector2i]:
	for _attempt in range(24):
		var start := Vector2i(rng.randi_range(0, board_size - 1), rng.randi_range(0, board_size - 1))
		var cells: Array[Vector2i] = [start]
		var used := {start: true}
		while cells.size() < BLOB_SIZE:
			var frontier: Array[Vector2i] = []
			var frontier_seen := {}
			for cell: Vector2i in cells:
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nxt: Vector2i = cell + step
					if nxt.x < 0 or nxt.y < 0 or nxt.x >= board_size or nxt.y >= board_size:
						continue
					if used.has(nxt) or frontier_seen.has(nxt):
						continue
					frontier_seen[nxt] = true
					frontier.append(nxt)
			if frontier.is_empty():
				break
			var pick: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
			cells.append(pick)
			used[pick] = true
		if cells.size() == BLOB_SIZE and is_contiguous_blob(cells):
			return cells
	return []


func _apply_config_zones(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		_apply_fallback_zones()
		return
	var dict: Dictionary = raw
	var blob_a: Array[Vector2i] = _cells_from_config(dict.get(0, dict.get("0", [])))
	var blob_b: Array[Vector2i] = _cells_from_config(dict.get(1, dict.get("1", [])))
	if pair_reject_reason(blob_a, blob_b, board_size) != "":
		_apply_fallback_zones()
		return
	_set_zone(SEAT_0, blob_a)
	_set_zone(SEAT_1, blob_b)
	zone_distance = min_chebyshev_between(blob_a, blob_b)
	zone_preferred = zone_distance >= PREFERRED_ZONE_CHEBYSHEV_MIN and zone_distance <= PREFERRED_ZONE_CHEBYSHEV_MAX


func _apply_fallback_zones() -> void:
	var fallback_a: Array[Vector2i] = _rect_blob(Vector2i(0, 2), 2, 3)
	var fallback_b: Array[Vector2i] = _rect_blob(Vector2i(6, 2), 2, 3)
	_set_zone(SEAT_0, fallback_a)
	_set_zone(SEAT_1, fallback_b)
	zone_distance = min_chebyshev_between(fallback_a, fallback_b)
	zone_preferred = true


func _set_zone(seat: int, cells: Array[Vector2i]) -> void:
	var copy: Array[Vector2i] = []
	for cell: Vector2i in cells:
		copy.append(cell)
	zones[seat] = copy


func _cells_from_config(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in raw:
		if item is Vector2i:
			out.append(item)
		elif typeof(item) == TYPE_ARRAY and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
		elif typeof(item) == TYPE_DICTIONARY:
			out.append(Vector2i(int(item.get("x", 0)), int(item.get("y", 0))))
	return out


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
