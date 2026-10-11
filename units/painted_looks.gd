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
## Visible gear (paper doll): a class switched on in data/pc/gear_looks.json
## draws its unarmoured base body (units/pc_gear_specs.gd) instead of its
## locked look; units/gear_looks.gd stacks the worn gear on it.
const GEAR_SPECS := preload("res://units/pc_gear_specs.gd")
const GEAR_DATA := "res://data/pc/gear_looks.json"
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
## Meta key on each pawn cell: [class, kind, letter, index] (gear layers follow it).
const KEY_META := "painted_key"

static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}
static var _frames: Dictionary = {}
static var _gear_roots = null


static func clear_cache() -> void:
	_sheets.clear()
	_cells.clear()
	_frames.clear()
	_gear_roots = null


## class -> "res://.../base/<class>_base" prefix for classes drawing the
## paper-doll base (on in the data and built), else absent.
static func _gear_base_prefix(class_id: String) -> String:
	if _gear_roots == null:
		_gear_roots = {}
		if FileAccess.file_exists(GEAR_DATA):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEAR_DATA))
			if parsed is Dictionary:
				var classes: Variant = (parsed as Dictionary).get("classes", {})
				if classes is Dictionary:
					for cls in (classes as Dictionary).keys():
						var row: Variant = (classes as Dictionary)[cls]
						if row is Dictionary and bool((row as Dictionary).get("enabled", false)) and GEAR_SPECS.SPECS.has(cls):
							var base := str((row as Dictionary).get("base", "base"))
							_gear_roots[cls] = "%s%s/%s_%s" % [str((row as Dictionary).get("root", "")), base, cls, base]
	return str((_gear_roots as Dictionary).get(class_id, ""))


## True when the class draws the paper-doll base body.
static func uses_gear_base(class_id: String) -> bool:
	return _gear_base_prefix(class_id.strip_edges().to_lower()) != ""


static func _specs_of(class_id: String) -> Dictionary:
	return GEAR_SPECS.SPECS if uses_gear_base(class_id) else SPECS.SPECS


static func has_class(class_id: String) -> bool:
	return SPECS.SPECS.has(class_id.strip_edges().to_lower())


static func spec(class_id: String, kind: String) -> Dictionary:
	var row: Variant = _specs_of(class_id.strip_edges().to_lower()).get(class_id.strip_edges().to_lower(), {})
	if not (row is Dictionary):
		return {}
	var s: Variant = (row as Dictionary).get(kind, {})
	return s if s is Dictionary else {}


static func world(class_id: String) -> Dictionary:
	var cls := class_id.strip_edges().to_lower()
	var row: Variant = (GEAR_SPECS.WORLD if uses_gear_base(cls) else SPECS.WORLD).get(cls, {})
	return row if row is Dictionary else {}


static func art_letter(letter: String) -> String:
	return str(SPECS.ART_LETTER.get(letter.strip_edges().to_lower(), "S"))


static func mirrored(letter: String) -> bool:
	return bool(SPECS.MIRRORED.get(letter.strip_edges().to_lower(), false))


static func sheet_path(class_id: String, kind: String, art: String) -> String:
	var cls := class_id.strip_edges().to_lower()
	var gear := _gear_base_prefix(cls)
	if gear != "":
		return "%s_%s_%s.png" % [gear, kind, art]
	return "%s%s/%s_%s_%s.png" % [ROOT, cls, cls, kind, art]


static func cell_of(class_id: String, kind: String) -> Vector2i:
	return spec(class_id, kind).get("cell", Vector2i.ZERO)


static func frame_count(class_id: String, kind: String) -> int:
	return int(spec(class_id, kind).get("frames", 0))


## Ground point of the cell for a letter, texture px (already mirrored for s, w).
static func pivot_of(class_id: String, kind: String, letter: String) -> Vector2i:
	return pivot_from(spec(class_id, kind), letter)


static func pivot_from(s: Dictionary, letter: String) -> Vector2i:
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
	out = cut_cells(src, cell_of(class_id, kind), frame_count(class_id, kind), pivot_of(class_id, kind, letter), mirrored(letter))
	for i in out.size():
		out[i].set_meta(KEY_META, [class_id.strip_edges().to_lower(), kind, letter.strip_edges().to_lower(), i])
	_cells[key] = out
	return out


## Cells of one sheet row as AtlasTextures (a mirrored copy for s and w), each
## carrying its ground point (CELL_PIVOT_META) and PAINTED_META.
static func cut_cells(src: Texture2D, size: Vector2i, count: int, pivot: Vector2i, mirror: bool) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if src == null or count <= 0 or size.x <= 0:
		return out
	var atlas: Texture2D = src
	if mirror:
		var image := src.get_image()
		if image == null or image.is_empty():
			return out
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.flip_x()
		# Mirror each cell in place: flip_x reversed the cell order too.
		var fixed := Image.create(image.get_width(), image.get_height(), false, image.get_format())
		for i in count:
			fixed.blit_rect(image, Rect2i((count - 1 - i) * size.x, 0, size.x, size.y), Vector2i(i * size.x, 0))
		atlas = ImageTexture.create_from_image(fixed)
	for i in count:
		var piece := AtlasTexture.new()
		piece.atlas = atlas
		piece.region = Rect2(i * size.x, 0, size.x, size.y)
		piece.set_meta(CELL_PIVOT_META, pivot)
		piece.set_meta(PAINTED_META, true)
		out.append(piece)
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
