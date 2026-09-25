extends RefCounted
class_name StripLibrary

## Load-or-null SpriteFrames for pawn walk / attack / cast strips.
## Prefer TA export_2x lettered facings. Grok drawn masters are an optional
## fallback and are not required at runtime. Missing files return null.
## See art/export_2x/characters/README.md.

const EXPORT_ROOT := "res://art/export_2x/characters/"
const GROK_DIR := "res://art/grok_project/anims/"

const KINDS: Array[String] = ["walk", "attack", "cast"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
## Drawn-master suffix → locked pawn letter. SE→e, SW→s, NE→n, NW→w.
const GROK_SHEETS: Array[String] = ["se", "sw", "ne", "nw"]

## Horizontal PNG when a SpriteFrames .tres does not carry timing.
## Walk: 6 frames @ 12 fps, loop. Attack: 6 frames, one-shot.
const WALK_FRAMES := 6
const WALK_FPS := 12.0
const ACTION_FRAMES := 6
const ACTION_FPS := 12.0
## Attack impact pose, 0-based, both kits. VFX reads this; the strip does not invent a hit.
const ATTACK_IMPACT_FRAME := 3

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Combined frames for one class, or null when nothing is on disk.
static func frames_for(class_id: String) -> SpriteFrames:
	var cls := SpellKits.normalize_class_id(class_id)
	if cls == "":
		return null
	if _cache.has(cls):
		var hit: Variant = _cache[cls]
		return hit if hit is SpriteFrames else null
	var built := _load_class(cls)
	_cache[cls] = built if built != null else false
	return built


## Slice one texture. "se"/"sw"/"ne"/"nw" store under the locked letter
## (`walk_e`, not `walk_se`). A letter facing is stored as itself.
static func frames_from_texture(tex: Texture2D, kind: String, facing: String, frame_count: int, fps: float, looped: bool) -> SpriteFrames:
	var built := SpriteFrames.new()
	var letter := letter_for_sheet(facing)
	var anim := kind if letter == "" else "%s_%s" % [kind, letter]
	_install_clip(built, anim, {
		"textures": _slice_texture(tex, frame_count),
		"fps": fps,
		"loop": looped,
	})
	_drop_default(built)
	return built


## Null when the path is missing or is not a Resource. Does not print a load error.
static func try_load(path: String) -> Resource:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var loaded: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	return loaded if loaded is Resource else null


static func export_png_path(class_id: String, kind: String, face: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	return "%s%s/anims/%s_%s_%s.png" % [EXPORT_ROOT, cls, cls, kind, face]


static func export_frames_path(class_id: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	return "%s%s/%s_frames.tres" % [EXPORT_ROOT, cls, cls]


static func grok_png_path(class_id: String, kind: String, sheet: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	return "%s%s_%s_%s.png" % [GROK_DIR, cls, kind, sheet]


## Batch-1 export_2x PNGs. Tests assert these stay absent until a real drop.
static func batch1_png_paths() -> Array[String]:
	var out: Array[String] = []
	for cls in ["kestrel", "ironjaw"]:
		for kind in ["walk", "attack"]:
			for face in LETTERS:
				out.append(export_png_path(cls, kind, face))
	return out


## Locked map. Unknown tokens pass through so `e` stays `e`.
static func letter_for_sheet(facing: String) -> String:
	match facing.strip_edges().to_lower():
		"se":
			return "e"
		"sw":
			return "s"
		"ne":
			return "n"
		"nw":
			return "w"
		_:
			return facing.strip_edges().to_lower()


static func _load_class(class_id: String) -> SpriteFrames:
	var built := SpriteFrames.new()
	var any := _load_export_pngs(built, class_id)
	if _absorb_export_frames(built, class_id):
		any = true
	if _load_grok_fallback(built, class_id):
		any = true
	if not any or not _has_playable(built):
		return null
	_drop_default(built)
	return built


static func _load_export_pngs(built: SpriteFrames, class_id: String) -> bool:
	var any := false
	for kind in KINDS:
		for face in LETTERS:
			var res := try_load(export_png_path(class_id, kind, face))
			if not (res is Texture2D):
				continue
			if _install_clip(built, "%s_%s" % [kind, face], _clip_from_texture(res as Texture2D, kind)):
				any = true
	return any


## Fills animation names the per-facing PNGs left empty. PNG wins when both exist.
static func _absorb_export_frames(built: SpriteFrames, class_id: String) -> bool:
	var res := try_load(export_frames_path(class_id))
	if not (res is SpriteFrames):
		return false
	var src := res as SpriteFrames
	var any := false
	for anim_name in src.get_animation_names():
		if str(anim_name) == "default":
			continue
		if not built.has_animation(anim_name):
			_copy_anim(built, src, anim_name, anim_name)
		if built.has_animation(anim_name) and built.get_frame_count(anim_name) > 0:
			any = true
	return any


static func _load_grok_fallback(built: SpriteFrames, class_id: String) -> bool:
	var any := false
	for kind in KINDS:
		for sheet in GROK_SHEETS:
			var letter := letter_for_sheet(sheet)
			var anim := "%s_%s" % [kind, letter]
			if built.has_animation(anim):
				continue
			var res := try_load(grok_png_path(class_id, kind, sheet))
			if not (res is Texture2D):
				continue
			if _install_clip(built, anim, _clip_from_texture(res as Texture2D, kind)):
				any = true
	return any


static func _clip_from_texture(tex: Texture2D, kind: String) -> Dictionary:
	var count := WALK_FRAMES if kind == "walk" else ACTION_FRAMES
	var fps := WALK_FPS if kind == "walk" else ACTION_FPS
	return {
		"textures": _slice_texture(tex, count),
		"fps": fps,
		"loop": kind == "walk",
	}


static func _slice_texture(tex: Texture2D, frame_count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if tex == null or frame_count <= 0:
		return out
	var width := tex.get_width()
	var height := tex.get_height()
	if width <= 0 or height <= 0:
		return out
	var cells := frame_count if width % frame_count == 0 else 1
	var frame_w := width / cells
	if frame_w <= 0:
		return out
	for i in cells:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, height)
		out.append(atlas)
	return out


static func _install_clip(built: SpriteFrames, anim: String, clip: Dictionary) -> bool:
	if anim == "" or built.has_animation(anim):
		return false
	var textures: Array = clip.get("textures", [])
	if textures.is_empty():
		return false
	built.add_animation(anim)
	built.set_animation_speed(anim, float(clip.get("fps", WALK_FPS)))
	built.set_animation_loop(anim, bool(clip.get("loop", false)))
	for tex in textures:
		if tex is Texture2D:
			built.add_frame(anim, tex)
	return built.get_frame_count(anim) > 0


static func _copy_anim(dst: SpriteFrames, src: SpriteFrames, from_name: StringName, to_name: StringName) -> void:
	if str(to_name) == "" or dst.has_animation(to_name) or not src.has_animation(from_name):
		return
	if src.get_frame_count(from_name) <= 0:
		return
	dst.add_animation(to_name)
	dst.set_animation_speed(to_name, src.get_animation_speed(from_name))
	dst.set_animation_loop(to_name, src.get_animation_loop(from_name))
	var count := src.get_frame_count(from_name)
	for i in count:
		var tex := src.get_frame_texture(from_name, i)
		if tex == null:
			continue
		dst.add_frame(to_name, tex, src.get_frame_duration(from_name, i))


static func _has_playable(frames: SpriteFrames) -> bool:
	if frames == null:
		return false
	for anim_name in frames.get_animation_names():
		if str(anim_name) == "default":
			continue
		var count := frames.get_frame_count(anim_name)
		for i in count:
			if frames.get_frame_texture(anim_name, i) != null:
				return true
	return false


static func _drop_default(built: SpriteFrames) -> void:
	if built.has_animation("default") and built.get_animation_names().size() > 1:
		built.remove_animation("default")
