extends RefCounted
class_name StripLibrary

## Load-or-null SpriteFrames for pawn strips.
## Prefer TA export_2x lettered facings. Grok drawn masters are an optional
## fallback and are not required at runtime. Missing files return null.
## Never load gen_raw `*_gen.png` (identity drift).
## Batch-1c names (`cast_mark`, `cast`, `hit`, `death`, gloam_*) load from
## the same folder. Authored `*_frames.tres` cells win. A PNG fills a clip
## the tres left empty. See art/export_2x/characters/README.md.

const EXPORT_ROOT := "res://art/export_2x/characters/"
## Walk-sheet drop. Replace the PNG at export_png_path(class, "walk", letter).
## 864×160 RGBA, six 144×160 cells. The class *_frames.tres slices that file.
## Classes: kestrel, ironjaw, gloam, and the same names for mender and bastion
## when those sheets arrive. Do not add a second folder. Never load *_gen.png.
const GROK_DIR := "res://art/grok_project/anims/"

const KINDS: Array[String] = ["walk", "attack", "cast", "cast_mark", "hit", "death"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
## Drawn-master suffix → locked pawn letter. SE→e, SW→s, NE→n, NW→w.
const GROK_SHEETS: Array[String] = ["se", "sw", "ne", "nw"]

## Horizontal PNG when a SpriteFrames .tres does not carry timing.
## Walk: 6 frames @ 12 fps, loop. Attack: 6 frames @ 12, one-shot (Gloam attack is 5).
const WALK_FRAMES := 6
const WALK_FPS := 12.0
const ACTION_FRAMES := 6
const ACTION_FPS := 12.0
const CELL_W := 144
## Attack impact pose, 0-based, Kestrel and Ironjaw. VFX reads this.
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
	# gen_raw sheets drift identity. Never promote them to playback.
	if path.get_file().contains("_gen"):
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


## Batch-1 export_2x PNGs (Kestrel and Ironjaw walk + attack, four letters).
static func batch1_png_paths() -> Array[String]:
	var out: Array[String] = []
	for cls in ["kestrel", "ironjaw"]:
		for kind in ["walk", "attack"]:
			for face in LETTERS:
				out.append(export_png_path(cls, kind, face))
	return out


## Batch-1c sheets that were not already in the v3 walk/attack set.
## Ironjaw attack is louder in place and stays on batch1_png_paths().
static func batch1c_png_paths() -> Array[String]:
	var out: Array[String] = []
	var added := {
		"kestrel": ["cast", "cast_mark", "hit", "death"],
		"ironjaw": ["hit", "death"],
		"gloam": ["walk", "attack", "cast", "hit", "death"],
	}
	for cls in ["kestrel", "ironjaw", "gloam"]:
		for kind in added[cls]:
			for face in LETTERS:
				out.append(export_png_path(cls, kind, face))
	return out


## Seconds from clip start to the impact cell. Playback and VFX share this.
static func release_sec(class_id: String, kind: String) -> float:
	var fps := kind_fps(kind)
	if fps <= 0.0:
		return 0.0
	return float(impact_frame(class_id, kind)) / fps


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
	var any := false
	# Tres first. A device CompressedTexture2D often reports a size that does not
	# divide into cells, and that one-frame AtlasTexture used to win over the tres.
	if _absorb_export_frames(built, class_id):
		any = true
	if _load_export_pngs(built, class_id):
		any = true
	if _load_grok_fallback(built, class_id):
		any = true
	if not any or not _has_playable(built):
		return null
	_drop_default(built)
	return _bake_compressed_atlases(built)


static func _load_export_pngs(built: SpriteFrames, class_id: String) -> bool:
	var any := false
	for kind in KINDS:
		for face in LETTERS:
			var res := try_load(export_png_path(class_id, kind, face))
			if not (res is Texture2D):
				continue
			if _install_clip(built, "%s_%s" % [kind, face], _clip_from_texture(res as Texture2D, kind, class_id)):
				any = true
	return any


## Authored `*_frames.tres` clips stay. A per-facing PNG fills a name the tres left empty.
## Runtime AtlasTexture slices must not replace a bank Godot already sliced.
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
			if _install_clip(built, anim, _clip_from_texture(res as Texture2D, kind, class_id)):
				any = true
	return any


## 0-based impact cell. Death holds the last frame in playback; this index is the collapse.
static func impact_frame(class_id: String, kind: String) -> int:
	var cls := SpellKits.normalize_class_id(class_id)
	match kind:
		"hit":
			return 0
		"death":
			return 4
		"attack":
			return 2 if cls == "gloam" else ATTACK_IMPACT_FRAME
		"cast":
			return 2 if cls == "gloam" else ATTACK_IMPACT_FRAME
		"cast_mark":
			return ATTACK_IMPACT_FRAME
		_:
			return ATTACK_IMPACT_FRAME


static func kind_fps(kind: String) -> float:
	if kind == "cast" or kind == "death":
		return 10.0
	return 12.0


static func kind_frame_hint(class_id: String, kind: String) -> int:
	var cls := SpellKits.normalize_class_id(class_id)
	if kind == "hit":
		return 4
	if kind == "death":
		return 6
	if cls == "gloam" and kind == "cast":
		return 4
	if cls == "gloam" and kind == "attack":
		return 5
	if kind == "walk":
		return WALK_FRAMES
	return ACTION_FRAMES


static func _clip_from_texture(tex: Texture2D, kind: String, class_id: String = "") -> Dictionary:
	var count := kind_frame_hint(class_id, kind)
	return {
		"textures": _slice_texture(tex, count),
		"fps": kind_fps(kind),
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
	var cells := 1
	if width % frame_count == 0:
		cells = frame_count
	elif width % CELL_W == 0:
		cells = width / CELL_W
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


## Android draws one region for every AtlasTexture that shares a CompressedTexture2D.
## Copy each authored cell into its own ImageTexture so the strip can cycle.
static func _bake_compressed_atlases(src: SpriteFrames) -> SpriteFrames:
	if src == null or not _needs_atlas_bake(src):
		return src
	var baked := SpriteFrames.new()
	for anim_name in src.get_animation_names():
		if str(anim_name) == "default":
			continue
		var count := src.get_frame_count(anim_name)
		if count <= 0:
			continue
		baked.add_animation(anim_name)
		baked.set_animation_speed(anim_name, src.get_animation_speed(anim_name))
		baked.set_animation_loop(anim_name, src.get_animation_loop(anim_name))
		for i in count:
			var tex := src.get_frame_texture(anim_name, i)
			var frame_tex := _bake_frame_texture(tex)
			if frame_tex == null:
				continue
			baked.add_frame(anim_name, frame_tex, src.get_frame_duration(anim_name, i))
	if not _has_playable(baked):
		return src
	_drop_default(baked)
	return baked


static func _needs_atlas_bake(frames: SpriteFrames) -> bool:
	for anim_name in frames.get_animation_names():
		if str(anim_name) == "default":
			continue
		var count := frames.get_frame_count(anim_name)
		for i in count:
			if _is_compressed_atlas(frames.get_frame_texture(anim_name, i)):
				return true
	return false


static func _is_compressed_atlas(tex: Texture2D) -> bool:
	if not (tex is AtlasTexture):
		return false
	var atlas := (tex as AtlasTexture).atlas
	return atlas is CompressedTexture2D


static func _bake_frame_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if not _is_compressed_atlas(tex):
		return tex
	var image := tex.get_image()
	if image == null or image.is_empty():
		return tex
	return ImageTexture.create_from_image(image)


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
