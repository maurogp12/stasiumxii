extends Node2D
class_name PcWorldWalker

## PC world body for a class that has a character set.
## Draw scale is the json world_draw_scale (draw_scale × 0.92). Feet stay on this node's
## origin: centered is off, offset is -pivot from the json, per state and facing.
## Walk frames advance by distance, using that world scale. Idle, attack and
## cast play on the json fps. Four baked facings, never flip_h.
## The sprite takes the 4.5a Crosshaven world light. The L7 rim sits on top
## of whichever frame is showing. Y-sort stays on the feet, including death.

const CHARS := preload("res://units/pc/pc_characters.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const WORLD_LIGHT := preload("res://scenes/pc/pc_world_light.gdshader")

var class_id := ""
var facing := "E"
var state := "idle"

var _sprite: Sprite2D
var _rim: Sprite2D
var _frame := 0
var _clock := 0.0
var _distance := 0.0


func setup(id: String) -> bool:
	class_id = SpellKits.normalize_class_id(id)
	if not CHARS.has_set(class_id):
		return false
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_sprite.flip_h = false
		var mat := ShaderMaterial.new()
		mat.shader = WORLD_LIGHT
		_sprite.material = mat
		add_child(_sprite)
		_rim = Sprite2D.new()
		_rim.name = "LookRim"
		_rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_rim.flip_h = false
		_rim.z_index = -1
		_rim.z_as_relative = true
		_rim.scale = Vector2(1.18, 1.18)
		_rim.position = Vector2(-8, -10)
		var tint := LIGHT.OUTDOOR_RIM
		tint.a = LIGHT.OUTDOOR_RIM_STRENGTH
		_rim.modulate = tint
		_sprite.add_child(_rim)
	_show("idle", 0)
	return true


func base_scale() -> float:
	return CHARS.world_scale(class_id)


func face(dir: String) -> void:
	var next := dir.strip_edges().to_upper()
	if next != "N" and next != "E" and next != "S" and next != "W":
		return
	facing = next
	_show(state, _frame)


## Idle, attack and cast advance on the clock. Walk ignores the clock.
func show_state(next: String) -> void:
	_clock = 0.0
	_distance = 0.0
	_show(next, 0)


## Board pixels travelled at the world draw scale. Walk only.
func set_travel_px(board_px: float) -> void:
	state = "walk"
	_distance = maxf(board_px, 0.0)
	_frame = CHARS.walk_frame_index(class_id, facing, _distance, base_scale())
	_apply()


func frame_index() -> int:
	return _frame


func _process(delta: float) -> void:
	if _sprite == null or state == "walk":
		return
	if not CHARS.loops(class_id, state) and _frame >= CHARS.frame_count(class_id, state) - 1:
		return
	var fps := CHARS.fps_of(class_id, state)
	if fps <= 0.0:
		return
	_clock += delta
	var count := maxi(CHARS.frame_count(class_id, state), 1)
	var index := int(_clock * fps)
	if CHARS.loops(class_id, state):
		index = posmod(index, count)
	else:
		index = mini(index, count - 1)
	if index == _frame:
		return
	_frame = index
	_apply()


func _show(next: String, index: int) -> void:
	if not CHARS.has_set(class_id):
		return
	if CHARS.frame_count(class_id, next) <= 0:
		next = "idle"
	state = next
	var count := maxi(CHARS.frame_count(class_id, state), 1)
	_frame = clampi(index, 0, count - 1)
	_apply()


func _apply() -> void:
	if _sprite == null:
		return
	var tex := CHARS.frame_texture(class_id, facing, state, _frame)
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.flip_h = false
	_sprite.offset = CHARS.offset_for(class_id, facing, state)
	var scale := base_scale()
	_sprite.scale = Vector2(scale, scale)
	_rim.centered = false
	_rim.flip_h = false
	_rim.offset = _sprite.offset
	_rim.texture = tex
	_rim.visible = tex != null
