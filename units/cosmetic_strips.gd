extends RefCounted
class_name CosmeticStrips

## Prebaked SpriteFrames for one gender × palette.
## Flag off, or a missing PNG, falls back to the live Batch-1 bank under
## `res://art/export_2x/characters/<class>/anims/`.
## Strip contract: 864×160, 6 frames, walk loop @ 12 fps, attack impact frame 3.
## Ironjaw `alt` keeps the same bulky scale as `default` (the path still exists).
## `palettes.json` is the later shader remap; this slice does not sample it for pixels.

const CUSTOM_ROOT := "res://art/export_2x/characters_custom/"
const STRIP_SIZE := Vector2i(864, 160)
const LIBRARY := preload("res://units/strip_library.gd")

static var _cache: Dictionary = {}
## Tests set this to force a missing-file fallback without deleting sheets.
static var _exists_override: Callable = Callable()


static func clear_cache() -> void:
	_cache.clear()


static func custom_png_path(class_id: String, gender_id: String, palette_id: String, kind: String, face: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	var gender := SeatCosmetics.normalize_gender(gender_id)
	var palette := SeatCosmetics.normalize_palette(cls, palette_id)
	return "%s%s/%s/%s/anims/%s_%s_%s.png" % [CUSTOM_ROOT, cls, gender, palette, cls, kind, face]


static func stock_png_path(class_id: String, kind: String, face: String) -> String:
	return LIBRARY.export_png_path(class_id, kind, face)


static func resolve_png_path(class_id: String, gender_id: String, palette_id: String, kind: String, face: String) -> String:
	var custom := custom_png_path(class_id, gender_id, palette_id, kind, face)
	return resolve_png_path_present(class_id, gender_id, palette_id, kind, face, _file_present(custom))


## `custom_present` is the disk check split out so tests can cover both branches.
static func resolve_png_path_present(class_id: String, gender_id: String, palette_id: String, kind: String, face: String, custom_present: bool) -> String:
	var stock := stock_png_path(class_id, kind, face)
	if not SeatCosmetics.enabled() or not SeatCosmetics.supports(class_id):
		return stock
	if not custom_present:
		return stock
	return custom_png_path(class_id, gender_id, palette_id, kind, face)


static func frames_for(spec: Dictionary) -> SpriteFrames:
	var cls := SpellKits.normalize_class_id(str(spec.get("class_id", "")))
	if not SeatCosmetics.enabled() or not SeatCosmetics.supports(cls):
		return LIBRARY.frames_for(cls)
	var gender := SeatCosmetics.normalize_gender(str(spec.get("gender", "")))
	var palette := SeatCosmetics.normalize_palette(cls, str(spec.get("palette", "")))
	var key := "%s/%s/%s" % [cls, gender, palette]
	if _cache.has(key):
		var hit: Variant = _cache[key]
		if hit is SpriteFrames:
			return hit
		return LIBRARY.frames_for(cls)
	var built := _load_custom(cls, gender, palette)
	if built == null:
		_cache[key] = false
		return LIBRARY.frames_for(cls)
	_cache[key] = built
	return built


static func _load_custom(class_id: String, gender_id: String, palette_id: String) -> SpriteFrames:
	var any := false
	for kind in ["walk", "attack"]:
		for face in LIBRARY.LETTERS:
			if _file_present(custom_png_path(class_id, gender_id, palette_id, kind, face)):
				any = true
				break
		if any:
			break
	if not any:
		return null
	var built := SpriteFrames.new()
	var stock := LIBRARY.frames_for(class_id)
	for kind in ["walk", "attack"]:
		for face in LIBRARY.LETTERS:
			var anim := "%s_%s" % [kind, face]
			var path := custom_png_path(class_id, gender_id, palette_id, kind, face)
			if _file_present(path) and LIBRARY.add_png_clip(built, path, kind, face):
				continue
			if stock != null:
				LIBRARY.copy_clip(built, stock, anim)
	return LIBRARY.finish_bank(built)


static func _file_present(path: String) -> bool:
	if _exists_override.is_valid():
		return bool(_exists_override.call(path))
	return FileAccess.file_exists(path)
