extends RefCounted

## PC painted character sheets (the locked looks of 4 Oct 2026), shared by the
## dungeon pawn and the world walker. Built by
## `build_tools/pc_characters/build_pc_characters.py`, which also writes the
## table this reads (`units/pc_character_specs.gd`).
##
## Files: `art/characters/painted/<class>/<class>_<kind>_<S|E>.png`, one row of
## equal cells. kind is walk, idle, attack, skill, hit or death. S is the front
## (down-right, letter e), E the back (up-right, letter n). Letters s and w are
## their mirrors: the world flips the sprite, the pawn gets a mirrored copy of
## the sheet (pawn mirrors are baked, it never sets flip_h).
## Every cell is at most MAX_CELL px a side. A sheet whose size does not match
## its spec, or whose cell is over the cap, is not loaded.
## Only what is asked for is loaded: the world asks for one class (the hero),
## the dungeon for its hero's class.

const SPECS := preload("res://units/pc_character_specs.gd")
const ROOT := "res://art/characters/painted/"
const KINDS: Array[String] = ["walk", "idle", "attack", "skill", "hit", "death"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
## Pawn clip name per painted kind. The skill plays where the board asks for a cast.
const PAWN_ANIM := {
	"walk": "walk",
	"idle": "idle",
	"attack": "attack",
	"skill": "cast",
	"hit": "hit",
	"death": "death",
}
## Meta key on each pawn cell: its ground point in texture px (Vector2i).
const CELL_PIVOT_META := "cell_pivot"
## Meta key on each pawn cell: true (painted, not an export_2x strip).
const PAINTED_META := "painted_cell"

static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}
static var _frames: Dictionary = {}


static func clear_cache() -> void:
	_sheets.clear()
	_cells.clear()
	_frames.clear()


static func has_class(class_id: String) -> bool:
	return SPECS.SPECS.has(class_id.strip_edges().to_lower())


static func spec(class_id: String, kind: String) -> Dictionary:
	var row: Variant = SPECS.SPECS.get(class_id.strip_edges().to_lower(), {})
	if not (row is Dictionary):
		return {}
	var s: Variant = (row as Dictionary).get(kind, {})
	return s if s is Dictionary else {}


static func world(class_id: String) -> Dictionary:
	var row: Variant = SPECS.WORLD.get(class_id.strip_edges().to_lower(), {})
	return row if row is Dictionary else {}


static func art_letter(letter: String) -> String:
	return str(SPECS.ART_LETTER.get(letter.strip_edges().to_lower(), "S"))


static func mirrored(letter: String) -> bool:
	return bool(SPECS.MIRRORED.get(letter.strip_edges().to_lower(), false))


static func sheet_path(class_id: String, kind: String, art: String) -> String:
	var cls := class_id.strip_edges().to_lower()
	return "%s%s/%s_%s_%s.png" % [ROOT, cls, cls, kind, art]


static func cell_of(class_id: String, kind: String) -> Vector2i:
	return spec(class_id, kind).get("cell", Vector2i.ZERO)


static func frame_count(class_id: String, kind: String) -> int:
	return int(spec(class_id, kind).get("frames", 0))


## Ground point of the cell for a letter, texture px (already mirrored for s, w).
static func pivot_of(class_id: String, kind: String, letter: String) -> Vector2i:
	var s := spec(class_id, kind)
	var cell: Vector2i = s.get("cell", Vector2i.ZERO)
	var pivots: Variant = s.get("pivots", {})
	var key := letter.strip_edges().to_lower()
	if pivots is Dictionary and (pivots as Dictionary).has(key):
		return (pivots as Dictionary)[key]
	return Vector2i(cell.x / 2, 152)


## The S or E sheet as drawn (no mirror), or null when missing or the wrong size.
static func sheet(class_id: String, kind: String, art: String) -> Texture2D:
	var path := sheet_path(class_id, kind, art)
	if _sheets.has(path):
		var hit: Variant = _sheets[path]
		return hit if hit is Texture2D else null
	var tex: Texture2D = null
	var s := spec(class_id, kind)
	var cell: Vector2i = s.get("cell", Vector2i.ZERO)
	var count := int(s.get("frames", 0))
	var cap := int(SPECS.MAX_CELL)
	if cell.x > 0 and cell.y > 0 and cell.x <= cap and cell.y <= cap and count > 0 and ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D:
			var t := loaded as Texture2D
			if t.get_width() == cell.x * count and t.get_height() == cell.y:
				tex = t
	_sheets[path] = tex if tex != null else false
	return tex


## Pawn cells for one kind and letter, each an AtlasTexture of the sheet (a
## mirrored copy for s and w) carrying its ground point as CELL_PIVOT_META.
static func cells(class_id: String, kind: String, letter: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var key := "%s|%s|%s" % [class_id.strip_edges().to_lower(), kind, letter.strip_edges().to_lower()]
	if _cells.has(key):
		out.assign(_cells[key])
		return out
	_cells[key] = []
	var src := sheet(class_id, kind, art_letter(letter))
	if src == null:
		return out
	var atlas: Texture2D = src
	if mirrored(letter):
		var image := src.get_image()
		if image == null or image.is_empty():
			return out
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.flip_x()
		# Mirror each cell in place: flip_x reversed the cell order too.
		var cell := cell_of(class_id, kind)
		var count := frame_count(class_id, kind)
		var fixed := Image.create(image.get_width(), image.get_height(), false, image.get_format())
		for i in count:
			fixed.blit_rect(image, Rect2i((count - 1 - i) * cell.x, 0, cell.x, cell.y), Vector2i(i * cell.x, 0))
		atlas = ImageTexture.create_from_image(fixed)
	var size := cell_of(class_id, kind)
	var pivot := pivot_of(class_id, kind, letter)
	for i in frame_count(class_id, kind):
		var piece := AtlasTexture.new()
		piece.atlas = atlas
		piece.region = Rect2(i * size.x, 0, size.x, size.y)
		piece.set_meta(CELL_PIVOT_META, pivot)
		piece.set_meta(PAINTED_META, true)
		out.append(piece)
	_cells[key] = out
	return out


static func is_painted_cell(tex: Texture2D) -> bool:
	return tex != null and bool(tex.get_meta(PAINTED_META, false))


## Every painted clip for the dungeon pawn: `<anim>_<letter>` per PAWN_ANIM.
## Null when the class has no painted walk on disk.
static func pawn_frames(class_id: String) -> SpriteFrames:
	var cls := class_id.strip_edges().to_lower()
	if _frames.has(cls):
		var hit: Variant = _frames[cls]
		return hit if hit is SpriteFrames else null
	var built: SpriteFrames = null
	if has_class(cls) and sheet(cls, "walk", "S") != null:
		built = SpriteFrames.new()
		for kind in KINDS:
			var s := spec(cls, kind)
			if s.is_empty():
				continue
			for letter in LETTERS:
				var list := cells(cls, kind, letter)
				if list.is_empty():
					continue
				var anim := "%s_%s" % [PAWN_ANIM[kind], letter]
				built.add_animation(anim)
				built.set_animation_speed(anim, float(s.get("fps", SPECS.AUTHORED_FPS)))
				built.set_animation_loop(anim, bool(s.get("loop", kind == "walk" or kind == "idle")))
				for tex in list:
					built.add_frame(anim, tex)
		if built.has_animation("default"):
			built.remove_animation("default")
	_frames[cls] = built if built != null else false
	return built


## Pawn walk playback over the authored fps: frames_per_tile cells every
## board tile (`tile_sec`). The spec caps it at MAX_LEG_RATE.
static func pawn_walk_speed_scale(class_id: String, tile_sec: float) -> float:
	var s := spec(class_id, "walk")
	var per_tile := float(s.get("frames_per_tile", 0.0))
	var fps := float(s.get("fps", SPECS.AUTHORED_FPS))
	if per_tile <= 0.0 or fps <= 0.0 or tile_sec <= 0.0:
		return 1.0
	return per_tile / (tile_sec * fps)


## 0-based impact cell of an attack or skill, -1 when the spec has none.
static func impact_frame(class_id: String, kind: String) -> int:
	return int(spec(class_id, kind).get("impact", -1))
