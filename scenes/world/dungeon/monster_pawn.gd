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
var _glow: AnimatedSprite2D
## Strength of the additive glow pass (run.json view.monster_glow; 1 = as painted).
var glow_strength := 1.0
## Room light on the kit's flat, cool frames. The run file sets it
## (view.light); WARM (the cellar's lantern light) when none is given.
const WARM := Color(1.14, 0.96, 0.74, 1.0)
var light := WARM
var tint := Color.WHITE
var stand_in := false
## A ★5 variant (data: variant_of + star_min 5), e.g. a radioactive rat.
var radioactive := false


## Stand-in base art for a monster whose own frames are not in the kit yet:
## the data row's stand_in {art, tint, scale} (dungeon_monsters.json).
func bind_art(man: Dictionary, id: String, is_boss: bool, variant_of: String = "") -> void:
	monster_id = id
	boss = is_boss
	var spec: Dictionary = Art.monster_spec(id)
	radioactive = int(spec.get("star_min", 0)) >= 5
	art = Art.monster_frames(man, id)
	tint = Color.WHITE
	stand_in = false
	var si: Variant = spec.get("stand_in", null)
	if not bool(art.get("painted", false)) and typeof(si) == TYPE_DICTIONARY:
		var base := Art.monster_frames(man, str((si as Dictionary).get("art", "")))
		if bool(base.get("painted", false)) or not Art.is_kit(man):
			art = base
			var tc: Array = (si as Dictionary).get("tint", [1, 1, 1, 1])
			tint = Color(float(tc[0]), float(tc[1]), float(tc[2]), float(tc[3]) if tc.size() > 3 else 1.0)
			stand_in = true
			if (si as Dictionary).has("scale"):
				art = art.duplicate()
				art["scale"] = float(art.get("scale", 0.5)) * float(si["scale"])
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
	if art.get("glow_frames", null) != null:
		# ★5 light maps: same frame, transform and flip, added on top.
		_glow = AnimatedSprite2D.new()
		_glow.name = "MonsterGlow"
		_glow.centered = false
		_glow.sprite_frames = art["glow_frames"]
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_root.add_child(_glow)
	_play_body("idle", true)


func body_height() -> float:
	if float(art.get("height", 0.0)) > 0.0:
		return minf(float(art["height"]) * 0.82, 150.0)
	return Art.placeholder_height(monster_id)


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
	_body.modulate = _sprite.modulate * light * tint
	if _glow != null:
		_glow.flip_h = flip
		_glow.offset = _body.offset
		if _glow.sprite_frames.has_animation(_body.animation):
			if _glow.animation != _body.animation:
				_glow.animation = _body.animation
			_glow.frame = _body.frame
		_glow.modulate = Color(1, 1, 1, _sprite.modulate.a * glow_strength)
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



## Where the sling releases its stone, in pawn-local px, for the facing shown.
func release_offset() -> Vector2:
	var rel: Dictionary = art.get("release", {})
	var by_face: Dictionary = rel.get("offset", {})
	var src := _face()
	var off: Vector2 = by_face.get(str(src["face"]), Vector2(14, -40))
	if bool(src["flip"]):
		off.x = -off.x
	return off


## Where the boss's lure (Old Saltmaw's lantern) shines from on the flare
## frame, in pawn-local px, for the facing shown (manifest lure_point).
func lure_offset() -> Vector2:
	var by_face: Dictionary = art.get("lure", {})
	var src := _face()
	var off: Vector2 = by_face.get(str(src["face"]), Vector2(26, -118))
	if bool(src["flip"]):
		off.x = -off.x
	return off


## Seconds from the attack's start to the release frame.
func release_sec() -> float:
	return float((art.get("release", {}) as Dictionary).get("sec", 0.22))


# --- Board picking and target chrome -----------------------------------------

## Pick levels: PICK_PIXEL when the point is on the visible pixels of the frame
## shown, PICK_BOX when it is only inside the generous body box.
const PICK_NONE := 0
const PICK_BOX := 1
const PICK_PIXEL := 2
## Smallest body box in pawn-local px (around the feet, up the body), so a
## small rat is still easy to hit. Grown by BOX_PAD on every side.
const MIN_BOX_HALF_W := 24.0
const BOX_PAD := 6.0
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float width = 2.0;
void fragment() {
	vec4 tint = COLOR;
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5 && width > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + px).a);
		a = max(a, texture(TEXTURE, UV - px).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
		if (a > 0.5) {
			COLOR = vec4(outline_color.rgb, outline_color.a * tint.a);
		} else {
			COLOR = c * tint;
		}
	} else {
		COLOR = c * tint;
	}
}
"""
## "" (none), "legal" (in range: gold ring + outline), "hover" (the target
## under the cursor: bright ring + outline), "dim" (out of range).
var target_state := ""
var _ring: Node2D
var _ring_front: Node2D
var _outline: ShaderMaterial
static var _outline_shader: Shader


func pickable() -> bool:
	return alive and visible and not _faded and is_inside_tree() and modulate.a > 0.05


## Where a canvas (global) point lands on this monster: PICK_PIXEL, PICK_BOX
## or PICK_NONE. Uses the frame on screen now, its flip and the motion offset.
func pick_test(global_point: Vector2) -> int:
	if not pickable() or _body == null or _body.sprite_frames == null:
		return PICK_NONE
	var tex: Texture2D = null
	if _body.sprite_frames.has_animation(_body.animation):
		tex = _body.sprite_frames.get_frame_texture(_body.animation, _body.frame)
	if tex != null:
		var at: Vector2 = _body.get_global_transform().affine_inverse() * global_point
		var p := at - _body.offset
		var w := tex.get_width()
		var h := tex.get_height()
		if p.x >= 0.0 and p.y >= 0.0 and p.x < w and p.y < h:
			var mask := Art.pick_mask(tex)
			var bx := int(p.x)
			if _body.flip_h:
				bx = w - 1 - bx
			if mask != null and _mask_near(mask, bx, int(p.y), w, h):
				return PICK_PIXEL
	if body_box().has_point(to_local(global_point)):
		return PICK_BOX
	return PICK_NONE


## A set mask bit at (x, y) or within MASK_SLOP texture px of it, so a click on
## the silhouette's edge still counts as the monster.
const MASK_SLOP := 2


static func _mask_near(mask: BitMap, x: int, y: int, w: int, h: int) -> bool:
	for dy in [0, -MASK_SLOP, MASK_SLOP]:
		for dx in [0, -MASK_SLOP, MASK_SLOP]:
			var px: int = x + int(dx)
			var py: int = y + int(dy)
			if px >= 0 and py >= 0 and px < w and py < h and mask.get_bit(px, py):
				return true
	return false


## The generous body box in pawn-local px: the frame rect on screen, at least
## MIN_BOX_HALF_W either side of the feet and body_height() tall, plus BOX_PAD.
func body_box() -> Rect2:
	var box := Rect2(Vector2(-MIN_BOX_HALF_W, -body_height()), Vector2(MIN_BOX_HALF_W * 2.0, body_height() + 6.0))
	if _body != null and _body.sprite_frames != null and _body.sprite_frames.has_animation(_body.animation):
		var tex := _body.sprite_frames.get_frame_texture(_body.animation, _body.frame)
		if tex != null and _root != null:
			var r := Rect2(_body.offset, tex.get_size())
			var a: Vector2 = _root.transform * r.position
			var b: Vector2 = _root.transform * r.end
			box = box.merge(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()))
	return box.grow(BOX_PAD)


func set_target_state(state: String) -> void:
	if state == target_state:
		return
	target_state = state
	_ensure_body()
	if _root != null:
		_root.modulate = Color(0.5, 0.5, 0.56, 0.78) if state == "dim" else Color.WHITE
	if state == "legal" or state == "hover":
		if _outline == null:
			if _outline_shader == null:
				_outline_shader = Shader.new()
				_outline_shader.code = OUTLINE_SHADER
			_outline = ShaderMaterial.new()
			_outline.shader = _outline_shader
		_outline.set_shader_parameter("outline_color", Color(1.0, 0.95, 0.7, 1.0) if state == "hover" else Color(1.0, 0.74, 0.22, 0.95))
		_outline.set_shader_parameter("width", 3.0 if state == "hover" else 2.0)
		if _body != null:
			_body.material = _outline
	elif _body != null:
		_body.material = null
	if _ring == null:
		# Back half under the body; front half over the floor tiles in front
		# (they sort above the unit) but under the units standing there.
		_ring = TargetRing.new()
		_ring.name = "TargetRingBack"
		_ring.z_as_relative = true
		_ring.z_index = 0
		add_child(_ring)
		move_child(_ring, 0)
		_ring_front = TargetRing.new()
		_ring_front.name = "TargetRingFront"
		_ring_front.front = true
		_ring_front.z_as_relative = true
		_ring_front.z_index = 7
		add_child(_ring_front)
	for ring in [_ring, _ring_front]:
		ring.state = state
		ring.radius = clampf(body_box().size.x * 0.36, 20.0, 40.0)
		ring.visible = state == "legal" or state == "hover"
		ring.queue_redraw()


## A pulsing ellipse under the feet of a legal target (one half per node).
class TargetRing extends Node2D:
	var state := ""
	var radius := 24.0
	var front := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var hover := state == "hover"
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var col := Color(1.0, 0.95, 0.7, 0.95) if hover else Color(1.0, 0.72, 0.2, 0.6 + 0.35 * pulse)
		var r := radius * (1.12 if hover else 1.0 + 0.05 * pulse)
		var from := 0.0 if front else PI
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
		if not front:
			draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.18 if hover else 0.1))
		draw_arc(Vector2.ZERO, r, from, from + PI, 32, col, 4.0 if hover else 3.0, true)
		if hover:
			draw_arc(Vector2.ZERO, r + 7.0, from, from + PI, 32, Color(col.r, col.g, col.b, 0.5), 2.0, true)
