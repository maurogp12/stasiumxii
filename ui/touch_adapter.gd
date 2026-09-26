extends RefCounted
class_name TouchAdapter

## Mobile-branch input adapter. Combat rules stay in CombatSim.
## Desktop hover and right-click remain. A finger can finish a hot-seat
## turn without them: tap a cell, tap a spell, tap Walk / Advance, tap the
## Face pad, tap End Turn.
## Board diamonds stay 64×32. The pick radius stays the existing nearest-tile
## test so a fatter radius cannot steal a neighbor. Fat targets are the HUD
## controls (canvas pixels on the 960×720 canvas_items / expand window).

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
## Unchanged diamond pick. See local_to_grid in board_view.gd.
const CELL_PICK_RADIUS := 22.0
## Sprite footprint in pawn-local pixels. Figures are 144×160 at scale 0.5
## with offset (0, -72), so the opaque body sits above the feet diamond.
## Radius stays inside the gap to a neighbor tile center (~34px away) so the
## body does not steal that diamond. It is not a wider CELL_PICK_RADIUS.
const PAWN_BODY_RADIUS := 34.0
const PAWN_BODY_HEAD_Y := -108.0
const PAWN_BODY_FEET_Y := -28.0

const VIEW_W := 960.0
const VIEW_H := 720.0
const PLAY_TOP := 140.0
## Top of the bottom chrome on the 720 canvas. The diamond fits above it.
const PLAY_BOTTOM := 460.0
const HUD_BOTTOM_OFFSET := -252.0

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


## True when the point lies on the fighter sprite, not the diamond at their feet.
static func hits_pawn_body(point: Vector2, pawn_origin: Vector2) -> bool:
	var local := point - pawn_origin
	var y := clampf(local.y, PAWN_BODY_HEAD_Y, PAWN_BODY_FEET_Y)
	return local.distance_to(Vector2(0.0, y)) <= PAWN_BODY_RADIUS


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
		for i in count:
			var t := 0.5 if count == 1 else float(i) / float(count - 1)
			var angle := lerpf(start, end, t)
			arc.append(primary + Vector2(CLUSTER_ARC_RADIUS, 0.0).rotated(angle))
	return {"primary": primary, "arc": arc}


static func cluster_button_size(primary: bool) -> Vector2:
	return PRIMARY_BUTTON_SIZE if primary else ABILITY_BUTTON_SIZE


static func cluster_button_rect(center: Vector2, primary: bool) -> Rect2:
	var size := cluster_button_size(primary)
	return Rect2(center - size * 0.5, size)


## Diamond nearest-tile stays at CELL_PICK_RADIUS. When prefer_unit is set, a
## hit on a living pawn's sprite wins over the empty diamond the sprite covers.
## living_pawns entries: {cell: Vector2i, origin: Vector2, sort: int}.
static func pick_board_cell(point: Vector2, tile_positions: Dictionary, living_pawns: Array, prefer_unit: bool) -> Vector2i:
	if prefer_unit:
		var found := false
		var best_cell := Vector2i(-1, -1)
		var best_sort := 0
		var best_d := 0.0
		for entry in living_pawns:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var pawn: Dictionary = entry
			var origin: Vector2 = pawn.get("origin", Vector2.ZERO)
			if not hits_pawn_body(point, origin):
				continue
			var sort := int(pawn.get("sort", 0))
			var dist := point.distance_to(origin)
			if not found or sort > best_sort or (sort == best_sort and dist < best_d):
				found = true
				best_sort = sort
				best_d = dist
				best_cell = pawn.get("cell", Vector2i(-1, -1))
		if found:
			return best_cell
	var best := Vector2i(-1, -1)
	var best_tile_d := CELL_PICK_RADIUS
	for cell in tile_positions.keys():
		var dist := point.distance_to(tile_positions[cell])
		if dist < best_tile_d:
			best_tile_d = dist
			best = cell
	if best.x >= 0:
		return best
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0
	return Vector2i(floori(grid_x + 0.5), floori(grid_y + 0.5))
