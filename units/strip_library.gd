extends RefCounted
class_name StripLibrary

## Load-or-null SpriteFrames for pawn walk / attack / cast strips.
## Missing files return null and never error. Batch 1 drops are Kestrel and
## Ironjaw SE/NE sheets under art/grok_project/anims/. The same names work
## for later classes when those files land. See anims/README.md.

const ANIM_DIR := "res://art/grok_project/anims/"
const EXPORT_DIR := "res://art/grok_project/anims/export_2x/"

const KINDS: Array[String] = ["walk", "attack", "cast"]
## Drawn sheets plus baked mirrors and cardinal names. First file on disk wins.
const FACE_FILES: Array[String] = ["se", "ne", "sw", "nw", "n", "e", "s", "w"]

## Horizontal PNG fallback when a .tres does not carry its own timing.
## Walk matches the handoff: 6 frames @ 12 fps, loop. Attack and cast are
## one-shot; a SpriteFrames .tres may override count, fps, and loop.
const WALK_FRAMES := 6
const WALK_FPS := 12.0
const ACTION_FRAMES := 6
const ACTION_FPS := 12.0

## SE sheet fills the resolver names se, then s and e if those are empty.
## NE sheet fills ne, then n and w. Dedicated sw/nw files stay preferred
## because the pawn asks for them first. No runtime flip.
const SE_ALIAS: Array[String] = ["s", "e"]
const NE_ALIAS: Array[String] = ["n", "w"]

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


## Slice one texture into a SpriteFrames bank. `facing` "se" / "ne" also
## fills the empty alias names. Used by the loader and by headless tests.
static func frames_from_texture(tex: Texture2D, kind: String, facing: String, frame_count: int, fps: float, looped: bool) -> SpriteFrames:
	var built := SpriteFrames.new()
	var clip := {
		"textures": _slice_texture(tex, frame_count),
		"fps": fps,
		"loop": looped,
	}
	var anim := kind if facing == "" else "%s_%s" % [kind, facing]
	_install_clip(built, anim, clip)
	_alias_drawn(built)
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


## Mauro's Batch-1 PNG paths. Tests assert these stay absent until a real drop.
static func batch1_png_paths() -> Array[String]:
	var out: Array[String] = []
	for cls in ["kestrel", "ironjaw"]:
		for kind in ["walk", "attack"]:
			for face in ["se", "ne"]:
				out.append(ANIM_DIR + "%s_%s_%s.png" % [cls, kind, face])
	out.append(ANIM_DIR + "kestrel_cast_se.png")
	out.append(ANIM_DIR + "kestrel_cast_ne.png")
	return out


static func _load_class(class_id: String) -> SpriteFrames:
	var built := SpriteFrames.new()
	var any := false
	for kind in KINDS:
		for face in FACE_FILES:
			var clip := _load_facing_clip(class_id, kind, face)
			if clip.is_empty():
				continue
			if _install_clip(built, "%s_%s" % [kind, face], clip):
				any = true
		var generic := _load_generic_clip(class_id, kind)
		if not generic.is_empty() and _install_clip(built, kind, generic):
			any = true
	_absorb_banks(built, class_id)
	if not _has_playable(built) and not any:
		return null
	_alias_drawn(built)
	if not _has_playable(built):
		return null
	_drop_default(built)
	return built


static func _load_facing_clip(class_id: String, kind: String, face: String) -> Dictionary:
	var stem := "%s_%s_%s" % [class_id, kind, face]
	return _load_stem(stem, kind, face)


static func _load_generic_clip(class_id: String, kind: String) -> Dictionary:
	return _load_stem("%s_%s" % [class_id, kind], kind, "")


static func _load_stem(stem: String, kind: String, face: String) -> Dictionary:
	var paths: Array[String] = [
		EXPORT_DIR + stem + ".tres",
		ANIM_DIR + stem + ".tres",
		EXPORT_DIR + stem + ".png",
		ANIM_DIR + stem + ".png",
	]
	for path in paths:
		var res := try_load(path)
		if res == null:
			continue
		var clip := _parse_motion_resource(res, kind, face)
		if not clip.is_empty():
			return clip
	return {}


static func _absorb_banks(built: SpriteFrames, class_id: String) -> void:
	var paths: Array[String] = [
		EXPORT_DIR + class_id + "_strips.tres",
		ANIM_DIR + class_id + "_strips.tres",
	]
	for path in paths:
		var res := try_load(path)
		if not (res is SpriteFrames):
			continue
		var src := res as SpriteFrames
		for anim_name in src.get_animation_names():
			if str(anim_name) == "default":
				continue
			_copy_anim(built, src, anim_name, anim_name)


static func _parse_motion_resource(res: Resource, kind: String, face: String) -> Dictionary:
	if res is SpriteFrames:
		var frames := res as SpriteFrames
		var anim := _pick_anim(frames, kind, face)
		if anim == "":
			return {}
		var textures: Array[Texture2D] = []
		var count := frames.get_frame_count(anim)
		for i in count:
			var frame_tex := frames.get_frame_texture(anim, i)
			if frame_tex != null:
				textures.append(frame_tex)
		if textures.is_empty():
			return {}
		return {
			"textures": textures,
			"fps": frames.get_animation_speed(anim),
			"loop": frames.get_animation_loop(anim),
		}
	if res is Texture2D:
		var png_count := WALK_FRAMES if kind == "walk" else ACTION_FRAMES
		var png_fps := WALK_FPS if kind == "walk" else ACTION_FPS
		return {
			"textures": _slice_texture(res as Texture2D, png_count),
			"fps": png_fps,
			"loop": kind == "walk",
		}
	return {}


static func _pick_anim(frames: SpriteFrames, kind: String, face: String) -> String:
	if face != "":
		var named := "%s_%s" % [kind, face]
		if frames.has_animation(named) and frames.get_frame_count(named) > 0:
			return named
	if frames.has_animation(kind) and frames.get_frame_count(kind) > 0:
		return kind
	for anim_name in frames.get_animation_names():
		var label := str(anim_name)
		if label == "default":
			continue
		if frames.get_frame_count(anim_name) > 0:
			return label
	return ""


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


static func _alias_drawn(built: SpriteFrames) -> void:
	for kind in KINDS:
		_alias_from(built, kind, "se", SE_ALIAS)
		_alias_from(built, kind, "ne", NE_ALIAS)


static func _alias_from(built: SpriteFrames, kind: String, src_face: String, dst_faces: Array[String]) -> void:
	var src := "%s_%s" % [kind, src_face]
	if not built.has_animation(src) or built.get_frame_count(src) <= 0:
		return
	for dst_face in dst_faces:
		_copy_anim(built, built, src, "%s_%s" % [kind, dst_face])


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
