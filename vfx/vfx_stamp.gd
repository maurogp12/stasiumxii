extends "res://vfx/vfx_pooled.gd"

## One-shot sprite overlay. Hero plates punch in with a scale and fade.
## Hit flash and footstep dust are 3×3 sheets and step one cell at a time.
## The director pools these. CombatSim never reads this file.

const SHEETS := {
	"ambush_slash": "res://art/vfx/scenario/ambush_slash.png",
	"mark_shot_impact": "res://art/vfx/scenario/mark_shot_impact.png",
	"detonate_burst": "res://art/vfx/scenario/detonate_burst.png",
	"hit_flash": "res://art/vfx/scenario/hit_flash.png",
	"footstep_dust": "res://art/vfx/scenario/footstep_dust.png",
}

## Row-major. Anything else is a single hero frame.
const GRIDS := {
	"hit_flash": Vector2i(3, 3),
	"footstep_dust": Vector2i(3, 3),
}

static var _cache: Dictionary = {}

var _sprite: Sprite2D
var _wait: float = 0.0
var _life: float = 0.0
var _span: float = 0.2
var _peak: float = 1.0
var _base_scale: float = 1.0
var _sheet: String = ""
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
	var grid := grid_for(sheet)
	return grid.x * grid.y


static func region_for(sheet: String, index: int, tex: Texture2D = null) -> Rect2:
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
	_sheet = str(spec.get("sheet", ""))
	var tex := texture_for(_sheet)
	if tex == null:
		release()
		return
	_sprite.texture = tex
	var grid := grid_for(_sheet)
	_cols = grid.x
	_rows = grid.y
	_frames = _cols * _rows
	_frame = -1
	# A sheet stamp fills `px` with one cell. A hero frame fills `px` with the plate.
	var cell_w := float(tex.get_width()) / float(_cols)
	var cell_h := float(tex.get_height()) / float(_rows)
	var side := maxf(cell_w, cell_h)
	var px := maxf(float(spec.get("px", VfxBudget.STAMP_HIT_PX)), 1.0)
	_base_scale = px / maxf(side, 1.0)
	position = spec.get("pos", Vector2.ZERO)
	z_as_relative = false
	z_index = int(spec.get("z", 40))
	_peak = clampf(float(spec.get("alpha", 1.0)), 0.0, 1.0)
	_span = maxf(float(spec.get("life", VfxBudget.STAMP_HIT_LIFE)), 0.05)
	_wait = maxf(float(spec.get("delay", 0.0)), 0.0)
	_life = _span
	_sprite.region_enabled = _frames > 1
	if _frames > 1:
		_apply_frame(0)
	else:
		_sprite.region_rect = Rect2()
	_sprite.scale = Vector2.ONE * _base_scale * (1.0 if _frames > 1 else 0.72)
	_sprite.modulate = Color(1, 1, 1, 0)
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


func _process(delta: float) -> void:
	if not in_use:
		return
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
		var idx := mini(int(t * float(_frames)), _frames - 1)
		_apply_frame(idx)
		var fade_start := float(_frames - 1) / float(_frames)
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
	if _sprite != null:
		_sprite.visible = false
		_sprite.region_enabled = false
		_sprite.texture = null
	_wait = 0.0
	_life = 0.0
	_frames = 1
	_frame = -1
	_sheet = ""
	super.release()
