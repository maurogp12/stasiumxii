class_name SnapshotTiles
extends RefCounted

## Live-board chrome adapter. Reads expected CombatSim snapshot tile fields.
## Does not invent walk costs, climb gates, hit bands, facing, or LoS.
## Walk highlights must come from CombatSim.legal_intents only.

const DEFAULT_TERRAIN := "ground"
const TERRAIN_IDS := ["ground", "mud", "water", "lava"]


static func default_cell() -> Dictionary:
	return {
		"elevation": 0,
		"terrain_type": DEFAULT_TERRAIN,
	}


static func from_snapshot(snap: Dictionary, board_size: int = 8) -> Dictionary:
	var out := {}
	for y in range(board_size):
		for x in range(board_size):
			out[Vector2i(x, y)] = default_cell()
	_merge_tile_records(out, _tile_payload(snap), board_size)
	_merge_parallel_maps(out, snap, board_size)
	_merge_named_cell_lists(out, snap)
	return out


static func cell_record(snap: Dictionary, cell: Vector2i, board_size: int = 8) -> Dictionary:
	var tiles: Dictionary = from_snapshot(snap, board_size)
	if tiles.has(cell):
		return tiles[cell]
	return default_cell()


static func elevation_at(snap: Dictionary, cell: Vector2i, board_size: int = 8) -> int:
	return normalize_elevation(cell_record(snap, cell, board_size).get("elevation", 0))


static func terrain_at(snap: Dictionary, cell: Vector2i, board_size: int = 8) -> String:
	return normalize_terrain(cell_record(snap, cell, board_size).get("terrain_type", DEFAULT_TERRAIN))


static func has_board_data(snap: Dictionary) -> bool:
	if snap.is_empty():
		return false
	for key in ["tiles", "board_tiles", "map_tiles", "terrain", "terrain_type", "elevation"]:
		if snap.has(key):
			return true
	var board: Variant = snap.get("board", {})
	if typeof(board) == TYPE_DICTIONARY:
		for key in ["tiles", "terrain", "terrain_type", "elevation"]:
			if board.has(key):
				return true
	return false


## Sim-legal walk dests only. Chrome must not invent climb costs or client reachability.
static func walk_dests(legal: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for intent in legal:
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) != "move":
			continue
		if not intent.has("to"):
			continue
		var cell := _as_cell(intent["to"])
		if not out.has(cell):
			out.append(cell)
	return out


static func normalize_terrain(value: Variant) -> String:
	if value == null:
		return DEFAULT_TERRAIN
	if value is String or value is StringName:
		var raw := str(value).strip_edges().to_lower()
		match raw:
			"ground", "g", "grass", "dirt", "0":
				return "ground"
			"mud", "m", "1":
				return "mud"
			"water", "w", "2":
				return "water"
			"lava", "l", "3":
				return "lava"
		if raw.begins_with("terraindef.id."):
			return normalize_terrain(raw.substr(raw.rfind(".") + 1))
		return DEFAULT_TERRAIN
	if value is int or value is float:
		var idx := int(value)
		if idx >= 0 and idx < TERRAIN_IDS.size():
			return TERRAIN_IDS[idx]
	return DEFAULT_TERRAIN


static func normalize_elevation(value: Variant) -> int:
	if value == null:
		return 0
	if value is String or value is StringName:
		return int(round(float(str(value))))
	return int(round(float(value)))


static func _tile_payload(snap: Dictionary) -> Variant:
	if snap.has("tiles"):
		return snap["tiles"]
	if snap.has("board_tiles"):
		return snap["board_tiles"]
	if snap.has("map_tiles"):
		return snap["map_tiles"]
	var board: Variant = snap.get("board", {})
	if typeof(board) == TYPE_DICTIONARY:
		if board.has("tiles"):
			return board["tiles"]
		if board.has("board_tiles"):
			return board["board_tiles"]
	return null


static func _merge_tile_records(out: Dictionary, payload: Variant, board_size: int) -> void:
	if payload == null:
		return
	if payload is Array:
		for item in payload:
			_apply_record(out, item, Vector2i(-1, -1), board_size)
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	for key in payload.keys():
		var cell := _key_to_cell(key)
		_apply_record(out, payload[key], cell, board_size)


static func _merge_parallel_maps(out: Dictionary, snap: Dictionary, board_size: int) -> void:
	var board: Dictionary = snap.get("board", {}) if typeof(snap.get("board", {})) == TYPE_DICTIONARY else {}
	_merge_grid_map(out, snap.get("elevation", board.get("elevation", null)), "elevation", board_size)
	_merge_grid_map(out, snap.get("terrain_type", board.get("terrain_type", snap.get("terrain", board.get("terrain", null)))), "terrain_type", board_size)


static func _merge_grid_map(out: Dictionary, payload: Variant, field: String, board_size: int) -> void:
	if payload == null:
		return
	if payload is Array:
		for y in range(mini(payload.size(), board_size)):
			var row: Variant = payload[y]
			if row is Array:
				for x in range(mini(row.size(), board_size)):
					_write_field(out, Vector2i(x, y), field, row[x])
			else:
				# Flat row-major board_size*board_size, or a list of cell records.
				if typeof(row) == TYPE_DICTIONARY and (_record_cell(row).x >= 0 or row.has("elevation") or row.has("terrain_type") or row.has("terrain")):
					_apply_record(out, row, Vector2i(-1, -1), board_size)
				elif y < board_size:
					_write_field(out, Vector2i(y % board_size, int(y / board_size)), field, row)
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	for key in payload.keys():
		var cell := _key_to_cell(key)
		if cell.x < 0:
			continue
		_write_field(out, cell, field, payload[key])


static func _merge_named_cell_lists(out: Dictionary, snap: Dictionary) -> void:
	# Convenience: { "mud": [Vector2i,...], "water": [...], "lava": [...] }
	for terrain_id in ["mud", "water", "lava", "ground"]:
		if not snap.has(terrain_id):
			continue
		var cells: Variant = snap[terrain_id]
		if typeof(cells) != TYPE_ARRAY:
			continue
		for item in cells:
			var cell := _as_cell(item)
			if not out.has(cell):
				continue
			out[cell]["terrain_type"] = terrain_id


static func _apply_record(out: Dictionary, raw: Variant, hinted: Vector2i, board_size: int) -> void:
	var rec := _normalize_record(raw)
	var cell := hinted
	if cell.x < 0:
		cell = rec["pos"]
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size or cell.y >= board_size:
		return
	if not out.has(cell):
		out[cell] = default_cell()
	if rec.has("elevation"):
		out[cell]["elevation"] = rec["elevation"]
	if rec.has("terrain_type"):
		out[cell]["terrain_type"] = rec["terrain_type"]


static func _normalize_record(raw: Variant) -> Dictionary:
	var rec := {
		"pos": Vector2i(-1, -1),
	}
	if raw == null:
		return rec
	if raw is String or raw is StringName or raw is int or raw is float:
		rec["terrain_type"] = normalize_terrain(raw)
		return rec
	if typeof(raw) != TYPE_DICTIONARY:
		return rec
	var data: Dictionary = raw
	rec["pos"] = _record_cell(data)
	if data.has("elevation") or data.has("height") or data.has("elev"):
		rec["elevation"] = normalize_elevation(data.get("elevation", data.get("height", data.get("elev", 0.0))))
	if data.has("terrain_type") or data.has("terrain") or data.has("type") or data.has("tile"):
		rec["terrain_type"] = normalize_terrain(data.get("terrain_type", data.get("terrain", data.get("type", data.get("tile", DEFAULT_TERRAIN)))))
	return rec


static func _record_cell(data: Dictionary) -> Vector2i:
	if data.has("pos"):
		return _as_cell(data["pos"])
	if data.has("cell"):
		return _as_cell(data["cell"])
	if data.has("grid_pos"):
		return _as_cell(data["grid_pos"])
	if data.has("x") or data.has("y"):
		return Vector2i(int(data.get("x", -1)), int(data.get("y", -1)))
	return Vector2i(-1, -1)


static func _write_field(out: Dictionary, cell: Vector2i, field: String, value: Variant) -> void:
	if not out.has(cell):
		return
	if field == "elevation":
		out[cell]["elevation"] = normalize_elevation(value)
	elif field == "terrain_type":
		out[cell]["terrain_type"] = normalize_terrain(value)


static func _key_to_cell(key: Variant) -> Vector2i:
	if key is Vector2i or key is Vector2:
		return _as_cell(key)
	if key is String or key is StringName:
		var text := str(key).strip_edges()
		text = text.replace("(", "").replace(")", "").replace(" ", "")
		var sep := "," if text.contains(",") else ("_" if text.contains("_") else ":")
		var parts := text.split(sep)
		if parts.size() >= 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	if key is Array and key.size() >= 2:
		return Vector2i(int(key[0]), int(key[1]))
	return Vector2i(-1, -1)


static func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is String or value is StringName:
		return _key_to_cell(value)
	return Vector2i.ZERO
