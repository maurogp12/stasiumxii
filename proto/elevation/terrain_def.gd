class_name TerrainDef
extends Resource

## Phase B+ prototype terrain table.
## Proposed (not Locked) — director starters only. Do not treat as GDD Locked.

enum Id { GROUND, MUD, WATER, LAVA }

@export var id: Id = Id.GROUND
@export var display_name: String = "Ground"
@export var base_mp: int = 1
@export var walkable: bool = true


static func catalog() -> Dictionary:
	# Proposed terrain MP: Ground 1, Mud 2, Water 2, Lava impassable.
	var out := {}
	out[Id.GROUND] = make(Id.GROUND, "Ground", 1, true)
	out[Id.MUD] = make(Id.MUD, "Mud", 2, true)
	out[Id.WATER] = make(Id.WATER, "Water", 2, true)
	out[Id.LAVA] = make(Id.LAVA, "Lava", 0, false)
	return out


static func make(terrain_id: Id, terrain_name: String, mp: int, can_walk: bool) -> TerrainDef:
	var def := TerrainDef.new()
	def.id = terrain_id
	def.display_name = terrain_name
	def.base_mp = mp
	def.walkable = can_walk
	return def


static func by_id(terrain_id: Id) -> TerrainDef:
	return catalog()[terrain_id]
