extends Resource
class_name TerrainDef

## Proposed (not Locked). Phase B+ prototype only.
## Do not wire these costs into CombatSim.submit(move). Phase A walk stays
## Locked Manhattan dest-click on a flat board.

enum Kind {
	GROUND,
	MUD,
	WATER,
	LAVA,
}

## Proposed display names. Not Locked.
const KIND_NAMES := {
	Kind.GROUND: "Ground",
	Kind.MUD: "Mud",
	Kind.WATER: "Water",
	Kind.LAVA: "Lava",
}

## Proposed MP to enter the tile. Lava is impassable (walkable=false);
## its base_move_cost is unused by MovementCost when rejected.
const PROPOSED_BASE_MP := {
	Kind.GROUND: 1,
	Kind.MUD: 2,
	Kind.WATER: 2,
	Kind.LAVA: 0,
}

## Proposed walkability. Lava is the only impassable starter.
const PROPOSED_WALKABLE := {
	Kind.GROUND: true,
	Kind.MUD: true,
	Kind.WATER: true,
	Kind.LAVA: false,
}

@export var kind: Kind = Kind.GROUND
@export var display_name: String = "Ground"
## Proposed base MP charged when entering a tile of this type.
@export var base_move_cost: int = 1
@export var walkable: bool = true


static func proposed(kind_id: Kind) -> TerrainDef:
	var def := TerrainDef.new()
	def.kind = kind_id
	def.display_name = str(KIND_NAMES.get(kind_id, "Unknown"))
	def.base_move_cost = int(PROPOSED_BASE_MP.get(kind_id, 1))
	def.walkable = bool(PROPOSED_WALKABLE.get(kind_id, true))
	return def


func is_impassable() -> bool:
	return not walkable or kind == Kind.LAVA
