extends RefCounted
class_name TerrainCatalog

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
##
## Proposed (Director starters):
##   Ground 1 MP, Mud 2, Water 2, Lava impassable.

enum Type {
	GROUND,
	MUD,
	WATER,
	LAVA,
}

## Proposed terrain table. Costs are paid when entering the dest tile.
const TABLE := {
	Type.GROUND: {"display_name": "Ground", "base_move_cost": 1, "walkable": true},
	Type.MUD: {"display_name": "Mud", "base_move_cost": 2, "walkable": true},
	Type.WATER: {"display_name": "Water", "base_move_cost": 2, "walkable": true},
	Type.LAVA: {"display_name": "Lava", "base_move_cost": 0, "walkable": false},
}


static func def(terrain_type: Type) -> TerrainDef:
	var row: Dictionary = TABLE.get(terrain_type, TABLE[Type.GROUND])
	var out := TerrainDef.new()
	out.terrain_type = terrain_type
	out.display_name = str(row["display_name"])
	out.base_move_cost = int(row["base_move_cost"])
	out.walkable = bool(row["walkable"])
	return out


static func display_name(terrain_type: Type) -> String:
	return str(TABLE[terrain_type]["display_name"])


static func base_move_cost(terrain_type: Type) -> int:
	return int(TABLE[terrain_type]["base_move_cost"])


static func is_walkable(terrain_type: Type) -> bool:
	return bool(TABLE[terrain_type]["walkable"])
