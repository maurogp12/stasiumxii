extends Node2D

## VIEW ONLY. The player avatar walking Crosshaven. Paths come from
## `WorldWalk.find_path`; this node only animates along them.
## `advance(delta)` is public so tests can step it deterministically.

signal stepped(cell: Vector2i)
signal arrived(cell: Vector2i)

const SPRITE_ROOT := "res://art/characters/kestrel/kestrel_%s.png"
const SPRITE_SCALE := 0.55
const FOOT_Y := 155.0
const STEP_TIME := 0.22

var zone: WorldZone
var cell := Vector2i.ZERO
var facing := "s"
var auto_advance := true

var _path: Array[Vector2i] = []
var _from := Vector2i.ZERO
var _to := Vector2i.ZERO
var _t := 0.0
var _moving := false
var _sprite: Sprite2D
var _textures: Dictionary = {}


func _ready() -> void:
	z_as_relative = false
	for dir in ["n", "e", "s", "w"]:
		var path := SPRITE_ROOT % dir
		if ResourceLoader.exists(path):
			_textures[dir] = load(path)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_apply_facing()


func place(target_zone: WorldZone, at: Vector2i) -> void:
	zone = target_zone
	cell = at
	_path.clear()
	_moving = false
	_from = at
	_to = at
	position = _cell_pos(at)
	z_index = _z_for(at)
	queue_redraw()


func is_moving() -> bool:
	return _moving or not _path.is_empty()


## Cell the walker will stand on once its current step finishes.
func anchor_cell() -> Vector2i:
	return _to if _moving else cell


## `steps` excludes the anchor cell.
func walk(steps: Array[Vector2i]) -> void:
	_path = steps.duplicate()
	if not _moving:
		_t = 0.0
		_next_step()


func stop() -> void:
	_path.clear()


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func advance(delta: float) -> void:
	if not _moving:
		return
	_t += delta / STEP_TIME
	while _moving and _t >= 1.0:
		var carry := _t - 1.0
		cell = _to
		position = _cell_pos(cell)
		z_index = _z_for(cell)
		stepped.emit(cell)
		if _path.is_empty():
			_moving = false
			_t = 0.0
			_sprite.position = _sprite_offset()
			arrived.emit(cell)
			return
		_next_step()
		_t = carry
	position = _cell_pos(_from).lerp(_cell_pos(_to), _t)
	var bob := -absf(sin(_t * PI)) * 3.0
	_sprite.position = _sprite_offset() + Vector2(0, bob)


func _next_step() -> void:
	if _path.is_empty():
		return
	_from = cell
	_to = _path.pop_front()
	_moving = true
	var d := _to - _from
	if d.x > 0:
		facing = "e"
	elif d.x < 0:
		facing = "w"
	elif d.y > 0:
		facing = "s"
	elif d.y < 0:
		facing = "n"
	_apply_facing()
	z_index = maxi(_z_for(_from), _z_for(_to))


func _z_for(c: Vector2i) -> int:
	return (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS


func _cell_pos(c: Vector2i) -> Vector2:
	if zone == null:
		return BoardVisualSort.cell_to_local(c)
	return BoardVisualSort.cell_to_local(c, float(zone.height_at(c)))


func _sprite_offset() -> Vector2:
	var tex: Texture2D = _textures.get(facing, null)
	var w := tex.get_size().x if tex != null else 144.0
	return Vector2(-w * 0.5 * SPRITE_SCALE, -FOOT_Y * SPRITE_SCALE)


func _apply_facing() -> void:
	if _sprite == null:
		return
	_sprite.texture = _textures.get(facing, null)
	_sprite.position = _sprite_offset()


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a) * 15.0, sin(a) * 6.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
	if _textures.is_empty():
		draw_circle(Vector2(0, -24), 10, Color("3f7d4a"))
