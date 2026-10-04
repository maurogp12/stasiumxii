extends RefCounted
class_name PcCharacters

## PC-only character sets. A class switches over when
## `res://art/pc/characters/<class>/<class>.json` and every frame it names
## are on disk. Gloam, Bastion and Mender stay on the shipped sprites until
## their json and art land here.
##
## Art facings follow the locked rule (S front down-right, W front down-left,
## N back up-left, E back up-right). Combat code letters are the old handoff
## (`units/pawn.gd` FACING_ISO). The json remaps once at load:
## code e ← art S, s ← art W, n ← art E, w ← art N.
## All four baked files are used. Nothing sets flip_h.
##
## Frames stay individual textures (linear, no mipmaps, fix-alpha-border).
## An atlas pack of these frames would need 2 px of padding. These files are
## not packed, because a pad cannot repair paint already cut at the cell edge.

const ROOT := "res://art/pc/characters/"
const CODE_LETTERS: Array[String] = ["n", "e", "s", "w"]

static var _sets: Dictionary = {}
static var _frames: Dictionary = {}
static var _textures: Dictionary = {}


static func clear_cache() -> void:
	_sets.clear()
	_frames.clear()
	_textures.clear()


## True when this class has a json and every frame the json names.
## Does not look at the phone/PC switch. Callers that draw use uses_body().
static func has_set(class_id: String) -> bool:
	return not _record(class_id).is_empty()


## The PC body. The phone path never takes it, even when the files exist.
static func uses_body(class_id: String) -> bool:
	return CombatHUD.uses_pc_chrome() and has_set(class_id)


static func art_facing(class_id: String, code_facing: String) -> String:
	var rec := _record(class_id)
	var letter := code_facing.strip_edges().to_lower()
	if letter.length() > 1:
		letter = letter.substr(0, 1)
	var mapping: Dictionary = rec.get("remap", {})
	return str(mapping.get(letter, "S"))


static func combat_scale(class_id: String) -> float:
	return float(_record(class_id).get("combat_scale", 0.5))


static func world_scale(class_id: String) -> float:
	return float(_record(class_id).get("world_scale", combat_scale(class_id) * 0.92))


static func head_hp_y(class_id: String) -> float:
	return float(_record(class_id).get("head_hp_y", -76.0))


static func offset_for(class_id: String, code_facing: String, state: String) -> Vector2:
	var piv: Array = _facing_row(class_id, code_facing, state).get("offset", [-0, -0])
	if piv.size() < 2:
		return Vector2.ZERO
	return Vector2(int(piv[0]), int(piv[1]))


static func travel_cell_px(class_id: String, code_facing: String) -> float:
	var rec := _record(class_id)
	var art := art_facing(class_id, code_facing)
	var row: Dictionary = rec.get("travel", {})
	return float(row.get(art, 0.0))


## Board pixels of one walk frame at this class's draw_scale.
static func board_px_per_frame(class_id: String, code_facing: String) -> float:
	var rec := _record(class_id)
	var art := art_facing(class_id, code_facing)
	var row: Dictionary = rec.get("step_px", {})
	if row.has(art):
		return float(row[art])
	var count := frame_count(class_id, "walk")
	var travel := travel_cell_px(class_id, code_facing)
	if count <= 0 or travel <= 0.0:
		return 0.0
	return travel / float(count) * combat_scale(class_id)


static func frame_count(class_id: String, state: String) -> int:
	return int(_state_row(class_id, state).get("frames", 0))


static func fps_of(class_id: String, state: String) -> float:
	return float(_state_row(class_id, state).get("fps", 1.0))


static func loops(class_id: String, state: String) -> bool:
	return bool(_state_row(class_id, state).get("loop", false))


static func cell_size(class_id: String, state: String) -> Vector2i:
	var cell: Array = _state_row(class_id, state).get("cell", [0, 0])
	if cell.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(cell[0]), int(cell[1]))


static func frame_path(class_id: String, code_facing: String, state: String, index: int) -> String:
	var pattern := str(_facing_row(class_id, code_facing, state).get("frames", ""))
	if pattern == "":
		return ""
	var cls := SpellKits.normalize_class_id(class_id)
	return ROOT + cls + "/" + pattern.replace("fNN", "f%02d" % index)


static func frame_texture(class_id: String, code_facing: String, state: String, index: int) -> Texture2D:
	var path := frame_path(class_id, code_facing, state, index)
	if path == "":
		return null
	if _textures.has(path) and _textures[path] is Texture2D:
		return _textures[path]
	if not ResourceLoader.exists(path):
		return null
	var loaded: Variant = load(path)
	var tex: Texture2D = loaded if loaded is Texture2D else null
	_textures[path] = tex
	return tex


## SpriteFrames keyed by combat letters: walk_e, attack_s, idle_n, death_w.
## The pixels are the baked art facing for that letter.
static func frames_for(class_id: String) -> SpriteFrames:
	var cls := SpellKits.normalize_class_id(class_id)
	if not has_set(cls):
		return null
	if _frames.has(cls) and _frames[cls] is SpriteFrames:
		return _frames[cls]
	var built := SpriteFrames.new()
	var rec := _record(cls)
	var states: Dictionary = rec.get("states", {})
	for state in states.keys():
		var spec: Dictionary = states[state]
		var count := int(spec.get("frames", 0))
		var fps := float(spec.get("fps", 1.0))
		var looped := bool(spec.get("loop", false))
		for letter in CODE_LETTERS:
			var anim := "%s_%s" % [str(state), letter]
			if not built.has_animation(anim):
				built.add_animation(anim)
			built.set_animation_speed(anim, fps)
			built.set_animation_loop(anim, looped)
			for i in count:
				var tex := frame_texture(cls, letter.to_upper(), str(state), i)
				if tex == null:
					continue
				built.add_frame(anim, tex)
	if built.has_animation("default"):
		built.remove_animation("default")
	_frames[cls] = built
	return built


## frame = floor(board_px / per_frame) mod count.
## per_frame is board_px_per_frame_at_draw_scale, scaled when the draw
## scale is the world walker (world_draw_scale / draw_scale).
static func walk_frame_index(class_id: String, code_facing: String, board_px: float, scale: float) -> int:
	var count := frame_count(class_id, "walk")
	var per := board_px_per_frame(class_id, code_facing)
	var draw := combat_scale(class_id)
	if count <= 0 or per <= 0.0 or scale <= 0.0 or draw <= 0.0:
		return 0
	per *= scale / draw
	var index := int(floor(maxf(board_px, 0.0) / per))
	return posmod(index, count)


static func _record(class_id: String) -> Dictionary:
	var cls := SpellKits.normalize_class_id(class_id)
	if cls == "":
		return {}
	if _sets.has(cls):
		var hit: Variant = _sets[cls]
		return hit if hit is Dictionary else {}
	var loaded := _load_set(cls)
	_sets[cls] = loaded
	return loaded


static func _load_set(class_id: String) -> Dictionary:
	var path := ROOT + class_id + "/" + class_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	var states: Dictionary = data.get("states", {})
	if states.is_empty():
		return {}
	var remap: Dictionary = data.get("combat_code_letter_from_art", {})
	for letter in CODE_LETTERS:
		if not remap.has(letter):
			return {}
		var art := str(remap[letter])
		for state in states.keys():
			var spec: Dictionary = states[state]
			var faces: Dictionary = spec.get("facings", {})
			if not faces.has(art):
				return {}
			var count := int(spec.get("frames", 0))
			var pattern := str((faces[art] as Dictionary).get("frames", ""))
			if pattern == "" or count <= 0:
				return {}
			for i in count:
				var file_path := ROOT + class_id + "/" + pattern.replace("fNN", "f%02d" % i)
				if not FileAccess.file_exists(file_path):
					return {}
	var draw := _draw_scales(data)
	var walk: Dictionary = data.get("walk", {})
	var travel: Dictionary = walk.get("travel_diag_cell_px_per_cycle", {})
	var step: Dictionary = walk.get("board_px_per_frame_at_draw_scale", {})
	return {
		"remap": remap,
		"states": states,
		"travel": travel,
		"step_px": step,
		"combat_scale": float(draw.x),
		"world_scale": float(draw.y),
		"head_hp_y": float(data.get("head_hp_y", -76.0)),
	}


## draw_scale is a number. world_draw_scale is that number times 0.92.
## The older object form (combat / world_walker) still loads.
static func _draw_scales(data: Dictionary) -> Vector2:
	var raw: Variant = data.get("draw_scale", 0.5)
	if raw is Dictionary:
		var scales: Dictionary = raw
		var combat := float(scales.get("combat", 0.5))
		var world := float(scales.get("world_walker", combat * 0.92))
		return Vector2(combat, world)
	var combat := float(raw)
	var world := float(data.get("world_draw_scale", combat * 0.92))
	return Vector2(combat, world)


static func _state_row(class_id: String, state: String) -> Dictionary:
	var states: Dictionary = _record(class_id).get("states", {})
	var row: Variant = states.get(state, {})
	return row if row is Dictionary else {}


static func _facing_row(class_id: String, code_facing: String, state: String) -> Dictionary:
	var faces: Dictionary = _state_row(class_id, state).get("facings", {})
	var art := art_facing(class_id, code_facing)
	var row: Variant = faces.get(art, {})
	return row if row is Dictionary else {}
