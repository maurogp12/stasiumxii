extends RefCounted
class_name ProtoBoard

## Proposed sample boards for the Phase B+ prototype. Not the live 8×8 duel.

static func mud_detour_board() -> Dictionary:
	## Short row is muddy; the long ortho wrap is cheaper Ground.
	## Start (0,0) → dest (4,0): mud corridor 7 MP, ground wrap 6 MP.
	var tiles := {}
	_put(tiles, 0, 0, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 1, 0, TerrainDef.Kind.MUD, 0.0)
	_put(tiles, 2, 0, TerrainDef.Kind.MUD, 0.0)
	_put(tiles, 3, 0, TerrainDef.Kind.MUD, 0.0)
	_put(tiles, 4, 0, TerrainDef.Kind.GROUND, 0.0)
	for x in range(5):
		_put(tiles, x, 1, TerrainDef.Kind.GROUND, 0.0)
	return tiles


static func demo_board() -> Dictionary:
	## Visual playground: mud corridor, lava, water, half / full / cliff.
	var tiles := mud_detour_board()
	_put(tiles, 5, 0, TerrainDef.Kind.GROUND, 1.0)
	_put(tiles, 6, 0, TerrainDef.Kind.GROUND, 1.0)
	for x in range(5):
		_put(tiles, x, 1, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 5, 1, TerrainDef.Kind.GROUND, 0.5)
	_put(tiles, 6, 1, TerrainDef.Kind.GROUND, 1.0)
	_put(tiles, 0, 2, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 1, 2, TerrainDef.Kind.LAVA, 0.0)
	_put(tiles, 2, 2, TerrainDef.Kind.GROUND, 2.0)
	_put(tiles, 3, 2, TerrainDef.Kind.WATER, 0.0)
	_put(tiles, 4, 2, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 5, 2, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 6, 2, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 0, 3, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 1, 3, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 2, 3, TerrainDef.Kind.GROUND, 1.0)
	_put(tiles, 3, 3, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 4, 3, TerrainDef.Kind.GROUND, 0.5)
	_put(tiles, 5, 3, TerrainDef.Kind.GROUND, 0.0)
	_put(tiles, 6, 3, TerrainDef.Kind.GROUND, 0.0)
	for x in range(7):
		_put(tiles, x, 4, TerrainDef.Kind.GROUND, 0.0)
	return tiles


static func _put(tiles: Dictionary, x: int, y: int, kind_id: TerrainDef.Kind, elevation: float) -> void:
	var pos := Vector2i(x, y)
	tiles[pos] = ProtoBoardTile.proposed(pos, kind_id, elevation)
