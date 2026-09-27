extends RefCounted

## Live terrain table. Ported from proto/elevation/terrain_def.gd (reference).
## Locked MP stamps: Ground 1, Mud 2, Water 2, Lava 0.
## Soft Lock: mud, water, and lava are voluntary impassable. Walk, path nodes,
## and Advance landings refuse them. A forced push may still land. Castigo is
## per terrain (lava Burn, water Silence, mud Slow) and lives in CombatSim.
## Mud and water stay walkable for deploy and for a body already standing there.
## Void is not a Locked MP terrain. It is a hole: not standable, so a gap
## cannot be stored as Ground. Void is not this voluntary-impassable flag.

enum Id { GROUND, MUD, WATER, LAVA, VOID }

const NAMES := {
	Id.GROUND: "ground",
	Id.MUD: "mud",
	Id.WATER: "water",
	Id.LAVA: "lava",
	Id.VOID: "void",
}

const DISPLAY := {
	Id.GROUND: "Ground",
	Id.MUD: "Mud",
	Id.WATER: "Water",
	Id.LAVA: "Lava",
	Id.VOID: "Void",
}


static func catalog() -> Dictionary:
	return {
		Id.GROUND: make(Id.GROUND, 1, true, false),
		Id.MUD: make(Id.MUD, 2, true, true),
		Id.WATER: make(Id.WATER, 2, true, true),
		Id.LAVA: make(Id.LAVA, 0, false, true),
		Id.VOID: make(Id.VOID, 0, false, false),
	}


static func make(terrain_id: int, mp: int, can_walk: bool, voluntary_impassable: bool = false) -> Dictionary:
	return {
		"id": terrain_id,
		"name": str(NAMES.get(terrain_id, "ground")),
		"display_name": str(DISPLAY.get(terrain_id, "Ground")),
		"base_mp": mp,
		"walkable": can_walk,
		"voluntary_impassable": voluntary_impassable,
	}


static func by_id(terrain_id: int) -> Dictionary:
	var table := catalog()
	if table.has(terrain_id):
		return table[terrain_id]
	return table[Id.GROUND]


static func name_of(terrain_id: int) -> String:
	return str(NAMES.get(terrain_id, "ground"))


static func parse(value: Variant) -> int:
	if value is int:
		return int(value)
	var key := str(value).strip_edges().to_lower()
	match key:
		"ground", "0":
			return Id.GROUND
		"mud", "1":
			return Id.MUD
		"water", "2":
			return Id.WATER
		"lava", "3":
			return Id.LAVA
		"void", "4":
			return Id.VOID
		_:
			return Id.GROUND
