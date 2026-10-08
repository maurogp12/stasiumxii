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
## South, north, and west stay 864×160, six 144×160 cells. East (down-right)
## is the locked 12-frame march in the same 144×160 cell, mirrored to face
## the old east diagonal, with the contact foot on the old plant.
## The class *_frames.tres slices that file. Do not add a second folder.
## Never load *_gen.png.
const GROK_DIR := "res://art/grok_project/anims/"

const KINDS: Array[String] = ["walk", "attack", "cast", "cast_mark", "hit", "death"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
## Drawn-master suffix → locked pawn letter. SE→e, SW→s, NE→n, NW→w.
const GROK_SHEETS: Array[String] = ["se", "sw", "ne", "nw"]

## Horizontal PNG when a SpriteFrames .tres does not carry timing.
## Back and down-left walks: 6 frames @ 12 fps, loop. East march: 12 frames
## @ 12 fps, one cycle still fitted to the tile by the pawn. Attack: 6 frames
## @ 12, one-shot (Gloam attack is 5).
const WALK_FRAMES := 6
## Locked down-right march (old letter e). Not mirrored onto south or west.
const LOCKED_EAST_WALK_FRAMES := 12
## Look 1 painted walks (Technical Artist): 8 frames, 144x176 cells.
const LOOK1_WALK_FRAMES := 8
const WALK_FPS := 12.0
const ACTION_FRAMES := 6
const ACTION_FPS := 12.0
const CELL_W := 144
## Attack impact pose, 0-based, Kestrel and Ironjaw. VFX reads this.
const ATTACK_IMPACT_FRAME := 3

## Painted character strips (new looks, 4 Oct 2026). One raw PNG sheet per
## class, kind and facing, cells left to right:
## `art/characters/<class>/<kind>/<class>_<kind>_<n|e|s|w>.pngbin`.
## Built by `build_tools/mobile_characters/build_mobile_walks.py`, which also
## writes the cell, pivot, fps and frames-per-tile table it reads
## (`units/character_strip_specs.gd`). The pivot is the ground point on the
## 152 sole line, so `Pawn.pivot_offset_for` stands every cell on the tile.
## Walk: a class with a painted walk spec plays only that walk. A missing
## facing sheet drops the walk clip, and the pawn shows its static
## `art/characters/<class>/<class>_<facing>.png` with the old hop.
## Actions (LOCKED painted idle, attack, skill, hit, death, 4 Oct 2026): a
## sheet that exists replaces that clip (`skill` plays as `cast_<facing>`).
## A missing sheet keeps today's export_2x strip or motion. A painted attack
## also drops the old export_2x `cast_mark_*` bow (another costume), so Mark
## Shot takes its existing fallback, the attack (Kestrel's painted bow shot).
## `idle_<facing>` loops while the pawn stands (Pawn.painted_idle_cell); walk
## frame 0 stays the fallback when that sheet is missing.
## Every painted cell carries its ground point as the `cell_pivot` meta
## (Vector2i, texture px). walk and idle sit on (cell_w / 2, 152); an action
## cell may sit lower (head room for a raised weapon) or off centre (a body
## lying on its side). Pawn.texture_pivot_offset stands any cell on it.
const STRIP_SPECS := preload("res://units/character_strip_specs.gd")
const PAINTED_ROOT := "res://art/characters/"
const PAINTED_KINDS: Array[String] = ["walk", "idle", "attack", "skill", "hit", "death"]
const PAINTED_ANIM := {
	"walk": "walk",
	"idle": "idle",
	"attack": "attack",
	"skill": "cast",
	"hit": "hit",
	"death": "death",
}

## Tests flip this off to pin the export_2x walk pipeline that a class
## without a painted spec still uses. The game never turns it off.
static var painted_looks: bool = true
## Meta key on each painted cell: its ground point in texture px (Vector2i).
const CELL_PIVOT_META := "cell_pivot"
## Longest a painted one-shot plays: the board's action lock
## (ViewMotion.ACTION_LOCK_MAX, 0.6 s). A 12-frame attack or skill authored
## at 17.144 fps is 0.70 s, so it plays at 20 fps to fit the lock.
const PAINTED_ACTION_MAX_SEC := 0.6

static var _cache: Dictionary = {}
static var _painted_cells: Dictionary = {}
## Fitted standing cards. Keyed by class and the canvas the caller asked for.
static var _card_portraits: Dictionary = {}


static func set_painted_looks(enabled: bool) -> void:
	painted_looks = enabled
	clear_cache()
## East walk frame 0, one ImageTexture per class. Select cards and turn chips.
static var _idle_cache: Dictionary = {}
## Foot-down cell per class facing. 0 when that cell is already frame 0.
static var _walk_contact: Dictionary = {}
## Foot row of the old 144x160 standing cell (walk frame 0 before Look 1).
const LEGACY_STAND_ROW := 150


static func clear_cache() -> void:
	_cache.clear()
	_painted_cells.clear()
	_card_portraits.clear()
	_idle_cache.clear()
	_walk_contact.clear()


## Standing plant of the locked Wakfu walk. East frame 0, 144×160.
## Bytes come from `art/export_2x/walk_src/` (same sheet as
## `art/export_2x/characters/<class>/anims/<class>_walk_e.png`).
## Null when the class is outside the roster or the sheet is missing.
static func idle_portrait(class_id: String) -> Texture2D:
	var cls := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(cls):
		return null
	if _idle_cache.has(cls):
		var hit: Variant = _idle_cache[cls]
		return hit if hit is Texture2D else null
	var tex := _idle_cell(cls, "e")
	_idle_cache[cls] = tex if tex != null else false
	return tex


## Frame 0 only. A full strip is not a portrait.
static func _idle_cell(class_id: String, face: String) -> Texture2D:
	var cells := _walk_cell_textures(class_id, face)
	if cells.is_empty():
		return null
	return cells[0]


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


## Spec row for a painted kind, or {} when the class has none.
static func painted_spec(class_id: String, kind: String) -> Dictionary:
	if not painted_looks:
		return {}
	var cls := SpellKits.normalize_class_id(class_id)
	var row: Variant = STRIP_SPECS.SPECS.get(cls, {})
	if not (row is Dictionary):
		return {}
	var spec: Variant = (row as Dictionary).get(kind, {})
	return spec if spec is Dictionary else {}


## True when the class walks on the painted strips (not the export_2x sheets).
static func has_painted_look(class_id: String) -> bool:
	return not painted_spec(class_id, "walk").is_empty()


static func painted_path(class_id: String, kind: String, face: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	var letter := letter_for_sheet(face)
	return "%s%s/%s/%s_%s_%s.pngbin" % [PAINTED_ROOT, cls, kind, cls, kind, letter]


## One ImageTexture per cell of the painted sheet. Empty when the spec, the
## file, or the sheet size (frames x cell) is missing or wrong.
static func painted_cells(class_id: String, kind: String, face: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var spec := painted_spec(class_id, kind)
	if spec.is_empty():
		return out
	var path := painted_path(class_id, kind, face)
	if _painted_cells.has(path):
		out.assign(_painted_cells[path])
		return out
	_painted_cells[path] = []
	if not FileAccess.file_exists(path):
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return out
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var count := int(spec.get("frames", 0))
	if cell.x <= 0 or cell.y <= 0 or count <= 0:
		return out
	if image.get_width() != cell.x * count or image.get_height() != cell.y:
		return out
	var letter := letter_for_sheet(face)
	var pivot: Vector2i = spec.get("pivot", Vector2i(cell.x / 2, 152))
	var pivots: Variant = spec.get("pivots", {})
	if pivots is Dictionary and (pivots as Dictionary).has(letter):
		pivot = (pivots as Dictionary)[letter]
	# Same edge pass the importer runs (fix_alpha_border), so linear filtering
	# does not pull black into the binary-alpha edge.
	image.fix_alpha_edges()
	for i in count:
		var tex := ImageTexture.create_from_image(image.get_region(Rect2i(i * cell.x, 0, cell.x, cell.y)))
		if tex == null:
			return []
		tex.set_meta(CELL_PIVOT_META, pivot)
		out.append(tex)
	_painted_cells[path] = out
	return out


## Opaque pixels of a cell. Alpha at or below `alpha_min` (0–255) is padding.
static func opaque_rect(image: Image, alpha_min: int = 16) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if int(image.get_pixel(x, y).a * 255.0) <= alpha_min:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Standing idle, cropped to the opaque body and scaled to one shared height.
## Feet sit on one baseline. A figure wider than the canvas (Gloam) is the
## only one that shrinks, and only enough to stay inside the card.
## Default canvas is the class-select plate. Linear sample, same as the match.
static func card_portrait(class_id: String, canvas_size: Vector2i = Vector2i(260, 248), height_frac: float = 0.78, feet_frac: float = 0.92) -> Texture2D:
	var cls := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(cls):
		return null
	var canvas := canvas_size
	if canvas.x < 8 or canvas.y < 8:
		canvas = Vector2i(260, 248)
	var key := "%s:%d:%d:%.3f:%.3f" % [cls, canvas.x, canvas.y, height_frac, feet_frac]
	if _card_portraits.has(key):
		var hit: Variant = _card_portraits[key]
		return hit as Texture2D if hit is Texture2D else null
	var cells := painted_cells(cls, "idle", "s")
	if cells.is_empty() or cells[0] == null:
		_card_portraits[key] = null
		return null
	var image := cells[0].get_image()
	if image == null or image.is_empty():
		_card_portraits[key] = cells[0]
		return cells[0]
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var used := opaque_rect(image)
	if used.size.x < 2 or used.size.y < 2:
		_card_portraits[key] = cells[0]
		return cells[0]
	var target_h := int(round(float(canvas.y) * clampf(height_frac, 0.5, 0.98)))
	var scale := float(target_h) / float(used.size.y)
	var target_w := int(round(float(used.size.x) * scale))
	var cap := int(round(float(canvas.x) * 0.92))
	if target_w > cap and target_w > 0:
		var fit := float(cap) / float(target_w)
		target_w = cap
		target_h = maxi(int(round(float(target_h) * fit)), 1)
	var cropped := image.get_region(used)
	cropped.resize(maxi(target_w, 1), maxi(target_h, 1), Image.INTERPOLATE_BILINEAR)
	var plate := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	plate.fill(Color(0, 0, 0, 0))
	var feet_y := int(round(float(canvas.y) * clampf(feet_frac, 0.5, 1.0)))
	var dest := Vector2i(int((canvas.x - cropped.get_width()) / 2.0), feet_y - cropped.get_height())
	if dest.y < 0:
		dest.y = 0
	plate.blit_rect(cropped, Rect2i(0, 0, cropped.get_width(), cropped.get_height()), dest)
	var tex := ImageTexture.create_from_image(plate)
	_card_portraits[key] = tex
	return tex


## Painted walk cells crossed by one board tile of travel, or 0 when this
## class and facing has no painted walk on disk. The spec caps it at
## MAX_LEG_RATE x the authored fps (natural leg speed, small foot slide).
static func painted_frames_per_tile(class_id: String, face: String) -> float:
	var spec := painted_spec(class_id, "walk")
	if spec.is_empty():
		return 0.0
	if painted_cells(class_id, "walk", face).size() < 2:
		return 0.0
	return float(spec.get("frames_per_tile", 0.0))


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


## Scenario hit-flinch sheets. 576×160, four 144×160 cells, one per facing.
## Same path the pawn already plays as `hit_<n|e|s|w>`.
static func hit_png_paths() -> Array[String]:
	var out: Array[String] = []
	for cls in ["kestrel", "ironjaw", "gloam", "mender", "bastion"]:
		for face in LETTERS:
			out.append(export_png_path(cls, "hit", face))
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
## A painted strip plays evenly inside the action lock, so its release is
## the impact cell at that playback rate (f06 of 12 in 0.6 s is 0.30 s).
static func release_sec(class_id: String, kind: String) -> float:
	var fps := kind_fps(kind)
	var painted := _painted_action_spec(class_id, kind)
	if not painted.is_empty():
		fps = painted_play_fps(painted)
	if fps <= 0.0:
		return 0.0
	return float(impact_frame(class_id, kind)) / fps


## Playback rate of a painted one-shot: authored, or faster when its
## authored length is longer than the action lock.
static func painted_play_fps(spec: Dictionary) -> float:
	var fps := float(spec.get("fps", 0.0))
	var count := int(spec.get("frames", 0))
	if fps <= 0.0 or count <= 0:
		return fps
	var natural := float(count) / fps
	if natural <= PAINTED_ACTION_MAX_SEC:
		return fps
	return float(count) / PAINTED_ACTION_MAX_SEC


## True when this cell is a painted strip cell (it carries its own pivot).
static func is_painted_cell(tex: Texture2D) -> bool:
	return tex != null and tex.has_meta(CELL_PIVOT_META)


## Painted spec behind a pawn clip kind ("attack", "cast", "hit", "death"),
## or {} when that kind still plays the export_2x strip or a motion.
static func painted_action_spec(class_id: String, kind: String) -> Dictionary:
	return _painted_action_spec(class_id, kind)


## Locked map. Unknown tokens pass through so `e` stays `e`.
## East is the 12-frame march. The other letters stay six frames.
## Look 1 (Mauro 4 Oct 2026): every facing is an 8-frame painted walk; the
## cell count comes from the sheet width (144 px cells), this is the fallback.
static func walk_sheet_frames(_face: String) -> int:
	return LOOK1_WALK_FRAMES


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
	# Walk playback is the locked export_2x sheet for this class. A tres cell,
	# a grok fallback, or a shared atlas must not keep another costume.
	if _force_locked_walk_pngs(built, class_id):
		any = true
	if _load_painted_actions(built, class_id):
		any = true
	if not any or not _has_playable(built):
		return null
	_drop_default(built)
	var baked := _bake_compressed_atlases(built)
	# Walk bytes are already ImageTextures, so the atlas bake no-ops them.
	# Feet still pin to frame 0. A second pass is a no-op once they match.
	# The contact index is scored before that shift.
	_stabilize_walk_feet(baked, class_id)
	_stabilize_hit_feet(baked)
	return baked


## Raw PNG bytes packed beside the import. Android `get_image()` on a
## CompressedTexture2D is often empty, and a shared AtlasTexture then draws
## one cell for the whole cycle (the idle plant sliding across the diamond).
## These files are not imported. The export include filter packs them.
const WALK_BYTES_DIR := "res://art/export_2x/walk_src/"


static func walk_bytes_path(class_id: String, face: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	return "%s%s_walk_%s.pngbin" % [WALK_BYTES_DIR, cls, face.strip_edges().to_lower()]


## The sheet as packed for the device. Null when the bytes are missing.
static func image_from_walk_bytes(class_id: String, face: String) -> Image:
	var path := walk_bytes_path(class_id, face)
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	if image.is_empty():
		return null
	# The texture importer runs fix_alpha_edges on the sheet (fix_alpha_border).
	# Raw PNG bytes skip that pass, so frame 0 would not match the tres cell.
	image.fix_alpha_edges()
	return image


## One ImageTexture per cell. Never an AtlasTexture. Fewer than two cells
## is not a walk: a single cell is the idle slide.
static func textures_from_image(image: Image, frame_count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if image == null or image.is_empty() or frame_count <= 0:
		return out
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return out
	var cells := 1
	if width % CELL_W == 0:
		cells = width / CELL_W
	elif width % frame_count == 0:
		cells = frame_count
	if cells < 2:
		return out
	var frame_w := width / cells
	if frame_w <= 0:
		return out
	for i in cells:
		var cut := image.get_region(Rect2i(i * frame_w, 0, frame_w, height))
		if cut == null or cut.is_empty():
			return []
		var tex := ImageTexture.create_from_image(cut)
		if tex == null:
			return []
		out.append(tex)
	return out


## Replace every walk_<n|e|s|w> clip with standalone ImageTextures.
## The packed PNG bytes win. The imported sheet is only a fallback, and it
## is sliced from the full image, not left as AtlasTexture regions.
## Authored attack/cast banks stay. A missing walk sheet leaves the clip loaded.
static func _force_locked_walk_pngs(built: SpriteFrames, class_id: String) -> bool:
	var any := false
	if has_painted_look(class_id):
		# The painted walk is the only walk. An old export_2x clip would be
		# another costume, so a missing painted facing falls to the static.
		var spec := painted_spec(class_id, "walk")
		for face in LETTERS:
			var anim := "walk_%s" % face
			if built.has_animation(anim):
				built.remove_animation(anim)
			var cells := painted_cells(class_id, "walk", face)
			if cells.size() < 2:
				continue
			if _install_clip(built, anim, {
				"textures": cells,
				"fps": float(spec.get("fps", WALK_FPS)),
				"loop": true,
			}):
				any = true
		return any
	for face in LETTERS:
		var textures := _walk_cell_textures(class_id, face)
		if textures.size() < 2:
			continue
		var anim := "walk_%s" % face
		if built.has_animation(anim):
			built.remove_animation(anim)
		if _install_clip(built, anim, {
			"textures": textures,
			"fps": kind_fps("walk"),
			"loop": true,
		}):
			any = true
	return any


static func _walk_cell_textures(class_id: String, face: String) -> Array[Texture2D]:
	if has_painted_look(class_id):
		return painted_cells(class_id, "walk", face)
	var count := walk_sheet_frames(face)
	var packed := image_from_walk_bytes(class_id, face)
	if packed != null:
		var from_bytes := textures_from_image(packed, count)
		if from_bytes.size() >= 2:
			return from_bytes
	var res := try_load(export_png_path(class_id, "walk", face))
	if res is Texture2D:
		var full := (res as Texture2D).get_image()
		if full != null and not full.is_empty():
			return textures_from_image(full, count)
	return []


## Painted action drop. A sheet on disk replaces that clip for its facing.
## Missing sheets leave the export_2x clip (or no clip) exactly as it was.
static func _load_painted_actions(built: SpriteFrames, class_id: String) -> bool:
	var any := false
	for kind in PAINTED_KINDS:
		if kind == "walk":
			continue
		var spec := painted_spec(class_id, kind)
		if spec.is_empty():
			continue
		for face in LETTERS:
			var cells := painted_cells(class_id, kind, face)
			if cells.is_empty():
				continue
			var anim := "%s_%s" % [str(PAINTED_ANIM[kind]), face]
			if built.has_animation(anim):
				built.remove_animation(anim)
			if _install_clip(built, anim, {
				"textures": cells,
				"fps": float(spec.get("fps", ACTION_FPS)),
				"loop": bool(spec.get("loop", kind == "idle")),
			}):
				any = true
			# The old export_2x Mark Shot bow is another costume. Without it
			# Mark Shot takes its existing fallback: the (painted) attack.
			if kind == "attack" and built.has_animation("cast_mark_%s" % face):
				built.remove_animation("cast_mark_%s" % face)
	return any


## Spec of the painted strip that plays as this pawn clip kind, or {}.
static func _painted_action_spec(class_id: String, kind: String) -> Dictionary:
	for painted in PAINTED_KINDS:
		if str(PAINTED_ANIM[painted]) == kind and painted != "walk":
			if painted_cells(class_id, painted, "e").is_empty():
				return {}
			return painted_spec(class_id, painted)
	return {}


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
	var painted := _painted_action_spec(cls, kind)
	if painted.has("impact"):
		return int(painted["impact"])
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
	if not (tex is AtlasTexture):
		return tex
	var atlas := tex as AtlasTexture
	var region := Rect2i(
		int(atlas.region.position.x),
		int(atlas.region.position.y),
		int(atlas.region.size.x),
		int(atlas.region.size.y)
	)
	var direct := tex.get_image()
	# A real cell is already the region. A device AtlasTexture often hands back
	# the whole sheet for every frame, which paints one pose for the cycle.
	if direct != null and not direct.is_empty() and direct.get_width() <= region.size.x and direct.get_height() <= region.size.y:
		return ImageTexture.create_from_image(direct)
	var sheet := direct
	if atlas.atlas != null:
		var full := atlas.atlas.get_image()
		if full != null and not full.is_empty():
			sheet = full
	if sheet == null or sheet.is_empty():
		return tex
	var cut := region.intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
	if cut.size.x <= 0 or cut.size.y <= 0:
		return tex
	return ImageTexture.create_from_image(sheet.get_region(cut))


## Foot-down cell for this facing. Frame 0 when that cell already shares the
## planted row. Another index only when frame 0's feet are off that row.
## Scoring happens on the authored cells, before the foot shift.
static func walk_contact_index(class_id: String, face: String) -> int:
	var cls := SpellKits.normalize_class_id(class_id)
	var letter := letter_for_sheet(face)
	if letter == "":
		letter = face.strip_edges().to_lower()
	return int(_walk_contact.get("%s:%s" % [cls, letter], 0))


## A sole tip 1–2px under the plant is the same row. v5 Ironjaw east/west
## puts two alpha pixels at y=148 while a passing cell kisses y=150.
## That is not a different contact. A real lift (the old 4–6px hop) still retargets.
const FOOT_ROW_SLACK := 2


## Lowest feet win. Frame 0 stays the contact when it shares that row, so a
## sheet that already plants on 0 is not retargeted. `feet` is the bottom
## opaque row (larger is lower). `heights` is the figure span.
static func contact_index_from_metrics(feet: Array, heights: Array) -> int:
	var n := mini(feet.size(), heights.size())
	if n <= 0:
		return 0
	var lowest := -1
	for i in n:
		lowest = maxi(lowest, int(feet[i]))
	if lowest < 0:
		return 0
	if int(feet[0]) >= lowest - FOOT_ROW_SLACK:
		return 0
	var best := 0
	var best_height := 999999
	for i in n:
		if int(feet[i]) < lowest - FOOT_ROW_SLACK:
			continue
		var span := int(heights[i])
		if span > 0 and span < best_height:
			best_height = span
			best = i
	return best


## Shift passing walk cells so each foot sits on frame 0's contact.
## Frame 0 stays the authored cell. A lifted frame reads as a pop, and a
## foot that drifts inside the cell reads as a skate.
static func _stabilize_walk_feet(frames: SpriteFrames, class_id: String = "") -> void:
	if frames == null:
		return
	var cls := SpellKits.normalize_class_id(class_id)
	for face in LETTERS:
		var anim := "walk_%s" % face
		if not frames.has_animation(anim):
			continue
		var count := frames.get_frame_count(anim)
		if count < 2:
			continue
		var feet: Array = []
		var heights: Array = []
		for i in count:
			var cell := frames.get_frame_texture(anim, i)
			var cell_img := cell.get_image() if cell != null else null
			var metrics := _figure_metrics(cell_img)
			feet.append(metrics.x)
			heights.append(metrics.y)
		if cls != "":
			_walk_contact["%s:%s" % [cls, face]] = contact_index_from_metrics(feet, heights)
		# Painted walks (Look 1, 144x176) plant every frame on the sole line
		# themselves. Pulling every sole back to frame 0 would erase the step.
		var probe := frames.get_frame_texture(anim, 0)
		if probe != null and (probe.get_height() != 160 or is_painted_cell(probe)):
			# Painted 8-frame walk: frame 0 is the right-foot contact.
			if cls != "":
				_walk_contact["%s:%s" % [cls, face]] = 0
			continue
		if face == "e":
			continue
		var base_tex := frames.get_frame_texture(anim, 0)
		if base_tex == null:
			continue
		var base_img := base_tex.get_image()
		if base_img == null or base_img.is_empty():
			continue
		var anchor := _foot_point(base_img)
		if anchor.x < 0:
			continue
		for i in range(1, count):
			var tex := frames.get_frame_texture(anim, i)
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null or img.is_empty():
				continue
			var foot := _foot_point(img)
			if foot.x < 0:
				continue
			var dx := anchor.x - foot.x
			var dy := anchor.y - foot.y
			if dx == 0 and dy == 0:
				continue
			var shifted := _shift_image(img, dx, dy)
			var duration := frames.get_frame_duration(anim, i)
			if duration <= 0.0:
				duration = 1.0
			frames.set_frame(anim, i, ImageTexture.create_from_image(shifted), duration)


static func _figure_metrics(image: Image) -> Vector2i:
	if image == null or image.is_empty():
		return Vector2i(-1, 0)
	var width := image.get_width()
	var height := image.get_height()
	var foot_y := -1
	var head_y := height
	for y in range(height - 1, -1, -1):
		var hit := false
		for x in width:
			if image.get_pixel(x, y).a > 0.08:
				hit = true
				break
		if hit:
			if foot_y < 0:
				foot_y = y
			head_y = y
	if foot_y < 0:
		return Vector2i(-1, 0)
	return Vector2i(foot_y, foot_y - head_y + 1)


## Pin every hit cell's foot row to the walk plant. The recoil stays in the
## pose. The contact row does not pop between the four frames or against idle.
static func _stabilize_hit_feet(frames: SpriteFrames) -> void:
	if frames == null:
		return
	for face in LETTERS:
		var anim := "hit_%s" % face
		if not frames.has_animation(anim):
			continue
		var count := frames.get_frame_count(anim)
		if count <= 0:
			continue
		var anchor_y := _walk_foot_y(frames, face)
		if anchor_y < 0:
			continue
		# Painted hit sheets (Look 1, 144x176) already stand on the sole line.
		var hit_probe := frames.get_frame_texture(anim, 0)
		if hit_probe != null and (hit_probe.get_height() != 160 or is_painted_cell(hit_probe)):
			continue
		# Old 160 hit cell beside a painted walk: frame 0 of the painted walk
		# is a stride, so pin to the old standing row instead.
		var walk_probe := frames.get_frame_texture("walk_%s" % face, 0)
		if walk_probe != null and (walk_probe.get_height() != 160 or is_painted_cell(walk_probe)):
			anchor_y = LEGACY_STAND_ROW
		for i in count:
			var tex := frames.get_frame_texture(anim, i)
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null or img.is_empty():
				continue
			var foot := _foot_point(img)
			if foot.y < 0 or foot.y == anchor_y:
				continue
			var shifted := _shift_image(img, 0, anchor_y - foot.y)
			var duration := frames.get_frame_duration(anim, i)
			if duration <= 0.0:
				duration = 1.0
			frames.set_frame(anim, i, ImageTexture.create_from_image(shifted), duration)


static func _walk_foot_y(frames: SpriteFrames, face: String) -> int:
	var walk := "walk_%s" % face
	if frames == null or not frames.has_animation(walk) or frames.get_frame_count(walk) <= 0:
		return -1
	var tex := frames.get_frame_texture(walk, 0)
	if tex == null:
		return -1
	var img := tex.get_image()
	if img == null or img.is_empty():
		return -1
	return _foot_point(img).y


static func _foot_point(image: Image) -> Vector2i:
	var width := image.get_width()
	var height := image.get_height()
	var foot_y := -1
	for y in range(height - 1, -1, -1):
		var hit := false
		for x in width:
			if image.get_pixel(x, y).a > 0.08:
				hit = true
				break
		if hit:
			foot_y = y
			break
	if foot_y < 0:
		return Vector2i(-1, -1)
	var sum_x := 0
	var count := 0
	var top := maxi(foot_y - 5, 0)
	for y in range(top, foot_y + 1):
		for x in width:
			if image.get_pixel(x, y).a > 0.08:
				sum_x += x
				count += 1
	if count <= 0:
		return Vector2i(-1, -1)
	return Vector2i(int(round(float(sum_x) / float(count))), foot_y)


static func _shift_image(image: Image, dx: int, dy: int) -> Image:
	var width := image.get_width()
	var height := image.get_height()
	var out := Image.create(width, height, false, image.get_format())
	out.fill(Color(0, 0, 0, 0))
	var src := Rect2i(0, 0, width, height)
	var dest := Vector2i(dx, dy)
	if dest.x < 0:
		src.position.x -= dest.x
		src.size.x += dest.x
		dest.x = 0
	if dest.y < 0:
		src.position.y -= dest.y
		src.size.y += dest.y
		dest.y = 0
	if dest.x + src.size.x > width:
		src.size.x = width - dest.x
	if dest.y + src.size.y > height:
		src.size.y = height - dest.y
	if src.size.x > 0 and src.size.y > 0:
		out.blit_rect(image, src, dest)
	return out


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
