extends RefCounted
class_name MovementCost

## Proposed (not Locked) single-step MP for Phase B+.
## calculate(from_tile, to_tile) → {ok, total_mp, terrain_mp, elev_mp, reason}
## Not called by CombatSim.submit(move).

const REASON_OK := ""
const REASON_MISSING := "missing_tile"
const REASON_SAME := "same_tile"
const REASON_IMPASSABLE := "impassable"
const REASON_CLIMB := "climb_exceeded"
const REASON_DROP := "drop_exceeded"


static func calculate(from_tile: ProtoBoardTile, to_tile: ProtoBoardTile) -> Dictionary:
	if from_tile == null or to_tile == null:
		return _result(false, 0, 0, 0, REASON_MISSING)
	if from_tile.grid_pos == to_tile.grid_pos:
		return _result(false, 0, 0, 0, REASON_SAME)

	## Proposed: entering dest costs dest.base_move_cost (Ground 1, Mud 2, Water 2).
	var terrain_mp := int(to_tile.base_move_cost)
	var elev_mp := ElevationRules.elevation_mp(from_tile.elevation, to_tile.elevation)

	if not to_tile.walkable or to_tile.terrain_type == TerrainDef.Kind.LAVA:
		return _result(false, terrain_mp + elev_mp, terrain_mp, elev_mp, REASON_IMPASSABLE)

	var elev_reason := ElevationRules.climb_or_drop_reason(from_tile.elevation, to_tile.elevation)
	if elev_reason != "":
		return _result(false, terrain_mp + elev_mp, terrain_mp, elev_mp, elev_reason)

	return _result(true, terrain_mp + elev_mp, terrain_mp, elev_mp, REASON_OK)


static func _result(ok: bool, total_mp: int, terrain_mp: int, elev_mp: int, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"total_mp": total_mp,
		"terrain_mp": terrain_mp,
		"elev_mp": elev_mp,
		"reason": reason,
	}
