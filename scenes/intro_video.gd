extends Control
class_name IntroVideo

## Opening video (Mauro 29 Sep 2026: "put this video at the opening of the
## game but it can be skipped by touching the screen"). Covers the hub at
## app start, plays art/intro/intro.ogv once, and any tap / click / key skips
## it. Only the first hub of an app run shows it; CLI routes and tests do not.

signal finished

const VIDEO_PATH := "res://art/intro/intro.ogv"

static var played: bool = false

var _player: VideoStreamPlayer
var _hint: Label
var _done := false


static func should_play(auto_launch: bool) -> bool:
	return auto_launch and not played and ResourceLoader.exists(VIDEO_PATH)


func _ready() -> void:
	played = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_player = VideoStreamPlayer.new()
	_player.name = "Video"
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stream := load(VIDEO_PATH) as VideoStream
	if stream == null:
		call_deferred("skip")
		return
	_player.stream = stream
	_player.finished.connect(skip)
	add_child(_player)
	_hint = Label.new()
	_hint.name = "SkipHint"
	_hint.text = "Tap to skip"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.0))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -150
	_hint.offset_top = -44
	_hint.offset_right = -20
	_hint.offset_bottom = -16
	add_child(_hint)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(_hint):
			_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, a)), 0.0, 0.85, 0.5)
	_player.play()
	_fit()
	resized.connect(_fit)


## Keep the 16:9 video whole on any phone shape (letterbox, no stretch).
func _fit() -> void:
	if _player == null or _player.stream == null:
		return
	var aspect := 16.0 / 9.0
	var w := size.x
	var h := w / aspect
	if h > size.y:
		h = size.y
		w = h * aspect
	_player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_player.position = Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
	_player.size = Vector2(w, h)


func _gui_input(event: InputEvent) -> void:
	if _is_skip(event):
		accept_event()
		skip()


func _unhandled_input(event: InputEvent) -> void:
	if _is_skip(event):
		skip()


static func _is_skip(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		return true
	if event is InputEventKey and (event as InputEventKey).pressed:
		return true
	return false


func is_done() -> bool:
	return _done


func skip() -> void:
	if _done:
		return
	_done = true
	if _player != null and is_instance_valid(_player):
		_player.stop()
	finished.emit()
	queue_free()
