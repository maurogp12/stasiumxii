extends RefCounted
class_name SpellArt

## Painted spell cues from art/vfx/spells/playback.json.
## Added beside the existing recipes. CombatSim never reads this file.

const PLAYBACK := "res://art/vfx/spells/playback.json"
const STAMP := preload("res://vfx/vfx_stamp.gd")
const MOTION := preload("res://units/view_motion.gd")

## Melee contact art waits for the same resolve as the hit flash.
const CONTACT := {
	"strike_axes": true,
	"crush_stamp": true,
	"shoulder_shove": true,
	"cut_slash": true,
	"bash_mace": true,
}

static var _book: Dictionary = {}
static var _loaded: bool = false


static func recipes_for(event: Dictionary) -> Array:
	if bool(event.get("foe", false)):
		return []
	var book := _playback()
	var out: Array = []
	var spell_id := str(event.get("spell", ""))
	var typ := str(event.get("type", ""))
	var phase := str(event.get("present_phase", ""))
	var caster_cell := _cell(event.get("caster_cell", Vector2i.ZERO))
	var to_cell := _cell(event.get("to", caster_cell)) if event.has("to") else caster_cell
	var from_cell := _cell(event.get("from", caster_cell)) if event.has("from") else caster_cell
	var origin_cell := _cell(event.get("origin", caster_cell)) if event.has("origin") else caster_cell
	for raw in book.get("cues", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cue: Dictionary = raw
		var cue_id := str(cue.get("id", ""))
		if typ == "trap":
			if cue_id != "snare_spring":
				continue
		else:
			if str(cue.get("spell", "")) != spell_id:
				continue
			var types: Array = cue.get("types", [])
			if not types.has(typ):
				continue
		if cue_id == "ambush_fold" and phase == "contact":
			continue
		if cue_id == "ambush_seam" and phase == "collapse":
			continue
		var spec := _recipe(cue, event, caster_cell, to_cell, from_cell, origin_cell)
		if not spec.is_empty():
			out.append(spec)
	if typ == "hit":
		var element := str(event.get("element", "")).to_lower()
		for raw in book.get("elements", []):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var accent: Dictionary = raw
			if str(accent.get("element", "")) != element:
				continue
			out.append(_element_recipe(accent, event, to_cell))
	return out


## Extra linger keys. Existing plant / wall / trap rings stay.
static func linger_specs(snapshot: Dictionary) -> Dictionary:
	var book := _playback()
	var by_id := {}
	for raw in book.get("lingers", []):
		if typeof(raw) == TYPE_DICTIONARY:
			by_id[str(raw.get("id", ""))] = raw
	var wanted := {}
	_linger_tiles(wanted, by_id.get("plant_banner_idle", {}), snapshot.get("plant_tiles", []), "plant_banner")
	_linger_tiles(wanted, by_id.get("snap_wall_block", {}), snapshot.get("blocked_tiles", []), "snap_wall")
	_linger_tiles(wanted, by_id.get("snare_trap_token", {}), snapshot.get("trap_tiles_visible", []), "snare_token")
	var ward: Dictionary = by_id.get("ward_shell_loop", {})
	var heart: Dictionary = by_id.get("heartstop_shell_loop", {})
	for unit in snapshot.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = unit
		if not bool(rec.get("alive", true)):
			continue
		var seat := int(rec.get("seat", -1))
		var cell := _cell(rec.get("pos", Vector2i.ZERO))
		if str(rec.get("class_id", "")) == "bastion" and int(rec.get("shield", 0)) > 0 and not ward.is_empty():
			wanted["ward_shell:%d" % seat] = _linger_payload(ward, cell, seat)
		if int(rec.get("hit_immunity", 0)) > 0 and not heart.is_empty():
			wanted["heartstop:%d" % seat] = _linger_payload(heart, cell, seat)
	return wanted


static func _playback() -> Dictionary:
	if _loaded:
		return _book
	_loaded = true
	if FileAccess.file_exists(PLAYBACK):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYBACK))
		if typeof(parsed) == TYPE_DICTIONARY:
			_book = parsed
	return _book


static func _recipe(cue: Dictionary, event: Dictionary, caster_cell: Vector2i, to_cell: Vector2i, from_cell: Vector2i, origin_cell: Vector2i) -> Dictionary:
	var cue_id := str(cue.get("id", ""))
	var at_name := str(cue.get("at", "to"))
	var system := str(cue.get("system", "strip"))
	var cell := to_cell
	match at_name:
		"from":
			cell = from_cell
		"origin":
			cell = origin_cell
		"caster":
			cell = caster_cell
		"fly":
			cell = to_cell
		_:
			cell = to_cell
	var seat := int(event.get("seat", -1))
	if not bool(cue.get("owner_only", false)) and at_name == "to" and event.has("target_seat"):
		seat = int(event.get("target_seat", seat))
	var delay := 0.0
	if CONTACT.has(cue_id):
		delay = MOTION.damage_resolve_sec(str(cue.get("spell", "")))
	var flip := false
	if bool(cue.get("flip", false)):
		flip = float(to_cell.x - to_cell.y) < float(caster_cell.x - caster_cell.y)
	if system == "stamp":
		var life := STAMP.windup_sec(cue_id)
		if life <= 0.0:
			life = 0.4
		return {
			"id": "stamp",
			"block": 0.0,
			"sheet": cue_id,
			"seat": seat,
			"cell": cell,
			"delay": delay,
			"px": float(cue.get("px", 80.0)),
			"life": life,
			"alpha": 1.0,
			"chest": false,
			"hand": false,
			"ground": str(cue.get("z", "air")) == "ground",
			"owner_only": false,
		}
	if system == "fly" or at_name == "fly":
		if caster_cell == to_cell:
			return {}
		var duration := 0.24 if cue_id == "mark_arrow" else 0.2
		var arc := 10.0 if cue_id == "mark_arrow" else 8.0
		var fly_delay := STAMP.lead_sec("mark_shot_cast", 3) if cue_id == "mark_arrow" else 0.0
		return {
			"id": "spell_fx",
			"block": 0.0,
			"system": "fly",
			"path": str(cue.get("path", "")),
			"frames": int(cue.get("frames", 1)),
			"fps": float(cue.get("fps", 8.0)),
			"scale": float(cue.get("scale", 1.0)),
			"anchor": _anchor(cue.get("anchor", [])),
			"from": caster_cell,
			"to": to_cell,
			"arc": arc,
			"duration": duration,
			"delay": fly_delay,
			"add": bool(cue.get("add", false)),
			"crossfade": bool(cue.get("crossfade", false)),
			"owner_only": bool(cue.get("owner_only", false)),
			"z": str(cue.get("z", "air")),
			"flip_h": flip,
			"seat": seat,
			"cell": to_cell,
		}
	return {
		"id": "spell_fx",
		"block": 0.0,
		"system": "strip",
		"path": str(cue.get("path", "")),
		"frames": int(cue.get("frames", 1)),
		"fps": float(cue.get("fps", 12.0)),
		"scale": float(cue.get("scale", 1.0)),
		"anchor": _anchor(cue.get("anchor", [])),
		"delay": delay,
		"add": bool(cue.get("add", false)),
		"crossfade": bool(cue.get("crossfade", false)),
		"owner_only": bool(cue.get("owner_only", false)),
		"z": str(cue.get("z", "ground")),
		"flip_h": flip,
		"seat": seat,
		"cell": cell,
	}


static func _element_recipe(accent: Dictionary, event: Dictionary, cell: Vector2i) -> Dictionary:
	return {
		"id": "spell_fx",
		"block": 0.0,
		"system": "strip",
		"path": str(accent.get("path", "")),
		"frames": int(accent.get("frames", 3)),
		"fps": float(accent.get("fps", 14.0)),
		"scale": float(accent.get("scale", 0.35)),
		"anchor": _anchor(accent.get("anchor", [])),
		"delay": 0.0,
		"add": bool(accent.get("add", true)),
		"crossfade": false,
		"owner_only": false,
		"z": "air",
		"flip_h": false,
		"seat": int(event.get("target_seat", -1)),
		"cell": cell,
	}


static func _linger_tiles(wanted: Dictionary, spec: Variant, raw: Variant, prefix: String) -> void:
	if typeof(spec) != TYPE_DICTIONARY or (spec as Dictionary).is_empty() or typeof(raw) != TYPE_ARRAY:
		return
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var cell := _cell(rec.get("pos", Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))))
		var seat := int(rec.get("owner_seat", -1))
		wanted["%s:%d,%d" % [prefix, cell.x, cell.y]] = _linger_payload(spec, cell, seat)


static func _linger_payload(spec: Dictionary, cell: Vector2i, seat: int) -> Dictionary:
	return {
		"pool": "strip",
		"path": str(spec.get("path", "")),
		"frames": int(spec.get("frames", 1)),
		"anchor": _anchor(spec.get("anchor", [])),
		"fps": float(spec.get("fps", 1.0)),
		"scale": float(spec.get("scale", 1.0)),
		"loop": true,
		"add": bool(spec.get("add", false)),
		"crossfade": false,
		"cell": cell,
		"seat": seat,
		"z_kind": str(spec.get("z", "ground")),
	}


static func _anchor(raw: Variant) -> Vector2:
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	if raw is Vector2:
		return raw
	return Vector2(96, 96)


## Local copy so this file does not preload the router.
static func _cell(value: Variant) -> Vector2i:
	if value == null:
		return Vector2i(-1, -1)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		var rec: Dictionary = value
		return Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
