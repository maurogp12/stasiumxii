extends Node2D

## VIEW ONLY. The hero walks Crosshaven on the painted class sheets.
## Paths still come from `WorldWalk.find_path`. This node only animates them.
## `advance(delta)` is public so tests can step it deterministically.
##
## Art: the locked painted walk and idle of `class_id` (`world_strips.gd`,
## `units/painted_looks.gd`, built by build_tools/pc_characters). The world
## sets `class_id` from `progress.hero_class` before this node enters the
## tree, so only the hero's class loads. walk and run share the walk sheet;
## idle loops the painted idle. s and w draw the e and n sheets mirrored.

signal stepped(cell: Vector2i)
signal arrived(cell: Vector2i)

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
var class_id := "ironjaw"
const CORNER_CUT := 10.0
## Ease distance, in strides, so a shorter hero still eases over about one step.
const EASE_STRIDES := 1.3
## Ease distance is also capped in time at cruise speed. The east/west walk
## cycle is one 73 px stride, so 1.3 strides was about 95 px of start-up from
## 20% speed: over 2 s of crawling before the hero reached pace.
const EASE_MAX_SEC := 0.25
## Idle/walk/run and facing swaps crossfade. Short enough that a step still reads.
const BLEND_SEC := 0.10
## Hero world pace over the painted cadence. Every class's art cadence is
## 25.05 px/s walking and 54.80 px/s running (pc_character_specs WORLD), which
## reads as a crawl on PC. Ground speed is multiplied by these; the frame clock
## follows distance, so playback scales too. The build picks fps and stride so
## the shown stride is the painted foot's travel (no skate) under the leg cap.
const HERO_WALK_PACE := 2.2
const HERO_RUN_PACE := 2.0
## Above this playback factor the walk cycle looks frantic. The rest of the
## pace goes into a slightly longer stride instead.
const WALK_ANIM_CAP := 1.8

var zone: WorldZone
var cell := Vector2i.ZERO
## World cell of local (0, 0). Positions are on the shared plane.
var plane_origin := Vector2i.ZERO
var facing := "s"
var pace := "walk"
var auto_advance := true
## Slow-motion capture. Tests leave this at 1.
var playback := 1.0

var _sprite: Sprite2D
var _strips
var _queue: Array[Vector2i] = []
var _moving := false
var _samples: Array = []
var _cursor := 0
var _traveled := 0.0
var _total := 0.0
var _leg_start := 0.0
var _cruise := 57.0
var _stride := 19.0
var _bob := 0.0
var _air := 0.0
var _idle_t := 0.0
var _phase := 0.0
var _halt_after := false
## True when the current path started from a stand. A re-click while moving
## keeps cruise speed instead of easing in again from 20%.
var _ease_in := true
## Gait actually on screen. `pace` is the request; it takes over on the next tick.
var _shown_pace := "walk"
var _fade: Sprite2D
var _rim: Sprite2D
var _covered := false
var _blend_left := 0.0
## Path point of the drawn pivot. The painted cells keep the planted foot on
## the pivot, so this is the path point itself.
var _visual := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	_strips = Strips.new()
	_strips.load_class(class_id)
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.offset = _strips.pivot
	_fade = Sprite2D.new()
	_fade.centered = true
	_fade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fade.offset = _strips.pivot
	_fade.visible = false
	_fade.z_index = -1
	add_child(_fade)
	add_child(_sprite)
	_rim = Sprite2D.new()
	_rim.centered = true
	_rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rim.offset = _strips.pivot
	_rim.visible = false
	_rim.z_as_relative = true
	_rim.z_index = 8
	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = load("res://scenes/world/crosshaven/crosshaven_rim.gdshader")
	_rim.material = rim_mat
	add_child(_rim)
	_apply_strip_speed()
	_show_idle()


func base_scale() -> float:
	return _strips.scale


## Swap the loaded strips (movies and tests). The world picks the hero class
## before _ready, so the game does not load a second class through this.
func use_class(id: String) -> void:
	var next := id.strip_edges().to_lower()
	if next == "":
		return
	class_id = next
	if _strips == null:
		return
	_strips.load_class(class_id)
	_apply_pivot(_strips.pivot)
	_apply_strip_speed()
	if not _moving:
		_show_idle()


func frame_count(gait: String, dir: String) -> int:
	return _strips.frame_count(gait, dir)


func fps_of(gait: String) -> float:
	return _strips.fps_of(gait, "s")


func stride_of(gait: String, dir: String = "s") -> float:
	return _strips.stride_of(gait, dir)


func speed_of(gait: String) -> float:
	return _strips.speed_of(gait, "s") * pace_scale(gait)


## Ground-speed multiplier over the art cadence for this gait.
static func pace_scale(gait: String) -> float:
	return HERO_RUN_PACE if gait == "run" else HERO_WALK_PACE


## Stride multiplier. Only the walk, and only past the playback cap.
static func stride_scale(gait: String) -> float:
	if gait == "run":
		return 1.0
	return maxf(1.0, HERO_WALK_PACE / WALK_ANIM_CAP)


## Playback multiplier over the authored fps. Pace over stride, so one cycle
## still covers one (scaled) stride of ground and the feet do not skate.
static func anim_scale(gait: String) -> float:
	return pace_scale(gait) / stride_scale(gait)


## On-screen fps and stride for the south strip, after the pace scales.
func shown_fps_of(gait: String) -> float:
	return fps_of(gait) * anim_scale(gait)


func shown_stride_of(gait: String, dir: String = "s") -> float:
	return stride_of(gait, dir) * stride_scale(gait)


func face(dir: String) -> void:
	var next := dir.to_lower()
	if next != "n" and next != "e" and next != "s" and next != "w":
		return
	facing = next
	if not _moving:
		_show_idle()


## Move to a cell on the current plane without resetting the walk facing.
func relocate(target_zone: WorldZone, at: Vector2i) -> void:
	var keep := facing
	zone = target_zone
	cell = at
	position = _cell_pos(at)
	_visual = position
	z_index = _z_for(at)
	facing = keep
	if not _moving:
		_show_idle()


func place(target_zone: WorldZone, at: Vector2i) -> void:
	zone = target_zone
	cell = at
	facing = "s"
	pace = "walk"
	_shown_pace = "walk"
	_queue.clear()
	_samples.clear()
	_moving = false
	_halt_after = false
	_traveled = 0.0
	_total = 0.0
	_phase = 0.0
	_bob = 0.0
	_air = 0.0
	position = _cell_pos(at)
	_visual = position
	z_index = _z_for(at)
	_show_idle()
	queue_redraw()


func is_moving() -> bool:
	return _moving


## Gait on screen now. `pace` is the request and swaps in on the next plant.
func shown_pace() -> String:
	return _gait_name()


## Sprite shift that keeps a planted sole in the world. The camera follows this
## so the shift is not a bob against the view.
func visual_offset() -> Vector2:
	if _sprite == null:
		return Vector2.ZERO
	return _sprite.position


func anchor_cell() -> Vector2i:
	if not _moving:
		return cell
	return _pending_cell()


## `steps` excludes the anchor cell. `pace_name` is "auto", "walk", or "run".
## "auto" walks: running is the player's call (see the world's run mode).
func walk(steps: Array[Vector2i], pace_name: String = "auto") -> void:
	var use := pace_name
	if use == "auto":
		use = "walk"
	pace = use
	_halt_after = false
	if not _moving:
		_shown_pace = use
	if _moving:
		var pending := _pending_cell()
		var rest: Array[Vector2i] = [pending]
		for step in steps:
			if rest.is_empty() or rest[rest.size() - 1] != step:
				rest.append(step)
		_queue = rest
		_rebuild(cell, position)
		return
	if steps.is_empty():
		return
	_queue = steps.duplicate()
	_phase = 0.0
	_rebuild(cell, _cell_pos(cell))


func stop() -> void:
	if _moving:
		_halt_after = true


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func advance(delta: float) -> void:
	delta *= playback
	_tick_blend(delta)
	if not _moving:
		_idle_t += delta
		_show_idle()
		return
	var speed := _speed_at(_traveled, _total, _cruise)
	_traveled = minf(_total, _traveled + speed * delta)
	_phase += speed * delta
	_consume()
	if _traveled >= _total - 0.15:
		_traveled = _total
		_consume()
		_moving = false
		if not _samples.is_empty():
			position = _samples[_samples.size() - 1]["pos"]
		_visual = position
		z_index = _z_for(cell)
		_bob = 0.0
		_show_idle()
		arrived.emit(cell)
		return
	var root := _point_at(_traveled)
	_sync_pace()
	_sync_facing(false)
	_apply_gait(root)
	_update_z()


func _rebuild(from_cell: Vector2i, from_pos: Vector2) -> void:
	var from_rest := not _moving
	var cells: Array[Vector2i] = [from_cell]
	for step in _queue:
		cells.append(step)
	_samples = _bake(cells, from_pos)
	_ease_in = from_rest
	_cursor = 0
	_traveled = 0.0
	_leg_start = 0.0
	_total = 0.0
	if not _samples.is_empty():
		_total = float(_samples[_samples.size() - 1]["dist"])
	_moving = _total > 0.4
	_visual = from_pos
	if _moving:
		_sync_facing(from_rest)
		_sync_pace()
		_apply_strip_speed()
		_apply_gait(from_pos)
	else:
		_show_idle()


func _bake(cells: Array[Vector2i], first_pos: Vector2) -> Array:
	var marks: Array = [{"pos": first_pos, "has": false, "cell": Vector2i.ZERO, "face": ""}]
	var i := 0
	while i < cells.size() - 1:
		var j := _segment_end(cells, i)
		var face := _segment_facing(cells, i, j)
		var origin := _cell_pos(cells[i])
		var dest := _cell_pos(cells[j])
		var span := j - i
		for k in range(i + 1, j + 1):
			var t := float(k - i) / float(span)
			marks.append({
				"pos": origin.lerp(dest, t),
				"has": true,
				"cell": cells[k],
				"face": face,
			})
		i = j
	return _measure(_cut_corners(marks))


## A colinear ortho run, or a staircase that crosses the grid diagonally.
## Those staircases become one straight screen segment so the facing and the
## speed stay constant instead of flipping at every cell.
func _segment_end(cells: Array[Vector2i], i: int) -> int:
	var step0 := cells[i + 1] - cells[i]
	var end := i + 1
	if end >= cells.size() - 1:
		return end
	var nxt := cells[end + 1] - cells[end]
	if nxt == step0:
		while end < cells.size() - 1 and cells[end + 1] - cells[end] == step0:
			end += 1
		return end
	if step0.x * nxt.x + step0.y * nxt.y != 0:
		return end
	var other := nxt
	var prev_step := step0
	while end < cells.size() - 1:
		var nstep := cells[end + 1] - cells[end]
		if nstep == prev_step:
			break
		if nstep != step0 and nstep != other:
			break
		prev_step = nstep
		end += 1
	return end


func _segment_facing(cells: Array[Vector2i], i: int, j: int) -> String:
	var delta := cells[j] - cells[i]
	if delta.x != 0 and delta.y != 0:
		return _best_screen_facing(delta)
	return _ortho_facing(cells[i + 1] - cells[i])


func _ortho_facing(step: Vector2i) -> String:
	if step.x > 0:
		return "e"
	if step.x < 0:
		return "w"
	if step.y > 0:
		return "s"
	return "n"


## Facing whose iso step best matches the screen direction of a diagonal run.
func _best_screen_facing(delta: Vector2i) -> String:
	var screen := BoardVisualSort.cell_to_local(delta)
	var best := "s"
	var best_dot := -1.0e9
	for dir in ["e", "w", "s", "n"]:
		var d := screen.dot(_iso_step(dir))
		if d > best_dot:
			best_dot = d
			best = dir
	return best


func _iso_step(dir: String) -> Vector2:
	match dir:
		"e":
			return Vector2(32, 16)
		"w":
			return Vector2(-32, -16)
		"s":
			return Vector2(-32, 16)
		_:
			return Vector2(32, -16)


func _cut_corners(marks: Array) -> Array:
	if marks.size() < 3:
		return marks
	var out: Array = [marks[0]]
	for i in range(1, marks.size() - 1):
		var prev: Vector2 = out[out.size() - 1]["pos"]
		var here: Vector2 = marks[i]["pos"]
		var nxt: Vector2 = marks[i + 1]["pos"]
		var arrive: Vector2i = marks[i]["cell"]
		var face: String = str(marks[i]["face"])
		var vin := here - prev
		var vout := nxt - here
		var lin := vin.length()
		var lout := vout.length()
		var aligned := true
		if lin > 0.01 and lout > 0.01:
			aligned = vin.normalized().dot(vout.normalized()) > 0.98
		if not aligned and lin > 8.0 and lout > 8.0:
			var cut_in := minf(CORNER_CUT, lin * 0.35)
			var cut_out := minf(CORNER_CUT, lout * 0.35)
			var a := here - vin.normalized() * cut_in
			var b := here + vout.normalized() * cut_out
			out.append({"pos": a, "has": false, "cell": Vector2i.ZERO, "face": face})
			for step in [0.35, 0.5, 0.75, 1.0]:
				var t := float(step)
				out.append({
					"pos": _quad(a, here, b, t),
					"has": is_equal_approx(t, 0.5),
					"cell": arrive,
					"face": face,
				})
			continue
		out.append(marks[i])
	out.append(marks[marks.size() - 1])
	return out


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


func _measure(marks: Array) -> Array:
	var out: Array = []
	var dist := 0.0
	var prev: Vector2 = marks[0]["pos"]
	for mark in marks:
		var pos: Vector2 = mark["pos"]
		dist += prev.distance_to(pos)
		out.append({
			"pos": pos,
			"dist": dist,
			"has": mark["has"],
			"cell": mark["cell"],
			"face": str(mark.get("face", "")),
		})
		prev = pos
	return out


func _point_at(dist: float) -> Vector2:
	if _samples.is_empty():
		return position
	var prev_d := 0.0
	var prev_p: Vector2 = _samples[0]["pos"]
	for sample in _samples:
		var d := float(sample["dist"])
		var pos: Vector2 = sample["pos"]
		if d >= dist:
			var span := d - prev_d
			var u := 0.0 if span < 0.001 else (dist - prev_d) / span
			return prev_p.lerp(pos, u)
		prev_d = d
		prev_p = pos
	return prev_p


func _consume() -> void:
	while _cursor < _samples.size():
		var sample: Dictionary = _samples[_cursor]
		if float(sample["dist"]) > _traveled + 0.05:
			break
		_cursor += 1
		if not bool(sample["has"]):
			continue
		var arrived_cell: Vector2i = sample["cell"]
		cell = arrived_cell
		_leg_start = float(sample["dist"])
		if not _queue.is_empty() and _queue[0] == arrived_cell:
			_queue.pop_front()
		stepped.emit(arrived_cell)
		if _halt_after:
			# End the path on this cell. Jumping `_traveled` to the old
			# `_total` would snap the sprite to the far end of the path
			# while `cell` and the z order stay here.
			_total = float(sample["dist"])
			_traveled = _total
			_samples.resize(_cursor)
			_queue.clear()
			return


func _pending_cell() -> Vector2i:
	for i in range(_cursor, _samples.size()):
		var sample: Dictionary = _samples[i]
		if bool(sample["has"]) and float(sample["dist"]) > _traveled + 0.001:
			return sample["cell"]
	if not _queue.is_empty():
		return _queue[0]
	return cell


func _pending_dist() -> float:
	for i in range(_cursor, _samples.size()):
		var sample: Dictionary = _samples[i]
		if bool(sample["has"]):
			return float(sample["dist"])
	return _total


func _speed_at(traveled: float, total: float, cruise: float) -> float:
	var ease := minf(minf(_stride * EASE_STRIDES, total * 0.22), cruise * EASE_MAX_SEC)
	if ease < 1.0:
		return cruise
	var gate := 1.0
	if traveled < ease and _ease_in:
		var u := traveled / ease
		gate = 0.2 + 0.8 * (u * u * (3.0 - 2.0 * u))
	elif traveled > total - ease:
		var u2 := (total - traveled) / ease
		gate = 0.2 + 0.8 * (u2 * u2 * (3.0 - 2.0 * u2))
	return cruise * gate


func _facing_ahead() -> String:
	for i in range(_cursor, _samples.size()):
		var sample: Dictionary = _samples[i]
		var face := str(sample.get("face", ""))
		if face != "" and float(sample["dist"]) >= _traveled - 0.001:
			return face
	return facing


## The painted cells bake the planted foot on the pivot, so facing and gait can
## change on any frame. _apply_strip_speed keeps the point in the cycle.
func _sync_facing(_force: bool) -> void:
	var want := _facing_ahead()
	if want == "" or want == facing:
		return
	facing = want
	_apply_strip_speed()


func _sync_pace() -> void:
	if pace == _shown_pace:
		return
	_shown_pace = pace
	_apply_strip_speed()


func _gait_name() -> String:
	return "run" if _shown_pace == "run" else "walk"


func _apply_strip_speed() -> void:
	if _strips == null:
		return
	var gait := _gait_name()
	var next_stride: float = _strips.stride_of(gait, facing) * stride_scale(gait)
	# Keep the same point in the cycle when a corner changes the stride.
	if _stride > 0.001 and not is_equal_approx(next_stride, _stride):
		var frac := fmod(_phase / _stride, 1.0)
		if frac < 0.0:
			frac += 1.0
		_phase = frac * next_stride
	_stride = next_stride
	_cruise = _strips.speed_of(gait, facing) * pace_scale(gait)


func _apply_gait(root: Vector2) -> void:
	var gait := _gait_name()
	var tex: Texture2D = _strips.texture(gait, facing)
	if tex == null:
		_show_idle()
		return
	var count := maxi(1, _strips.frame_count(gait, facing))
	var span := maxf(_stride, 0.001)
	var phase := fmod(_phase / span, 1.0)
	if phase < 0.0:
		phase += 1.0
	var frame := int(phase * float(count)) % count
	var cell_size: Vector2i = _strips.frame_size_of(gait, facing)
	_bob = 0.0
	_air = 0.0
	_visual = root
	position = _visual
	var sc: float = _strips.draw_scale(gait, facing)
	_apply_pivot(_strips.draw_pivot(gait, facing))
	_present(tex, true, Rect2(frame * cell_size.x, 0, cell_size.x, cell_size.y), Vector2(sc, sc), Vector2.ZERO, _strips.flipped(facing))
	queue_redraw()


func _show_idle() -> void:
	if _strips == null or not _strips.has_gait("idle"):
		_present(null, false, Rect2(), Vector2.ONE * 0.33, Vector2.ZERO)
	else:
		# The painted idle breathes in its own cells, at the authored fps.
		var count := maxi(1, _strips.frame_count("idle", facing))
		var frame := idle_frame()
		var cell: Vector2i = _strips.frame_size_of("idle", facing)
		var sc: float = _strips.draw_scale("idle", facing)
		_apply_pivot(_strips.draw_pivot("idle", facing))
		_present(_strips.texture("idle", facing), true, Rect2((frame % count) * cell.x, 0, cell.x, cell.y), Vector2(sc, sc), Vector2.ZERO, _strips.flipped(facing))
	_visual = position
	_bob = 0.0
	_air = 0.0
	queue_redraw()


## Painted idle cell on screen now (loops at the idle fps while standing).
func idle_frame() -> int:
	if _strips == null:
		return 0
	var count := maxi(1, _strips.frame_count("idle", facing))
	return int(floor(_idle_t * _strips.fps_of("idle", facing))) % count


## A building in front of the hero fades to 45%. This rim sits above that fade.
func set_covered(on: bool) -> void:
	_covered = on
	_sync_rim()


func _apply_pivot(piv: Vector2) -> void:
	if _sprite != null:
		_sprite.offset = piv
	if _fade != null:
		_fade.offset = piv
	if _rim != null:
		_rim.offset = piv


func _present(tex: Texture2D, region_on: bool, region: Rect2, sc: Vector2, foot: Vector2, flip: bool = false) -> void:
	if (tex != _sprite.texture or flip != _sprite.flip_h) and _sprite.texture != null:
		_begin_fade()
	_sprite.texture = tex
	_sprite.flip_h = flip
	_sprite.region_enabled = region_on
	if region_on:
		_sprite.region_rect = region
	_sprite.scale = sc
	_sprite.position = foot
	_sync_rim()


func _sync_rim() -> void:
	if _rim == null or _sprite == null:
		return
	_rim.visible = _covered and _sprite.texture != null
	if not _rim.visible:
		return
	_rim.texture = _sprite.texture
	_rim.flip_h = _sprite.flip_h
	_rim.region_enabled = _sprite.region_enabled
	_rim.region_rect = _sprite.region_rect
	_rim.scale = _sprite.scale
	_rim.position = _sprite.position
	_rim.offset = _sprite.offset


func _begin_fade() -> void:
	_fade.texture = _sprite.texture
	_fade.flip_h = _sprite.flip_h
	_fade.region_enabled = _sprite.region_enabled
	_fade.region_rect = _sprite.region_rect
	_fade.scale = _sprite.scale
	_fade.position = _sprite.position
	_fade.offset = _sprite.offset
	_fade.modulate.a = 1.0
	_fade.visible = true
	_blend_left = BLEND_SEC


func _tick_blend(delta: float) -> void:
	if _fade == null or not _fade.visible:
		return
	_blend_left = maxf(0.0, _blend_left - delta)
	if _blend_left <= 0.0:
		_fade.visible = false
		return
	_fade.modulate.a = _blend_left / BLEND_SEC


func _update_z() -> void:
	# Sort by ground screen-Y so the order slides across a step. Add the
	# elevation lift back: props sort on the cell diagonal, not the raised pixels.
	var ground_y := position.y
	if zone != null:
		var nxt := _pending_cell()
		var span := maxf(_pending_dist() - _leg_start, 0.001)
		var along := clampf((_traveled - _leg_start) / span, 0.0, 1.0)
		var h := lerpf(float(zone.height_at(cell)), float(zone.height_at(nxt)), along)
		ground_y += h * BoardVisualSort.ELEVATION_PIXELS
	z_index = int(round(ground_y * float(BoardVisualSort.TILE_Z_SCALE) / 16.0)) + BoardVisualSort.UNIT_Z_BIAS


func _z_for(c: Vector2i) -> int:
	var w := plane_origin + c
	return (w.x + w.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS


func _cell_pos(c: Vector2i) -> Vector2:
	var h := 0.0
	if zone != null and zone.in_bounds(c):
		h = float(zone.height_at(c))
	return BoardVisualSort.cell_to_local(plane_origin + c, h)


func _draw() -> void:
	# Contact shadow sized to the figure (the old 62.7 px hero had rx 7.9).
	var tall := 62.7
	if _strips != null and _strips.height() > 0.0:
		tall = _strips.height()
	var rx := tall * 0.126
	var ry := rx * 0.375
	var at := Vector2.ZERO
	if _sprite != null:
		at = _sprite.position
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
	if _strips == null or not _strips.has_gait("walk"):
		draw_circle(Vector2(0, -28), 10, Color("6a5344"))
