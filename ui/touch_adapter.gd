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
const SPELL_BUTTON_SIZE := Vector2(148, 72)
const END_TURN_BUTTON_SIZE := Vector2(128, 72)
const READY_BUTTON_SIZE := Vector2(128, 72)
const NEW_MATCH_BUTTON_SIZE := Vector2(128, 72)
const ACTION_BAR_MIN_HEIGHT := 150
## Unchanged diamond pick. See local_to_grid in board_view.gd.
const CELL_PICK_RADIUS := 22.0

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
