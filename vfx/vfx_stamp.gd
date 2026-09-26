extends "res://vfx/vfx_pooled.gd"

## One-shot sprite overlay. Scenario plates are keyed and phone-sized.
## The director pools these. CombatSim never reads this file.

const SHEETS := {
	"ambush_slash": "res://art/vfx/scenario/ambush_slash.png",
	"mark_shot_impact": "res://art/vfx/scenario/mark_shot_impact.png",
	"detonate_burst": "res://art/vfx/scenario/detonate_burst.png",
	"hit_flash": "res://art/vfx/scenario/hit_flash.png",
	"footstep_dust": "res://art/vfx/scenario/footstep_dust.png",
}

static var _cache: Dictionary = {}

var _sprite: Sprite2D
var _wait: float = 0.0
var _life: float = 0.0
var _span: float = 0.2
var _peak: float = 1.0
var _base_scale: float = 1.0


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
	var tex := texture_for(str(spec.get("sheet", "")))
	if tex == null:
		release()
		return
	_sprite.texture = tex
	var side := maxf(float(tex.get_width()), float(tex.get_height()))
	var px := maxf(float(spec.get("px", VfxBudget.STAMP_HIT_PX)), 1.0)
	_base_scale = px / maxf(side, 1.0)
	position = spec.get("pos", Vector2.ZERO)
	z_as_relative = false
	z_index = int(spec.get("z", 40))
	_peak = clampf(float(spec.get("alpha", 1.0)), 0.0, 1.0)
	_span = maxf(float(spec.get("life", VfxBudget.STAMP_HIT_LIFE)), 0.05)
	_wait = maxf(float(spec.get("delay", 0.0)), 0.0)
	_life = _span
	_sprite.scale = Vector2.ONE * _base_scale * 0.72
	_sprite.modulate = Color(1, 1, 1, 0)
	if _wait > 0.0:
		_sprite.visible = false
		return
	_kick()


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
	var pop := clampf(t / 0.22, 0.0, 1.0)
	var fade := 1.0
	if t > 0.35:
		fade = clampf((1.0 - t) / 0.65, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * _base_scale * lerpf(0.72, 1.0, pop)
	_sprite.modulate = Color(1, 1, 1, _peak * pop * fade)


func release() -> void:
	if _sprite != null:
		_sprite.visible = false
	_wait = 0.0
	_life = 0.0
	super.release()
