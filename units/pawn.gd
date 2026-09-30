extends Node2D
class_name Pawn

## One Sprite2D child ("Sprite") at the pawn origin. Feet sit on that origin:
## centered, offset (0, -72), scale 0.5, then the shared roster read (feet
## pivot, not the pick capsule). When a walk sheet exists, the standing
## pose is frame 0 of `walk_<facing>` so idle and the stride are one identity.
## That cell is drawn on WalkDraw. A paused strip keeps one cell on device
## while the pawn eases, which is the idle slide.
## `art/characters/<class>/<class>_<n|e|s|w>.png` stays the fallback when that
## sheet is missing. It is not the combat idle under a walk sheet, and it is
## not the class card. Select uses `art/ui/select/<class>_select.png`. Mirrors are baked into
## the files — never set flip_h.
## Bastion _n/_w turnarounds are placeholder back views on those filenames.
## Mobile-track chrome. Batch 1 strips load from
## `art/export_2x/characters/<class>/anims/` when the files exist
## (see that folder's README). Lettered names win: `walk_e` / `attack_e`
## (SE→e, SW→s, NE→n, NW→w). A drawn master name (`walk_se`, `attack_ne`)
## still resolves when the lettered clip is absent, then generic `walk` / `attack`.
## A walk strip plays one full cycle per tile. Authored 6 frames at 12 fps
## are sped so playback is about 20 fps and the cycle lasts WALK_TILE_SEC.
## The board samples that frame from the tile tween, so zoom and the frame
## clock cannot drift the stride. The foot-down cell shows when the hop is
## on the ground. The sprite hops a few pixels and squashes on the plant
## only. The foot, ground marks, shade, and name chrome stay on this node.
## If play() does not start, the same hop stays on the static sprite.
## There is no tile-tall hop.
## `grid_position` is the tactical cell. This node's origin is the visual foot.
## The contact shadow is the Foot child and does not rise with the body.
## Attack strips play one-shot on attack plans. Mark Shot plays `cast_mark_*`
## and falls back to v3 `attack_*` only when that sheet is missing.
## Detonate plays `cast_*` when present, otherwise a point pose — not attack_*.
## Hit plays the facing `hit_*` strip only after damage resolves: four
## 144×160 cells, flash on the first, settled on the last, feet on the
## walk baseline. A miss or a self-cast does not play it. The strip is the
## recoil, so it does not also knock or squash, and it does not resume a
## stride it interrupted. The white flash still rides on top.
## Death plays `death_*` and holds the last cell. Missing sheets keep the
## flash plus flinch, and a dissolve.
## Anticipation pulls back, the impact frame holds, then the body recovers.
## The clip keeps authored fps when that length still fits the 0.6s lock.
## A walk strip never plays the old hop arc. The fallback is the same bounce.
## Named paths: WalkStrip, AttackStrip, BodyStrip. A Sprite node that is an
## AnimatedSprite2D is kept as BodyStrip and the static sprite is recreated.
## Missing nodes, empty frames, or null textures keep the static sprite.
## Mirrors are baked. Never set flip_h.
## `debug_draw_tokens` keeps the old circle token as a fallback.

var grid_position: Vector2i = Vector2i.ZERO
var unit_name: String = ""
## Set by the board when this name plate would cover a neighbour's.
var name_nudge: Vector2 = Vector2.ZERO
var class_id: String = ""
var facing: String = "E"
## Fade's Neutral Invisible. The solid body stays off; status chrome is the read.
var invisible: bool = false
var seat: int = 0
## Package crop for a Stasis foe. Empty on Koliseo bodies.
var stasis_sprite: String = ""
## Room B foe: drawn bigger, with a BossAura on the ground (view only).
var stasis_boss: bool = false
var hp: int = 80
var max_hp: int = 80
var alive: bool = true
var is_active: bool = false
## Aim chrome while a unit spell is armed and this cell is selected.
## The ring is view-only. It does not change range or AP.
var target_marked: bool = false
var _target_pulse: float = 0.0
var stunned: bool = false
var burning: bool = false
var burn_remaining: int = 0
var burn_stacks: int = 0
var debug_draw_tokens: bool = false
var _hit_flash: bool = false
var _flashing: bool = false
var _sprite: Sprite2D
var _chrome: StatusChrome
var _idle_tween: Tween
var _action_tween: Tween
var _bounce_tween: Tween
var _landing_tween: Tween
var _gesture: GestureHand
var _bounce_gen: int = 0
var _motion_playing: bool = false
var _idle_hold: bool = false
var _motion_gen: int = 0
## Bumped when the collapse must stop. A late sample cannot hide the arrival.
var _ambush_collapse_gen: int = 0
## Invisible Ambush shows the body only after the back-tile plant.
var _ambush_strike_visible: bool = false
## Collapse keeps the body hidden even after the snapshot has cleared Invisible.
var _ambush_conceal: bool = false
## True only while the collapse tween is the action holding the motion lock.
var _collapse_holds_motion: bool = false
## Pre-strike vitals. A snapshot during the collapse must not paint the hit early.
var _vitals_frozen: bool = false
var _frozen_vitals: int = 0
var _frozen_vital_cap: int = 0
var _plan_died: bool = false
var _death_from: Color = Color.WHITE
var _death_sampled: bool = false
var _active_strip: AnimatedSprite2D
var _strip_holds_body: bool = false
## Standing combat pose. Frame 0 of the facing walk sheet, not the static turnaround.
var _walk_idle_plant: bool = false
var _path_walk: bool = false
var _walk_looping: bool = false
## Which half-cycle the driven step is on. The board does not pass this.
var _driven_step: int = 0
var _driven_open: bool = false
## The board owns the pose. A free clock would slide the contact frame.
var _driven_walk: bool = false
## Walk cells draw here. The strip stays the sampler and is not the phone picture.
var _walk_draw: Sprite2D
var _walk_draw_stamp: bool = false
var _walk_draw_cache: Dictionary = {}
var _strip_play_scale: float = 1.0
var _impact_frozen: bool = false
var _body_kind: String = ""
var _death_tilt: float = 1.0
var _held_death_strip: bool = false
var _foot: FootMark

const VIEW_MOTION := preload("res://units/view_motion.gd")
const STRIP_LIBRARY := preload("res://units/strip_library.gd")
const FIGURE_SHADER := preload("res://units/figure_read.gdshader")

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}
const FACING_ORDER: Array[String] = ["n", "e", "s", "w"]
const SPRITE_OFFSET := Vector2(0, -72)
const SPRITE_SCALE := Vector2(0.5, 0.5)
## Body scale per class (Mauro, 29 Sep): the plate fighters, Bastion and
## Ironjaw, are the biggest; Kestrel, Gloam and Mender are small. Scale grows
## from the foot offset (0, -72), so feet stay on the diamond. The pawn node
## and the pick capsule stay at scale 1. Kit numbers and maps never read this.
const PRESENTATION_SCALE_MIN := 0.80
const PRESENTATION_SCALE_CAP := 1.25
const HEAVY_COMBAT_SCALE := 1.18
const LIGHT_COMBAT_SCALE := 0.88
const IRONJAW_COMBAT_SCALE := HEAVY_COMBAT_SCALE
const CLASS_PRESENTATION_SCALE := {
	"ironjaw": HEAVY_COMBAT_SCALE,
	"bastion": HEAVY_COMBAT_SCALE,
	"kestrel": LIGHT_COMBAT_SCALE,
	"gloam": LIGHT_COMBAT_SCALE,
	"mender": LIGHT_COMBAT_SCALE,
}
## One cell of travel, straight or diagonal. Equal time keeps the slide even.
## Phase A tile time. Do not stretch this to hide a short or long cycle.
const WALK_TILE_SEC := 0.30
const WALK_HOP_SEC := WALK_TILE_SEC
## Authored walk sheet: 6 frames at 12 fps (864×160). Playback is
## walk_playback_fps(), about 20 fps, so one cycle matches one tile.
const WALK_STRIP_FRAMES := 6
const WALK_STRIP_FPS := 12.0
const WALK_STRIP_PATH := NodePath("WalkStrip")
const ATTACK_STRIP_PATH := NodePath("AttackStrip")
const BODY_STRIP_PATH := NodePath("BodyStrip")
## Shared HP line for a 0.5 figure (Bastion ~68px). Ironjaw uses head_hp_y().
const HEAD_HP_Y := -76.0
const NAME_FONT_SIZE := 12
## Seat ring under the feet. The name used to share this band.
const SEAT_RING_CENTER := Vector2(0, 3)
const SEAT_RING_RX := 18.0
const SEAT_RING_RY := 7.0
const NAME_GAP_ABOVE_HP := 2.0

static var _sprite_cache: Dictionary = {}


## Resting combat scale. Missing classes stay on the shared 0.5. A listed
## class uses the capped interim nudge. Ironjaw ships at 1.0.
static func sprite_scale_for(class_id: String) -> Vector2:
	return SPRITE_SCALE * presentation_mul(class_id)


## Class multiplier inside the 0.80–1.25 band. Anything outside is ignored.
static func presentation_mul(class_id: String) -> float:
	var key := SpellKits.normalize_class_id(class_id)
	return capped_presentation_mul(float(CLASS_PRESENTATION_SCALE.get(key, 1.0)))


static func capped_presentation_mul(raw: float) -> float:
	if is_equal_approx(raw, 1.0):
		return 1.0
	if raw >= PRESENTATION_SCALE_MIN and raw <= PRESENTATION_SCALE_CAP:
		return raw
	return 1.0


## A Stasis boss towers over the pack (Mauro: "boss looking lame").
const BOSS_SCALE := 1.5
## Regular Stasis monsters read bigger on the board too (Mauro 30 Sep 2026:
## "Yes" to ~15–20% bigger, Dofus-sized monsters). View only.
const TRASH_SCALE := 1.18


func _monster_scale() -> float:
	if stasis_sprite == "":
		return 1.0
	return BOSS_SCALE if stasis_boss else TRASH_SCALE


## Stasis foe art may be drawn at 2x (288x320): same world size, more detail.
func _stasis_res() -> float:
	if stasis_sprite == "" or _sprite == null or not is_instance_valid(_sprite) or _sprite.texture == null:
		return 1.0
	var h := float(_sprite.texture.get_height())
	return 160.0 / h if h > 0.0 else 1.0


func _body_scale() -> Vector2:
	return sprite_scale_for(class_id) * _monster_scale() * _stasis_res()


func _body_scale_mul(mul: Vector2) -> Vector2:
	var base := _body_scale()
	return Vector2(base.x * mul.x, base.y * mul.y)


## Shared bar clears a 0.5 figure. Ironjaw's bar rises with his presentation
## scale so the name still clears the taller cell.
func head_hp_y() -> float:
	# Heavy bodies raise the bar; small bodies keep the shared line above them.
	# World size only: the 2x foe art factor (_stasis_res) is not a size change.
	var world := sprite_scale_for(class_id).y * _monster_scale()
	return HEAD_HP_Y * maxf(world / SPRITE_SCALE.y, 1.0)


## Ground contact. Stays on the visual foot. The body sprite rises above it.
class FootMark extends Node2D:
	var host: Pawn

	func _draw() -> void:
		if host != null:
			host._draw_ground_mark_on(self)


## A small reach drawn in front of the body during a cast or a lunge.
## Same mark on every fighter. It is a gesture, not a cosmetic.
class GestureHand extends Node2D:
	func _draw() -> void:
		var palm := PackedVector2Array([
			Vector2(9, 0),
			Vector2(2, 5),
			Vector2(-7, 3),
			Vector2(-7, -3),
			Vector2(2, -5),
		])
		draw_colored_polygon(palm, Color(1.0, 0.94, 0.84, 0.96))
		var loop := palm.duplicate()
		loop.append(palm[0])
		draw_polyline(loop, Color(0.16, 0.08, 0.06, 0.95), 1.6, true)
		draw_line(Vector2(2, -3.5), Vector2(8, -7), Color(1.0, 0.94, 0.84, 0.96), 2.2, true)
		draw_line(Vector2(2, 3.5), Vector2(8, 7), Color(1.0, 0.94, 0.84, 0.96), 2.2, true)
		draw_line(Vector2(3, -1), Vector2(10, -1), Color(1.0, 0.94, 0.84, 0.96), 2.2, true)


class StatusChrome extends Node2D:
	var host: Pawn

	func _draw() -> void:
		if host != null:
			host._paint_status(self)


## `events` supply Burn only when the unit dict has no `burn_remaining` / `burn_stacks`.
## This pawn does not tick Burn or add stacks; the next host snapshot replaces both.
func apply_snapshot(unit: Dictionary, active_seat: int, events: Array = []) -> void:
	grid_position = unit["pos"]
	unit_name = str(unit["name"])
	class_id = str(unit["class_id"])
	stasis_sprite = str(unit.get("stasis_sprite", ""))
	stasis_boss = bool(unit.get("stasis_boss", false)) and stasis_sprite != ""
	facing = str(unit["facing"])
	invisible = bool(unit.get("invisible", false))
	seat = int(unit.get("seat", seat))
	hp = int(unit["hp"])
	max_hp = int(unit["max_hp"])
	alive = bool(unit["alive"])
	is_active = int(unit["seat"]) == active_seat and alive
	_hit_flash = false
	stunned = int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))
	burn_remaining = CombatHUD.unit_burn_remaining(unit, events)
	burn_stacks = CombatHUD.unit_burn_stacks(unit, events)
	burning = burn_remaining > 0 and burn_stacks > 0
	if alive and (_held_death_strip or _body_kind == "death"):
		_held_death_strip = false
		_plan_died = false
		_end_body_strip()
	_sync_sprite()
	_sync_idle()
	if alive and _vanished:
		_vanished = false
		modulate.a = 1.0
		visible = true
	elif not alive and stasis_sprite != "" and not _motion_playing:
		_vanish_if_monster()
	# Breath and sway follow alive (and class/seat) on every body material.
	_apply_figure_read()
	rewrite_frozen_vitals()


func burn_badge_label() -> String:
	return CombatHUD.burn_badge_text(burn_remaining, burn_stacks)


func set_facing(dir: String) -> void:
	if dir == "" or dir == facing:
		return
	facing = dir
	_sync_sprite()


## A snapshot refresh during a step must not lock the end-of-path facing.
func hold_walk_facing(dir: String) -> void:
	if dir == "":
		return
	facing = dir
	if _path_walk or _driven_walk:
		retarget_walk_strip()
	else:
		_sync_sprite()


func facing_screen() -> Vector2:
	return FACING_ISO.get(facing, Vector2(20, 10))


## The cell combat and sorting commit. The node position can sit between cells.
func tactical_cell() -> Vector2i:
	return grid_position


func motion_playing() -> bool:
	return _motion_playing


## True when a walk strip is actually playing.
## The pawn node slides either way. The sprite root takes the step bounce,
## including when play() does not start. A path bounce is not restarted per tile.
func play_step_hop() -> bool:
	_kill_landing()
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		_end_body_strip()
		return false
	_ensure_motion_strips()
	var playing := _play_walk_flat()
	# A failed play replants the walk sheet. Hiding strips here would uncover
	# the static still for the hop.
	if not playing and not _walk_idle_plant:
		_hide_body_strips()
	if _path_walk:
		if not _bounce_running():
			_start_path_bounce()
		return playing
	_start_step_bounce()
	return playing


func _bounce_running() -> bool:
	return _bounce_tween != null and is_instance_valid(_bounce_tween) and _bounce_tween.is_running()


func _kill_bounce() -> void:
	_bounce_gen += 1
	if _bounce_tween != null and is_instance_valid(_bounce_tween):
		_bounce_tween.kill()
	_bounce_tween = null


func _kill_landing() -> void:
	if _landing_tween != null and is_instance_valid(_landing_tween):
		_landing_tween.kill()
	_landing_tween = null


## Feet stay planted. The body squashes and releases so the step has a landing.
func _play_landing() -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree() or _motion_playing:
		return
	_kill_landing()
	var tw := create_tween()
	_landing_tween = tw
	tw.tween_method(_sample_landing, 0.0, 1.0, VIEW_MOTION.LAND_SEC)
	tw.finished.connect(func() -> void:
		if _landing_tween == tw:
			_landing_tween = null
	)


func _sample_landing(t: float) -> void:
	if _motion_playing or _path_walk:
		return
	var mul := VIEW_MOTION.landing_scale(t)
	var scaled := _body_scale_mul(mul)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = scaled
		_sprite.position = Vector2.ZERO


func _ensure_gesture() -> void:
	if _gesture != null and is_instance_valid(_gesture):
		return
	_gesture = GestureHand.new()
	_gesture.name = "Gesture"
	_gesture.z_index = 3
	_gesture.z_as_relative = true
	_gesture.visible = false
	add_child(_gesture)


func _hide_gesture() -> void:
	if _gesture != null and is_instance_valid(_gesture):
		_gesture.visible = false


func _place_gesture(phase: String, aim: Vector2, body_pos: Vector2) -> void:
	var reach := VIEW_MOTION.gesture_reach(phase)
	# A monster strikes with its own body, not the heroes' hand mark.
	if reach <= 0.0 or VIEW_MOTION.reduce_motion() or stasis_sprite != "":
		_hide_gesture()
		return
	_ensure_gesture()
	var dir := aim
	if dir.length_squared() < 0.01:
		dir = facing_screen()
	if dir.length_squared() < 0.01:
		_hide_gesture()
		return
	dir = dir.normalized()
	_gesture.position = body_pos + Vector2(0, -46) + dir * reach
	_gesture.rotation = dir.angle()
	_gesture.visible = true
	_gesture.queue_redraw()


## Loop the step sine until end_path_walk. Phase is the walk cycle, not the tile.
func _start_path_bounce() -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_kill_bounce()
	_stop_idle()
	_motion_playing = true
	var tw := create_tween()
	tw.set_loops(0)
	_bounce_tween = tw
	tw.tween_method(_sample_hop, 0.0, 1.0, WALK_TILE_SEC)


## One plant-to-plant bob for a step that is not part of a path.
func _start_step_bounce() -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_kill_bounce()
	_stop_idle()
	_motion_playing = true
	var gen := _bounce_gen
	var tw := create_tween()
	_bounce_tween = tw
	tw.tween_method(_sample_hop, 0.0, 1.0, WALK_TILE_SEC)
	tw.finished.connect(_on_step_bounce_finished.bind(gen), CONNECT_ONE_SHOT)


func _on_step_bounce_finished(gen: int) -> void:
	if gen != _bounce_gen or _path_walk:
		return
	_bounce_tween = null
	_motion_playing = false
	_plant_sprite()
	_play_landing()


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


## Hold the walk loop and the step bounce across every tile. The board calls this once.
func begin_path_walk() -> void:
	_path_walk = true
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_ensure_motion_strips()
	if not _play_walk_flat() and not _walk_idle_plant:
		_hide_body_strips()
	_start_path_bounce()


## One path segment. Facing is the segment delta, then the walk strip for that
## letter is the body. False means the idle still is still showing: the caller
## must not translate.
func begin_segment_walk(dir: String) -> bool:
	var face := dir.strip_edges().to_upper()
	if face != "" and facing != face:
		facing = face
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return false
	_driven_walk = true
	_path_walk = true
	if not _present_driven_walk():
		return false
	return body_is_segment_walk(face if face != "" else facing)


## True when the drawn body is walk_<facing> with a real cycle. The idle sprite
## being visible is the slide. WalkDraw is that body: the strip is only the sampler.
func body_is_segment_walk(dir: String) -> bool:
	if _sprite != null and is_instance_valid(_sprite) and _sprite.visible:
		return false
	var face := dir.strip_edges().to_lower()
	if _walk_draw_matches(face):
		return true
	if _active_strip == null or not is_instance_valid(_active_strip) or not _active_strip.visible:
		return false
	var anim := str(_active_strip.animation)
	if face == "" or anim != "walk_%s" % face:
		return false
	var frames := _active_strip.sprite_frames
	if frames == null or not frames.has_animation(_active_strip.animation):
		return false
	return frames.get_frame_count(_active_strip.animation) >= 2


## The phone picture for a walk. Tests read the hidden sampler through this.
func walk_cell_is_drawn() -> bool:
	return _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw) and _walk_draw.visible


func walk_sampler() -> AnimatedSprite2D:
	if _active_strip != null and is_instance_valid(_active_strip):
		return _active_strip
	return null


func drawn_walk_texture() -> Texture2D:
	if walk_cell_is_drawn():
		return _walk_draw.texture
	return null


func _walk_draw_matches(face: String) -> bool:
	if not _walk_draw_stamp or face == "":
		return false
	if _walk_draw == null or not is_instance_valid(_walk_draw) or not _walk_draw.visible:
		return false
	if _walk_draw.texture == null:
		return false
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip) or strip.sprite_frames == null:
		return false
	var anim := "walk_%s" % face
	if str(strip.animation) != anim:
		return false
	var frames := strip.sprite_frames
	if not frames.has_animation(anim) or frames.get_frame_count(anim) < 2:
		return false
	return true


func _ensure_walk_draw() -> Sprite2D:
	if _walk_draw != null and is_instance_valid(_walk_draw):
		return _walk_draw
	var existing := get_node_or_null("WalkDraw") as Sprite2D
	if existing != null:
		_walk_draw = existing
		return existing
	var node := Sprite2D.new()
	node.name = "WalkDraw"
	node.centered = true
	node.offset = SPRITE_OFFSET
	node.scale = _body_scale()
	node.flip_h = false
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.z_index = 1
	node.z_as_relative = true
	node.visible = false
	node.material = _figure_material()
	add_child(node)
	_walk_draw = node
	return node


func _hide_walk_draw() -> void:
	_walk_draw_stamp = false
	if _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.visible = false


## Copy the sampled cell onto WalkDraw. The strip stays paused and hidden so
## a device that never refreshes AnimatedSprite2D.frame cannot keep the plant.
func _publish_walk_cell() -> void:
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		return
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(strip.animation):
		return
	var count := frames.get_frame_count(strip.animation)
	if count < 1:
		return
	var index := clampi(strip.frame, 0, count - 1)
	var tex := _cell_texture_for_draw(frames, strip.animation, index)
	if tex == null:
		return
	var draw := _ensure_walk_draw()
	draw.texture = tex
	draw.visible = true
	draw.flip_h = false
	draw.centered = true
	draw.offset = SPRITE_OFFSET
	draw.position = strip.position
	draw.scale = strip.scale
	draw.rotation = strip.rotation
	if _sprite != null and is_instance_valid(_sprite):
		draw.modulate = _sprite.modulate
		_sprite.visible = false
	else:
		draw.modulate = rest_modulate()
	strip.visible = false
	strip.speed_scale = 0.0
	strip.modulate = draw.modulate
	_walk_draw_stamp = true
	_apply_figure_read()


func _cell_texture_for_draw(frames: SpriteFrames, anim: StringName, index: int) -> Texture2D:
	var tex := frames.get_frame_texture(anim, index)
	if tex is ImageTexture:
		return tex
	var key := "%s:%s" % [class_id, str(anim)]
	if not _walk_draw_cache.has(key):
		var built: Array[Texture2D] = []
		var face := key.trim_prefix("walk_")
		var packed := STRIP_LIBRARY.image_from_walk_bytes(class_id, face)
		if packed != null:
			built = STRIP_LIBRARY.textures_from_image(packed, frames.get_frame_count(anim))
		_walk_draw_cache[key] = built
	var cached: Array = _walk_draw_cache[key]
	if index >= 0 and index < cached.size() and cached[index] != null:
		return cached[index]
	if tex == null:
		return null
	var image := tex.get_image()
	if image != null and not image.is_empty():
		if tex is AtlasTexture:
			var atlas := tex as AtlasTexture
			var region := Rect2i(
				int(atlas.region.position.x),
				int(atlas.region.position.y),
				int(atlas.region.size.x),
				int(atlas.region.size.y)
			)
			if image.get_width() > region.size.x or image.get_height() > region.size.y:
				var cut := image.get_region(region)
				if cut != null and not cut.is_empty():
					return ImageTexture.create_from_image(cut)
		return ImageTexture.create_from_image(image)
	return tex


func _sync_walk_draw_xform() -> void:
	if not _walk_draw_stamp or _walk_draw == null or not is_instance_valid(_walk_draw):
		return
	if _sprite == null or not is_instance_valid(_sprite):
		return
	_walk_draw.position = _sprite.position
	_walk_draw.scale = _sprite.scale
	_walk_draw.rotation = _sprite.rotation
	if not _flashing:
		_walk_draw.modulate = _sprite.modulate


## Board-driven steps own the gait. Drop the free-running bounce so the plant
## matches the tile instead of sliding under a looping hop.
func arm_driven_walk() -> void:
	_driven_step = 0
	_driven_open = false
	_driven_walk = true
	begin_path_walk()
	_kill_bounce()
	_hold_driven_pose()


## Foot-down cell for the facing walk. Frame 0 on the v5 sheets. Another
## index only when that cell is not the planted row. Tile time stays put.
func walk_contact_frame() -> int:
	if class_id == "":
		return 0
	STRIP_LIBRARY.frames_for(class_id)
	return STRIP_LIBRARY.walk_contact_index(class_id, facing)


func _sampled_walk_frame(t: float, count: int) -> int:
	return VIEW_MOTION.walk_cycle_frame(t, count, _driven_step, walk_contact_frame())


## Seek the facing's walk clip to the contact frame for this tile.
func sync_walk_plant() -> void:
	if not _path_walk or VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_ensure_motion_strips()
	_play_walk_flat()
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		return
	if not strip.visible and not _walk_draw_stamp:
		return
	if _driven_open:
		_driven_step += 1
	_driven_open = true
	strip.speed_scale = 0.0 if _driven_walk else walk_strip_speed_scale()
	var frames := strip.sprite_frames
	if frames != null and frames.has_animation(strip.animation) and frames.get_frame_count(strip.animation) > 0:
		strip.frame = _sampled_walk_frame(0.0, frames.get_frame_count(strip.animation))
		strip.frame_progress = 0.0
	if _driven_walk or _walk_draw_stamp:
		_publish_walk_cell()


## One tile of the path. t is 0 at the departure contact and 1 on the plant.
## The walk frame comes from t, one full cycle, so a free clock cannot idle-slide
## and arrival cannot freeze a passing frame. The hop is sprite-local.
func sample_driven_gait(t: float) -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	# A flinch cleared the stride. Later samples must not put the passing
	# frame back on screen.
	if not _path_walk or _hit_strip_is_body():
		return
	_kill_bounce()
	var u := clampf(t, 0.0, 1.0)
	_apply_hop_visual(u)
	_apply_driven_cycle(u)


## Facing is already the segment letter. A short lean, then the tween.
## The pawn node does not move. Frame 0 stays up so the settle is not a slide.
func sample_step_anticipation(t: float) -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_kill_bounce()
	var lean := VIEW_MOTION.step_anticipation_offset(t, facing_screen())
	_place_body(lean)
	_ride_chrome(Vector2.ZERO)
	_hold_walk_contact()
	_reset_walk_scale()


func _apply_driven_cycle(t: float) -> void:
	if not _path_walk:
		return
	_ensure_motion_strips()
	var choice := _strip_choice("walk")
	if not choice.is_empty():
		var next: AnimatedSprite2D = choice["node"]
		var anim := StringName(str(choice["anim"]))
		if next != null and is_instance_valid(next):
			if next.animation != anim or (not next.visible and not _walk_draw_stamp):
				if _sprite != null and is_instance_valid(_sprite):
					_sprite.visible = false
				next.visible = true
				next.animation = anim
				_active_strip = next
				_strip_holds_body = true
				_walk_looping = true
				next.speed_scale = 0.0
			elif _active_strip != next:
				_active_strip = next
				_strip_holds_body = true
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		return
	if not strip.visible and not _walk_draw_stamp:
		return
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(strip.animation):
		return
	var count := frames.get_frame_count(strip.animation)
	if count <= 1:
		return
	# The step owns the pose. A running clock would leave the idle cell on screen.
	if strip.is_playing():
		strip.pause()
	strip.speed_scale = 0.0
	strip.frame = _sampled_walk_frame(t, count)
	strip.frame_progress = 0.0
	_publish_walk_cell()


## Swap the walk clip when facing snaps. Does not restart the path bounce.
func retarget_walk_strip() -> void:
	if not _path_walk or VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_ensure_motion_strips()
	_play_walk_flat()
	_hold_driven_pose()


func _hold_driven_pose() -> void:
	if not _driven_walk:
		return
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.speed_scale = 0.0


## Straight seam. Keep the contact pose on the walk strip. Do not hide it
## for an idle flash, and do not settle.
func bridge_straight_tile() -> void:
	if VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return
	_path_walk = true
	_driven_walk = true
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip) or (not strip.visible and not _walk_draw_stamp):
		sync_walk_plant()
		return
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = false
	var frames := strip.sprite_frames
	if frames != null and frames.has_animation(strip.animation):
		var count := frames.get_frame_count(strip.animation)
		if count > 0:
			strip.frame = _sampled_walk_frame(1.0, count)
			strip.frame_progress = 0.0
	strip.speed_scale = 0.0
	_publish_walk_cell()
	_place_body(Vector2.ZERO)
	_ride_chrome(Vector2.ZERO)
	_apply_sprite_mul(Vector2.ONE)


## Landed plant, held before a cast or the face pad. Contact frame, hop
## down, squash already released. Not a passing cell.
func hold_stop_plant() -> void:
	if not is_inside_tree():
		return
	sample_driven_gait(1.0)
	_place_body(Vector2.ZERO)
	_ride_chrome(Vector2.ZERO)
	_apply_sprite_mul(Vector2.ONE)
	var strip := _active_strip
	if strip != null and is_instance_valid(strip) and (strip.visible or _walk_draw_stamp):
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.visible = false
		strip.speed_scale = 0.0
		_publish_walk_cell()


## Path end or interrupt. Plant the facing walk and let idle resume.
## A walk strip already took its plant squash. A missing strip still lands.
func end_path_walk() -> void:
	_path_walk = false
	_driven_step = 0
	_driven_open = false
	_driven_walk = false
	_kill_bounce()
	_kill_action()
	_motion_playing = false
	_plant_sprite()
	# The stride already took its plant squash. A walk frame-0 plant does not
	# squash again. A missing strip still lands.
	if not _walk_idle_plant:
		_play_landing()


## Playback rate that puts one full cycle on one tile.
## 6 frames → 20 fps. 8 frames → about 27 fps. Not the authored 12 fps.
static func walk_playback_fps(frame_count: int = -1) -> float:
	var count := WALK_STRIP_FRAMES if frame_count < 1 else frame_count
	if WALK_TILE_SEC <= 0.0:
		return WALK_STRIP_FPS
	return float(count) / WALK_TILE_SEC


## Authored cycle length divided by the tile, so a running clock matches the
## driven sampler. One integer cycle per tile. Not a half-cycle skate.
static func walk_strip_speed_scale() -> float:
	var authored := float(WALK_STRIP_FRAMES) / WALK_STRIP_FPS
	if WALK_TILE_SEC <= 0.0:
		return 1.0
	return authored / WALK_TILE_SEC


## Mark Shot uses cast_mark_* when Batch-1c is on disk. Until then the v3
## attack_* bow plays. Detonate must not borrow that attack strip.
func _mark_falls_back_to_attack(plan: Dictionary) -> bool:
	if str(plan.get("strip", "")) != "cast_mark":
		return false
	if not _strip_choice("cast_mark").is_empty():
		return false
	return not _strip_choice("attack").is_empty()


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
	_death_tilt = float(plan.get("tilt", (1.0 if int(seat) % 2 == 0 else -1.0)))
	_held_death_strip = false
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
		elif kind == "whiff":
			tw.tween_method(_sample_ambush_whiff, 0.0, 1.0, sec)
			tw.tween_callback(restore_ambush_body)
		elif kind == "attack" or (kind == "cast" and _mark_falls_back_to_attack(plan)):
			var play_sec := _fit_strip_window("attack", sec, steps)
			var aim: Vector2 = step.get("dir", plan.get("aim", Vector2.ZERO))
			if aim.length_squared() < 0.01:
				aim = facing_screen()
			_face_strike(aim)
			var reach := float(step.get("reach", plan.get("reach", VIEW_MOTION.ATTACK_LUNGE_PX)))
			_begin_body_strip("attack", play_sec)
			tw.tween_method(_sample_attack.bind(aim, reach), 0.0, 1.0, play_sec)
			tw.tween_callback(_end_body_strip)
			total += play_sec - sec
		elif kind == "cast":
			var strip_kind := str(step.get("strip", plan.get("strip", "cast")))
			var aim_cast: Vector2 = step.get("dir", plan.get("aim", Vector2.ZERO))
			_face_strike(aim_cast if aim_cast.length_squared() > 0.01 else facing_screen())
			if strip_kind == "cast_mark" and not _strip_choice("cast_mark").is_empty():
				var bow_sec := _fit_strip_window("cast_mark", sec, steps)
				_begin_body_strip("cast_mark", bow_sec)
				tw.tween_method(_sample_attack.bind(aim_cast if aim_cast.length_squared() > 0.01 else facing_screen(), VIEW_MOTION.ATTACK_LUNGE_PX), 0.0, 1.0, bow_sec)
				tw.tween_callback(_end_body_strip)
				total += bow_sec - sec
			elif strip_kind != "" and not _strip_choice(strip_kind).is_empty():
				var cast_play := _fit_strip_window(strip_kind, sec, steps)
				_begin_body_strip(strip_kind, cast_play)
				tw.tween_method(_sample_cast.bind(aim_cast), 0.0, 1.0, cast_play)
				tw.tween_callback(_end_body_strip)
				total += cast_play - sec
			else:
				# TODO(TA): Detonate cast_* is not on disk. Point pose only.
				tw.tween_method(_sample_cast.bind(aim_cast), 0.0, 1.0, sec)
		elif kind == "hit":
			tw.tween_callback(_interrupt_stride_for_flinch)
			tw.tween_callback(_end_body_strip)
			if not _strip_choice("hit").is_empty():
				var hit_play := _fit_strip_window("hit", sec, steps)
				tw.tween_callback(_start_kind_strip.bind("hit", hit_play))
				total += hit_play - sec
				sec = hit_play
			tw.tween_method(_sample_hit.bind(step.get("dir", Vector2.ZERO)), 0.0, 1.0, sec)
		elif kind == "lift":
			tw.tween_callback(_end_body_strip)
			tw.tween_method(_sample_lift, 0.0, 1.0, sec)
		elif kind == "death":
			var tilt := float(step.get("tilt", _death_tilt))
			if _strip_choice("death").is_empty():
				# TODO(TA): death_* is not on disk. Collapse and dissolve.
				tw.tween_callback(_end_body_strip)
				tw.tween_method(_sample_death.bind(tilt), 0.0, 1.0, sec)
			else:
				var death_play := _fit_strip_window("death", sec, steps)
				tw.tween_callback(_start_kind_strip.bind("death", death_play))
				tw.tween_method(_sample_death_strip.bind(tilt), 0.0, 1.0, death_play)
				total += death_play - sec
	if total <= 0.0:
		_plan_died = false
		_kill_action()
		_motion_playing = false
		_start_idle()
		return 0.0
	tw.finished.connect(_on_action_finished.bind(gen), CONNECT_ONE_SHOT)
	return minf(total, VIEW_MOTION.ACTION_LOCK_MAX)


## Fade and shrink on the current tile. The board snaps after this returns.
## A miss uses the whiff step instead, and that one restores itself.
func play_ambush_collapse(sec: float) -> float:
	if sec <= 0.0 or VIEW_MOTION.reduce_motion() or not is_inside_tree():
		return 0.0
	_begin_action()
	_ambush_collapse_gen += 1
	_collapse_holds_motion = true
	var gen := _ambush_collapse_gen
	var tw := create_tween()
	_action_tween = tw
	tw.tween_method(_sample_ambush_collapse.bind(gen), 0.0, 1.0, sec)
	tw.finished.connect(_on_ambush_collapse_finished.bind(gen), CONNECT_ONE_SHOT)
	return sec


func _on_ambush_collapse_finished(gen: int) -> void:
	# A plant bumps the gen, and a later strike clears the flag in _begin_action.
	# Either one means this collapse no longer owns the lock.
	if gen != _ambush_collapse_gen or not _collapse_holds_motion:
		return
	_collapse_holds_motion = false
	_motion_playing = false
	_action_tween = null


func restore_ambush_body() -> void:
	# Drop any collapse sample that is still queued for this frame.
	_ambush_collapse_gen += 1
	if _collapse_holds_motion:
		_collapse_holds_motion = false
		_kill_action()
		_motion_playing = false
	_show_rest_body()


func _sample_ambush_collapse(t: float, gen: int) -> void:
	if gen != _ambush_collapse_gen or _sprite == null:
		return
	var k := clampf(t, 0.0, 1.0)
	var shrunk := lerpf(1.0, 0.12, k)
	_sprite.scale = _body_scale() * shrunk
	var color := rest_modulate()
	# Start from the resting alpha. Forcing 1 here flashes a solid body
	# on a hidden Invisible pawn before the snap.
	color.a = lerpf(color.a, 0.0, k)
	_sprite.modulate = color
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.scale = _sprite.scale
		_active_strip.modulate = color
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.scale = _sprite.scale
		_walk_draw.modulate = color


func _sample_ambush_whiff(t: float) -> void:
	if _sprite == null:
		return
	var k := sin(clampf(t, 0.0, 1.0) * PI)
	_sprite.scale = _body_scale_mul(Vector2(lerpf(1.0, 1.12, k), lerpf(1.0, 0.8, k)))
	var color := rest_modulate()
	color.a = lerpf(color.a, color.a * 0.4, k)
	_sprite.modulate = color
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.scale = _sprite.scale
		_walk_draw.modulate = color


## Strike and cast strips face the prey. A tie between two letters keeps the stand,
## so a straight screen-right aim does not spin a pawn that is already facing east.
func _face_strike(aim: Vector2) -> void:
	if aim.length_squared() < 1.0:
		return
	var face := _unique_aim_facing(aim)
	if face == "" or face == facing:
		return
	facing = face
	_sync_sprite()


func _unique_aim_facing(aim: Vector2) -> String:
	var unit := aim.normalized()
	var best := ""
	var best_dot := -2.0
	var second := -2.0
	for face in ["N", "E", "S", "W"]:
		var axis: Vector2 = VIEW_MOTION.FACING_SCREEN[face]
		var dotted := unit.dot(axis.normalized())
		if dotted > best_dot:
			second = best_dot
			best_dot = dotted
			best = face
		elif dotted > second:
			second = dotted
	if best == "" or best_dot - second < 0.08:
		return ""
	return best


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
	_ambush_strike_visible = false
	_ambush_conceal = false
	_collapse_holds_motion = false
	var died := _plan_died
	_plan_died = false
	_path_walk = false
	_driven_walk = false
	_kill_bounce()
	_kill_landing()
	_kill_action()
	_motion_playing = false
	if died or not alive:
		_stop_idle()
		_flashing = false
		_apply_downed_pose()
		return
	_show_rest_body()
	_start_idle()


func plant_sprite() -> void:
	_plant_sprite()


## End one path step. A looping walk strip and the path bounce stay up.
func finish_step() -> void:
	if _path_walk and (_walk_looping or _bounce_running()):
		_motion_playing = true
		return
	_kill_bounce()
	_kill_action()
	_motion_playing = false
	_plant_sprite()


func flash_hit() -> void:
	_hit_flash = true
	# Tuned for the fixed figure shader (was 2.8 while the art rendered squared).
	_apply_flash(Color(1.9, 1.85, 1.8))


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
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw) and _walk_draw.visible:
		return _walk_draw
	if _strip_holds_body and _active_strip != null and is_instance_valid(_active_strip) and _active_strip.visible:
		return _active_strip
	if _sprite != null:
		return _sprite
	return self


func rest_modulate() -> Color:
	if not alive:
		return Color(0.45, 0.45, 0.45, VIEW_MOTION.DEATH_FADE_ALPHA)
	# Locked Fade: do not draw a solid body while Invisible, including the walk.
	# The Ambush plant is the exception, and only after the back-tile snap.
	if _ambush_conceal:
		return Color(1, 1, 1, 0)
	if invisible and not _ambush_strike_visible:
		return Color(1, 1, 1, 0)
	# Stasis foe art is darker than the heroes' and sinks into night floors.
	if stasis_sprite != "":
		return FOE_LIGHT
	return Color.WHITE


## Stay hidden through the collapse. A snapshot that already cleared Invisible
## must not draw the body on the cast cell.
func conceal_for_ambush() -> void:
	_ambush_conceal = true
	_ambush_strike_visible = false
	_apply_rest_color()


## Reveal Gloam on the back tile. The cast cell stays hidden.
func show_ambush_plant() -> void:
	_ambush_conceal = false
	invisible = false
	_ambush_strike_visible = true
	_apply_rest_color()


## Miss, or any Ambush that does not plant. Invisible is over. No slash pose.
func reveal_after_ambush() -> void:
	_ambush_conceal = false
	invisible = false
	_ambush_strike_visible = false
	_apply_rest_color()


func _apply_rest_color() -> void:
	var color := rest_modulate()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = color
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.modulate = color
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.modulate = color


func note_flash_settled() -> void:
	_flashing = false
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = rest_modulate()


## Overhead bar for a prey whose hit was already resolved. The board calls this
## only after the caster is standing on the back tile, facing them.
func note_prey_vitals(unit: Dictionary) -> void:
	note_resolved_vitals(unit)


## The sim has already subtracted the hit. Paint that total with the float.
## A plant hold keeps the pre-contact read until the slash releases it.
func note_resolved_vitals(unit: Dictionary) -> void:
	if _vitals_frozen:
		return
	hp = int(unit.get("hp", hp))
	max_hp = int(unit.get("max_hp", max_hp))
	_request_paint()


## Remember the numbers on screen. Later snapshots during the plant hold rewrite
## back to these until the slash releases them.
func freeze_shown_vitals() -> void:
	_vitals_frozen = true
	_frozen_vitals = hp
	_frozen_vital_cap = max_hp


func rewrite_frozen_vitals() -> void:
	if not _vitals_frozen:
		return
	hp = _frozen_vitals
	max_hp = _frozen_vital_cap
	_request_paint()


func release_frozen_vitals() -> void:
	_vitals_frozen = false


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
	return _texture_at(sprite_path(class_id, facing))


## Old deploy still. A different costume from the walk sheet. The combat
## body does not show it. Null when the file is missing.
static func idle_plant_path(class_id: String, facing: String) -> String:
	var cls := SpellKits.normalize_class_id(class_id)
	var face := facing.strip_edges().to_lower()
	if not FACING_ORDER.has(face):
		face = "e"
	return "res://art/export_2x/characters/%s/idle/%s_idle_plant_%s_v1.png" % [cls, cls, face]


static func idle_plant_texture(class_id: String, facing: String) -> Texture2D:
	var path := idle_plant_path(class_id, facing)
	if not FileAccess.file_exists(path):
		return null
	return _texture_at(path)


static func _stasis_texture(path: String) -> Texture2D:
	return _texture_at(path)


static func _texture_at(path: String) -> Texture2D:
	if path == "":
		return null
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
	if _active_strip != null and is_instance_valid(_active_strip) and _strip_holds_body:
		_active_strip.modulate = color
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.modulate = color
	_request_paint()


func _ensure_visuals() -> void:
	_ensure_foot()
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


func _sync_boss_aura() -> void:
	var aura := get_node_or_null("BossAura")
	if stasis_boss and alive:
		if aura == null:
			aura = BossAura.new()
			aura.name = "BossAura"
			aura.z_index = -1
			aura.z_as_relative = true
			add_child(aura)
			move_child(aura, 0)
		(aura as BossAura).tint = BossAura.tint_for(stasis_sprite)
		(aura as BossAura).active = is_active
		(aura as BossAura).radius = Vector2(40, 18) * BOSS_SCALE * 0.8
	elif aura != null:
		aura.queue_free()


func _ensure_foot() -> void:
	if _foot != null and is_instance_valid(_foot):
		return
	var existing := get_node_or_null("Foot")
	if existing is FootMark:
		_foot = existing as FootMark
		_foot.host = self
		return
	_foot = FootMark.new()
	_foot.name = "Foot"
	_foot.host = self
	_foot.z_index = -1
	_foot.z_as_relative = true
	add_child(_foot)
	move_child(_foot, 0)


func _figure_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FIGURE_SHADER
	_write_figure_read(mat)
	return mat


## Ice read. Ironjaw lifts toward iron/ochre. Bastion lifts toward stone-gold.
## The rim is one warm texel, not a cyan halo. Other classes stay a straight
## sample. Facing does not change these colors.
static func figure_read_for(class_id: String) -> Dictionary:
	var key := SpellKits.normalize_class_id(class_id)
	if key == SpellKits.CLASS_IRONJAW:
		return {
			"rim_ink": Color(0.24, 0.13, 0.05, 1.0),
			"rim_px": 1.0,
			"mid_tone": Color(0.58, 0.38, 0.16, 1.0),
			"mid_mix": 0.45,
		}
	if key == SpellKits.CLASS_BASTION:
		return {
			"rim_ink": Color(0.30, 0.24, 0.12, 1.0),
			"rim_px": 1.0,
			"mid_tone": Color(0.64, 0.54, 0.34, 1.0),
			"mid_mix": 0.40,
		}
	return {
		"rim_ink": Color(0, 0, 0, 0),
		"rim_px": 0.0,
		"mid_tone": Color(0, 0, 0, 1),
		"mid_mix": 0.0,
	}


## Stasis foes run on Ironjaw's card but must not take its ochre lift: a thin
## hostile rim and a neutral lift of the crushed blacks so dark creatures
## read on dark floors.
const FOE_LIGHT := Color(1.0, 1.0, 1.0, 1.0)
const FIGURE_LIFT := 0.0
const FIGURE_SAT := 1.06
const FIGURE_EDGE := 0.3
const FOE_READ := {
	"rim_ink": Color(0.38, 0.05, 0.05, 1.0),
	"rim_px": 1.3,
	"mid_tone": Color(0.32, 0.29, 0.28, 1.0),
	"mid_mix": 0.3,
}

## Stasis foe life (Mauro 29 Sep 2026: "the boss looks not even like a monster
## looks like just a image moving"). View only. Each foe painting gets a body:
## beasts pant, crawlers skitter, brutes heave, flyers hover off the floor.
## `faces` is the side the painting looks toward ("" = to camera); the body
## turns (shader mirror) to face its target. Bosses breathe deeper and slower.
const FOE_BODY := {
	"beast": {"breath": 0.026, "rate": 5.2, "sway": 0.006, "bob": 0.8, "hover": 0.0},
	"crawler": {"breath": 0.018, "rate": 7.5, "sway": 0.012, "bob": 0.5, "hover": 0.0},
	"brute": {"breath": 0.034, "rate": 2.4, "sway": 0.008, "bob": 0.6, "hover": 0.0},
	"flyer": {"breath": 0.02, "rate": 2.8, "sway": 0.016, "bob": 0.0, "hover": 7.0},
}
const FOE_KIND := {
	"ash_stalker": ["beast", "left"],
	"grain_hound": ["beast", "right"],
	"brine_gullkin": ["beast", "right"],
	"scarecrow_drudge": ["brute", "right"],
	"silt_raider": ["brute", ""],
	"cinder_imp": ["brute", ""],
	"threshling": ["crawler", ""],
	"slag_mite": ["crawler", "left"],
	"tide_skitter": ["crawler", ""],
	"gale_skitter": ["crawler", ""],
	"coil_tick": ["crawler", ""],
	"sparkin": ["crawler", ""],
	"frost_wisp": ["flyer", ""],
	"gustling": ["flyer", ""],
	"volt_mote": ["flyer", ""],
	"warden_of_the_sheaves": ["brute", ""],
	"captain_brineclaw": ["brute", ""],
	"slagheart_the_emberbrute": ["brute", ""],
	"serra_the_gale_sentinel": ["flyer", ""],
	"tyrant_coilspire": ["brute", ""],
	# Caster stand-ins (recoloured melee paintings): they hover like spell
	# channelers so they read as ranged on the board.
	"caster_scribe_bolt": ["flyer", "right"],
	"caster_bell_chanter": ["flyer", ""],
	"caster_gullkin_hex": ["flyer", "right"],
	"caster_tide_adept": ["flyer", ""],
	"caster_ember_cantor": ["flyer", ""],
	"caster_kiln_voice": ["flyer", "left"],
	"caster_white_adept": ["flyer", ""],
	"caster_gale_chanter": ["flyer", ""],
	"caster_arc_adept": ["flyer", ""],
	"caster_high_cantor": ["flyer", ""],
}
## Max lean of a foe body into a lunge / away from a blow (UV shear per height).
const FOE_LEAN := 0.16
const FOE_HIT_LEAN := 0.12


static func foe_body_for(art_path: String, boss: bool = false) -> Dictionary:
	var entry: Array = FOE_KIND.get(art_path.get_file().get_basename(), ["brute", ""])
	var body: Dictionary = (FOE_BODY[entry[0]] as Dictionary).duplicate()
	body["kind"] = entry[0]
	body["faces"] = entry[1]
	if boss:
		body["breath"] = float(body["breath"]) * 1.25
		body["rate"] = float(body["rate"]) * 0.75
	return body


## 1 when a one-sided foe painting must turn to face `screen_dir`.
static func foe_mirror(faces: String, screen_dir: Vector2) -> float:
	if faces == "" or absf(screen_dir.x) < 0.01:
		return 0.0
	var wants_left := screen_dir.x < 0.0
	return 1.0 if wants_left != (faces == "left") else 0.0


func _write_figure_read(mat: ShaderMaterial) -> void:
	var read := FOE_READ if stasis_sprite != "" else figure_read_for(class_id)
	mat.set_shader_parameter("rim_ink", read["rim_ink"])
	mat.set_shader_parameter("rim_px", read["rim_px"])
	mat.set_shader_parameter("mid_tone", read["mid_tone"])
	mat.set_shader_parameter("mid_mix", read["mid_mix"])
	# Board light: the painted sheets are dark (mean ~56/255) and turn to
	# silhouettes at board scale. Lift, a little colour, a warm key rim.
	mat.set_shader_parameter("lift", FIGURE_LIFT)
	mat.set_shader_parameter("sat", FIGURE_SAT)
	mat.set_shader_parameter("edge_light", FIGURE_EDGE if alive else 0.0)
	# Living idle: a slow breath and a small head sway, per-fighter phase so a
	# pair never breathes in lockstep. Heavy plate breathes less. Off when down.
	var heavy := class_id == SpellKits.CLASS_IRONJAW or class_id == SpellKits.CLASS_BASTION
	mat.set_shader_parameter("breath", (0.016 if heavy else 0.024) if alive else 0.0)
	mat.set_shader_parameter("sway", (0.004 if heavy else 0.009) if alive else 0.0)
	mat.set_shader_parameter("breath_rate", 3.3)
	mat.set_shader_parameter("breath_phase", float(seat) * 2.1 + float(class_id.hash() % 97) * 0.13)
	mat.set_shader_parameter("mirror", 0.0)
	if stasis_sprite != "":
		var body := foe_body_for(stasis_sprite, stasis_boss)
		mat.set_shader_parameter("breath", float(body["breath"]) if alive else 0.0)
		mat.set_shader_parameter("sway", float(body["sway"]) if alive else 0.0)
		mat.set_shader_parameter("breath_rate", float(body["rate"]))
		mat.set_shader_parameter("breath_phase", float(seat) * 2.1 + float(unit_name.hash() % 97) * 0.13)
		mat.set_shader_parameter("mirror", foe_mirror(str(body["faces"]), facing_screen()))


func _apply_figure_read() -> void:
	if _sprite != null and is_instance_valid(_sprite) and _sprite.material is ShaderMaterial:
		_write_figure_read(_sprite.material as ShaderMaterial)
	for child in get_children():
		if child is AnimatedSprite2D and (child as CanvasItem).material is ShaderMaterial:
			_write_figure_read((child as CanvasItem).material as ShaderMaterial)
	if _walk_draw != null and is_instance_valid(_walk_draw) and _walk_draw.material is ShaderMaterial:
		_write_figure_read(_walk_draw.material as ShaderMaterial)


func _adopt_static_sprite(sprite: Sprite2D) -> void:
	sprite.centered = true
	sprite.offset = SPRITE_OFFSET
	sprite.scale = _body_scale()
	sprite.flip_h = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 0
	sprite.z_as_relative = true
	if not (sprite.material is ShaderMaterial):
		sprite.material = _figure_material()


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
	if stasis_sprite != "":
		_walk_idle_plant = false
		_hide_walk_draw()
		_sprite.texture = _stasis_texture(stasis_sprite)
		_sprite.scale = _body_scale()
		# Flyers float off the floor; the shadow stays on the tile.
		var hover := float(foe_body_for(stasis_sprite)["hover"])
		_sprite.offset = SPRITE_OFFSET / _stasis_res() - Vector2(0.0, hover / maxf(_sprite.scale.y, 0.001))
		_sync_boss_aura()
		_apply_figure_read()
		if not _flashing:
			_sprite.modulate = rest_modulate()
		_sprite.visible = true
		_hide_body_strips()
		_request_paint()
		return
	# The static turnaround stays on this node as the missing-sheet fallback.
	# It is not the combat idle. A walk sheet plants frame 0 of walk_<facing>.
	_sprite.texture = sprite_texture(class_id, facing)
	if not _flashing:
		_sprite.modulate = rest_modulate()
	# A driven step owns the frame. Replanting idle here freezes the cycle on
	# frame 0 and the pawn skates the static plant across the diamond.
	if _driven_walk and _walk_draw_stamp and _active_strip != null and is_instance_valid(_active_strip):
		_sprite.visible = false
		_active_strip.visible = false
		if not _flashing and _walk_draw != null and is_instance_valid(_walk_draw):
			_walk_draw.modulate = _sprite.modulate
			_active_strip.modulate = _sprite.modulate
		_apply_figure_read()
		_request_paint()
		return
	if _driven_walk and _strip_holds_body and _active_strip != null and is_instance_valid(_active_strip):
		_sprite.visible = false
		if not _flashing:
			_active_strip.modulate = _sprite.modulate
		_apply_figure_read()
		_request_paint()
		return
	if _strip_holds_body and _active_strip != null and is_instance_valid(_active_strip) and _active_strip.visible:
		_hide_walk_draw()
		_sprite.visible = false
		if not _flashing:
			_active_strip.modulate = _sprite.modulate
	elif _plant_walk_idle():
		pass
	else:
		_walk_idle_plant = false
		_hide_walk_draw()
		_active_strip = null
		_sprite.visible = true
		_hide_body_strips()
	_apply_figure_read()
	_request_paint()


func _sync_idle() -> void:
	if not alive:
		_stop_idle()
		if not _motion_playing:
			_apply_downed_pose()
		return
	if _motion_playing or _idle_hold or VIEW_MOTION.reduce_motion():
		return
	# Next frame so a snapshot apply does not move the sprite before callers read it.
	call_deferred("_start_idle")


func _begin_action() -> int:
	_collapse_holds_motion = false
	_ensure_visuals()
	_kill_landing()
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
	_ambush_strike_visible = false
	if _plan_died or not alive:
		_apply_downed_pose()
		return
	_plant_sprite()
	_apply_rest_color()


func _sample_hop(t: float) -> void:
	_apply_hop_visual(t)


## Hop offset on the body sprites only. Name, HP, aim rings, shade, and the
## foot stay. Walk strips squash on the plant only. A missing strip keeps
## the fallback weight curve.
func _apply_hop_visual(t: float) -> void:
	if stasis_sprite != "":
		_apply_foe_gait(t)
		return
	var hop := VIEW_MOTION.hop_offset(t, VIEW_MOTION.hop_crest_px(class_id))
	_place_body(hop)
	_ride_chrome(Vector2.ZERO)
	if _walk_looping or has_walk_strip():
		_apply_sprite_mul(VIEW_MOTION.plant_scale(t))
	else:
		_apply_sprite_mul(VIEW_MOTION.fallback_hop_scale(t))


## Monster walk gaits (Mauro 30 Sep 2026: "keep improving … walking
## animation"). Monster paintings have no walk sheet, so each body type moves
## the painting itself: beasts bound and lean into the step, crawlers skitter
## low with a quick side wiggle, brutes (and bosses) stomp and squash on the
## landing, flyers glide leaning forward. t is one tile hop, 0..1.
static func foe_gait(kind: String, boss: bool, t: float, dir_x: float) -> Dictionary:
	var u := clampf(t, 0.0, 1.0)
	var arc := sin(u * PI)
	var land := clampf((u - 0.78) / 0.22, 0.0, 1.0)
	var land_squash := sin(land * PI)
	var lean := 0.0
	var squash := 0.0
	var off := Vector2.ZERO
	match kind:
		"beast":
			off = Vector2(0.0, -7.0 * arc)
			lean = dir_x * 0.11 * arc
			squash = 0.05 * land_squash - 0.03 * arc
		"crawler":
			off = Vector2(sin(u * TAU * 2.0) * 1.6, -2.0 * absf(sin(u * TAU)))
			lean = dir_x * 0.05 + sin(u * TAU * 2.0) * 0.03
			squash = 0.03 * absf(sin(u * TAU))
		"flyer":
			off = Vector2(0.0, -2.5 * arc)
			lean = dir_x * 0.13 * arc
		_:
			var heavy := 1.5 if boss else 1.0
			off = Vector2(0.0, -3.5 * arc * (0.8 if boss else 1.0))
			lean = dir_x * 0.06 * arc
			squash = 0.09 * heavy * land_squash
	return {"offset": off, "lean": lean, "squash": squash}


func _apply_foe_gait(t: float) -> void:
	var body := foe_body_for(stasis_sprite, stasis_boss)
	var dir_x := signf(facing_screen().x)
	var gait := foe_gait(str(body.get("kind", "brute")), stasis_boss, t, dir_x)
	_place_body(gait["offset"])
	_ride_chrome(Vector2.ZERO)
	_apply_sprite_mul(Vector2.ONE)
	_set_foe_body(float(gait["lean"]), float(gait["squash"]))
	if t >= 1.0:
		_set_foe_body(0.0, 0.0)


func _apply_sprite_mul(mul: Vector2) -> void:
	var scaled := _body_scale_mul(mul)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = scaled
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.scale = scaled
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.scale = scaled


func _hold_walk_contact() -> void:
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		return
	if not strip.visible and not _walk_draw_stamp:
		return
	if strip.is_playing():
		strip.pause()
	strip.speed_scale = 0.0
	var frames := strip.sprite_frames
	if frames != null and frames.has_animation(strip.animation) and frames.get_frame_count(strip.animation) > 0:
		strip.frame = _sampled_walk_frame(0.0, frames.get_frame_count(strip.animation))
		strip.frame_progress = 0.0
	if _driven_walk or _walk_draw_stamp:
		_publish_walk_cell()


func _reset_walk_scale() -> void:
	var resting := _body_scale()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = resting
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.scale = resting
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.scale = resting


func _sample_attack(t: float, dir: Vector2, reach: float = -1.0) -> void:
	var pose: Dictionary = VIEW_MOTION.attack_pose(t, dir, reach)
	_apply_body_pose(pose)
	_sync_impact_freeze(t, false)
	_place_gesture(VIEW_MOTION.attack_phase(t), dir, pose.get("pos", Vector2.ZERO))


func _sample_cast(t: float, dir: Vector2 = Vector2.ZERO) -> void:
	var pose: Dictionary = VIEW_MOTION.cast_pose(t, dir)
	_apply_body_pose(pose)
	_sync_impact_freeze(t, true)
	var aim := dir if dir.length_squared() > 0.01 else facing_screen()
	_place_gesture(VIEW_MOTION.cast_phase(t), aim, pose.get("pos", Vector2.ZERO))


func _apply_body_pose(pose: Dictionary) -> void:
	var pos: Vector2 = pose.get("pos", Vector2.ZERO)
	var mul: Vector2 = pose.get("scale", Vector2.ONE)
	# A foe painting has no attack sheet: the body winds back, then throws its
	# weight into the lunge instead of sliding as a flat card.
	if stasis_sprite != "":
		_set_foe_body(clampf(pos.x / maxf(VIEW_MOTION.ATTACK_LUNGE_PX, 1.0), -1.0, 1.0) * FOE_LEAN, (1.0 - mul.y) * 0.3)
		mul = Vector2.ONE.lerp(mul, 0.35)
	var scaled := _body_scale_mul(mul)
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
			var kind_name := _body_kind
			if kind_name == "":
				kind_name = "cast" if last_pose else "attack"
			if kind_name != "death":
				frame = mini(STRIP_LIBRARY.impact_frame(class_id, kind_name), count - 1)
			strip.frame = frame
	if not _impact_frozen and strip.speed_scale > 0.01:
		_strip_play_scale = strip.speed_scale
	strip.speed_scale = 0.0
	_impact_frozen = true


func _thaw_strip_pose() -> void:
	_impact_frozen = false
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.speed_scale = _strip_play_scale if _strip_play_scale > 0.0 else 1.0


## Stasis foes only: lean (+ = screen right) and squash on the body shader.
func _set_foe_body(lean: float, squash: float) -> void:
	if stasis_sprite == "" or _sprite == null or not is_instance_valid(_sprite):
		return
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("lean", lean)
	mat.set_shader_parameter("squash", squash)


func foe_body_lean() -> float:
	if stasis_sprite == "" or _sprite == null or not (_sprite.material is ShaderMaterial):
		return 0.0
	return float((_sprite.material as ShaderMaterial).get_shader_parameter("lean"))


func _sample_hit(t: float, dir: Vector2) -> void:
	if _sprite == null:
		return
	# The 4-frame sheet already flashes and recoils, and its feet stay on the
	# walk baseline. Knock and squash are the fallback when that clip is missing.
	var planted := _hit_strip_is_body()
	var pos := Vector2.ZERO if planted else VIEW_MOTION.hit_offset(t, dir)
	var mul := Vector2.ONE if planted else VIEW_MOTION.hit_squash(t)
	# A struck foe reels from the blow (upper body first) and buckles.
	var reel := sin(clampf(t, 0.0, 1.0) * PI) * (1.0 - clampf(t, 0.0, 1.0) * 0.4)
	var away := signf(dir.x) if absf(dir.x) > 0.01 else 1.0
	_set_foe_body(away * reel * FOE_HIT_LEAN, reel * 0.06)
	var scaled := _body_scale_mul(mul)
	_sprite.position = pos
	_sprite.scale = scaled
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = pos
		_active_strip.scale = scaled


## A flinch ends the stride. The next pose is the idle plant, not the frame
## the walk was on when the blow landed.
func _interrupt_stride_for_flinch() -> void:
	_path_walk = false
	_driven_walk = false
	_driven_step = 0
	_driven_open = false
	_walk_looping = false
	_kill_bounce()
	_kill_landing()
	_place_body(Vector2.ZERO)
	_reset_walk_scale()


func _hit_strip_is_body() -> bool:
	return (
		_body_kind == "hit"
		and _strip_holds_body
		and _active_strip != null
		and is_instance_valid(_active_strip)
		and _active_strip.visible
	)


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
	_sprite.scale = _body_scale_mul(mul)
	_sprite.rotation_degrees = float(pose.get("rot", 0.0))
	_sprite.position = Vector2(0.0, float(pose.get("drop", 0.0)))
	var faded: float = float(pose.get("fade", 1.0))
	var grey := Color(0.45, 0.45, 0.45, faded)
	_sprite.modulate = _death_from.lerp(grey, clampf(t, 0.0, 1.0))


## Death strip: play the authored collapse and hold the last cell. No extra squash.
func _sample_death_strip(t: float, _tilt_sign: float) -> void:
	_held_death_strip = true
	var strip := _active_strip
	if strip == null or not is_instance_valid(strip):
		_sample_death(t, _tilt_sign)
		return
	var last := _last_frame(strip)
	if strip.frame >= last or t >= 0.58:
		_freeze_on_frame(strip, last)
	_hide_walk_draw()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = false
		strip.position = _sprite.position


func _apply_downed_pose() -> void:
	_stop_idle()
	if _hold_death_strip():
		return
	_end_body_strip()
	_ensure_visuals()
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var pose: Dictionary = VIEW_MOTION.death_pose(1.0, _death_tilt)
	var mul: Vector2 = pose.get("scale", Vector2.ONE)
	_sprite.visible = true
	_sprite.position = Vector2(0.0, float(pose.get("drop", 0.0)))
	_sprite.scale = _body_scale_mul(mul)
	_sprite.rotation_degrees = float(pose.get("rot", 0.0))
	_sprite.modulate = Color(0.45, 0.45, 0.45, float(pose.get("fade", 0.0)))
	_vanish_if_monster()


## Stasis monsters leave the board when they die (Mauro 30 Sep 2026: "corpses
## are supposed to disappear once dead"): body, ring, name and bar fade out.
## Heroes keep their downed body.
var _vanished := false


func _vanish_if_monster() -> void:
	if stasis_sprite == "" or alive or _vanished:
		return
	_vanished = true
	if not is_inside_tree():
		visible = false
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		if not alive:
			visible = false)


## Last cell of `death_<facing>`. A rebuild with no tween still shows DOWN.
func _hold_death_strip() -> bool:
	_ensure_motion_strips()
	var choice := _strip_choice("death")
	if choice.is_empty():
		return false
	var strip: AnimatedSprite2D = choice["node"]
	var anim := StringName(str(choice["anim"]))
	if strip == null or not is_instance_valid(strip):
		return false
	if _active_strip != strip:
		_prepare_strip_pose(strip)
	if strip.animation != anim:
		strip.animation = anim
	_active_strip = strip
	_strip_holds_body = true
	_held_death_strip = true
	_body_kind = "death"
	strip.position = Vector2.ZERO
	strip.scale = _body_scale()
	strip.rotation = 0.0
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = Vector2.ZERO
		_sprite.scale = _body_scale()
		_sprite.rotation = 0.0
	_freeze_on_frame(strip, _last_frame(strip))
	_hide_walk_draw()
	strip.visible = true
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = false
	return true


func _last_frame(strip: AnimatedSprite2D) -> int:
	if strip == null or strip.sprite_frames == null:
		return 0
	var anim := strip.animation
	if not strip.sprite_frames.has_animation(anim):
		return 0
	return maxi(strip.sprite_frames.get_frame_count(anim) - 1, 0)


func _freeze_on_frame(strip: AnimatedSprite2D, frame: int) -> void:
	if strip == null or not is_instance_valid(strip):
		return
	strip.frame = frame
	strip.speed_scale = 0.0
	_impact_frozen = true


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
	var bob := Vector2(0.0, sin((now + phase) * TAU / VIEW_MOTION.IDLE_PERIOD) * VIEW_MOTION.IDLE_BOB_PX)
	if stasis_sprite != "":
		bob = foe_idle_offset(foe_body_for(stasis_sprite, stasis_boss), now + phase)
	_sprite.position = bob
	if _walk_idle_plant and _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = bob
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.position = bob
	if _foot != null and is_instance_valid(_foot):
		_foot.queue_redraw()


## Foe idle body offset: flyers (already raised by their sprite offset) rise,
## sink and drift; walkers shift their weight a little.
static func foe_idle_offset(body: Dictionary, t: float) -> Vector2:
	var hover := float(body.get("hover", 0.0))
	if hover > 0.0:
		return Vector2(sin(t * 1.3) * 1.6, -sin(t * TAU / 2.4) * hover * 0.45)
	return Vector2(0.0, sin(t * TAU / VIEW_MOTION.IDLE_PERIOD) * float(body.get("bob", VIEW_MOTION.IDLE_BOB_PX)))


func _stop_idle() -> void:
	if _idle_tween != null and is_instance_valid(_idle_tween):
		_idle_tween.kill()
	_idle_tween = null


func _show_rest_body() -> void:
	_plant_sprite()
	if _flashing:
		return
	var color := rest_modulate()
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.modulate = color
		_walk_draw.visible = true
		_walk_draw.scale = _body_scale()
		if _active_strip != null and is_instance_valid(_active_strip):
			_active_strip.modulate = color
			_active_strip.visible = false
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.modulate = color
			_sprite.visible = false
		return
	if _walk_idle_plant and _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.modulate = color
		_active_strip.visible = true
		_active_strip.scale = _body_scale()
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.modulate = color
			_sprite.visible = false
		return
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = color
		_sprite.visible = true


func _plant_sprite() -> void:
	_hide_gesture()
	_end_body_strip()
	_ride_chrome(Vector2.ZERO)
	if _sprite == null or not is_instance_valid(_sprite):
		return
	_sprite.position = Vector2.ZERO
	_sprite.scale = _body_scale()
	_sprite.rotation = 0.0
	_sprite.flip_h = false
	_set_foe_body(0.0, 0.0)
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.position = Vector2.ZERO
		_walk_draw.scale = _body_scale()
		_walk_draw.rotation = 0.0
		_walk_draw.visible = true
		if _active_strip != null and is_instance_valid(_active_strip):
			_active_strip.position = Vector2.ZERO
			_active_strip.scale = _body_scale()
			_active_strip.rotation = 0.0
			_active_strip.visible = false
		_sprite.visible = false
	elif _walk_idle_plant and _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = Vector2.ZERO
		_active_strip.scale = _body_scale()
		_active_strip.rotation = 0.0
		_active_strip.visible = true
		_sprite.visible = false
	else:
		_hide_walk_draw()
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


func _start_kind_strip(kind: String, window_sec: float) -> void:
	_begin_body_strip(kind, window_sec)
	if kind != "death" or _active_strip == null or not is_instance_valid(_active_strip):
		return
	# Finish the authored collapse early so the last cell can sit.
	var quicker := maxf(_active_strip.speed_scale * 1.45, 1.15)
	_active_strip.speed_scale = quicker
	_strip_play_scale = quicker


func _begin_body_strip(kind: String, window_sec: float) -> void:
	_ensure_motion_strips()
	var choice := _strip_choice(kind)
	_end_body_strip(false)
	if choice.is_empty():
		_show_rest_or_static()
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
	_body_kind = kind
	_prepare_strip_pose(strip)
	strip.visible = true
	strip.play(anim)
	if not strip.is_playing():
		strip.visible = false
		_show_rest_or_static()
		return
	_active_strip = strip
	_strip_holds_body = true
	_hide_walk_draw()
	if _sprite != null and is_instance_valid(_sprite):
		strip.modulate = _sprite.modulate
		strip.position = _sprite.position
		_sprite.visible = false


func _end_body_strip(replant: bool = true) -> void:
	_walk_looping = false
	_strip_holds_body = false
	_impact_frozen = false
	_walk_idle_plant = false
	_body_kind = ""
	_hide_walk_draw()
	if _active_strip != null and is_instance_valid(_active_strip):
		if _active_strip.is_playing():
			_active_strip.stop()
		_active_strip.visible = false
		_active_strip.position = Vector2.ZERO
	_active_strip = null
	_hide_body_strips()
	if replant and _plant_walk_idle():
		return
	if replant:
		_show_rest_or_static()


## Walk sheet on screen when this class has one. Rest is frame 0 of that
## sheet, so a stop does not swap in another costume.
func _show_rest_or_static() -> void:
	if _plant_walk_idle():
		return
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = true


## Idle and the stride share frame 0 of this facing's walk sheet.
## The static turnaround stays hidden so a step cannot flash a second costume.
func _should_plant_walk_idle() -> bool:
	if not alive or stasis_sprite != "" or _held_death_strip:
		return false
	return has_walk_strip()


func _plant_walk_idle() -> bool:
	if not _should_plant_walk_idle():
		return false
	_ensure_motion_strips()
	var choice := _strip_choice("walk")
	if choice.is_empty():
		return false
	var strip: AnimatedSprite2D = choice["node"]
	var anim := StringName(str(choice["anim"]))
	if strip == null or not is_instance_valid(strip):
		return false
	_hide_body_strips()
	_prepare_strip_pose(strip)
	if strip.animation != anim:
		strip.animation = anim
	var frames := strip.sprite_frames
	if frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
		strip.frame = mini(walk_contact_frame(), frames.get_frame_count(anim) - 1)
		strip.frame_progress = 0.0
	strip.speed_scale = 0.0
	if strip.is_playing():
		strip.pause()
	_active_strip = strip
	_walk_idle_plant = true
	_strip_holds_body = false
	if _sprite != null and is_instance_valid(_sprite):
		strip.position = _sprite.position
		strip.scale = _sprite.scale
		if not _flashing:
			strip.modulate = _sprite.modulate
		_sprite.visible = false
	_publish_walk_cell()
	return true


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
	strip.scale = _body_scale()
	strip.flip_h = false
	strip.rotation = 0.0
	strip.z_index = 0
	strip.z_as_relative = true
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not (strip.material is ShaderMaterial):
		strip.material = _figure_material()
	else:
		_write_figure_read(strip.material as ShaderMaterial)
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
	_walk_idle_plant = false
	_strip_holds_body = false
	if _active_strip == strip:
		_active_strip = null
	_sync_sprite()


func _ensure_motion_strips() -> void:
	# Stasis foes keep the package still. Ironjaw walk/attack strips must not play.
	if stasis_sprite != "":
		return
	if class_id == "":
		return
	var frames := STRIP_LIBRARY.frames_for(class_id)
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
	# The board samples the frame. play() on device can stay on frame 0 while
	# the pawn node eases, which is the idle slide.
	if _driven_walk:
		return _present_driven_walk()
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
	# Hide the foreign still before the clip swaps. Stopping used to plant
	# that PNG again; a start must not flash it for a frame either.
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = false
	_end_body_strip(false)
	_prepare_walk_loop(strip, anim)
	_prepare_strip_pose(strip)
	_hide_walk_draw()
	strip.visible = true
	strip.play(anim)
	_active_strip = strip
	_strip_holds_body = true
	_walk_looping = true
	if _sprite != null and is_instance_valid(_sprite):
		strip.modulate = _sprite.modulate
		_sprite.visible = false
	# A clock that does not start is still the walk sheet. Hiding it uncovered
	# the static portrait and the step read as a slide. Callers that require a
	# running clock still see false; the driven step samples this strip anyway.
	if not strip.is_playing():
		strip.pause()
		strip.speed_scale = 0.0
		if strip.sprite_frames != null and strip.sprite_frames.has_animation(anim) and strip.sprite_frames.get_frame_count(anim) > 0:
			strip.frame = mini(walk_contact_frame(), strip.sprite_frames.get_frame_count(anim) - 1)
			strip.frame_progress = 0.0
		_walk_idle_plant = true
		_flatten_body()
		_publish_walk_cell()
		return false
	_walk_idle_plant = false
	_motion_playing = true
	_flatten_body()
	return true


## Driven steps show the facing strip paused on the sampled cell.
## A one-frame clip is refused: that cell is the idle slide.
func _present_driven_walk() -> bool:
	var choice := _strip_choice("walk")
	if choice.is_empty():
		return false
	var strip: AnimatedSprite2D = choice["node"]
	var anim := StringName(str(choice["anim"]))
	if strip == null or not is_instance_valid(strip):
		return false
	var frames := strip.sprite_frames
	if frames == null or not frames.has_animation(anim) or frames.get_frame_count(anim) < 2:
		return false
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.visible = false
	_prepare_strip_pose(strip)
	var same := strip.animation == anim and _active_strip == strip
	strip.animation = anim
	if strip.is_playing():
		strip.pause()
	strip.speed_scale = 0.0
	if not same and frames.get_frame_count(anim) > 0:
		strip.frame = mini(walk_contact_frame(), frames.get_frame_count(anim) - 1)
		strip.frame_progress = 0.0
	_active_strip = strip
	_strip_holds_body = true
	_walk_looping = true
	_walk_idle_plant = false
	_motion_playing = true
	if _sprite != null and is_instance_valid(_sprite):
		strip.modulate = _sprite.modulate
		_sprite.visible = false
	_flatten_body()
	_publish_walk_cell()
	return true


func _flatten_body() -> void:
	_reset_walk_scale()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.rotation = 0.0
		_sprite.flip_h = false
		if _walk_looping:
			_sprite.visible = false
	if _walk_looping and _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.rotation = 0.0
		_active_strip.flip_h = false
	if _bounce_running():
		return
	_ride_chrome(Vector2.ZERO)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.position = Vector2.ZERO
	if _active_strip != null and is_instance_valid(_active_strip):
		_active_strip.position = Vector2.ZERO


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
	if _walk_draw_stamp and _walk_draw != null and is_instance_valid(_walk_draw):
		_walk_draw.position = pos
		if _sprite != null and is_instance_valid(_sprite) and not _flashing:
			_walk_draw.modulate = _sprite.modulate
	if _foot != null and is_instance_valid(_foot):
		_foot.queue_redraw()


func _request_paint() -> void:
	queue_redraw()
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.queue_redraw()
	if _foot != null and is_instance_valid(_foot):
		_foot.queue_redraw()


func _sprite_ready() -> bool:
	return _sprite != null and _sprite.texture != null


func _draw() -> void:
	if debug_draw_tokens or not _sprite_ready():
		_draw_legacy_token()


func set_target_marked(marked: bool) -> void:
	if target_marked == marked:
		return
	target_marked = marked
	if not marked:
		_target_pulse = 0.0
	_request_paint()


func advance_target_pulse(delta: float) -> void:
	if not target_marked:
		return
	_target_pulse = fposmod(_target_pulse + delta, 1.0)
	_request_paint()


## Contact shadow and seat ring. Drawn on Foot so a body rise does not lift them.
## The aim pulse stays on that same ground mark.
func _draw_ground_mark_on(canvas: CanvasItem) -> void:
	if not _sprite_ready():
		return
	var foot := SEAT_RING_CENTER
	var lift := 0.0
	if _sprite != null and is_instance_valid(_sprite):
		var crest := VIEW_MOTION.hop_crest_px(class_id)
		lift = clampf(-_sprite.position.y / maxf(crest, 0.001), 0.0, 1.0)
	# Same disc on every class. It stays full size while the body hops.
	# Seat color and the yellow active ring paint above it.
	_draw_ellipse_on(canvas, foot + Vector2(0.0, 1.0), 14.0, 5.6, Color(0.18, 0.13, 0.09, 0.78))
	var shadow := lerpf(1.0, 0.62, lift)
	var shade := Color(0.08, 0.05, 0.04, lerpf(0.42, 0.2, lift))
	_draw_ellipse_on(canvas, foot + Vector2(0.0, 2.0), 16.0 * shadow, 6.0 * shadow, shade)
	# Dofus team circle: a soft team disc, a bright team ring, a dark keyline
	# outside it and a light glint on the near rim, so the fighter reads on
	# any tile at phone zoom.
	var team := _seat_color()
	_draw_ellipse_on(canvas, foot, SEAT_RING_RX, SEAT_RING_RY, Color(team.r, team.g, team.b, 0.38))
	_draw_ellipse_ring_on(canvas, foot, SEAT_RING_RX + 1.2, SEAT_RING_RY + 0.6, Color(0.05, 0.04, 0.06, 0.75), 1.4)
	_draw_ellipse_ring_on(canvas, foot, SEAT_RING_RX, SEAT_RING_RY, Color(team.r, team.g, team.b, 1.0), 2.6)
	_draw_ellipse_ring_on(canvas, foot + Vector2(0.0, 0.8), SEAT_RING_RX - 3.0, SEAT_RING_RY - 1.6, Color(1.0, 1.0, 1.0, 0.35), 1.0)
	if target_marked:
		var pulse := 0.5 + 0.5 * sin(_target_pulse * TAU)
		_draw_ellipse_ring_on(canvas, foot, 28.0 + 3.0 * pulse, 11.0 + 1.2 * pulse, Color(1.0, 0.62, 0.18, 0.9), 2.8)
	if burning:
		_draw_ellipse_ring_on(canvas, foot, 27.0, 10.5, Color(0.95, 0.32, 0.1, 0.95), 2.0)
	if stunned:
		_draw_ellipse_ring_on(canvas, foot, 24.0, 9.2, Color(0.95, 0.78, 0.2, 0.95), 2.0)
	if is_active:
		_draw_ellipse_ring_on(canvas, foot, 21.0, 8.2, Color(0.95, 0.78, 0.28, 0.95), 2.2)


func _paint_status(canvas: CanvasItem) -> void:
	if debug_draw_tokens or not _sprite_ready():
		return
	if target_marked:
		var pulse := 0.5 + 0.5 * sin(_target_pulse * TAU)
		_paint_ellipse_ring(canvas, SPRITE_OFFSET, 36.0 + 6.0 * pulse, 46.0 + 4.0 * pulse, Color(1.0, 0.78, 0.28, 0.4 + 0.5 * pulse), 3.6)
	_paint_unit_chrome(canvas, head_hp_y(), name_baseline())


## Baseline of the overhead name, in chrome-local space. The chrome node
## stays on the pawn through a hop. Lunges and the idle bob leave it there too.
func name_baseline() -> float:
	return head_hp_y() - NAME_GAP_ABOVE_HP - ThemeDB.fallback_font.get_descent(NAME_FONT_SIZE)


## The name plate box in pawn space, before any nudge (board spacing pass).
func name_plate_rect() -> Rect2:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_CENTER, -1, NAME_FONT_SIZE)
	var ascent := font.get_ascent(NAME_FONT_SIZE)
	var descent := font.get_descent(NAME_FONT_SIZE)
	var base := name_baseline() if _sprite_ready() else 10.0
	return Rect2(Vector2(-size.x * 0.5 - 4.0, base - ascent - 1.0), Vector2(size.x + 8.0, ascent + descent + 2.0))


## Two champions side by side used to print their name plates on top of
## each other. Plates that would overlap are pushed apart: sideways when the
## pawns stand side by side, the rear plate up when one stands behind.
static func spread_name_plates(pawns: Array) -> void:
	var bodies: Array = []
	for pawn in pawns:
		if pawn != null and is_instance_valid(pawn) and pawn is Pawn and (pawn as Pawn).visible and (pawn as Pawn).unit_name != "":
			bodies.append(pawn)
	var nudges := {}
	for body in bodies:
		nudges[body] = Vector2.ZERO
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Pawn = bodies[i]
			var b: Pawn = bodies[j]
			var ra := a.name_plate_rect()
			ra.position += a.position + nudges[a]
			var rb := b.name_plate_rect()
			rb.position += b.position + nudges[b]
			var both := ra.intersection(rb)
			if both.size.x <= 0.0 or both.size.y <= 0.0:
				continue
			var dx := b.position.x - a.position.x
			if absf(dx) >= 8.0:
				var half := both.size.x * 0.5 + 2.0
				var lean := signf(dx)
				nudges[a] += Vector2(-half * lean, 0.0)
				nudges[b] += Vector2(half * lean, 0.0)
			else:
				var rear: Pawn = a if a.position.y < b.position.y else b
				nudges[rear] += Vector2(0.0, -(both.size.y + 2.0))
	for body in bodies:
		(body as Pawn).set_name_nudge(nudges[body])


func set_name_nudge(nudge: Vector2) -> void:
	if nudge.is_equal_approx(name_nudge):
		return
	name_nudge = nudge
	queue_redraw()
	if _chrome != null:
		_chrome.queue_redraw()


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
	var label_x := -size.x * 0.5 + name_nudge.x
	name_y += name_nudge.y
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
	# Same blue / red as the P1 / P2 deploy zone highlights (Dofus teams).
	# Stasis trash seats 2 and 3 are hostiles, same as seat 1.
	var team: Color = BoardTile.TEAM_RED if seat > 0 else BoardTile.TEAM_BLUE
	return Color(team.r, team.g, team.b, 0.92)


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
	_draw_ellipse_on(self, center, rx, ry, color)


func _draw_ellipse_on(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	canvas.draw_colored_polygon(_ellipse_points(center, rx, ry), color)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	_draw_ellipse_ring_on(self, center, rx, ry, color, width)


func _draw_ellipse_ring_on(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	_paint_ellipse_ring(canvas, center, rx, ry, color, width)


func _paint_ellipse_ring(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := _ellipse_points(center, rx, ry)
	if pts.is_empty():
		return
	pts.append(pts[0])
	canvas.draw_polyline(pts, color, width, true)


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

