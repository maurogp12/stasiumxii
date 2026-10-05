extends Pawn

## VIEW ONLY. A dungeon monster on the combat board.
## The base Pawn keeps doing the motion work (idle bob, step bounce, lunge,
## recoil, slump) on an invisible stand-in sprite; this pawn copies that
## motion onto its own body, which plays the monster's frame strips from the
## art manifest (idle, walk, attack, hit, death, summon; S and E painted, W
## and N mirrored) or drawn placeholders until the art lands.

const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")

var monster_id := ""
var boss := false
var art: Dictionary = {}
var _root: Node2D
var _body: AnimatedSprite2D
var _oneshot := ""
var _blank: Texture2D
var _faded := false
const WARM := Color(1.06, 0.94, 0.8, 1.0)


func bind_art(man: Dictionary, id: String, is_boss: bool) -> void:
	monster_id = id
	boss = is_boss
	art = Art.monster_frames(man, id)
	_ensure_body()


func _ensure_body() -> void:
	if _root != null and is_instance_valid(_root):
		return
	_root = Node2D.new()
	_root.name = "MonsterRoot"
	_root.z_as_relative = true
	_root.z_index = 1
	add_child(_root)
	_body = AnimatedSprite2D.new()
	_body.name = "MonsterBody"
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_root.add_child(_body)
	if not art.is_empty():
		_body.sprite_frames = art["frames"]
	_body.animation_finished.connect(_on_body_finished)
	_play_body("idle", true)


func body_height() -> float:
	if float(art.get("height", 0.0)) > 0.0:
		return minf(float(art["height"]) * 0.82, 150.0)
	return float(Art.PLACEHOLDER_HEIGHT.get(monster_id, 80.0))


func _face() -> Dictionary:
	var faces: Dictionary = art.get("faces", {"s": true, "e": true})
	return Art.facing_source(facing, func(f: String) -> bool: return faces.has(f))


func _anim_name(kind: String) -> String:
	var f := str(_face()["face"])
	var name := "%s_%s" % [kind, f]
	if _body != null and _body.sprite_frames != null and _body.sprite_frames.has_animation(name):
		return name
	for other in ["s", "e", "n", "w"]:
		var alt := "%s_%s" % [kind, other]
		if _body != null and _body.sprite_frames != null and _body.sprite_frames.has_animation(alt):
			return alt
	return ""


func _play_body(kind: String, loop_ok: bool = false) -> void:
	if _body == null or _body.sprite_frames == null:
		return
	var name := _anim_name(kind)
	if name == "":
		if kind != "idle":
			_play_body("idle", true)
		return
	if not loop_ok:
		_oneshot = kind
	elif _oneshot != "":
		return
	if _body.animation == StringName(name) and _body.is_playing():
		return
	_body.play(StringName(name))


func _on_body_finished() -> void:
	if _oneshot == "death":
		return
	_oneshot = ""
	_play_body("walk" if _path_walk else "idle", true)


func _hold_last(kind: String) -> void:
	if _body == null or _body.sprite_frames == null:
		return
	var name := _anim_name(kind)
	if name == "":
		return
	_oneshot = kind
	_body.animation = StringName(name)
	_body.frame = maxi(_body.sprite_frames.get_frame_count(StringName(name)) - 1, 0)
	_body.stop()


func _sync_sprite() -> void:
	_ensure_visuals()
	_ensure_body()
	if _blank == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank = ImageTexture.create_from_image(img)
	_sprite.texture = _blank
	_sprite.flip_h = false
	if not _flashing:
		_sprite.modulate = rest_modulate()
	_sprite.visible = true
	_hide_body_strips()
	if _oneshot == "" and _body != null:
		var want := "walk" if _path_walk else "idle"
		var name := _anim_name(want)
		if name != "" and _body.animation != StringName(name):
			_body.play(StringName(name))
	if not alive and _oneshot != "death":
		_hold_last("death")
	_request_paint()


func _process(_delta: float) -> void:
	if _body == null or _sprite == null or not is_instance_valid(_sprite):
		return
	var src := _face()
	var s := float(art.get("scale", 0.5))
	var rel := Vector2(_sprite.scale.x / SPRITE_SCALE.x, _sprite.scale.y / SPRITE_SCALE.y)
	var pivot: Vector2 = art.get("pivot", Vector2(64, 150))
	var flip := bool(src["flip"])
	_body.flip_h = flip
	var frame_tex := _body.sprite_frames.get_frame_texture(_body.animation, _body.frame) if _body.sprite_frames != null and _body.sprite_frames.has_animation(_body.animation) else null
	var w := float(frame_tex.get_width()) if frame_tex != null else pivot.x * 2.0
	var px := (w - pivot.x) if flip else pivot.x
	_body.offset = Vector2(-px, -pivot.y)
	_root.position = _sprite.position
	_root.rotation = _sprite.rotation
	_root.scale = Vector2(s * rel.x, s * rel.y)
	# The kit's monsters are flatly lit and cool: warm them to the room light.
	_body.modulate = _sprite.modulate * WARM
	if _path_walk and _oneshot == "":
		_play_body("walk", true)


func play_view_plan(plan: Dictionary) -> float:
	var sec := super.play_view_plan(plan)
	if bool(plan.get("death", false)):
		_play_body("death")
	elif bool(plan.get("attack", false)):
		_play_body("attack")
	elif bool(plan.get("cast", false)):
		_play_body("summon")
	elif bool(plan.get("hit", false)):
		get_tree().create_timer(0.16).timeout.connect(func():
			if is_instance_valid(self) and alive:
				_play_body("hit"))
	return sec


func begin_path_walk() -> void:
	super.begin_path_walk()
	_oneshot = ""
	_play_body("walk", true)


func end_path_walk() -> void:
	super.end_path_walk()
	if _oneshot == "":
		_body.stop()
		_play_body("idle", true)


func settle_motion() -> void:
	super.settle_motion()
	if not alive:
		_hold_last("death")


## Dungeon corpses fade out once the slump has played.
func fade_out() -> void:
	if _faded or not is_inside_tree():
		return
	_faded = true
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): visible = false)


func _seat_color() -> Color:
	if boss:
		return Color(0.86, 0.62, 0.22, 0.92)
	return Color(0.78, 0.42, 0.42, 0.92)


func name_baseline() -> float:
	return -body_height() - 10.0 - NAME_GAP_ABOVE_HP - ThemeDB.fallback_font.get_descent(NAME_FONT_SIZE)


func _paint_status(canvas: CanvasItem) -> void:
	if debug_draw_tokens or not _sprite_ready() or _faded:
		return
	_paint_unit_chrome(canvas, -body_height() - 10.0, name_baseline())
