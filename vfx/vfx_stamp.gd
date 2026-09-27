extends "res://vfx/vfx_pooled.gd"

## One-shot sprite overlay. Strips play left to right.
## Punch v3: Ambush slash, hit flash, damage float, Detonate, footstep dust,
## and the melee windup. The hit flash keeps the authored cyan/gold.
## Mark Shot impact stays punch v2. The bow windup is the v4 transparent
## strip (scenario asset_bXoujAQYZwDDQJQNGL2ouD7M). #175 holds stay locked
## at 70+80+80+70. Cells are draw, snap burst, reticle peak, arrow-tip release.
## Mark Shot's lower band is three stack sigils. The one-shot does not play
## them: Marks still count on the existing pips (cap 5).
## Mark Shot cast is four equal cells. Holds are absolute seconds. A longer
## life does not stretch them.
## The bow ink sits above the cell center, so the offset drops it onto the hands.
## CombatSim never reads this file.

const SHEETS := {
	"ambush_slash": "res://art/vfx/scenario/ambush_slash.png",
	"mark_shot_impact": "res://art/vfx/scenario/mark_shot_impact.png",
	"mark_shot_cast": "res://art/vfx/scenario/mark_shot_cast.png",
	"detonate_burst": "res://art/vfx/scenario/detonate_burst.png",
	"hit_flash": "res://art/vfx/scenario/hit_flash.png",
	"damage_float": "res://art/vfx/scenario/damage_float.png",
	"footstep_dust": "res://art/vfx/scenario/footstep_dust.png",
	"melee_windup": "res://art/vfx/scenario/melee_windup.png",
}

## Equal grids. Punch-v2 strips are not equal cells, so they live in STRIPS.
## Mark Shot cast is four equal cells across the plate.
## A sheet missing from both maps is one hero plate.
const GRIDS := {
	"mark_shot_cast": Vector2i(4, 1),
}

## Locked bow windup, in milliseconds. 70 + 80 + 80 + 70 = 300.
## Integers so the snap does not drift past 0.30s. Not tile time, not the body clip.
const FRAME_MS := {
	"mark_shot_cast": [70, 80, 80, 70],
}

## Texture pixels that move the bow ink (above the cell center) onto the
## hand anchor. Positive Y drops the ink. The feet stay empty.
const INK_OFFSET := {
	"mark_shot_cast": Vector2(0, 26),
}

## Measured opaque frames, left to right, with a shared vertical band so a
## shrinking frame stays planted instead of drifting. Padding keeps the
## linear filter off the neighboring cell.
const STRIPS := {
	"ambush_slash": [
		Rect2(31, 225, 166, 250),
		Rect2(216, 225, 179, 250),
		Rect2(395, 225, 213, 250),
		Rect2(608, 225, 151, 250),
		Rect2(777, 225, 171, 250),
		Rect2(948, 225, 161, 250),
		Rect2(1109, 225, 146, 250),
	],
	"hit_flash": [
		Rect2(76, 232, 64, 222),
		Rect2(215, 232, 193, 222),
		Rect2(428, 232, 209, 222),
		Rect2(661, 232, 204, 222),
		Rect2(891, 232, 186, 222),
		Rect2(1135, 232, 84, 222),
	],
	"damage_float": [
		Rect2(22, 177, 160, 312),
		Rect2(203, 177, 166, 312),
		Rect2(392, 177, 188, 312),
		Rect2(583, 177, 268, 312),
		Rect2(858, 177, 237, 312),
		Rect2(1104, 177, 144, 312),
	],
	"footstep_dust": [
		Rect2(61, 265, 107, 184),
		Rect2(222, 265, 167, 184),
		Rect2(416, 265, 221, 184),
		Rect2(659, 265, 202, 184),
		Rect2(892, 265, 160, 184),
	],
	# Gray guide columns between cells are not frames.
	"detonate_burst": [
		Rect2(42, 165, 133, 353),
		Rect2(221, 165, 199, 353),
		Rect2(429, 165, 208, 353),
		Rect2(644, 165, 205, 353),
		Rect2(865, 165, 191, 353),
		Rect2(1109, 165, 135, 353),
	],
	"melee_windup": [
		Rect2(30, 165, 252, 355),
		Rect2(337, 165, 279, 355),
		Rect2(656, 165, 271, 355),
		Rect2(964, 165, 312, 355),
	],
	# Floor rings opening into the burst, then closing. Not the sigil row.
	"mark_shot_impact": [
		Rect2(42, 112, 105, 211),
		Rect2(183, 112, 129, 211),
		Rect2(348, 112, 145, 211),
		Rect2(524, 112, 159, 211),
		Rect2(708, 112, 151, 211),
		Rect2(889, 112, 120, 211),
		Rect2(1044, 112, 97, 211),
	],
}

static var _cache: Dictionary = {}

var _sprite: Sprite2D
var _follow: Callable = Callable()
var _wait: float = 0.0
var _life: float = 0.0
var _span: float = 0.2
var _peak: float = 1.0
var _base_scale: float = 1.0
var _sheet: String = ""
var _holds: Array = []
var _frames: int = 1
var _cols: int = 1
var _rows: int = 1
var _frame: int = -1


static func texture_for(sheet: String) -> Texture2D:
	if _cache.has(sheet) and _cache[sheet] is Texture2D:
		return _cache[sheet]
	var path := str(SHEETS.get(sheet, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		_cache[sheet] = tex
	return tex


static func grid_for(sheet: String) -> Vector2i:
	var grid: Vector2i = GRIDS.get(sheet, Vector2i.ONE)
	return Vector2i(maxi(grid.x, 1), maxi(grid.y, 1))


static func frame_count(sheet: String) -> int:
	if FRAME_MS.has(sheet):
		return (FRAME_MS[sheet] as Array).size()
	if STRIPS.has(sheet):
		return (STRIPS[sheet] as Array).size()
	var grid := grid_for(sheet)
	return grid.x * grid.y


static func holds_for(sheet: String) -> Array:
	var out: Array = []
	if not FRAME_MS.has(sheet):
		return out
	for raw in FRAME_MS[sheet]:
		out.append(float(int(raw)) / 1000.0)
	return out


## Sum of the locked holds. Zero when the sheet is not a timed windup.
static func windup_sec(sheet: String) -> float:
	if not FRAME_MS.has(sheet):
		return 0.0
	var ms := 0
	for raw in FRAME_MS[sheet]:
		ms += int(raw)
	return float(ms) / 1000.0


## Frame index at `elapsed` seconds. The next cell starts on the millisecond
## boundary, so the bolt can leave on the tick after the arrow-tip release.
static func frame_at(sheet: String, elapsed: float) -> int:
	if not FRAME_MS.has(sheet):
		return 0
	var frames: Array = FRAME_MS[sheet]
	var ms := int(round(elapsed * 1000.0))
	var acc := 0
	for i in frames.size():
		acc += int(frames[i])
		if ms < acc:
			return i
	return frames.size() - 1


## Longest side of the biggest played frame. `px` maps to that side, so a
## smaller cel in the strip stays smaller and transparent padding does not
## shrink the punch.
static func span_for(sheet: String, tex: Texture2D = null) -> float:
	if STRIPS.has(sheet):
		var span := 1.0
		for raw in STRIPS[sheet]:
			var rect: Rect2 = raw
			span = maxf(span, maxf(rect.size.x, rect.size.y))
		return span
	var image_tex := tex if tex != null else texture_for(sheet)
	if image_tex == null:
		return 1.0
	var grid := grid_for(sheet)
	return maxf(float(image_tex.get_width()) / float(grid.x), float(image_tex.get_height()) / float(grid.y))


static func region_for(sheet: String, index: int, tex: Texture2D = null) -> Rect2:
	if STRIPS.has(sheet):
		var frames: Array = STRIPS[sheet]
		if frames.is_empty():
			return Rect2()
		return frames[clampi(index, 0, frames.size() - 1)]
	var image_tex := tex if tex != null else texture_for(sheet)
	if image_tex == null:
		return Rect2()
	var grid := grid_for(sheet)
	var count := grid.x * grid.y
	var idx := clampi(index, 0, count - 1)
	var col := idx % grid.x
	var row := int(idx / grid.x)
	var fw := float(image_tex.get_width()) / float(grid.x)
	var fh := float(image_tex.get_height()) / float(grid.y)
	return Rect2(float(col) * fw, float(row) * fh, fw, fh)


func _ready() -> void:
	super._ready()
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.visible = false
	add_child(_sprite)


func prewarm() -> void:
	super.prewarm()
	for sheet in SHEETS.keys():
		texture_for(str(sheet))


func play(spec: Dictionary) -> void:
	_begin()
	_follow = Callable()
	if _sprite != null:
		_sprite.flip_h = false
	_sheet = str(spec.get("sheet", ""))
	var tex := texture_for(_sheet)
	if tex == null:
		release()
		return
	_sprite.texture = tex
	_frames = frame_count(_sheet)
	var grid := grid_for(_sheet)
	_cols = _frames if STRIPS.has(_sheet) else grid.x
	_rows = 1 if STRIPS.has(_sheet) else grid.y
	_frame = -1
	# A strip fills `px` with its largest frame. A hero plate fills `px` whole.
	var side := span_for(_sheet, tex)
	var px := maxf(float(spec.get("px", VfxBudget.STAMP_HIT_PX)), 1.0)
	_base_scale = px / maxf(side, 1.0)
	position = spec.get("pos", Vector2.ZERO)
	z_as_relative = false
	z_index = int(spec.get("z", 40))
	_peak = clampf(float(spec.get("alpha", 1.0)), 0.0, 1.0)
	_holds = holds_for(_sheet)
	var locked := windup_sec(_sheet)
	# Authored holds win. A cast window or a tile time must not stretch the snap.
	_span = locked if locked > 0.0 else maxf(float(spec.get("life", VfxBudget.STAMP_HIT_LIFE)), 0.05)
	_wait = maxf(float(spec.get("delay", 0.0)), 0.0)
	_life = _span
	_sprite.region_enabled = _frames > 1
	if _frames > 1:
		_apply_frame(0)
	else:
		_sprite.region_rect = Rect2()
	_sprite.scale = Vector2.ONE * _base_scale * (1.0 if _frames > 1 else 0.72)
	_sprite.modulate = Color(1, 1, 1, 0)
	_sprite.offset = INK_OFFSET.get(_sheet, Vector2.ZERO)
	_sprite.flip_h = bool(spec.get("flip_h", false))
	var follow: Variant = spec.get("follow", Callable())
	if follow is Callable and (follow as Callable).is_valid():
		_follow = follow
		_follow_hand()
	if _wait > 0.0:
		_sprite.visible = false
		return
	_kick()


func _apply_frame(index: int) -> void:
	var idx := clampi(index, 0, _frames - 1)
	if idx == _frame and _sprite.region_enabled:
		return
	_frame = idx
	_sprite.region_rect = region_for(_sheet, idx, _sprite.texture)


func _kick() -> void:
	_sprite.visible = true
	_sample(0.0)


func _follow_hand() -> void:
	if not _follow.is_valid():
		return
	var at: Variant = _follow.call()
	if at is Vector2:
		position = at


func _process(delta: float) -> void:
	if not in_use:
		return
	_follow_hand()
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = 0.0
		_kick()
		return
	_life -= delta
	var t := 1.0 - clampf(_life / _span, 0.0, 1.0)
	_sample(t)
	if _life <= 0.0:
		release()


func _sample(t: float) -> void:
	if _frames > 1:
		var elapsed := clampf(t, 0.0, 1.0) * _span
		var idx := frame_at(_sheet, elapsed) if not _holds.is_empty() else mini(int(t * float(_frames)), _frames - 1)
		_apply_frame(idx)
		var fade_start := float(_frames - 1) / float(_frames)
		if not _holds.is_empty() and _span > 0.0:
			var lead := _span - float(_holds[_holds.size() - 1])
			fade_start = lead / _span
		var fade := 1.0
		if t > fade_start:
			fade = clampf((1.0 - t) / maxf(1.0 - fade_start, 0.0001), 0.0, 1.0)
		_sprite.scale = Vector2.ONE * _base_scale
		_sprite.modulate = Color(1, 1, 1, _peak * fade)
		return
	var pop := clampf(t / 0.22, 0.0, 1.0)
	var fade_hero := 1.0
	if t > 0.35:
		fade_hero = clampf((1.0 - t) / 0.65, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * _base_scale * lerpf(0.72, 1.0, pop)
	_sprite.modulate = Color(1, 1, 1, _peak * pop * fade_hero)


func release() -> void:
	_follow = Callable()
	if _sprite != null:
		_sprite.visible = false
		_sprite.flip_h = false
		_sprite.offset = Vector2.ZERO
		_sprite.region_enabled = false
		_sprite.texture = null
	_wait = 0.0
	_life = 0.0
	_holds = []
	_frames = 1
	_frame = -1
	_sheet = ""
	super.release()
