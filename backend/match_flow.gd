class_name MatchFlow
extends RefCounted

## Locked Phase A match flow. Owned by CombatSim.
## Simultaneous local both-ready deploy, then Turn 1 combat.
## Copy of proto/deployment zone math (studio #27/#29). Proto stays reference.
## Networking OFF. No fog. No deploy timer. One fighter per seat.

enum Phase {
	DEPLOYMENT,
	TURN_1,
}

const BOARD_SIZE := 8
const SEAT_0 := 0
const SEAT_1 := 1

var phase: int = Phase.DEPLOYMENT
var board_size: int = BOARD_SIZE
## Last seat that placed or readied. Not a turn gate during deploy.
var last_seat: int = SEAT_0
var ready: Dictionary = {}
var placed: Dictionary = {}
var locked: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	phase = Phase.DEPLOYMENT
	board_size = BOARD_SIZE
	last_seat = SEAT_0
	ready = {SEAT_0: false, SEAT_1: false}
	placed = {SEAT_0: false, SEAT_1: false}
	locked = {SEAT_0: false, SEAT_1: false}


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
	if not is_border_cell(cell, board_size):
		return "interior"
	if not is_in_zone(seat, cell):
		return "wrong_half"
	return ""


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


func is_in_zone(seat: int, cell: Vector2i) -> bool:
	if seat == SEAT_0:
		return owns_south_west_half(cell, board_size)
	if seat == SEAT_1:
		return owns_north_east_half(cell, board_size)
	return false


func zone_cells(seat: int) -> Array[Vector2i]:
	return zone_cells_for(seat, board_size)


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
		"zone_split": "p1_south_west_p2_north_east",
		"legal_cells": "border_ring_1_deep",
		"combat_enabled": combat_enabled(),
		"walk_enabled": combat_enabled(),
		"end_turn_enabled": combat_enabled(),
		"positions_locked": phase == Phase.TURN_1,
		"networking": false,
		"deploy": "locked",
		"open_deploy": ["fog", "hidden_enemy", "deploy_timer", "multi_unit"],
		"last_seat": last_seat,
	}


## 1-deep map border ring: every outer-edge cell of an N×N board.
## Copied from proto DeploymentZone (studio #27).
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


## Seat 0 owns south (incl. SW/SE) + west exclusive of corners.
static func owns_south_west_half(cell: Vector2i, board_size: int = BOARD_SIZE) -> bool:
	if not is_border_cell(cell, board_size):
		return false
	if cell.y == board_size - 1:
		return true
	if cell.x == 0 and cell.y > 0 and cell.y < board_size - 1:
		return true
	return false


## Seat 1 owns north (incl. NW/NE) + east exclusive of corners.
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


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
