extends "res://vfx/vfx_pooled.gd"

## Painted boss effect strips (Technical Artist, boss round 1). One horizontal
## strip of equal cells, played once on the board, or looped while it flies.
## View only. CombatSim never reads this file.
##
## Payload:
##   path     strip PNG
##   frames   cell count
##   anchor   cell pixel that sits on `pos` (the impact point on the floor)
##   fps      frames per second
##   scale    world scale of one cell pixel
##   pos      world point of the anchor (strip mode), or
##   from/to  world points of a flight (fly mode): the strip loops while it
##            travels and is rotated to the flight (art faces +x)
##   arc      lob height in world px (fly mode)
##   duration flight seconds (fly mode)
##   delay    seconds before it shows
##   z        z index
##   loop     true: loop the strip in place until released (lingering tiles)

var _sprite: Sprite2D
var _cells: Array = []
var _fps: float = 15.0
var _wait: float = 0.0
var _age: float = 0.0
var _fly: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _duration: float = 0.3
var _loop: bool = false

static var _cache: Dictionary = {}


## Equal cells of one strip, cached per path. Empty when the file is missing.
static func cells_for(path: String, frames: int) -> Array:
	var key := "%s#%d" % [path, frames]
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	if path != "" and ResourceLoader.exists(path):
		var sheet := load(path) as Texture2D
		if sheet != null and frames > 0:
			var w := float(sheet.get_width()) / float(frames)
			for i in frames:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(w * float(i), 0.0, w, float(sheet.get_height()))
				out.append(atlas)
	_cache[key] = out
	return out


## Strip seconds for a one-shot.
static func play_sec(frames: int, fps: float) -> float:
	return float(maxi(frames, 1)) / maxf(fps, 0.001)


## Point on a lob at u 0..1 (screen up is -y).
static func flight_point(from: Vector2, to: Vector2, arc: float, u: float) -> Vector2:
	var k := clampf(u, 0.0, 1.0)
	return from.lerp(to, k) + Vector2(0.0, -arc * 4.0 * k * (1.0 - k))


func _ready() -> void:
	super._ready()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	set_process(false)


func play(spec: Dictionary) -> void:
	_cells = cells_for(str(spec.get("path", "")), int(spec.get("frames", 1)))
	if _cells.is_empty():
		release()
		return
	_begin()
	_fps = float(spec.get("fps", 15.0))
	_wait = float(spec.get("delay", 0.0))
	_age = 0.0
	_fly = spec.has("from") and spec.has("to")
	_loop = bool(spec.get("loop", false))
	var anchor: Vector2 = spec.get("anchor", Vector2.ZERO)
	_sprite.offset = -anchor
	var s := float(spec.get("scale", 1.0))
	scale = Vector2(s, s)
	z_as_relative = false
	z_index = int(spec.get("z", 0))
	if _fly:
		_from = spec["from"]
		_to = spec["to"]
		_arc = float(spec.get("arc", 0.0))
		_duration = maxf(float(spec.get("duration", 0.3)), 0.05)
		position = _from
	else:
		position = spec.get("pos", Vector2.ZERO)
	_sprite.texture = _cells[0]
	visible = _wait <= 0.0


## A lingering (looping) strip leaves when its tile does: quick fade, then free.
func dismiss() -> void:
	if not in_use:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(release)


func _process(delta: float) -> void:
	if not in_use:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		visible = true
	_age += delta
	var index := int(floor(_age * _fps))
	if _fly:
		var u := _age / _duration
		if u >= 1.0:
			release()
			return
		var here := flight_point(_from, _to, _arc, u)
		var ahead := flight_point(_from, _to, _arc, minf(u + 0.02, 1.0))
		position = here
		if (ahead - here).length_squared() > 0.0001:
			rotation = (ahead - here).angle()
		_sprite.texture = _cells[posmod(index, _cells.size())]
		return
	if _loop:
		_sprite.texture = _cells[posmod(index, _cells.size())]
		return
	if index >= _cells.size():
		release()
		return
	_sprite.texture = _cells[index]
