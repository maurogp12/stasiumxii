extends Node2D
class_name Pawn

## One Sprite2D child ("Sprite") at the pawn origin. Feet sit on that origin:
## centered, offset (0, -72), scale 0.5. Facings stay
## `art/characters/<class>/<class>_<n|e|s|w>.png`. Mirrors are baked into the
## files — never set flip_h. Bastion _n/_w are placeholder back views loaded
## from those same filenames.
## Mobile-track chrome. Batch 1 strips load from
## `art/export_2x/characters/<class>/anims/` when the files exist
## (see that folder's README). Lettered names win: `walk_e` / `attack_e`
## (SE→e, SW→s, NE→n, NW→w). A drawn master name (`walk_se`, `attack_ne`)
## still resolves when the lettered clip is absent, then generic `walk` / `attack`.
## A walk strip loops at authored fps for the whole path and skips the hop
## only while that clip is actually playing. If play() does not start, the
## hop returns. Missing strips keep the hop and this static sprite.
## Attack strips play one-shot on attack plans. A cast with no cast strip
## (Kestrel Mark Shot / Detonate) uses the attack strip and the melee lunge.
## Anticipation pulls back, the impact frame holds, then the body recovers.
## The clip keeps authored fps when that length still fits the 0.6s lock.
## A walk strip never hops. The hop (or a static facing) is only the fallback.
## Named paths: WalkStrip, AttackStrip, BodyStrip. A Sprite node that is an
## AnimatedSprite2D is kept as BodyStrip and the static sprite is recreated.
## Missing nodes, empty frames, or null textures keep the static sprite.
## Mirrors are baked. Never set flip_h.
## `debug_draw_tokens` keeps the old circle token as a fallback.

var grid_position: Vector2i = Vector2i.ZERO
var unit_name: String = ""
var class_id: String = ""
var facing: String = "E"
var seat: int = 0
var hp: int = 80
var max_hp: int = 80
var alive: bool = true
var is_active: bool = false
var stunned: bool = false
var burning: bool = false
var burn_remaining: int = 0
var debug_draw_tokens: bool = false
var _hit_flash: bool = false
var _flashing: bool = false
var _sprite: Sprite2D
var _chrome: StatusChrome
var _idle_tween: Tween
var _action_tween: Tween
var _motion_playing: bool = false
var _idle_hold: bool = false
var _motion_gen: int = 0
var _plan_died: bool = false
var _death_from: Color = Color.WHITE
var _death_sampled: bool = false
var _active_strip: AnimatedSprite2D
var _strip_holds_body: bool = false
var _path_walk: bool = false
var _walk_looping: bool = false
var _strip_play_scale: float = 1.0
var _impact_frozen: bool = false

const VIEW_MOTION := preload("res://units/view_motion.gd")
const STRIP_LIBRARY := preload("res://units/strip_library.gd")
const COSMETIC_STRIPS := preload("res://units/cosmetic_strips.gd")
const SEAT_COSMETICS := preload("res://data/seat_cosmetics.gd")

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}
const FACING_ORDER: Array[String] = ["n", "e", "s", "w"]
const SPRITE_OFFSET := Vector2(0, -72)
const SPRITE_SCALE := Vector2(0.5, 0.5)
## One tile of travel. The hop arc and the pawn position tween both use this.
## A walk strip does not. It loops at authored fps for the whole path.
const WALK_HOP_SEC := 0.25
## Handoff walk cycle: 6 frames at 12 fps (~0.50s), looped, not one cycle per tile.
const WALK_STRIP_FRAMES := 6
const WALK_STRIP_FPS := 12.0
const WALK_STRIP_PATH := NodePath("WalkStrip")
const ATTACK_STRIP_PATH := NodePath("AttackStrip")
const BODY_STRIP_PATH := NodePath("BodyStrip")
## Clears the tallest shipped figure (Ironjaw / Bastion ~68px).
const HEAD_HP_Y := -76.0
const NAME_FONT_SIZE := 12
## Seat ring under the feet. The name used to share this band.
const SEAT_RING_CENTER := Vector2(0, 3)
const SEAT_RING_RX := 18.0
const SEAT_RING_RY := 7.0
const NAME_GAP_ABOVE_HP := 2.0

static var _sprite_cache: Dictionary = {}


class StatusChrome extends Node2D:
	var host: Pawn

	func _draw() -> void:
		if host != null:
			host._paint_status(self)


## `events` supply Burn only when the unit dict has no `burn_remaining`.
## This pawn does not tick Burn; the next host snapshot replaces the number.
func apply_snapshot(unit: Dictionary, active_seat: int, events: Array = []) -> void:
	grid_position = unit["pos"]
	unit_name = str(unit["name"])
	class_id = str(unit["class_id"])
	facing = str(unit["facing"])
	seat = int(unit.get("seat", seat))
	hp = int(unit["hp"])
	max_hp = int(unit["max_hp"])
	alive = bool(unit["alive"])
	is_active = int(unit["seat"]) == active_seat and alive
	_hit_flash = false
	stunned = int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))
	burn_remaining = CombatHUD.unit_burn_remaining(unit, events)
	burning = burn_remaining > 0
	_sync_sprite()
	_sync_idle()
	# Spawn binds the seat's gender × palette bank (stock Batch-1 when the flag is off).
	_ensure_motion_strips()


func burn_badge_label() -> String:
	return CombatHUD.burn_badge_text(burn_remaining)


func set_facing(dir: String) -> void:
	if dir == "" or dir == facing:
		return
	facing = dir
	_sync_sprite()


func facing_screen() -> Vector2:
	return FACING_ISO.get(facing, Vector2(20, 10))


func motion_playing() -> bool:
	return _motion_playing


## True when a walk strip is actually playing (flat slide, no hop).
## False plays the sprite-local hop. The pawn node stays on the path.
## has_walk_strip() alone must not drop the hop: on device play() can
## leave is_playing() false and the body would only tween.
func play_step_hop() -> bool:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		_end_body_strip()
		return false
	_ensure_motion_strips()
	if _play_walk_flat():
		return true
	_play_static_hop()
	return false


func _play_static_hop() -> void:
	if _walk_looping:
		_end_body_strip()
	var gen := _begin_action()
	var tw := create_tween()
	_action_tween = tw
	tw.tween_method(_sample_hop, 0.0, 1.0, WALK_HOP_SEC)
	tw.finished.connect(_on_action_finished.bind(gen), CONNECT_ONE_SHOT)


## True when this class and facing can play a walk clip. Missing files are false.
func has_walk_strip() -> bool:
	_ensure_motion_strips()
	return not _strip_choice("walk").is_empty()


func has_attack_strip() -> bool:
	_ensure_motion_strips()
	return not _strip_choice("attack").is_empty()


func has_cast_strip() -> bool:
	_ensure_motion_strips()
	return not _strip_choice("cast").is_empty()


## Hold the walk loop across tiles. The board calls this once per path.
func begin_path_walk() -> void:
	_path_walk = true


## Path end or interrupt. Plant the static facing and let idle resume.
func end_path_walk() -> void:
	_path_walk = false
	_kill_action()
	_motion_playing = false
	_plant_sprite()


## Walk strips play at authored fps. speed_scale 1 does not squeeze a cycle into one tile.
static func walk_strip_speed_scale() -> float:
	return 1.0


## A cast plays the attack cycle when this class has attack frames and no cast strip.
func _cast_uses_attack_strip() -> bool:
	return _strip_choice("cast").is_empty() and not _strip_choice("attack").is_empty()


## Authored clip length. 6 frames at 12 fps is 0.5s. Zero when the strip is missing.
func _strip_natural_sec(kind: String) -> float:
	var choice := _strip_choice(kind)
	if choice.is_empty():
		return 0.0
	var strip: AnimatedSprite2D = choice["node"]
	if strip == null or not is_instance_valid(strip) or strip.sprite_frames == null:
		return 0.0
	var anim := StringName(str(choice["anim"]))
	var frames := strip.sprite_frames
	if not frames.has_animation(anim):
		return 0.0
	var fps := frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var span := 0.0
	var count := frames.get_frame_count(anim)
	for i in count:
		span += frames.get_frame_duration(anim, i)
	return span / fps


## Keep the motion window when the clip is shorter. Stretch to authored length
## when the 0.6s lock still has room, so a 12 fps attack is not squeezed.
func _fit_strip_window(kind: String, sec: float, steps: Array) -> float:
	var others := 0.0
	for step in steps:
		var s := float(step.get("sec", 0.0))
		if s > 0.0:
			others += s
	others = maxf(0.0, others - sec)
	var room := VIEW_MOTION.ACTION_LOCK_MAX - others
	var natural := _strip_natural_sec(kind)
	if natural <= sec or room <= sec:
		return sec
	return minf(natural, room)


## Fit `frame_count` frames at `fps` into `window_sec`. Empty input stays at 1.
static func strip_speed_scale(frame_count: int, fps: float, window_sec: float) -> float:
	if frame_count <= 0 or fps <= 0.0 or window_sec <= 0.0:
		return 1.0
	return (float(frame_count) / fps) / window_sec


func play_view_plan(plan: Dictionary) -> float:
	_plan_died = false
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return 0.0
	_ensure_motion_strips()
	_plan_died = bool(plan.get("death", false))
	var steps: Array = VIEW_MOTION.steps_for(plan)
	if steps.is_empty():
		_plan_died = false
		return 0.0
	var gen := _begin_action()
	var tw := create_tween()
	_action_tween = tw
	var total := 0.0
	for step in steps:
		var kind := str(step.get("kind", ""))
		var sec := float(step.get("sec", 0.0))
		if sec <= 0.0:
			continue
		total += sec
		if kind == "wait":
			tw.tween_interval(sec)
		elif kind == "attack" or (kind == "cast" and _cast_uses_attack_strip()):
			var play_sec := _fit_strip_window("attack", sec, steps)
			var aim: Vector2 = step.get("dir", plan.get("aim", Vector2.ZERO))
			if aim.length_squared() < 0.01:
				aim = facing_screen()
			var reach := float(step.get("reach", plan.get("reach", VIEW_MOTION.ATTACK_LUNGE_PX)))
			_begin_body_strip("attack", play_sec)
			tw.tween_method(_sample_attack.bind(aim, reach), 0.0, 1.0, play_sec)
			tw.tween_callback(_end_body_strip)
			total += play_sec - sec
		elif kind == "cast":
			_begin_body_strip("cast", sec)
			tw.tween_method(_sample_cast, 0.0, 1.0, sec)
			tw.tween_callback(_end_body_strip)
		elif kind == "hit":
			tw.tween_callback(_end_body_strip)
			tw.tween_method(_sample_hit.bind(step.get("dir", Vector2.ZERO)), 0.0, 1.0, sec)
		elif kind == "lift":
			tw.tween_callback(_end_body_strip)
			tw.tween_method(_sample_lift, 0.0, 1.0, sec)
		elif kind == "death":
			tw.tween_callback(_end_body_strip)
			tw.tween_method(_sample_death.bind(float(step.get("tilt", 1.0))), 0.0, 1.0, sec)
	if total <= 0.0:
		_plan_died = false
		_kill_action()
		_motion_playing = false
		_start_idle()
		return 0.0
	tw.finished.connect(_on_action_finished.bind(gen), CONNECT_ONE_SHOT)
	return minf(total, VIEW_MOTION.ACTION_LOCK_MAX)


func hold_idle() -> void:
	_idle_hold = true
	_stop_idle()
	if not _motion_playing:
		_plant_sprite()


func release_idle() -> void:
	_idle_hold = false
	if _motion_playing:
		return
	_plant_sprite()
	_start_idle()


func settle_motion() -> void:
	_kill_action()
	_motion_playing = false
	_plant_sprite()
	if _plan_died:
		_plan_died = false
		_stop_idle()
		_flashing = false
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)
		return
	_start_idle()


func plant_sprite() -> void:
	_plant_sprite()


## End one path step. A looping walk strip stays up until end_path_walk.
func finish_step() -> void:
	_kill_action()
	if _path_walk and _walk_looping:
		_motion_playing = true
		_flatten_body()
		return
	_motion_playing = false
	_plant_sprite()


func flash_hit() -> void:
	_hit_flash = true
	_apply_flash(Color(1.85, 1.55, 1.15))


func flash_impact() -> void:
	_apply_flash(Color(1.35, 1.2, 0.75))


## Green / teal. Heals and Cleanse.
func flash_support() -> void:
	_apply_flash(Color(0.45, 1.65, 0.85))


## Pale blue. Ward shield.
func flash_ward() -> void:
	_apply_flash(Color(0.72, 0.9, 1.7))


func flash_canvas() -> CanvasItem:
	_ensure_visuals()
	if _strip_holds_body and _active_strip != null and is_instance_valid(_active_strip) and _active_strip.visible:
		return _active_strip
	if _sprite != null:
		return _sprite
	return self


func rest_modulate() -> Color:
	if not alive:
		return Color(0.45, 0.45, 0.45, 1)
	return Color.WHITE


func note_flash_settled() -> void:
	_flashing = false
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = rest_modulate()


## Hit events only. "ward" is pale blue, "support" is heal / Cleanse, "damage" stays orange.
## Reads spell id, healed amount, negative damage, and shield fields. Misses return "".
static func resolve_flash_kind(event: Dictionary) -> String:
	if str(event.get("type", "")) != "hit":
		return ""
	var spell_id := str(event.get("spell", ""))
	var def: Dictionary = SpellKits.spell(spell_id)
	var dealt := int(event.get("damage", 0))
	var healed := int(event.get("healed", 0))
	if healed > 0 or dealt < 0:
		return "support"
	if spell_id == SpellKits.CLEANSE:
		return "support"
	var shield_now := int(event.get("shield", 0))
	var grants_shield := int(def.get("shield", 0)) > 0 and shield_now > 0 and dealt <= 0
	if spell_id == SpellKits.WARD or grants_shield:
		return "ward"
	if int(def.get("base_heal", 0)) > 0 and dealt <= 0 and event.has("healed"):
		return "support"
	return "damage"


static func sprite_path(class_id: String, facing: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(cls):
		cls = SpellKits.CLASS_KESTREL
	var face := facing.strip_edges().to_lower()
	if not FACING_ORDER.has(face):
		face = "e"
	return "res://art/characters/%s/%s_%s.png" % [cls, cls, face]


static func sprite_texture(class_id: String, facing: String) -> Texture2D:
	var path := sprite_path(class_id, facing)
	if _sprite_cache.has(path) and _sprite_cache[path] is Texture2D:
		return _sprite_cache[path]
	var loaded: Variant = load(path)
	var tex: Texture2D = loaded if loaded is Texture2D else null
	_sprite_cache[path] = tex
	return tex


func _apply_flash(color: Color) -> void:
	_flashing = true
	_ensure_visuals()
	if _sprite != null:
		_sprite.modulate = color
	_request_paint()


func _ensure_visuals() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_ensure_chrome()
		return
	var existing := get_node_or_null("Sprite")
	if existing is Sprite2D:
		_sprite = existing as Sprite2D
		_adopt_static_sprite(_sprite)
		_ensure_chrome()
		return
	if existing is AnimatedSprite2D:
		_rehome_sprite_strip(existing as AnimatedSprite2D)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_adopt_static_sprite(_sprite)
	add_child(_sprite)
	_ensure_chrome()


func _adopt_static_sprite(sprite: Sprite2D) -> void:
	sprite.centered = true
	sprite.offset = SPRITE_OFFSET
	sprite.scale = SPRITE_SCALE
	sprite.flip_h = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 0
	sprite.z_as_relative = true


func _rehome_sprite_strip(strip: AnimatedSprite2D) -> void:
	strip.visible = false
	if str(strip.name) != "Sprite":
		return
	if get_node_or_null(BODY_STRIP_PATH) == null:
		strip.name = "BodyStrip"
	else:
		strip.name = "BodyStripExtra"


func _ensure_chrome() -> void:
	if _chrome != null and is_instance_valid(_chrome):
		return
	_chrome = StatusChrome.new()
	_chrome.name = "Chrome"
	_chrome.host = self
	_chrome.z_index = 2
	_chrome.z_as_relative = true
	add_child(_chrome)


func _sync_sprite() -> void:
	_ensure_visuals()
	_sprite.flip_h = false
	_sprite.texture = sprite_texture(class_id, facing)
	if not _flashing:
		_sprite.modulate = rest_modulate()
	if _strip_holds_body and _active_strip != null and is_instance_valid(_active_strip):
		_sprite.visible = false
		if not _flashing:
			_active_strip.modulate = _sprite.modulate
	else:
		_sprite.visible = true
		_hide_body_strips()
	_request_paint()


func _sync_idle() -> void:
	if not alive:
		_stop_idle()
		if not _motion_playing:
			_plant_sprite()
		return
	if _motion_playing or _idle_hold or VIEW_MOTION.reduce_motion():
		return
	# Next frame so a snapshot apply does not move the sprite before callers read it.
	call_deferred("_start_idle")


func _begin_action() -> int:
	_ensure_visuals()
	_kill_action()
	_stop_idle()
	_plant_sprite()
	_motion_playing = true
	_death_sampled = false
	return _motion_gen


func _kill_action() -> void:
	_motion_gen += 1
	if _action_tween != null and is_instance_valid(_action_tween):
		_action_tween.kill()
	_action_tween = null


func _on_action_finished(gen: int) -> void:
	if gen != _motion_gen:
		return
	_motion_playing = false
	_action_tween = null
	_plant_sprite()


func _sample_hop(t: float) -> void:
	var hop := VIEW_MOTION.hop_offset(t)
	_place_body(hop)
	# Name and HP ride the arc. The seat ring stays on the pawn, so the gap reads.
	_ride_chrome(hop)
	var mul: Vector2 = VIEW_MOTION.hop_scale(t)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = Vector2(SPRITE_SCALE.x * mul.x, SPRITE_SCALE.y * mul.y)
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.scale = Vector2(SPRITE_SCALE.x * mul.x, SPRITE_SCALE.y * mul.y)


func _sample_attack(t: float, dir: Vector2, reach: float = -1.0) -> void:
	_apply_body_pose(VIEW_MOTION.attack_pose(t, dir, reach))
	_sync_impact_freeze(t, false)


func _sample_cast(t: float) -> void:
	_apply_body_pose(VIEW_MOTION.cast_pose(t))
	_sync_impact_freeze(t, true)


func _apply_body_pose(pose: Dictionary) -> void:
	var pos: Vector2 = pose.get("pos", Vector2.ZERO)
	var mul: Vector2 = pose.get("scale", Vector2.ONE)
	var scaled := Vector2(SPRITE_SCALE.x * mul.x, SPRITE_SCALE.y * mul.y)
	_ride_chrome(Vector2.ZERO)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = pos
		_sprite.scale = scaled
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = pos
		_active_strip.scale = scaled
		if _sprite != null and is_instance_valid(_sprite):
			_active_strip.modulate = _sprite.modulate


## Pause on the impact cell (attack) or the last cell (cast) while the pose holds.
## Playback resumes at the authored scale for the recover.
func _sync_impact_freeze(t: float, last_pose: bool) -> void:
	if _active_strip == null or not is_instance_valid(_active_strip):
		return
	var phase := VIEW_MOTION.cast_phase(t) if last_pose else VIEW_MOTION.attack_phase(t)
	if phase == "hold":
		_freeze_strip_pose(last_pose)
	elif _impact_frozen:
		_thaw_strip_pose()


func _freeze_strip_pose(last_pose: bool) -> void:
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		return
	var frames := strip.sprite_frames
	var anim := strip.animation
	if frames != null and frames.has_animation(anim):
		var count := frames.get_frame_count(anim)
		if count > 0:
			var frame := count - 1
			if not last_pose:
				frame = mini(STRIP_LIBRARY.ATTACK_IMPACT_FRAME, count - 1)
			strip.frame = frame
	if not _impact_frozen and strip.speed_scale > 0.01:
		_strip_play_scale = strip.speed_scale
	strip.speed_scale = 0.0
	_impact_frozen = true


func _thaw_strip_pose() -> void:
	_impact_frozen = false
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.speed_scale = _strip_play_scale if _strip_play_scale > 0.0 else 1.0


func _sample_hit(t: float, dir: Vector2) -> void:
	if _sprite == null:
		return
	_sprite.position = VIEW_MOTION.hit_offset(t, dir)


func _sample_lift(t: float) -> void:
	if _sprite == null:
		return
	_sprite.position = VIEW_MOTION.support_offset(t)


func _sample_death(t: float, tilt_sign: float) -> void:
	if _sprite == null:
		return
	if not _death_sampled:
		_death_from = _sprite.modulate
		_death_sampled = true
	var pose: Dictionary = VIEW_MOTION.death_pose(t, tilt_sign)
	var mul: Vector2 = pose.get("scale", Vector2.ONE)
	_sprite.scale = Vector2(SPRITE_SCALE.x * mul.x, SPRITE_SCALE.y * mul.y)
	_sprite.rotation_degrees = float(pose.get("rot", 0.0))
	var faded: float = float(pose.get("fade", 1.0))
	var grey := Color(0.45, 0.45, 0.45, faded)
	_sprite.modulate = _death_from.lerp(grey, clampf(t, 0.0, 1.0))


func _start_idle() -> void:
	if _idle_hold or _motion_playing or not alive or not is_inside_tree():
		return
	if VIEW_MOTION.reduce_motion():
		return
	if _idle_tween != null and is_instance_valid(_idle_tween) and _idle_tween.is_running():
		return
	_ensure_visuals()
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.tween_method(_sample_idle, 0.0, 1.0, VIEW_MOTION.IDLE_PERIOD)


func _sample_idle(_t: float) -> void:
	if _sprite == null or _motion_playing or _idle_hold or not alive or _strip_holds_body:
		return
	var phase := VIEW_MOTION.idle_phase_sec(seat, "%s:%s" % [class_id, unit_name])
	var now := Time.get_ticks_msec() / 1000.0
	_sprite.position = Vector2(0.0, sin((now + phase) * TAU / VIEW_MOTION.IDLE_PERIOD) * VIEW_MOTION.IDLE_BOB_PX)


func _stop_idle() -> void:
	if _idle_tween != null and is_instance_valid(_idle_tween):
		_idle_tween.kill()
	_idle_tween = null


func _plant_sprite() -> void:
	_end_body_strip()
	_ride_chrome(Vector2.ZERO)
	if _sprite == null or not is_instance_valid(_sprite):
		return
	_sprite.position = Vector2.ZERO
	_sprite.scale = SPRITE_SCALE
	_sprite.rotation = 0.0
	_sprite.flip_h = false
	_sprite.visible = true


## Locked letters first (SE→e, SW→s, NE→n, NW→w), then the drawn-master
## name (`walk_se` / `attack_ne`), then the generic clip.
func body_anim_candidates(kind: String) -> Array:
	var face := facing.strip_edges().to_lower()
	var diag := str({"n": "ne", "e": "se", "s": "sw", "w": "nw"}.get(face, ""))
	var names: Array = []
	if face != "":
		names.append("%s_%s" % [kind, face])
	if str(diag) != "":
		names.append("%s_%s" % [kind, diag])
	names.append(kind)
	return names


func _begin_body_strip(kind: String, window_sec: float) -> void:
	_ensure_motion_strips()
	var choice := _strip_choice(kind)
	_end_body_strip()
	if choice.is_empty():
		return
	var strip: AnimatedSprite2D = choice["node"]
	var anim := StringName(str(choice["anim"]))
	if strip == null or not is_instance_valid(strip):
		return
	if kind == "walk":
		_prepare_walk_loop(strip, anim)
	else:
		_prepare_play_once(strip, anim)
		var frames := strip.sprite_frames
		var fps := WALK_STRIP_FPS
		var count := 1
		if frames != null and frames.has_animation(anim):
			count = frames.get_frame_count(anim)
			fps = frames.get_animation_speed(anim)
		strip.speed_scale = strip_speed_scale(count, fps, window_sec)
	_strip_play_scale = strip.speed_scale
	_impact_frozen = false
	_prepare_strip_pose(strip)
	strip.visible = true
	strip.play(anim)
	if not strip.is_playing():
		strip.visible = false
		return
	_active_strip = strip
	_strip_holds_body = true
	if _sprite != null and is_instance_valid(_sprite):
		strip.modulate = _sprite.modulate
		strip.position = _sprite.position
		_sprite.visible = false


func _end_body_strip() -> void:
	_walk_looping = false
	_strip_holds_body = false
	_impact_frozen = false
	if _active_strip != null and is_instance_valid(_active_strip):
		if _active_strip.is_playing():
			_active_strip.stop()
		_active_strip.visible = false
		_active_strip.position = Vector2.ZERO
	_active_strip = null
	_hide_body_strips()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = true


func _strip_choice(kind: String) -> Dictionary:
	var preferred: Array = [ATTACK_STRIP_PATH, BODY_STRIP_PATH, WALK_STRIP_PATH]
	if kind == "walk":
		preferred = [WALK_STRIP_PATH, BODY_STRIP_PATH]
	var nodes: Array = []
	for path in preferred:
		var node := get_node_or_null(path)
		if node is AnimatedSprite2D and not nodes.has(node):
			nodes.append(node)
	for child in get_children():
		if child is AnimatedSprite2D and not nodes.has(child):
			nodes.append(child)
	for node in nodes:
		var anim := _first_playable_anim(node as AnimatedSprite2D, kind)
		if anim != "":
			return {"node": node, "anim": anim}
	return {}


func _first_playable_anim(strip: AnimatedSprite2D, kind: String) -> String:
	if strip == null or not is_instance_valid(strip):
		return ""
	for name in body_anim_candidates(kind):
		if _can_play_anim(strip, StringName(str(name))):
			return str(name)
	return ""


func _can_play_anim(strip: AnimatedSprite2D, anim: StringName) -> bool:
	if strip == null or not is_instance_valid(strip):
		return false
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return false
	var count := frames.get_frame_count(anim)
	if count <= 0:
		return false
	for i in count:
		if frames.get_frame_texture(anim, i) != null:
			return true
	return false


func _prepare_walk_loop(strip: AnimatedSprite2D, anim: StringName) -> void:
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if not frames.get_animation_loop(anim):
		frames = _editable_strip_frames(strip)
		if frames != null and frames.has_animation(anim):
			frames.set_animation_loop(anim, true)
	strip.speed_scale = walk_strip_speed_scale()


func _prepare_play_once(strip: AnimatedSprite2D, anim: StringName) -> void:
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if not frames.get_animation_loop(anim):
		return
	frames = _editable_strip_frames(strip)
	if frames != null and frames.has_animation(anim):
		frames.set_animation_loop(anim, false)


## A duplicate that dropped the clips is ignored. play() bails on zero
## frames and is_playing() stays false, which used to leave a static slide.
func _editable_strip_frames(strip: AnimatedSprite2D) -> SpriteFrames:
	var frames := strip.sprite_frames
	if frames == null:
		return null
	if bool(strip.get_meta("_chrome_frames_copy", false)):
		return frames
	var copy := frames.duplicate() as SpriteFrames
	if copy == null or not _duplicate_kept_clips(frames, copy):
		return frames
	strip.sprite_frames = copy
	strip.set_meta("_chrome_frames_copy", true)
	return copy


func _duplicate_kept_clips(src: SpriteFrames, copy: SpriteFrames) -> bool:
	for anim_name in src.get_animation_names():
		if src.get_frame_count(anim_name) > 0 and copy.get_frame_count(anim_name) <= 0:
			return false
	return true


func _prepare_strip_pose(strip: AnimatedSprite2D) -> void:
	strip.centered = true
	strip.offset = SPRITE_OFFSET
	strip.scale = SPRITE_SCALE
	strip.flip_h = false
	strip.rotation = 0.0
	strip.z_index = 0
	strip.z_as_relative = true
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _sprite != null and is_instance_valid(_sprite):
		strip.position = _sprite.position
		strip.modulate = _sprite.modulate


## Assign frames built in memory (tests, or a caller that already sliced a sheet).
func bind_motion_frames(frames: SpriteFrames) -> void:
	_ensure_visuals()
	var strip := get_node_or_null(BODY_STRIP_PATH) as AnimatedSprite2D
	if strip == null:
		strip = AnimatedSprite2D.new()
		strip.name = "BodyStrip"
		add_child(strip)
	strip.sprite_frames = frames
	strip.set_meta("_from_strip_library", false)
	if strip.has_meta("_chrome_frames_copy"):
		strip.remove_meta("_chrome_frames_copy")
	strip.visible = false
	strip.flip_h = false
	_prepare_strip_pose(strip)


func _library_frames() -> SpriteFrames:
	var spec: Dictionary = SEAT_COSMETICS.for_seat(seat, class_id)
	if spec.is_empty():
		return STRIP_LIBRARY.frames_for(class_id)
	return COSMETIC_STRIPS.frames_for(spec)


func _ensure_motion_strips() -> void:
	if class_id == "":
		return
	var frames := _library_frames()
	var existing := get_node_or_null(BODY_STRIP_PATH) as AnimatedSprite2D
	if existing != null and existing.sprite_frames != null:
		if not bool(existing.get_meta("_from_strip_library", false)):
			return
		if bool(existing.get_meta("_chrome_frames_copy", false)):
			return
		if frames == null or existing.sprite_frames == frames:
			return
	if frames == null:
		return
	var strip := existing
	if strip == null:
		strip = AnimatedSprite2D.new()
		strip.name = "BodyStrip"
		add_child(strip)
	strip.sprite_frames = frames
	strip.set_meta("_from_strip_library", true)
	if strip.has_meta("_chrome_frames_copy"):
		strip.remove_meta("_chrome_frames_copy")
	if not _strip_holds_body or _active_strip != strip:
		strip.visible = false
	strip.flip_h = false


func _play_walk_flat() -> bool:
	_ensure_visuals()
	_stop_idle()
	var choice := _strip_choice("walk")
	if choice.is_empty():
		return false
	var strip: AnimatedSprite2D = choice["node"]
	var anim := StringName(str(choice["anim"]))
	if strip == null or not is_instance_valid(strip):
		return false
	var continuing := (
		_walk_looping
		and _active_strip == strip
		and strip.visible
		and strip.animation == anim
		and strip.is_playing()
	)
	if continuing:
		_motion_playing = true
		_flatten_body()
		return true
	_kill_action()
	_end_body_strip()
	_prepare_walk_loop(strip, anim)
	_prepare_strip_pose(strip)
	strip.visible = true
	strip.play(anim)
	if not strip.is_playing():
		strip.visible = false
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.visible = true
		return false
	_active_strip = strip
	_strip_holds_body = true
	_walk_looping = true
	_motion_playing = true
	if _sprite != null and is_instance_valid(_sprite):
		strip.modulate = _sprite.modulate
		_sprite.visible = false
	_flatten_body()
	if _path_walk:
		return true
	var gen := _motion_gen
	var tw := create_tween()
	_action_tween = tw
	tw.tween_interval(WALK_HOP_SEC)
	tw.finished.connect(_on_action_finished.bind(gen), CONNECT_ONE_SHOT)
	return true


func _flatten_body() -> void:
	_ride_chrome(Vector2.ZERO)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = Vector2.ZERO
		_sprite.scale = SPRITE_SCALE
		_sprite.rotation = 0.0
		_sprite.flip_h = false
		if _walk_looping:
			_sprite.visible = false
	if _walk_looping and _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = Vector2.ZERO
		_active_strip.scale = SPRITE_SCALE
		_active_strip.rotation = 0.0
		_active_strip.flip_h = false


func _hide_body_strips() -> void:
	for child in get_children():
		if child is AnimatedSprite2D:
			(child as AnimatedSprite2D).visible = false


func _ride_chrome(pos: Vector2) -> void:
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.position = pos


func _place_body(pos: Vector2) -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = pos
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = pos
		if _sprite != null and is_instance_valid(_sprite):
			_active_strip.modulate = _sprite.modulate


func _request_paint() -> void:
	queue_redraw()
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.queue_redraw()


func _sprite_ready() -> bool:
	return _sprite != null and _sprite.texture != null


func _draw() -> void:
	if _sprite_ready():
		_draw_ground_mark()
	if debug_draw_tokens or not _sprite_ready():
		_draw_legacy_token()


func _draw_ground_mark() -> void:
	var foot := SEAT_RING_CENTER
	_draw_ellipse(foot, SEAT_RING_RX, SEAT_RING_RY, _seat_color())
	_draw_ellipse_ring(foot, SEAT_RING_RX, SEAT_RING_RY, Color(0.1, 0.07, 0.08, 0.85), 1.3)
	if burning:
		_draw_ellipse_ring(foot, 27.0, 10.5, Color(0.95, 0.32, 0.1, 0.95), 2.0)
	if stunned:
		_draw_ellipse_ring(foot, 24.0, 9.2, Color(0.95, 0.78, 0.2, 0.95), 2.0)
	if is_active:
		_draw_ellipse_ring(foot, 21.0, 8.2, Color(1.0, 0.92, 0.45, 1.0), 2.6)


func _paint_status(canvas: CanvasItem) -> void:
	if debug_draw_tokens or not _sprite_ready():
		return
	_paint_unit_chrome(canvas, HEAD_HP_Y, name_baseline())


## Baseline of the overhead name, in chrome-local space. The chrome node
## itself rides a walk hop. Lunges and the idle bob leave it on the pawn.
func name_baseline() -> float:
	return HEAD_HP_Y - NAME_GAP_ABOVE_HP - ThemeDB.fallback_font.get_descent(NAME_FONT_SIZE)


func name_label_origin() -> Vector2:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_CENTER, -1, NAME_FONT_SIZE)
	return Vector2(-size.x * 0.5, name_baseline())


func _draw_legacy_token() -> void:
	var fill := _body_color()
	if not alive:
		fill = Color(0.35, 0.35, 0.38, 0.85)
	if is_active:
		draw_circle(Vector2(0, -12), 14.0, Color(1, 0.92, 0.45, 0.55))
	if stunned:
		draw_circle(Vector2(0, -12), 16.0, Color(0.95, 0.78, 0.2, 0.35))
	if burning:
		draw_circle(Vector2(0, -12), 18.0, Color(0.95, 0.32, 0.1, 0.28))
	var body := fill
	if _hit_flash:
		body = body.lightened(0.35)
	draw_circle(Vector2(0, -12), 10.0, body)
	draw_arc(Vector2(0, -12), 10.0, 0.0, TAU, 24, Color(0.12, 0.08, 0.1), 1.6, true)

	var pointer: Vector2 = FACING_ISO.get(facing, Vector2(20, 10))
	var tip := Vector2(0, -12) + pointer.normalized() * 18.0
	draw_line(Vector2(0, -12), tip, Color(0.12, 0.08, 0.1), 2.0, true)
	draw_circle(tip, 2.4, Color(0.12, 0.08, 0.1))
	_paint_unit_chrome(self, -28.0, 10.0)


func _paint_unit_chrome(canvas: CanvasItem, hp_y: float, name_y: float) -> void:
	var bar_origin := Vector2(-14, hp_y)
	canvas.draw_rect(Rect2(bar_origin, Vector2(28, 4)), Color(0.12, 0.1, 0.12))
	var ratio := 0.0 if max_hp <= 0 else clampf(float(maxi(hp, 0)) / float(max_hp), 0.0, 1.0)
	var hp_color := _body_color().lightened(0.25)
	canvas.draw_rect(Rect2(bar_origin, Vector2(28.0 * ratio, 4)), hp_color)

	var font := ThemeDB.fallback_font
	var label := unit_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, NAME_FONT_SIZE)
	var label_x := -size.x * 0.5
	var name_color := Color(0.1, 0.08, 0.1)
	if name_y < hp_y:
		var ascent := font.get_ascent(NAME_FONT_SIZE)
		var descent := font.get_descent(NAME_FONT_SIZE)
		var plate := Rect2(Vector2(label_x - 4.0, name_y - ascent - 1.0), Vector2(size.x + 8.0, ascent + descent + 2.0))
		canvas.draw_rect(plate, Color(0.07, 0.05, 0.06, 0.84))
		name_color = Color(0.97, 0.95, 0.90)
	canvas.draw_string(font, Vector2(label_x, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, name_color)
	var badge_bottom := _badge_stack_bottom(font, hp_y, name_y)
	if stunned:
		var stun_size := font.get_string_size("STUN", HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var stun_y := badge_bottom - 12.0
		var badge := Rect2(Vector2(-stun_size.x * 0.5 - 3, stun_y), Vector2(stun_size.x + 6, 12))
		canvas.draw_rect(badge, Color(0.95, 0.78, 0.18, 0.95))
		canvas.draw_string(font, Vector2(-stun_size.x * 0.5, stun_y + 10), "STUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.12, 0.08, 0.1))
		badge_bottom = stun_y - 2.0
	if burning:
		var burn_label := burn_badge_label()
		if burn_label == "":
			burn_label = "BURN"
		var burn_size := font.get_string_size(burn_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var burn_y := badge_bottom - 12.0
		var burn_badge := Rect2(Vector2(-burn_size.x * 0.5 - 3, burn_y), Vector2(burn_size.x + 6, 12))
		canvas.draw_rect(burn_badge, Color(0.92, 0.28, 0.1, 0.95))
		_paint_flame(canvas, Vector2(burn_badge.position.x - 8.0, burn_y + 6.0))
		canvas.draw_string(font, Vector2(-burn_size.x * 0.5, burn_y + 10), burn_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.99, 0.94, 0.88))


## Bottom edge of the next overhead badge. Above the name when the name sits
## with the HP bar; otherwise the legacy gap above the token bar.
func _badge_stack_bottom(font: Font, hp_y: float, name_y: float) -> float:
	if name_y < hp_y:
		return name_y - font.get_ascent(NAME_FONT_SIZE) - 2.0
	return hp_y - 4.0


func _seat_color() -> Color:
	# Same greens / reds as the P1 / P2 deploy zone highlights.
	if seat == 1:
		return Color(0.78, 0.42, 0.42, 0.92)
	return Color(0.36, 0.72, 0.52, 0.92)


func _body_color() -> Color:
	match class_id:
		SpellKits.CLASS_IRONJAW:
			return Color("#b04a4a")
		SpellKits.CLASS_MENDER:
			return Color("#3d6ea8")
		SpellKits.CLASS_GLOAM:
			return Color("#6a5088")
		SpellKits.CLASS_BASTION:
			return Color("#7a7364")
		_:
			return Color("#4a8a62")


func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, rx, ry), color)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := _ellipse_points(center, rx, ry)
	if pts.is_empty():
		return
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


func _paint_flame(canvas: CanvasItem, origin: Vector2) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -7),
		origin + Vector2(3.5, -1),
		origin + Vector2(1.5, 0),
		origin + Vector2(3, 5),
		origin + Vector2(0, 2.5),
		origin + Vector2(-3, 5),
		origin + Vector2(-1.5, 0),
		origin + Vector2(-3.5, -1),
	]), Color(1.0, 0.42, 0.08, 0.98))
	canvas.draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -1),
		origin + Vector2(1.6, 2.2),
		origin + Vector2(0, 4),
		origin + Vector2(-1.6, 2.2),
	]), Color(1.0, 0.88, 0.4, 0.98))

