extends RefCounted
class_name TouchAdapter

## Mobile-branch input adapter. Combat rules stay in CombatSim.
## Desktop hover and right-click remain. A finger can finish a hot-seat
## turn without them: tap a cell, tap a spell, tap Walk / Advance, tap the
## Face pad, tap End Turn.
## Board diamonds stay 64×32. Desktop pick stays the nearest tile inside 22px
## so a mouse cannot steal a neighbor. A finger uses the painted diamond (the
## side tips the 22px circle used to give away) and a fatter sprite capsule.
## That padding is off unless the event is a touch or the OS is mobile.
## Fat HUD targets are canvas pixels on the 960×720 canvas_items / expand window.

const EMULATED_DEVICE_ID := -1
const HIT_FLOOR := 48
const HIT_PREFERRED := 64
## Primary actions (Walk, spells, Advance, Ready, End Turn, New Match).
## 72 fits beside the face cross without covering the play band.
const ACTION_BUTTON_HEIGHT := 72
## The 3×3 pad uses the floor. 72×3 would eat the board.
const FACE_BUTTON_SIZE := Vector2(48, 48)
const WALK_BUTTON_SIZE := Vector2(104, 72)
## Thumb cluster. Primary is the basic cast; the arc is the rest of the kit.
## Both clear the 72px fat-target floor. Diamond pick stays 22px.
const PRIMARY_BUTTON_SIZE := Vector2(104, 104)
const ABILITY_BUTTON_SIZE := Vector2(72, 72)
const SPELL_BUTTON_SIZE := ABILITY_BUTTON_SIZE
const END_TURN_BUTTON_SIZE := Vector2(128, 72)
const READY_BUTTON_SIZE := Vector2(128, 72)
const NEW_MATCH_BUTTON_SIZE := Vector2(128, 72)
const ACTION_BAR_MIN_HEIGHT := 150
const CLUSTER_SIZE := Vector2(272, 272)
const CLUSTER_EDGE := 8.0
## Arc radius keeps 72px satellites from covering each other or the primary.
const CLUSTER_ARC_RADIUS := 160.0
const CLUSTER_ARC_START_DEG := -96.0
const CLUSTER_ARC_END_DEG := -176.0
## Six-spell kits (Mender with Rekindle): five arc circles fit on a wider
## ring with smaller buttons.
const CROWDED_ARC_COUNT := 5
const CROWDED_ARC_RADIUS := 172.0
const CROWDED_BUTTON_SIZE := Vector2(58, 58)
## Unchanged desktop diamond pick. See local_to_grid in board_view.gd.
const CELL_PICK_RADIUS := 22.0
## Off-board finger slop. Interior taps use the painted diamond, not this circle.
## Neighbor centers are ~36px apart, so a nearer tile still wins.
const MOBILE_CELL_PICK_RADIUS := 36.0
## Sprite footprint in pawn-local pixels. Figures are 144×160 at scale 0.5
## with offset (0, -72), so the opaque body sits above the feet diamond.
## Desktop radius stays inside the gap to an east neighbor tile center (~54px
## from the spine) so that diamond is not a body hit. It is not a wider
## CELL_PICK_RADIUS.
const PAWN_BODY_RADIUS := 34.0
## Finger capsule for walks and for taps that are not a unit cast.
## A tap beside the chest (~48px) still selects the fighter.
## The east neighbor diamond (~54px) stays a tile on this radius.
const MOBILE_PAWN_BODY_RADIUS := 52.0
## Authored cell on the pawn: 144×160 at 0.5, centered on (0, -72).
## Half of 72×80. A unit cast must cover this drawing, not only the spine.
const SPRITE_HALF_W := 36.0
const SPRITE_HEAD_Y := -112.0
const SPRITE_FOOT_Y := -32.0
## Unit-cast finger pad. Sprite half-width plus this pad. 64 reaches the
## east-neighbor center. Walk picks keep MOBILE_PAWN_BODY_RADIUS.
const TARGET_BODY_PAD := 28.0
const TARGET_PAWN_BODY_RADIUS := SPRITE_HALF_W + TARGET_BODY_PAD
## Past the painted diamond, still short of the next tile center (metric 2).
## A finger does not have to hit the 22px circle in the middle of the tile.
const TARGET_DIAMOND_LIMIT := 1.35
## Two sprites under one tap. The nearer body wins when it is clearly closer.
## A tie stays the ground cell so Soft Lock can refuse two neighbors.
const BODY_PICK_TIE_PX := 8.0
const PAWN_BODY_HEAD_Y := -108.0
const PAWN_BODY_FEET_Y := -28.0

const VIEW_W := 960.0
const VIEW_H := 720.0
const PLAY_TOP := 140.0
## Top of the bottom chrome on the 720 canvas. The diamond fits above it.
const PLAY_BOTTOM := 460.0
const HUD_BOTTOM_OFFSET := -252.0
## Same clamp the board camera used on the 960×720 fit.
const BOARD_ZOOM_MIN := 0.35
const BOARD_ZOOM_MAX := 1.25
## Backstop for extreme windows. A 20:9 phone overview is 1.55, under this.
## The 0.1.25 rest sat on the old 2.0 cap. The 0.1.21 cover zoom was ~3.0.
const MOBILE_BOARD_ZOOM_MAX := 2.0
## Iso diamond height in board pixels.
const DIAMOND_H := 32.0
## Insets for the phone frame. The navy/gold HUD overlays this band.
## The old path reserved 260px of empty gutter, then cover-zoomed into it.
const MOBILE_FRAME_TOP := 36.0
const MOBILE_FRAME_BOTTOM := 64.0
## Mauro (29 Sep): the menus must not sit on the map. The clear band is the
## space between the top plaques and the bottom thumb row. Pinch zoom-out reaches a
## view that fits the whole diamond inside it, and the board centres in it.
const MOBILE_CLEAR_TOP := 124.0
const MOBILE_CLEAR_BOTTOM := 150.0
## Canvas pixels the phone camera keeps clear under the top portrait bar.
## A fighter on the top rows stands about 90px above the cell; at the phone
## zoom that name was landing inside the 128px turn bar (Kestrel's plate sat
## on y=-6 at 2400×1080). This drops the fit by that margin. The chips stay
## full size. Pan toward the bottom still reaches the far edge of the board.
## 250 put the top names under the turn bar's clearance and shoved the
## bottom spawns under the thumb HUD (Stasis Stormspire A, Kestrel).
## 110 still left both corner fighters on the Face pad and the thumb cluster.
## 48 lifts the diamond so those start cells sit above that bottom chrome
## while the top-row names stay under the turn bar. Zoom is unchanged.
const PORTRAIT_BAR_INSET := 48.0
## Share of the limiting board axis kept on screen at the default zoom.
## 1.0 is a pure contain (the postage-stamp board: ~1.24 on 20:9, ~40px
## diamonds, ~205px black wings). 0.80 is a Koliseo overview: zoom 1.55,
## ~50px diamonds, the full 15×15 width, ~80% of the height, and a ~56px
## side gutter. The 0.1.25 keep of 0.62 was zoom 2.0 (64px diamonds) and
## cropped the arena down to the fighters.
## 0.68 is a closer phone default than the 0.80 overview (~1.82 on 20:9,
## ~58px diamonds) so a fighter is readable without pinching in.
const MOBILE_BOARD_KEEP := 0.68
## Session camera. 1.0 is the overview default. Each press multiplies this.
## 1.55 * 0.90 sits on the 1.40 zoom-out floor. 1.55 * 1.46 reaches the
## 2.25 zoom-in cap. Zoom out stays above the contain fit. Zoom in stays
## under the 2.5 ultra-close and the 3.0 cover.
## Wider and finer than before (Mauro asked for more adjustable zoom): the
## floor shows the whole diamond clear of the menus, the cap is a close view.
## Pinch sets the bias continuously inside the same limits.
const PLAYER_ZOOM_STEP := 1.12
const PLAYER_ZOOM_BIAS_MIN := 0.5
const PLAYER_ZOOM_BIAS_MAX := 2.6
## Zoom-out floor. 1.5 keeps a 48px diamond (32 * 1.5). The old 0.8 floor
## let a pinch shrink fighters until a tap could not land on one.
const PLAYER_ZOOM_MIN := 1.5
const PLAYER_ZOOM_MAX := 3.0
static var player_zoom_bias: float = 1.0
## A short finger slide still picks a cell. A longer drag pans the cropped map.
const PAN_SLOP := 48.0

const AIM := "aim"
const COMMIT := "commit"
const FACE := "face"
const PAN := "pan"
const PAN_STOP := "pan_stop"
const IGNORE := "ignore"


static func meets_hit_floor(size: Vector2) -> bool:
	return size.x >= float(HIT_FLOOR) and size.y >= float(HIT_FLOOR)


static func meets_preferred_height(size: Vector2) -> bool:
	return size.y >= float(HIT_PREFERRED)


static func play_band_fits_canvas() -> bool:
	return PLAY_TOP >= 0.0 and PLAY_BOTTOM > PLAY_TOP and PLAY_BOTTOM < VIEW_H and VIEW_W == 960.0 and VIEW_H == 720.0


static func is_emulated_mouse(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == EMULATED_DEVICE_ID


static func pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return Vector2.ZERO


static func is_touch_press(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and (event as InputEventScreenTouch).index == 0


static func is_touch_release(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed and (event as InputEventScreenTouch).index == 0


## Finger down or drag. Used to preview aim hit % before the release commits.
static func is_touch_contact(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).index == 0
	return is_touch_press(event)


## Board pointer policy.
## Mouse motion and a finger press/drag preview aim (hit %).
## Mouse left press commits immediately (existing click).
## Finger release commits, so a tap still moves / casts, and a drag can
## show hit % before the finger lifts.
## Right-click faces. The Face pad is the touch path for the same intent.
## Emulated mouse is ignored so a touch is not also a second click.
static func board_gesture(event: InputEvent) -> String:
	if event is InputEventScreenDrag:
		return AIM if (event as InputEventScreenDrag).index == 0 else IGNORE
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return IGNORE
		return AIM if touch.pressed else COMMIT
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.device == EMULATED_DEVICE_ID:
			return IGNORE
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			return FACE if mouse.pressed else IGNORE
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			return PAN if mouse.pressed else PAN_STOP
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			return COMMIT
		return IGNORE
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).device == EMULATED_DEVICE_ID:
			return IGNORE
		return AIM
	return IGNORE


## Phone / tablet export. Headless and desktop stay false, so tests keep the 22px pick.
## `--mobile-frame` previews that camera on a desktop window. It is not a combat rule.
static func use_mobile_pick() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	return OS.get_cmdline_user_args().has("--mobile-frame")


## Full-bleed landscape. 0.1.21 left the activity portrait while the UI is the
## 960×720 poster, so the whole game sat in a short strip with black bars.
## Sensor landscape turns the phone. canvas_items + expand then fills that
## window instead of letterboxing the base size. Desktop and headless no-op.
static func lock_landscape_frame(window: Window = null) -> void:
	if not use_mobile_pick() or OS.get_cmdline_user_args().has("--mobile-frame"):
		return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(int(VIEW_W), int(VIEW_H))


## (top, bottom) of the board band in canvas pixels.
## Desktop keeps 140..460. A phone frames the diamond across the screen.
## The turn plaque and the thumb cluster overlay the edges. They no longer
## reserve a 260px empty band that the 0.1.21 cover zoom then filled.
static func play_band_for(viewport_size: Vector2, mobile: bool = false) -> Vector2:
	if not mobile:
		return Vector2(PLAY_TOP, PLAY_BOTTOM)
	var top := MOBILE_FRAME_TOP
	var bottom := maxf(viewport_size.y - MOBILE_FRAME_BOTTOM, top + 1.0)
	return Vector2(top, bottom)


## (top, bottom) of the space between the phone menus.
static func clear_band_for(viewport_size: Vector2) -> Vector2:
	var top := MOBILE_CLEAR_TOP
	return Vector2(top, maxf(viewport_size.y - MOBILE_CLEAR_BOTTOM, top + 1.0))


## Fit zoom for a board of board_w × board_h. Desktop ignores viewport_size and
## stays on the 960×720 band (15×15 is 0.64). A phone default keeps
## MOBILE_BOARD_KEEP of the limiting axis: a Koliseo overview (20:9 is 1.55),
## not the 0.1.25 close crop (2.0) and not the postage-stamp contain (~1.24).
static func board_zoom(board_w: float, board_h: float, viewport_size: Vector2, mobile: bool = false) -> float:
	var view := viewport_size if mobile else Vector2(VIEW_W, VIEW_H)
	var span := _play_span(view, mobile)
	var bw := maxf(board_w, 1.0)
	var bh := maxf(board_h, 1.0)
	var fit := minf(span.x / bw, span.y / bh)
	if not mobile:
		return clampf(fit, BOARD_ZOOM_MIN, BOARD_ZOOM_MAX)
	var overview := fit / maxf(MOBILE_BOARD_KEEP, 0.05)
	return clampf(overview, BOARD_ZOOM_MIN, MOBILE_BOARD_ZOOM_MAX)


## (min, max) the player may reach. Phone zoom-out rests at PLAYER_ZOOM_MIN
## (1.40 on a 20:9 phone) when that is still under the overview, so a pinch zoom-out
## shows the diamond tips without the contain fit's black wings. Desktop
## min is the desk fit. Max is 2.25, a closer view, not the 2.5 crop or the 3.0 cover.
static func player_zoom_limits(board_w: float, board_h: float, viewport_size: Vector2, mobile: bool = false) -> Vector2:
	var base := board_zoom(board_w, board_h, viewport_size, mobile)
	if not mobile:
		return Vector2(base, BOARD_ZOOM_MAX)
	var clear := clear_band_for(viewport_size)
	var fit := minf((viewport_size.x - 16.0) / maxf(board_w, 1.0), (clear.y - clear.x) / maxf(board_h, 1.0))
	var floor_zoom := minf(base, maxf(fit * 0.96, PLAYER_ZOOM_MIN))
	return Vector2(floor_zoom, PLAYER_ZOOM_MAX)


## Overview times the session bias, clamped to player_zoom_limits.
## The bias survives a new fight. It is not a combat rule.
static func player_board_zoom(board_w: float, board_h: float, viewport_size: Vector2, mobile: bool = false) -> float:
	var base := board_zoom(board_w, board_h, viewport_size, mobile)
	var limits := player_zoom_limits(board_w, board_h, viewport_size, mobile)
	return clampf(base * player_zoom_bias, limits.x, limits.y)


## +1 zooms in, -1 zooms out. No-op at the bias ends.
static func nudge_player_zoom(direction: int) -> void:
	if direction > 0:
		player_zoom_bias = minf(player_zoom_bias * PLAYER_ZOOM_STEP, PLAYER_ZOOM_BIAS_MAX)
	elif direction < 0:
		player_zoom_bias = maxf(player_zoom_bias / PLAYER_ZOOM_STEP, PLAYER_ZOOM_BIAS_MIN)


## Pinch: set the bias from a target zoom (continuous), inside the limits.
static func set_player_zoom(target: float, board_w: float, board_h: float, viewport_size: Vector2) -> void:
	var base := board_zoom(board_w, board_h, viewport_size, true)
	if base <= 0.0:
		return
	player_zoom_bias = clampf(target / base, PLAYER_ZOOM_BIAS_MIN, PLAYER_ZOOM_BIAS_MAX)


static func reset_player_zoom() -> void:
	player_zoom_bias = 1.0


## (play width, play height) used to fit the diamond between the chrome.
static func _play_span(view: Vector2, mobile: bool) -> Vector2:
	var band := play_band_for(view, mobile)
	var margin := 16.0 if mobile else 32.0
	return Vector2(view.x - margin, maxf(band.y - band.x, 1.0))


## World-space half-overflow when zoom shows less than the whole board.
## Zero on an axis that still fits. Phone pan stops here so the gutter
## does not come back.
static func pan_room(board_w: float, board_h: float, viewport_size: Vector2, zoom: float, mobile: bool = false) -> Vector2:
	var view := viewport_size if mobile else Vector2(VIEW_W, VIEW_H)
	var span := _play_span(view, mobile)
	var z := maxf(zoom, 0.001)
	var vis_w := view.x / z
	var vis_h := span.y / z
	return Vector2(
		maxf(0.0, (board_w - vis_w) * 0.5),
		maxf(0.0, (board_h - vis_h) * 0.5)
	)


## Free roam (Mauro 4 Oct 2026: "the map focus whoever turn it is, also
## move the screen by touching it in the direction we want"): even when the
## whole board fits, a finger can drag it this share of its size each way,
## and the turn focus can bring the active fighter toward the middle.
const FREE_ROAM := 0.32


static func free_room(board_w: float, board_h: float, room: Vector2) -> Vector2:
	return Vector2(maxf(room.x, board_w * FREE_ROAM), maxf(room.y, board_h * FREE_ROAM))


## Shift the look-at point toward focus, without sliding past the board edge.
static func focus_point(center: Vector2, focus: Vector2, room: Vector2) -> Vector2:
	var delta := focus - center
	delta.x = clampf(delta.x, -room.x, room.x)
	delta.y = clampf(delta.y, -room.y, room.y)
	return center + delta


## Walk-mode finger travel past the slop pans. A spell drag still aims.
static func drag_is_pan(from: Vector2, to: Vector2, spell_armed: bool) -> bool:
	if spell_armed:
		return false
	return from.distance_to(to) >= PAN_SLOP


## Flat iso cell. Matches the fallback in pick_board_cell.
static func iso_cell(point: Vector2) -> Vector2i:
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0
	return Vector2i(floori(grid_x + 0.5), floori(grid_y + 0.5))


## 1.0 is the painted 64×32 diamond around center.
static func diamond_metric(point: Vector2, center: Vector2) -> float:
	var local := point - center
	return absf(local.x) / 32.0 + absf(local.y) / 16.0


## True when the point lies on the fighter sprite, not the diamond at their feet.
## mobile widens the walk capsule. targeting covers the authored drawing, and
## a finger adds TARGET_BODY_PAD. The default radius is the desktop test.
static func hits_pawn_body(point: Vector2, pawn_origin: Vector2, mobile: bool = false, targeting: bool = false) -> bool:
	var local := point - pawn_origin
	var head := PAWN_BODY_HEAD_Y
	var foot := PAWN_BODY_FEET_Y
	var radius := PAWN_BODY_RADIUS
	if targeting and mobile:
		head = SPRITE_HEAD_Y
		foot = SPRITE_FOOT_Y
		radius = TARGET_PAWN_BODY_RADIUS
	elif targeting:
		head = SPRITE_HEAD_Y
		foot = SPRITE_FOOT_Y
		radius = SPRITE_HALF_W
	elif mobile:
		radius = MOBILE_PAWN_BODY_RADIUS
	var y := clampf(local.y, head, foot)
	return local.distance_to(Vector2(0.0, y)) <= radius


## The painted diamond of the cell the fighter stands on.
## expanded lets a finger land past the edge without taking the next tile center.
static func hits_unit_diamond(point: Vector2, tile_center: Vector2, expanded: bool = false) -> bool:
	var limit := TARGET_DIAMOND_LIMIT if expanded else 1.0
	return diamond_metric(point, tile_center) <= limit


## Enemy / ally / any casts need a living unit. Empty-tile and self spells do not.
static func spell_targets_unit(spell_id: String) -> bool:
	if spell_id == "":
		return false
	var def: Dictionary = SpellKits.spell(spell_id)
	if def.is_empty():
		return false
	return str(def.get("target", "")) in ["enemy", "ally", "any"]


## First rolling enemy cast is the thumb button. Otherwise the first offered spell.
static func primary_spell_id(offered: Array) -> String:
	var first := ""
	for spell_id in offered:
		var id := str(spell_id)
		if id == "":
			continue
		if first == "":
			first = id
		var def: Dictionary = SpellKits.spell(id)
		if str(def.get("target", "")) == "enemy" and bool(def.get("rolls", false)):
			return id
	return first


## Centers inside CLUSTER_SIZE. Primary sits bottom-right; arc fans up and left.
static func cluster_centers(arc_count: int) -> Dictionary:
	var primary_r := PRIMARY_BUTTON_SIZE.x * 0.5
	var primary := Vector2(
		CLUSTER_SIZE.x - CLUSTER_EDGE - primary_r,
		CLUSTER_SIZE.y - CLUSTER_EDGE - primary_r
	)
	var arc: Array[Vector2] = []
	var count := maxi(arc_count, 0)
	if count > 0:
		var start := deg_to_rad(CLUSTER_ARC_START_DEG)
		var end := deg_to_rad(CLUSTER_ARC_END_DEG)
		var radius := CROWDED_ARC_RADIUS if count >= CROWDED_ARC_COUNT else CLUSTER_ARC_RADIUS
		for i in count:
			var t := 0.5 if count == 1 else float(i) / float(count - 1)
			var angle := lerpf(start, end, t)
			arc.append(primary + Vector2(radius, 0.0).rotated(angle))
	return {"primary": primary, "arc": arc}


static func cluster_button_size(primary: bool, arc_count: int = 0) -> Vector2:
	if primary:
		return PRIMARY_BUTTON_SIZE
	return CROWDED_BUTTON_SIZE if arc_count >= CROWDED_ARC_COUNT else ABILITY_BUTTON_SIZE


static func cluster_button_rect(center: Vector2, primary: bool, arc_count: int = 0) -> Rect2:
	var size := cluster_button_size(primary, arc_count)
	return Rect2(center - size * 0.5, size)


## One body, or the clearly nearer body. A tie returns (-1, -1) so the ground
## cell can stay empty and Soft Lock can refuse two neighbors.
## body true: the drawing. body false: the diamond that fighter stands on.
static func _pick_pawn_hit(point: Vector2, living_pawns: Array, mobile: bool, body: bool, wide: bool = false) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_d := 0.0
	var second_d := 0.0
	var hits := 0
	var have_second := false
	for entry in living_pawns:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pawn: Dictionary = entry
		var origin: Vector2 = pawn.get("origin", Vector2.ZERO)
		var dist := point.distance_to(origin)
		if body:
			if not hits_pawn_body(point, origin, mobile, wide):
				continue
		elif not hits_unit_diamond(point, origin, mobile):
			continue
		hits += 1
		if hits == 1 or dist < best_d:
			if hits > 1:
				second_d = best_d
				have_second = true
			best_d = dist
			best_cell = pawn.get("cell", Vector2i(-1, -1))
		elif not have_second or dist < second_d:
			second_d = dist
			have_second = true
	if hits == 1:
		return best_cell
	if hits > 1 and have_second and best_d + BODY_PICK_TIE_PX < second_d:
		return best_cell
	return Vector2i(-1, -1)


## The painted top diamond under `point` that is drawn in front (same order as
## VisualSort.tile_z_index: row sum, then elevation read back from the lift).
static func front_cell(point: Vector2, tile_positions: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_z := -INF
	for key in tile_positions.keys():
		var cell: Vector2i = key
		var center: Vector2 = tile_positions[key]
		if diamond_metric(point, center) > 1.0:
			continue
		var row := float(cell.x + cell.y)
		var elevation := (row * 16.0 - center.y) / 10.0
		var z := row * 10.0 + elevation * 8.0
		if z > best_z:
			best_z = z
			best = cell
	return best


## Name plate grown so the shorter side is at least the 48px hit floor.
static func hits_name_plate(point: Vector2, plate: Rect2) -> bool:
	if plate.size.x < 1.0 or plate.size.y < 1.0:
		return false
	var need := float(HIT_FLOOR)
	var grow_x := maxf(0.0, (need - plate.size.x) * 0.5)
	var grow_y := maxf(0.0, (need - plate.size.y) * 0.5)
	return plate.grow_individual(grow_x, grow_y, grow_x, grow_y).has_point(point)


## living_pawns may carry "plate": Rect2 in board space. One plate wins.
## Two plates under the same tap stay unresolved so the body or the ground can.
static func _pick_name_plate(point: Vector2, living_pawns: Array) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_d := 0.0
	var second_d := 0.0
	var hits := 0
	var have_second := false
	for entry in living_pawns:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pawn: Dictionary = entry
		var plate: Variant = pawn.get("plate", null)
		if not (plate is Rect2):
			continue
		var rect: Rect2 = plate
		if not hits_name_plate(point, rect):
			continue
		var origin: Vector2 = pawn.get("origin", rect.get_center())
		var dist := point.distance_to(origin)
		hits += 1
		if hits == 1 or dist < best_d:
			if hits > 1:
				second_d = best_d
				have_second = true
			best_d = dist
			best_cell = pawn.get("cell", Vector2i(-1, -1))
		elif not have_second or dist < second_d:
			second_d = dist
			have_second = true
	if hits == 1:
		return best_cell
	if hits > 1 and have_second and best_d + BODY_PICK_TIE_PX < second_d:
		return best_cell
	return Vector2i(-1, -1)


## mobile: the front painted diamond first (elevation aware).
## Desktop: nearest tile inside CELL_PICK_RADIUS, else the flat iso cell.
## mobile: a living body uses the fatter capsule; otherwise the painted diamond
## (side tips included). A tap just off the board uses MOBILE_CELL_PICK_RADIUS.
## prefer_unit: the drawing wins over empty ground, then the fighter's own
## diamond wins over the neighbor iso_cell would steal. A tie stays ground.
## A tap on the sprite or its name plate selects that fighter either way.
## prefer_unit widens the body pad and also takes the fighter's diamond.
## living_pawns entries: {cell, origin, sort, plate}.
static func pick_board_cell(point: Vector2, tile_positions: Dictionary, living_pawns: Array, prefer_unit: bool, mobile: bool = false) -> Vector2i:
	if mobile:
		# The painted diamond under the finger is the cell. A sprite or a name
		# plate drawn across an empty tile must not steal a walk, a jump, a
		# wall, or an attack aimed at that tile. The fighter's own diamond
		# is still them. Off the diamonds, the body and the name still select.
		var painted := front_cell(point, tile_positions)
		if painted.x >= 0:
			return painted
	var plate := _pick_name_plate(point, living_pawns)
	if plate.x >= 0:
		return plate
	if prefer_unit:
		var body := _pick_pawn_hit(point, living_pawns, mobile, true, true)
		if body.x >= 0:
			return body
		var stood := _pick_pawn_hit(point, living_pawns, mobile, false)
		if stood.x >= 0:
			return stood
	else:
		# The sprite itself selects that fighter. The wider finger pad stays
		# on an armed unit spell, so a walk can still land on a neighbor tile.
		var body := _pick_pawn_hit(point, living_pawns, false, true, false)
		if body.x >= 0:
			return body
		if mobile:
			# Whole painted drawing when it is not standing on another tile.
			# A neighbor diamond (the north face the figure covers) stays a walk.
			var drawn := _pick_pawn_hit(point, living_pawns, false, true, true)
			if drawn.x >= 0:
				var stood := front_cell(point, tile_positions)
				if stood.x < 0 or stood == drawn:
					return drawn
	if mobile:
		# The top face drawn in front wins (raised tiles cover the tile behind
		# them; the flat iso_cell used to hand those taps to the hidden tile).
		var painted := front_cell(point, tile_positions)
		if painted.x >= 0:
			return painted
		var edge := Vector2i(-1, -1)
		var edge_d := MOBILE_CELL_PICK_RADIUS
		for cell in tile_positions.keys():
			var dist := point.distance_to(tile_positions[cell])
			if dist < edge_d:
				edge_d = dist
				edge = cell
		if edge.x >= 0:
			return edge
	var best := Vector2i(-1, -1)
	var best_tile_d := CELL_PICK_RADIUS
	for cell in tile_positions.keys():
		var dist := point.distance_to(tile_positions[cell])
		if dist < best_tile_d:
			best_tile_d = dist
			best = cell
	if best.x >= 0:
		return best
	return iso_cell(point)
