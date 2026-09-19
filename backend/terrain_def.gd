extends RefCounted

## Live terrain table. Ported from proto/elevation/terrain_def.gd (reference).
## Locked: Ground 1, Mud 2, Water 2, Lava impassable.

enum Id { GROUND, MUD, WATER, LAVA }

const NAMES := {
	Id.GROUND: "ground",
	Id.MUD: "mud",
	Id.WATER: "water",
	Id.LAVA: "lava",
}

const DISPLAY := {
	Id.GROUND: "Ground",
	Id.MUD: "Mud",
	Id.WATER: "Water",
	Id.LAVA: "Lava",
}


static func catalog() -> Dictionary:
	return {
		Id.GROUND: make(Id.GROUND, 1, true),
		Id.MUD: make(Id.MUD, 2, true),
		Id.WATER: make(Id.WATER, 2, true),
		Id.LAVA: make(Id.LAVA, 0, false),
	}


static func make(terrain_id: int, mp: int, can_walk: bool) -> Dictionary:
	return {
		"id": terrain_id,
		"name": str(NAMES.get(terrain_id, "ground")),
		"display_name": str(DISPLAY.get(terrain_id, "Ground")),
		"base_mp": mp,
		"walkable": can_walk,
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
		_:
			return Id.GROUND
