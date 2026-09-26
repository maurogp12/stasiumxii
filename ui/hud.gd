extends CanvasLayer
class_name CombatHUD

signal spell_selected(spell_id: String)
signal face_requested(dir: String)
signal end_turn_requested
signal new_match_requested
signal ready_requested(seat: int)
## Finger moved on an ability button. committing is the release.
signal aim_dragged(screen_pos: Vector2, committing: bool)
## +1 zooms in, -1 zooms out. The board keeps the step for the session.
signal zoom_step_requested(direction: int)

const KESTREL_GREEN := Color("#2E5A3C")
const IRONJAW_RED := Color("#8B2E2E")
const MENDER_BLUE := Color("#2E4A6E")
const GLOAM_PURPLE := Color("#4A3A62")
const BASTION_SLATE := Color("#5C5648")
## Same gold / navy as the hub chrome in scenes/mobile_hub.gd.
const NAVY := Color(0.035, 0.05, 0.09, 0.94)
const NAVY_ACTIVE := Color(0.07, 0.09, 0.15, 0.97)
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const CREAM := Color(0.96, 0.92, 0.84)
const HUB_FONT := "res://art/ui/hub/Cinzel-Semibold.ttf"
const STUN_GREY := Color(0.58, 0.58, 0.62, 0.82)
const AMBUSH_SHADE_TIP := "Ambush from Shade"
const AMBUSH_SHADE_MODULATE := Color(1.45, 1.15, 1.7)
## Soft-disable when legal_intents has no Ambush cast. Not a teach arm.
const AMBUSH_DISARMED_MODULATE := Color(0.62, 0.62, 0.66, 0.78)
const PUSH_BLOCKED_TOAST := "PushBlocked"
const BOUNCE_TOAST := "Bounce"
## Lava forced-push lands and applies Burn. Not a Bounce toast.
const LAVA_BURN_TOAST := "Lava - Burn"
const TOAST_SEC := 1.4
const TERRAIN_LEGEND := "G Ground 1    M Mud 2    W Water 2    L Lava    ·    tile labels = terrain + elevation    ·    z-sort is view-only"
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const TOUCH := preload("res://ui/touch_adapter.gd")

var _selected_spell: String = ""
var _spell_buttons: Dictionary = {}
var _face_buttons: Dictionary = {}
var _face_bar: HBoxContainer
var _action_bar: FlowContainer
var _ability_cluster: Control
var _bottom_box: VBoxContainer
var _kestrel_body: RichTextLabel
var _ironjaw_body: RichTextLabel
## Left card is seat 0, right card is seat 1. Titles follow units[].class_id.
var _banner_panels: Array[Panel] = []
var _banner_titles: Array[Label] = []
var _seat_panels: Array[Panel] = []
var _seat_titles: Array[Label] = []
var _turn_label: Label
var _turn_strip: HBoxContainer
var _head_cache: Dictionary = {}
var _coach_label: Label
var _selected_label: Label
var _ap_pips: HBoxContainer
var _mp_pips: HBoxContainer
var _walk_button: Button
var _end_turn_button: Button
var _new_match_button: Button
var _ready_p1_button: Button
var _ready_p2_button: Button
var _clock_row: HBoxContainer
var _deploying: bool = false
var _deploy_note: String = ""
var _handoff_overlay: ColorRect
var _handoff_panel: Panel
var _handoff_label: Label
var _clock_label: Label
var _clock_bar: ColorRect
var _clock_bar_max_width: float = 220.0
var _clock_seconds: int = int(TurnClock.DURATION_SEC)
var _locked: bool = false
var _aim_hit_label: Label
var _zoom_in_button: Button
var _zoom_out_button: Button
var _aim_hit_chance: int = -1
var _stunned: bool = false
var _stun_badge: Label
var _toast_label: Label
var _toast_token: int = 0
var _spell_hosts: Dictionary = {}
## spell path -> Texture2D or null when the stub is missing.
var _ability_textures: Dictionary = {}
var _empty_kit_button: Button
var _empty_kit_label: Label
var _tooltip_panel: Panel
var _tooltip_label: Label
var _tooltip_spell: String = ""
## Hold card ignores synthetic mouse-exit until the finger lifts, a board tap, or Walk.
var _tooltip_pinned: bool = false
## Spell armed on button-down. The matching release must not toggle it off.
var _suppress_toggle_spell: String = ""
var _press_gesture_armed: String = ""
var _press_release_token: int = 0
var _long_press_spell: String = ""
var _long_press_elapsed: float = 0.0
## True while the open long-press started from a finger, not a mouse click.
var _long_press_touch: bool = false
## Finger contact. Desktop hover must not open the card during a tap.
var _hover_suppressed: bool = false
var _last_snap: Dictionary = {}
var _last_legal: Array = []
var _preview_source: Node = null
var _terrain_legend: Label
var _turn_label_base: String = ""
var _ui_font: Font


## Kit chrome uses local_seat when NetSession set it; hot-seat (local_seat < 0)
## falls back to active_seat. Snapshot does not encode "show active kit".
## Also reads net.local_seat / net.active_seat when the top-level keys are absent.
## Advance is never offered unless class_id is ironjaw.
## Spell buttons follow units[kit_seat].class_id via SpellKits.class_spells.
## Intent spell ids are the Locked card ids. Enablement follows legal_intents.
## Gated open_can_wait rows (Nightfold) stay off the bar.
static func _net_dict(snap: Dictionary) -> Dictionary:
	var raw: Variant = snap.get("net", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func snap_local_seat(snap: Dictionary) -> int:
	if snap.has("local_seat"):
		return int(snap.get("local_seat", -1))
	var net := _net_dict(snap)
	if net.has("local_seat"):
		return int(net.get("local_seat", -1))
	return -1


static func snap_active_seat(snap: Dictionary) -> int:
	if snap.has("active_seat"):
		return int(snap.get("active_seat", 0))
	var net := _net_dict(snap)
	if net.has("active_seat"):
		return int(net.get("active_seat", 0))
	return 0


static func kit_seat(snap: Dictionary) -> int:
	var local_seat := snap_local_seat(snap)
	if local_seat >= 0:
		return local_seat
	return snap_active_seat(snap)


static func unit_for_seat(units: Array, seat: int) -> Dictionary:
	for unit in units:
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -1)) == seat:
			return unit
	return {}


## Class of the fighter whose kit bar is showing.
static func kit_class_id(snap: Dictionary) -> String:
	var units: Array = snap.get("units", [])
	var unit := unit_for_seat(units, kit_seat(snap))
	return str(unit.get("class_id", ""))


static func is_local_turn(snap: Dictionary) -> bool:
	var local_seat := snap_local_seat(snap)
	if local_seat < 0:
		return true
	return local_seat == snap_active_seat(snap)


## Living fighters in the order CombatSim already hands off turns: ascending seat.
## Koliseo is seat 0 then seat 1. Stasis walks the same sorted seats. No new formula.
static func turn_order(snap: Dictionary) -> Array:
	var rows: Array = []
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) < 0:
			continue
		if not bool(unit.get("alive", true)):
			continue
		rows.append(unit)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("seat", 0)) < int(b.get("seat", 0))
	)
	return rows


static func turn_status_text(snap: Dictionary) -> String:
	if snap_local_seat(snap) < 0:
		return ""
	if is_local_turn(snap):
		return "Your Turn"
	return "Opponent's Turn"


## Visible countdown. Prefer host turn_time_seconds (ceil). Missing fields → -1.
static func turn_clock_seconds(snap: Dictionary) -> int:
	if snap.has("turn_time_seconds"):
		return maxi(int(snap.get("turn_time_seconds", 0)), 0)
	if not snap.has("turn_time_remaining"):
		return -1
	var remaining := float(snap.get("turn_time_remaining", 0.0))
	if remaining <= 0.0:
		return 0
	return int(ceili(remaining))


static func turn_clock_running(snap: Dictionary) -> bool:
	return bool(snap.get("turn_time_running", false))


static func has_host_turn_clock(snap: Dictionary) -> bool:
	return snap.has("turn_time_seconds") or snap.has("turn_time_remaining")


static func turn_clock_fraction(snap: Dictionary) -> float:
	var limit := float(snap.get("turn_time_limit", TurnClock.DURATION_SEC))
	if limit <= 0.0:
		return 0.0
	return clampf(float(snap.get("turn_time_remaining", 0.0)) / limit, 0.0, 1.0)


static func offered_cast_ids(active: Dictionary, _legal: Array = []) -> Array:
	var offered: Array = []
	if active.is_empty():
		return offered
	var class_id := str(active.get("class_id", ""))
	var from_table: Array = SpellKits.class_spells(class_id)
	if from_table.is_empty():
		return offered
	var owned: Variant = active.get("spells", [])
	var filter := typeof(owned) == TYPE_ARRAY and not (owned as Array).is_empty()
	var owned_ids := {}
	if filter:
		for spell_id in owned:
			owned_ids[str(spell_id)] = true
	for spell_id in from_table:
		var id := str(spell_id)
		if id == "":
			continue
		if filter and not bool(owned_ids.get(id, false)):
			continue
		if id == SpellKits.ADVANCE and class_id != SpellKits.CLASS_IRONJAW:
			continue
		if id == SpellKits.DETONATE and class_id != SpellKits.CLASS_KESTREL:
			continue
		if (id == SpellKits.SHOULDER or id == SpellKits.CRUSH) and class_id != SpellKits.CLASS_IRONJAW:
			continue
		if not SpellKits.has_spell(class_id, id):
			continue
		if SpellKits.is_gated(id):
			continue
		if not offered.has(id):
			offered.append(id)
	return offered


static func banner_color(class_id: String) -> Color:
	match class_id:
		SpellKits.CLASS_IRONJAW:
			return IRONJAW_RED
		SpellKits.CLASS_MENDER:
			return MENDER_BLUE
		SpellKits.CLASS_GLOAM:
			return GLOAM_PURPLE
		SpellKits.CLASS_BASTION:
			return BASTION_SLATE
		_:
			return KESTREL_GREEN


static func aim_hit_caption(chance: int) -> String:
	if chance < 0:
		return ""
	return "HIT %d%%" % chance


static func engine_pips(current: int, maximum: int) -> String:
	var filled := clampi(current, 0, maximum)
	var out := ""
	for i in range(maximum):
		out += "●" if i < filled else "○"
	return out


## A01 Locked: Marks live on the target, not the caster. Kestrel's Marks row is
## that stack (the foe the consume spell reads). Other Marks rows are the stack
## on the unit itself — Ironjaw, when he is the target. Impact stays on the unit
## that holds it (Ironjaw), so that card reads `impact` directly.
static func marks_holder(unit: Dictionary, snap: Dictionary) -> Dictionary:
	if str(unit.get("class_id", "")) != SpellKits.CLASS_KESTREL:
		return unit
	var seat := int(unit.get("seat", -1))
	for other in snap.get("units", []):
		if typeof(other) != TYPE_DICTIONARY:
			continue
		if int(other.get("seat", -1)) == seat:
			continue
		return other
	return unit


## Chrome only. A live Shade on the acting Gloam is the cue that Ambush relocates.
## CombatSim still owns legality, spends, and the blink.
static func gloam_has_live_shade(snap: Dictionary) -> bool:
	if not is_local_turn(snap):
		return false
	var seat := kit_seat(snap)
	var unit := unit_for_seat(snap.get("units", []), seat)
	if str(unit.get("class_id", "")) != SpellKits.CLASS_GLOAM:
		return false
	for token in snap.get("shade_tokens", []):
		if typeof(token) != TYPE_DICTIONARY:
			continue
		if int(token.get("owner_seat", -1)) == seat and int(token.get("turns", 0)) > 0:
			return true
	return int(unit.get("shades", 0)) > 0


static func legal_cast_ids(legal: Array) -> Dictionary:
	var out := {}
	for intent in legal:
		if str(intent.get("type", "")) != "cast":
			continue
		var id := str(intent.get("spell", ""))
		if id != "":
			out[id] = true
	return out


static func terrain_legend_text() -> String:
	return TERRAIN_LEGEND


static func is_deployment_phase(snap: Dictionary) -> bool:
	return str(snap.get("phase", snap.get("phase_name", ""))) == "DEPLOYMENT"


static func can_ready_from_snap(snap: Dictionary, seat: int) -> bool:
	if not is_deployment_phase(snap):
		return false
	var ready: Dictionary = snap.get("ready", {})
	if bool(ready.get(seat, false)):
		return false
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return bool(unit.get("placed", false))
	return false


## Click routing for simultaneous deploy. A selected seat on the other blob
## (or an unclaimed cell) keeps that seat so CombatSim can emit wrong_zone / outside.
static func deploy_seat_for_cell(cell: Vector2i, selected_seat: int = -1, zones: Dictionary = {}) -> int:
	var in0 := _zone_has_cell(zones, 0, cell)
	var in1 := _zone_has_cell(zones, 1, cell)
	if selected_seat >= 0:
		var selected_owns := in0 if selected_seat == 0 else in1
		if not selected_owns:
			return selected_seat
	if in0:
		return 0
	if in1:
		return 1
	return selected_seat if selected_seat >= 0 else 0


static func _zone_has_cell(zones: Dictionary, seat: int, cell: Vector2i) -> bool:
	var raw: Variant = zones.get(seat, zones.get(str(seat), []))
	if typeof(raw) != TYPE_ARRAY:
		return false
	for owned in raw:
		if owned is Vector2i and owned == cell:
			return true
	return false


## outside_zone copy: other blob vs unclaimed cell. Interior cells are legal when sampled.
static func deploy_reject_copy(reason: String, dest: Vector2i, zone_kind: String = "") -> String:
	var where := "(%d,%d)" % [dest.x, dest.y] if dest.x >= 0 and dest.y >= 0 else "that tile"
	match reason:
		"outside_zone":
			if zone_kind == "wrong_zone" or zone_kind == "wrong_half":
				return "REJECT — %s is the other side's deploy zone." % where
			return "REJECT — %s is outside this side's deployment zone." % where
		"occupied":
			return "REJECT — %s is occupied." % where
		"out_of_bounds":
			return "REJECT — out of bounds."
		"units_not_placed":
			return "REJECT — place the required fighter before Ready."
		"side_locked":
			return "REJECT — this side is already ready."
		"wrong_phase":
			return "REJECT — deploy is over."
		"already_ready":
			return "REJECT — already ready."
		_:
			return "REJECT — %s." % reason


static func unit_is_stunned(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	return int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))


static func unit_is_burning(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	return unit_burn_remaining(unit) > 0


## Snapshot `burn_remaining` wins when the unit carries it. Status / burn events
## fill in only when that field is absent. Does not tick or add durations.
static func unit_burn_remaining(unit: Dictionary, events: Array = []) -> int:
	if unit.is_empty():
		return 0
	if unit.has("burn_remaining"):
		return maxi(0, int(unit.get("burn_remaining", 0)))
	var seat := int(unit.get("seat", -999))
	var remaining := 0
	var saw := false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if int(event.get("target_seat", -999)) != seat:
			continue
		var kind := str(event.get("type", ""))
		if kind == "status" and str(event.get("status", "")) == "burn":
			remaining = int(event.get("remaining", 0))
			saw = true
		elif kind == "hit" and bool(event.get("burn_applied", false)):
			remaining = int(event.get("burn_remaining", 0))
			saw = true
		elif kind == "burn" and event.has("remaining"):
			remaining = int(event.get("remaining", 0))
			saw = true
	if not saw:
		return 0
	return maxi(0, remaining)


## Icon caption. Empty when the snapshot has no turns left.
static func burn_badge_text(remaining: int) -> String:
	if remaining <= 0:
		return ""
	return "BURN %d" % remaining


static func events_include_push_blocked(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "push_blocked":
			return true
		if bool(event.get("push_blocked", false)):
			return true
	return false


static func events_include_lava_burn(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if bool(event.get("burn_applied", false)):
			return true
		if str(event.get("type", "")) == "status" and str(event.get("status", "")) == "burn":
			return true
	return false


static func events_include_push_bounce(events: Array) -> bool:
	# A lava land is a displace, not a bounce, even if a bounce flag is also present.
	if events_include_lava_burn(events):
		return false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "push_bounce":
			return true
		if bool(event.get("bounced", false)):
			return true
	return false


static func events_include_stagger(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "stagger":
			return true
		if bool(event.get("staggered", false)):
			return true
	return false


static func should_play_walk_hops(events: Array) -> bool:
	if events_include_push_blocked(events) or events_include_push_bounce(events):
		return false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "move":
			continue
		if not event.has("path"):
			continue
		var path: Array = event["path"]
		if not path.is_empty():
			return true
	return false


## One Impact number from the hit event. Bounce is that gain only — never +1 stacked with +2.
static func shoulder_impact_gained(events: Array) -> int:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "hit":
			continue
		if str(event.get("spell", "")) != SpellKits.SHOULDER:
			continue
		if str(event.get("engine", "")) != "impact":
			continue
		return maxi(0, int(event.get("engine_gained", 0)))
	return 0


static func impact_gain_toast(amount: int) -> String:
	if amount <= 0:
		return ""
	return "+%d Impact" % amount


static func toast_for_events(events: Array) -> String:
	if events_include_push_blocked(events):
		return PUSH_BLOCKED_TOAST
	if events_include_lava_burn(events):
		return _join_toast(impact_gain_toast(shoulder_impact_gained(events)), LAVA_BURN_TOAST)
	if events_include_push_bounce(events):
		return _join_toast(BOUNCE_TOAST, impact_gain_toast(shoulder_impact_gained(events)))
	return impact_gain_toast(shoulder_impact_gained(events))


static func _join_toast(left: String, right: String) -> String:
	if left == "":
		return right
	if right == "":
		return left
	return "%s  %s" % [left, right]


## Presentation of a CombatSim auto-skip. Does not submit end_turn.
## Prefer Locked A′ `end_turn auto` / `turn_start.stunned_skip` over coach text on
## the previous seat's handoff (that coach mentions the skip but belongs to the actor).
static func stun_skip_event(events: Array) -> Dictionary:
	var turn_start_skip := {}
	var coach_skip := {}
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var kind := str(event.get("type", ""))
		var coach := str(event.get("coach", ""))
		if kind in ["stun_skip", "turn_skipped", "stunned_skip"]:
			return event
		if kind == "end_turn" and str(event.get("reason", "")) != "timer" and (
			bool(event.get("auto", false))
			or bool(event.get("auto_end_turn", false))
			or bool(event.get("stunned", false))
			or bool(event.get("stun_skip", false))
			or bool(event.get("stunned_skip", false))
			or bool(event.get("skipped", false))
			or str(event.get("reason", "")) == "stunned"
		):
			return event
		if kind == "turn_start" and (
			bool(event.get("skipped", false))
			or bool(event.get("stun_skip", false))
			or bool(event.get("stunned_skip", false))
		):
			if turn_start_skip.is_empty():
				turn_start_skip = event
		elif kind != "end_turn" and coach.contains("turn skipped"):
			if coach_skip.is_empty():
				coach_skip = event
	if not turn_start_skip.is_empty():
		return turn_start_skip
	return coach_skip


static func events_include_stun_skip(events: Array) -> bool:
	return not stun_skip_event(events).is_empty()


static func stun_skip_caption(event: Dictionary, snap: Dictionary = {}) -> String:
	if event.is_empty():
		return ""
	var unit_name := str(event.get("name", event.get("unit_name", "")))
	if unit_name == "" and not snap.is_empty():
		var seat := int(event.get("seat", -1))
		for unit in snap.get("units", []):
			if int(unit.get("seat", -2)) == seat:
				unit_name = str(unit.get("name", ""))
				break
	if unit_name != "":
		return "%s stunned — turn skipped" % unit_name
	var coach := str(event.get("coach", "")).strip_edges()
	if coach != "":
		return coach
	return "Stunned — turn skipped"


## Proposed hover / long-press card. Formats CombatSim.preview_cast only.
static func spell_card_text(preview: Dictionary) -> String:
	return SpellTooltip.card_text(preview)


func _ready() -> void:
	layer = 10
	set_process(false)
	_build()


func _process(delta: float) -> void:
	if _long_press_spell == "":
		set_process(false)
		return
	_long_press_elapsed += delta
	if _long_press_elapsed >= SpellTooltip.LONG_PRESS_SEC:
		var spell_id := _long_press_spell
		var from_touch := _long_press_touch
		show_spell_tooltip(spell_id)
		if from_touch and tooltip_visible():
			_tooltip_pinned = true
			# Release dismisses the card and must not toggle the armed spell off.
			_suppress_toggle_spell = spell_id
		_cancel_long_press()


func _input(event: InputEvent) -> void:
	if TOUCH.is_emulated_mouse(event):
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.index != 0:
		return
	if touch.pressed:
		# Before emulated mouse_entered, so a tap does not flash the card.
		_hover_suppressed = true
		return
	_finish_touch_tooltip()


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("ui_cancel"):
		if cancel_spell_selection():
			get_viewport().set_input_as_handled()


func selected_spell() -> String:
	return _selected_spell


func clear_spell() -> void:
	_selected_spell = ""
	set_aim_preview({})
	_refresh_spell_buttons()
	_update_selected_label()
	hide_spell_tooltip()


## Client Walk mode. Does not submit a CombatSim intent. Does not face.
func select_walk() -> void:
	clear_spell()
	spell_selected.emit("")


## Esc / Walk-button cancel. Clears spell chrome only; right-click face is unchanged.
func cancel_spell_selection() -> bool:
	if _selected_spell == "":
		return false
	select_walk()
	return true


func set_aim_preview(preview: Dictionary) -> void:
	if bool(preview.get("show", false)):
		_aim_hit_chance = int(preview.get("hit_chance", 0))
	else:
		_aim_hit_chance = -1
	if _aim_hit_label != null:
		_aim_hit_label.text = aim_hit_caption(_aim_hit_chance)
		_aim_hit_label.visible = _aim_hit_chance >= 0
	_update_selected_label()


func set_locked(locked: bool) -> void:
	_locked = locked
	_apply_controls(false)


func _banner_color(class_id: String) -> Color:
	return banner_color(class_id)


func show_turn_banner(unit_name: String, class_id: String, caption: String = "") -> void:
	_handoff_label.text = caption if caption != "" else "%s's turn" % unit_name
	var fill := _banner_color(class_id)
	_handoff_panel.add_theme_stylebox_override("panel", _fighter_frame(true, fill))
	_handoff_overlay.visible = true
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func banner_caption() -> String:
	if _handoff_label == null or _handoff_overlay == null or not _handoff_overlay.visible:
		return ""
	return _handoff_label.text


func hide_turn_banner() -> void:
	_handoff_overlay.visible = false
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_turn_clock(seconds_left: int, running: bool, fraction: float) -> void:
	if _clock_label == null:
		return
	_clock_label.text = "%ds" % maxi(seconds_left, 0)
	_clock_seconds = maxi(seconds_left, 0)
	var color := CREAM
	if not running:
		color = GOLD_DIM
	elif seconds_left <= 5:
		color = Color(0.92, 0.32, 0.28)
	elif seconds_left <= 10:
		color = Color(0.95, 0.72, 0.32)
	_clock_label.add_theme_color_override("font_color", color)
	if _clock_bar == null:
		return
	var width := _clock_bar_max_width * clampf(fraction, 0.0, 1.0)
	_clock_bar.custom_minimum_size = Vector2(width, 8)
	_clock_bar.size = Vector2(width, 8)
	if not running:
		_clock_bar.color = GOLD_DIM
	elif seconds_left <= 5:
		_clock_bar.color = Color(0.82, 0.28, 0.28)
	elif seconds_left <= 10:
		_clock_bar.color = Color(0.92, 0.68, 0.28)
	else:
		_clock_bar.color = GOLD
	_apply_turn_label_clock()


func set_preview_source(sim: Node) -> void:
	_preview_source = sim


func render(snap: Dictionary, legal: Array) -> void:
	_last_snap = snap
	_last_legal = legal.duplicate()
	_deploying = is_deployment_phase(snap)
	var units: Array = snap.get("units", [])
	var seat0 := _unit(units, 0)
	var seat1 := _unit(units, 1)
	var active_seat := snap_active_seat(snap)
	# Stasis Room A has more than the Koliseo pair. The right card follows the
	# living hostile whose turn it is, then the first one still standing.
	if units.size() > 2:
		var shown: Dictionary = {}
		if active_seat > 0:
			shown = _unit(units, active_seat)
		if shown.is_empty() or not bool(shown.get("alive", false)):
			for unit in units:
				if typeof(unit) != TYPE_DICTIONARY:
					continue
				if int(unit.get("seat", -1)) > 0 and bool(unit.get("alive", false)):
					shown = unit
					break
		if not shown.is_empty():
			seat1 = shown
	_apply_seat_banner(0, seat0, active_seat == 0 and not _deploying)
	_apply_seat_banner(1, seat1, active_seat == 1 and not _deploying)
	_kestrel_body.text = _unit_card_text(seat0, active_seat == 0, snap)
	_ironjaw_body.text = _unit_card_text(seat1, active_seat == 1, snap)

	var active := _unit(units, active_seat)
	var chrome := _unit(units, kit_seat(snap))
	var active_name := str(active.get("name", "—"))
	var clock_sec := turn_clock_seconds(snap)
	if clock_sec >= 0:
		_clock_seconds = clock_sec
	if snap.get("match_over", false):
		var winner := _unit(units, int(snap.get("winner_seat", -1)))
		_turn_label_base = "Match over — %s wins" % str(winner.get("name", "—"))
	elif _deploying:
		_turn_label_base = "DEPLOYMENT  ·  place both fighters"
	else:
		var whose := turn_status_text(snap)
		if whose == "":
			whose = active_name
		_turn_label_base = "Turn %d  ·  %s" % [int(snap.get("turn_index", 1)), whose]
	var net_prefix := _net_prefix(snap)
	if net_prefix != "":
		_turn_label_base = "%s%s" % [net_prefix, _turn_label_base]
	if has_host_turn_clock(snap):
		set_turn_clock(clock_sec if clock_sec >= 0 else _clock_seconds, turn_clock_running(snap), turn_clock_fraction(snap))
	else:
		_apply_turn_label_clock()
	_sync_turn_strip(snap)

	_render_pips(_ap_pips, int(active.get("ap", 0)), int(active.get("max_ap", 6)), GOLD_BRIGHT)
	_render_pips(_mp_pips, int(active.get("mp", 0)), int(active.get("max_mp", 3)), Color(0.78, 0.84, 0.9))
	if _deploy_note != "" and _deploying:
		_coach_label.text = _deploy_note
	else:
		_coach_label.text = str(snap.get("coach", ""))

	var offered: Array = [] if _deploying else offered_cast_ids(chrome, legal)
	_sync_spell_buttons(offered)
	_sync_empty_kit(chrome, offered)
	if _selected_spell != "" and not offered.has(_selected_spell):
		_selected_spell = ""
		_aim_hit_chance = -1
		hide_spell_tooltip()
	if _selected_spell == "":
		_aim_hit_chance = -1
		if _aim_hit_label != null:
			_aim_hit_label.text = ""
			_aim_hit_label.visible = false
	if _tooltip_spell != "" and not offered.has(_tooltip_spell):
		hide_spell_tooltip()

	var legal_spells := legal_cast_ids(legal)
	var match_over := bool(snap.get("match_over", false))
	# Ambush arms only from a legal cast. Drop a stale selection so the
	# cluster cannot keep teaching the arm after the geometry goes illegal.
	if _selected_spell == SpellKits.AMBUSH and not legal_spells.has(SpellKits.AMBUSH):
		_selected_spell = ""
		_aim_hit_chance = -1
		_press_gesture_armed = ""
		_suppress_toggle_spell = ""
		if _aim_hit_label != null:
			_aim_hit_label.text = ""
			_aim_hit_label.visible = false
	# Locked Stun (A′): face/cast chrome follows CombatSim stun reject (move + cast + face blocked).
	# Grey Walk / Face / spells. CombatSim auto-ends the turn; End Turn is a fallback.
	# Online: stun-grey the local kit only while that seat is acting.
	_stunned = unit_is_stunned(chrome) and is_local_turn(snap) and not match_over and not _deploying
	if _stunned and _selected_spell != "":
		_selected_spell = ""
		_aim_hit_chance = -1
		if _aim_hit_label != null:
			_aim_hit_label.text = ""
			_aim_hit_label.visible = false
	_update_selected_label()
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		var can_submit: bool = legal_spells.has(spell_id) and not match_over and not _stunned and not _deploying and is_local_turn(snap)
		_set_spell_button_clickable(button, can_submit)
		_apply_spell_modulate(str(spell_id), button, can_submit)
	_refresh_walk_button()
	_apply_controls(match_over)
	_sync_deploy_chrome(snap)
	_sync_stun_badge(chrome, units, match_over)


func _apply_controls(match_over: bool) -> void:
	var block := match_over or _locked or _deploying
	var not_your_turn := snap_local_seat(_last_snap) >= 0 and not is_local_turn(_last_snap)
	for spell_id in _spell_buttons.keys():
		if block:
			_set_spell_button_clickable(_spell_buttons[spell_id], false)
	for button in _face_buttons.values():
		(button as Button).disabled = block or _stunned or not_your_turn
		(button as Button).modulate = STUN_GREY if ((_stunned or _deploying or not_your_turn) and not match_over and not _locked) else Color.WHITE
	if _walk_button != null:
		_walk_button.disabled = block or _stunned or not_your_turn
		if (_stunned or _deploying or not_your_turn) and not match_over and not _locked:
			_walk_button.modulate = STUN_GREY
		_sync_ability_icon(_walk_button)
	if _end_turn_button != null:
		# Locked Stun (A′): End Turn stays as a fallback; CombatSim auto-skips.
		# Deploy: End Turn stays off until both Ready leave DEPLOYMENT.
		# Online: only the owner of active_seat can End Turn.
		_end_turn_button.disabled = block or not_your_turn
		_end_turn_button.modulate = Color.WHITE
		_sync_ability_icon(_end_turn_button)
	if _new_match_button != null:
		_new_match_button.disabled = _locked
		_new_match_button.visible = _show_new_match(_last_snap)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_ui_font = _load_ui_font()

	root.add_child(_make_banner(true))
	root.add_child(_make_banner(false))

	var resource_panel := Panel.new()
	resource_panel.position = Vector2(256, 8)
	resource_panel.size = Vector2(448, 128)
	resource_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_panel.add_theme_stylebox_override("panel", _fighter_frame(true, GOLD))
	root.add_child(resource_panel)

	_turn_strip = HBoxContainer.new()
	_turn_strip.name = "TurnStrip"
	_turn_strip.position = Vector2(8, 4)
	_turn_strip.size = Vector2(432, 48)
	_turn_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_strip.add_theme_constant_override("separation", 8)
	_turn_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_panel.add_child(_turn_strip)

	_turn_label = Label.new()
	_turn_label.position = Vector2(8, 52)
	_turn_label.size = Vector2(432, 16)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_label.clip_text = true
	_turn_label.add_theme_font_size_override("font_size", 11)
	_turn_label.add_theme_color_override("font_color", GOLD)
	_apply_display_font(_turn_label)
	resource_panel.add_child(_turn_label)

	var res_box := VBoxContainer.new()
	res_box.position = Vector2(18, 70)
	res_box.size = Vector2(412, 52)
	res_box.add_theme_constant_override("separation", 4)
	res_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_panel.add_child(res_box)
	_ap_pips = _make_pip_row("AP")
	_mp_pips = _make_pip_row("MP")
	res_box.add_child(_ap_pips)
	res_box.add_child(_mp_pips)
	res_box.add_child(_make_clock_row())

	_terrain_legend = Label.new()
	_terrain_legend.text = TERRAIN_LEGEND
	_terrain_legend.position = Vector2(12, 106)
	_terrain_legend.size = Vector2(424, 16)
	_terrain_legend.clip_text = true
	_terrain_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terrain_legend.add_theme_font_size_override("font_size", 9)
	_terrain_legend.add_theme_color_override("font_color", GOLD_DIM)
	# The string stays for the elevation contract. It is not player combat feedback.
	_terrain_legend.modulate = Color(1, 1, 1, 0)
	resource_panel.add_child(_terrain_legend)

	_stun_badge = Label.new()
	_stun_badge.text = "STUN"
	_stun_badge.position = Vector2(430, 140)
	_stun_badge.size = Vector2(100, 22)
	_stun_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_badge.add_theme_font_size_override("font_size", 14)
	_stun_badge.add_theme_color_override("font_color", Color(0.18, 0.1, 0.04))
	_stun_badge.add_theme_color_override("font_outline_color", Color(0.98, 0.82, 0.28))
	_stun_badge.add_theme_constant_override("outline_size", 6)
	_stun_badge.visible = false
	root.add_child(_stun_badge)

	var bottom := VBoxContainer.new()
	_bottom_box = bottom
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -8
	bottom.offset_top = TOUCH.HUD_BOTTOM_OFFSET
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	_aim_hit_label = Label.new()
	_aim_hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_hit_label.add_theme_font_size_override("font_size", 20)
	_aim_hit_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.16))
	_aim_hit_label.visible = false
	bottom.add_child(_aim_hit_label)

	_selected_label = Label.new()
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_label.custom_minimum_size = Vector2(0, 40)
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", CREAM)
	_selected_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	_selected_label.add_theme_constant_override("outline_size", 5)
	bottom.add_child(_selected_label)

	# Face cross beside the action bar so 72px buttons and a 48px pad both fit.
	var combat_row := HBoxContainer.new()
	combat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_row.add_theme_constant_override("separation", 8)
	combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(combat_row)

	var face_bar := HBoxContainer.new()
	_face_bar = face_bar
	face_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	face_bar.add_theme_constant_override("separation", 8)
	face_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_row.add_child(face_bar)
	var face_caption := Label.new()
	face_caption.text = "Face"
	face_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_caption.add_theme_color_override("font_color", GOLD_BRIGHT)
	face_caption.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	face_caption.add_theme_constant_override("outline_size", 4)
	_apply_display_font(face_caption)
	face_bar.add_child(face_caption)
	var face_pad := GridContainer.new()
	face_pad.columns = 3
	face_pad.add_theme_constant_override("h_separation", 4)
	face_pad.add_theme_constant_override("v_separation", 4)
	face_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_bar.add_child(face_pad)
	# Cardinal pad: N top, W/E sides, S bottom. Empty cells keep the cross aligned.
	for dir in ["", "N", "", "W", "", "E", "", "S", ""]:
		if dir == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = TOUCH.FACE_BUTTON_SIZE
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face_pad.add_child(spacer)
			continue
		var button := Button.new()
		button.text = dir
		button.custom_minimum_size = TOUCH.FACE_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", CREAM)
		_style_chrome_button(button, false)
		button.pressed.connect(_on_face_pressed.bind(dir))
		face_pad.add_child(button)
		_face_buttons[dir] = button

	_action_bar = FlowContainer.new()
	_action_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	_action_bar.custom_minimum_size = Vector2(0, TOUCH.ACTION_BAR_MIN_HEIGHT)
	_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_bar.add_theme_constant_override("h_separation", 6)
	_action_bar.add_theme_constant_override("v_separation", 6)
	combat_row.add_child(_action_bar)

	_walk_button = Button.new()
	_walk_button.text = "Walk"
	_walk_button.custom_minimum_size = TOUCH.WALK_BUTTON_SIZE
	_walk_button.clip_text = true
	_walk_button.add_theme_font_size_override("font_size", 16)
	_walk_button.add_theme_color_override("font_color", CREAM)
	_style_chrome_button(_walk_button, true)
	_walk_button.pressed.connect(_on_walk_pressed)
	_action_bar.add_child(_walk_button)
	_bind_ability_icon(_walk_button, "walk", "Walk")

	_empty_kit_label = Label.new()
	_empty_kit_label.visible = false
	_empty_kit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_kit_label.add_theme_font_size_override("font_size", 14)
	_empty_kit_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.16))
	_action_bar.add_child(_empty_kit_label)
	_empty_kit_button = Button.new()
	_empty_kit_button.text = "—"
	_empty_kit_button.disabled = true
	_empty_kit_button.visible = false
	_empty_kit_button.focus_mode = Control.FOCUS_NONE
	_empty_kit_button.custom_minimum_size = TOUCH.WALK_BUTTON_SIZE
	_empty_kit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_bar.add_child(_empty_kit_button)

	_ready_p1_button = Button.new()
	_ready_p1_button.text = "Ready P1"
	_ready_p1_button.custom_minimum_size = TOUCH.READY_BUTTON_SIZE
	_ready_p1_button.add_theme_font_size_override("font_size", 15)
	_ready_p1_button.add_theme_color_override("font_color", CREAM)
	_style_chrome_button(_ready_p1_button, false)
	_ready_p1_button.clip_text = true
	_ready_p1_button.pressed.connect(func() -> void: ready_requested.emit(0))
	_action_bar.add_child(_ready_p1_button)

	_ready_p2_button = Button.new()
	_ready_p2_button.text = "Ready P2"
	_ready_p2_button.custom_minimum_size = TOUCH.READY_BUTTON_SIZE
	_ready_p2_button.add_theme_font_size_override("font_size", 15)
	_ready_p2_button.add_theme_color_override("font_color", CREAM)
	_style_chrome_button(_ready_p2_button, false)
	_ready_p2_button.clip_text = true
	_ready_p2_button.pressed.connect(func() -> void: ready_requested.emit(1))
	_action_bar.add_child(_ready_p2_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = TOUCH.END_TURN_BUTTON_SIZE
	_end_turn_button.add_theme_font_size_override("font_size", 16)
	_end_turn_button.add_theme_color_override("font_color", CREAM)
	_style_chrome_button(_end_turn_button, true)
	_end_turn_button.clip_text = true
	_end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	_action_bar.add_child(_end_turn_button)
	_bind_ability_icon(_end_turn_button, "end_turn", "End Turn")

	_new_match_button = Button.new()
	_new_match_button.text = "New Match"
	_new_match_button.custom_minimum_size = TOUCH.NEW_MATCH_BUTTON_SIZE
	_new_match_button.add_theme_font_size_override("font_size", 15)
	_new_match_button.add_theme_color_override("font_color", CREAM)
	_style_chrome_button(_new_match_button, false)
	_new_match_button.clip_text = true
	_new_match_button.pressed.connect(func() -> void: new_match_requested.emit())
	_action_bar.add_child(_new_match_button)

	_coach_label = Label.new()
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.add_theme_font_size_override("font_size", 14)
	_coach_label.add_theme_color_override("font_color", CREAM)
	_coach_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	_coach_label.add_theme_constant_override("outline_size", 4)
	bottom.add_child(_coach_label)

	_ability_cluster = Control.new()
	_ability_cluster.name = "AbilityCluster"
	_ability_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability_cluster.offset_left = -(TOUCH.CLUSTER_SIZE.x + TOUCH.CLUSTER_EDGE)
	_ability_cluster.offset_top = -(TOUCH.CLUSTER_SIZE.y + TOUCH.CLUSTER_EDGE)
	_ability_cluster.offset_right = -TOUCH.CLUSTER_EDGE
	_ability_cluster.offset_bottom = -TOUCH.CLUSTER_EDGE
	_ability_cluster.custom_minimum_size = TOUCH.CLUSTER_SIZE
	_ability_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_cluster.visible = false
	root.add_child(_ability_cluster)

	_toast_label = Label.new()
	_toast_label.position = Vector2(220, 540)
	_toast_label.size = Vector2(520, 32)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(0.92, 0.22, 0.14))
	_toast_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.visible = false
	root.add_child(_toast_label)

	_tooltip_panel = Panel.new()
	# Above the touch action row so a pinned card does not cover Face / End Turn.
	_tooltip_panel.position = Vector2(240, 168)
	_tooltip_panel.size = Vector2(480, 248)
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.add_theme_stylebox_override("panel", _card_panel())
	root.add_child(_tooltip_panel)
	_tooltip_label = Label.new()
	_tooltip_label.position = Vector2(12, 8)
	_tooltip_label.size = Vector2(456, 232)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_label)

	var zoom_box := VBoxContainer.new()
	zoom_box.name = "ZoomControls"
	zoom_box.position = Vector2(16, 152)
	zoom_box.add_theme_constant_override("separation", 8)
	zoom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(zoom_box)
	_zoom_in_button = _make_zoom_button("ZoomIn", "Zoom +", 1)
	_zoom_out_button = _make_zoom_button("ZoomOut", "Zoom −", -1)
	zoom_box.add_child(_zoom_in_button)
	zoom_box.add_child(_zoom_out_button)

	_handoff_overlay = ColorRect.new()
	_handoff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_overlay.color = Color(0.06, 0.05, 0.07, 0.42)
	_handoff_overlay.visible = false
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_handoff_overlay)

	_handoff_panel = Panel.new()
	_handoff_panel.position = Vector2(230, 268)
	_handoff_panel.size = Vector2(500, 140)
	_handoff_panel.add_theme_stylebox_override("panel", _fighter_frame(true, GOLD))
	_handoff_overlay.add_child(_handoff_panel)

	_handoff_label = Label.new()
	_handoff_label.position = Vector2(16, 28)
	_handoff_label.size = Vector2(468, 84)
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_handoff_label.add_theme_font_size_override("font_size", 36)
	_handoff_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	_handoff_label.text = "Kestrel's turn"
	_handoff_panel.add_child(_handoff_label)

	_update_selected_label()


func set_zoom_buttons(can_in: bool, can_out: bool) -> void:
	if _zoom_in_button != null:
		_zoom_in_button.disabled = not can_in
	if _zoom_out_button != null:
		_zoom_out_button.disabled = not can_out


func _make_zoom_button(node_name: String, label: String, direction: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(128, 72)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", CREAM)
	_apply_display_font(button)
	_style_chrome_button(button, true)
	button.pressed.connect(func() -> void: zoom_step_requested.emit(direction))
	return button


func _show_new_match(snap: Dictionary) -> bool:
	var seat := snap_local_seat(snap)
	if seat < 0:
		return true
	var net := _net_dict(snap)
	if str(net.get("mode", "")) == "host":
		return true
	return bool(net.get("dedicated", false)) and seat == 0


func _apply_seat_banner(seat: int, unit: Dictionary, acting: bool = false) -> void:
	if seat < 0 or seat >= _seat_titles.size():
		return
	var class_id := str(unit.get("class_id", ""))
	var unit_name := str(unit.get("name", ""))
	if unit_name == "":
		unit_name = SpellKits.display_name(class_id)
	if unit_name == "":
		unit_name = "Seat %d" % seat
	_seat_titles[seat].text = unit_name
	_seat_titles[seat].add_theme_color_override("font_color", GOLD_BRIGHT if acting else GOLD)
	if seat >= _seat_panels.size():
		return
	var color := _banner_color(class_id)
	if str(unit.get("stasis_sprite", "")) != "":
		color = Color(0.72, 0.48, 0.28)
	var alive := bool(unit.get("alive", true))
	var lit := acting and alive
	_seat_panels[seat].add_theme_stylebox_override("panel", _fighter_frame(lit, color))
	var accent := _seat_panels[seat].get_node_or_null("Accent")
	if accent is ColorRect:
		(accent as ColorRect).color = color
	_paint_hp_bar(_seat_panels[seat], unit)


func _make_banner(is_kestrel: bool) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(8, 8) if is_kestrel else Vector2(712, 8)
	panel.size = Vector2(240, 128)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := KESTREL_GREEN if is_kestrel else IRONJAW_RED
	panel.add_theme_stylebox_override("panel", _fighter_frame(false, color))
	var accent := ColorRect.new()
	accent.name = "Accent"
	accent.position = Vector2(0, 8)
	accent.size = Vector2(4, 112)
	accent.color = color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	var title := Label.new()
	title.text = "Kestrel" if is_kestrel else "Ironjaw"
	_seat_panels.append(panel)
	_seat_titles.append(title)
	title.position = Vector2(16, 6)
	title.size = Vector2(210, 24)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	_apply_display_font(title)
	panel.add_child(title)
	_banner_panels.append(panel)
	_banner_titles.append(title)
	var track := ColorRect.new()
	track.name = "HpTrack"
	track.position = Vector2(16, 34)
	track.size = Vector2(208, 8)
	track.color = Color(0.08, 0.07, 0.09, 0.95)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	var fill := ColorRect.new()
	fill.name = "HpFill"
	fill.position = Vector2.ZERO
	fill.size = Vector2(208, 8)
	fill.color = Color(0.62, 0.18, 0.16)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	var body := RichTextLabel.new()
	body.position = Vector2(14, 46)
	body.size = Vector2(214, 76)
	body.bbcode_enabled = true
	body.scroll_active = false
	body.fit_content = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_color_override("default_color", CREAM)
	body.add_theme_font_size_override("normal_font_size", 13)
	panel.add_child(body)
	if is_kestrel:
		_kestrel_body = body
	else:
		_ironjaw_body = body
	return panel


func _make_pip_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(28, 18)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", GOLD)
	_apply_display_font(label)
	row.add_child(label)
	return row


func _make_clock_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	_clock_row = row
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "TIME"
	caption.custom_minimum_size = Vector2(36, 18)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", GOLD)
	_apply_display_font(caption)
	row.add_child(caption)
	_clock_label = Label.new()
	_clock_label.text = "%ds" % int(TurnClock.DURATION_SEC)
	_clock_label.custom_minimum_size = Vector2(36, 18)
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.add_theme_color_override("font_color", CREAM)
	row.add_child(_clock_label)
	_clock_bar = ColorRect.new()
	_clock_bar.custom_minimum_size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.color = GOLD
	row.add_child(_clock_bar)
	return row


func _render_pips(row: HBoxContainer, current: int, maximum: int, fill: Color) -> void:
	while row.get_child_count() > 1:
		var child := row.get_child(row.get_child_count() - 1)
		row.remove_child(child)
		child.free()
	for i in range(maximum):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 10)
		pip.color = fill if i < current else Color(0.1, 0.11, 0.15, 0.95)
		row.add_child(pip)


func _sync_turn_strip(snap: Dictionary) -> void:
	if _turn_strip == null:
		return
	while _turn_strip.get_child_count() > 0:
		var child := _turn_strip.get_child(0)
		_turn_strip.remove_child(child)
		child.free()
	var active := snap_active_seat(snap)
	var deploying := is_deployment_phase(snap)
	var over := bool(snap.get("match_over", false))
	for unit in turn_order(snap):
		var seat := int(unit.get("seat", -1))
		var acting := (not deploying) and (not over) and seat == active
		_turn_strip.add_child(_turn_chip(unit, acting))


func _turn_chip(unit: Dictionary, acting: bool) -> Control:
	var side := 46 if acting else 36
	var host := Panel.new()
	host.custom_minimum_size = Vector2(side, side)
	host.size = Vector2(side, side)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_stylebox_override("panel", _chip_frame(acting))
	var tex := _portrait_for(unit)
	if tex != null:
		var plate := TextureRect.new()
		plate.texture = tex
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plate.offset_left = 3
		plate.offset_top = 3
		plate.offset_right = -3
		plate.offset_bottom = -3
		host.add_child(plate)
	else:
		var label := Label.new()
		label.text = _placeholder_mark(unit)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", CREAM)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(label)
	if not acting:
		host.modulate = Color(0.72, 0.7, 0.64, 1)
	return host


func _chip_frame(acting: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = NAVY_ACTIVE if acting else NAVY
	box.border_color = GOLD_BRIGHT if acting else GOLD_DIM
	box.set_border_width_all(3 if acting else 1)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	if acting:
		box.shadow_color = Color(0.95, 0.78, 0.38, 0.7)
		box.shadow_size = 5
	return box


func _portrait_for(unit: Dictionary) -> Texture2D:
	var foe := str(unit.get("stasis_sprite", ""))
	if foe != "" and ResourceLoader.exists(foe):
		return _head_crop(foe)
	var class_id := SpellKits.normalize_class_id(str(unit.get("class_id", "")))
	if not SpellKits.is_roster_class(class_id):
		return null
	return _head_crop("res://art/characters/%s/%s_s.png" % [class_id, class_id])


func _head_crop(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _head_cache.has(path) and _head_cache[path] is Texture2D:
		return _head_cache[path]
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var size := tex.get_size()
	var side := minf(size.x * 0.62, size.y * 0.46)
	atlas.region = Rect2((size.x - side) * 0.5, size.y * 0.02, side, side)
	_head_cache[path] = atlas
	return atlas


func _placeholder_mark(unit: Dictionary) -> String:
	var unit_name := str(unit.get("name", "")).strip_edges()
	if unit_name == "":
		unit_name = SpellKits.display_name(str(unit.get("class_id", "")))
	if unit_name == "":
		return "?"
	return unit_name.substr(0, mini(4, unit_name.length()))


func _unit_card_text(unit: Dictionary, active: bool, snap: Dictionary = {}) -> String:
	if unit.is_empty():
		return "[color=#ffffff]—[/color]"
	var status := "[color=#f2d48a][b]ACTIVE[/b][/color]" if active and unit["alive"] else ("[color=#d07068]DOWN[/color]" if not unit["alive"] else "[color=#b7a88a]waiting[/color]")
	if is_deployment_phase(snap):
		var ready: Dictionary = snap.get("ready", {})
		if bool(ready.get(int(unit.get("seat", -1)), false)) or bool(unit.get("locked", false)):
			status = "[color=#f2d48a][b]READY[/b][/color]"
		elif bool(unit.get("placed", false)):
			status = "[color=#e6d7b0]placed[/color]"
		else:
			status = "[color=#cbb892]open[/color]"
	# Locked Stun (A′): STUN badge on the unit card while remaining or stunned-this-turn.
	var stun_note := ""
	if unit_is_stunned(unit):
		stun_note = "  [b]STUN[/b]"
	# Director Locked Burn: duration left is the snapshot field host replicas already carry.
	var burn_note := ""
	if unit_is_burning(unit):
		burn_note = "  [b]BURN[/b] %d" % unit_burn_remaining(unit)
	# Spell ids stay on the bottom bar. The card keeps HP, AP, MP, facing, and meters.
	return "%s   HP %d/%d%s%s\nAP %d    MP %d    Face %s\n%s" % [
		status,
		int(unit["hp"]),
		int(unit["max_hp"]),
		stun_note,
		burn_note,
		int(unit["ap"]),
		int(unit["mp"]),
		str(unit["facing"]),
		_resource_meter_line(unit, snap),
	]


func _unit(units: Array, seat: int) -> Dictionary:
	return unit_for_seat(units, seat)


## Kestrel / Ironjaw keep Marks / Impact. Card classes paint snapshot fields.
## `unit.resources` mirrors pulse / umbral / shades / aegis when the field is absent.
## Marks pips follow `marks_holder` so a connect on the foe fills Kestrel's row.
func _resource_meter_line(unit: Dictionary, snap: Dictionary = {}) -> String:
	var class_id := str(unit.get("class_id", ""))
	var mastery := int(unit.get("mastery", 0))
	var resist := int(unit.get("resist", 0))
	if class_id == SpellKits.CLASS_MENDER:
		return "%s %d/%d  Mastery %d  Resist %d" % [
			SpellKits.resource_label("pulse"),
			_resource_current(unit, "pulse"),
			int(unit.get("pulse_cap", SpellKits.PULSE_CAP)),
			mastery,
			resist,
		]
	if class_id == SpellKits.CLASS_GLOAM:
		return "%s %d/%d  %s %d/%d  Mastery %d  Resist %d" % [
			SpellKits.resource_label("umbral"),
			_resource_current(unit, "umbral"),
			int(unit.get("umbral_cap", SpellKits.UMBRAL_CAP)),
			SpellKits.resource_label("shades"),
			shade_count(unit, snap),
			int(unit.get("shades_cap", SpellKits.SHADE_CAP)),
			mastery,
			resist,
		]
	if class_id == SpellKits.CLASS_BASTION:
		return "%s %d/%d  Mastery %d  Resist %d" % [
			SpellKits.resource_label("aegis"),
			_resource_current(unit, "aegis"),
			int(unit.get("aegis_cap", SpellKits.AEGIS_CAP)),
			mastery,
			resist,
		]
	var marked := marks_holder(unit, snap)
	return "Marks %s  Impact %s" % [
		engine_pips(int(marked.get("marks", 0)), int(marked.get("marks_cap", SpellKits.MARKS_CAP))),
		engine_pips(int(unit.get("impact", 0)), int(unit.get("impact_cap", SpellKits.IMPACT_CAP))),
	]


func _resource_current(unit: Dictionary, id: String) -> int:
	if unit.has(id):
		return int(unit[id])
	var bag: Variant = unit.get("resources", null)
	if typeof(bag) == TYPE_DICTIONARY and (bag as Dictionary).has(id):
		return int((bag as Dictionary)[id])
	return 0


## Live Shade tokens win over a stale unit.shades field so the card matches the tile.
static func shade_count(unit: Dictionary, snap: Dictionary) -> int:
	if not snap.has("shade_tokens"):
		if unit.has("shades"):
			return int(unit.get("shades", 0))
		var bag: Variant = unit.get("resources", null)
		if typeof(bag) == TYPE_DICTIONARY and (bag as Dictionary).has("shades"):
			return int((bag as Dictionary).get("shades", 0))
		return 0
	var seat := int(unit.get("seat", -1))
	var count := 0
	for token in snap.get("shade_tokens", []):
		if typeof(token) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = token
		if int(rec.get("owner_seat", -1)) == seat and int(rec.get("turns", 0)) > 0:
			count += 1
	return count


func _kit_footer(unit: Dictionary) -> String:
	var class_id := str(unit.get("class_id", ""))
	var names := PackedStringArray()
	for spell_id in unit.get("spells", []):
		names.append(str(spell_id))
	var element := str(unit.get("element", ""))
	if element == "":
		element = SpellKits.element_of(class_id)
	element = element.capitalize()
	if element == "":
		return ", ".join(names)
	if names.is_empty():
		return element
	return element + " · " + ", ".join(names)


func _paint_seat_banner(seat: int, unit: Dictionary) -> void:
	if unit.is_empty() or seat < 0 or seat >= _banner_titles.size():
		return
	var class_id := str(unit.get("class_id", ""))
	if not SpellKits.is_roster_class(class_id):
		return
	var title := _banner_titles[seat]
	var panel := _banner_panels[seat]
	var label := SpellKits.display_name(class_id)
	if label != "":
		title.text = label
	panel.add_theme_stylebox_override("panel", _fighter_frame(false, banner_color(class_id)))


func _sync_empty_kit(chrome: Dictionary, offered: Array) -> void:
	var class_id := str(chrome.get("class_id", ""))
	var empty_slot := (
		not _deploying
		and not chrome.is_empty()
		and SpellKits.is_roster_class(class_id)
		and SpellKits.class_spells(class_id).is_empty()
		and offered.is_empty()
	)
	if _empty_kit_label != null:
		_empty_kit_label.visible = empty_slot
		_empty_kit_label.text = SpellKits.display_name(class_id) if empty_slot else ""
	if _empty_kit_button != null:
		_empty_kit_button.visible = empty_slot
		_empty_kit_button.disabled = true
		_empty_kit_button.text = "—"


func _panel(color: Color) -> StyleBoxFlat:
	return _fighter_frame(false, color)


func _fighter_frame(active: bool, accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = NAVY_ACTIVE if active else NAVY
	box.border_color = GOLD_BRIGHT if active else GOLD
	var edge := 2 if active else 1
	box.set_border_width_all(edge)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	box.content_margin_left = 10
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if accent.a > 0.0:
		box.border_color = GOLD_BRIGHT if active else accent.lerp(GOLD, 0.55)
	return box


func _load_ui_font() -> Font:
	var loaded := load(HUB_FONT) as Font
	return loaded


func _apply_display_font(control: Control) -> void:
	if _ui_font == null or control == null:
		return
	control.add_theme_font_override("font", _ui_font)


func _paint_hp_bar(panel: Panel, unit: Dictionary) -> void:
	var track := panel.get_node_or_null("HpTrack")
	if track == null:
		return
	var fill := track.get_node_or_null("HpFill")
	if not (fill is ColorRect):
		return
	var max_hp := maxi(int(unit.get("max_hp", 1)), 1)
	var hp := clampi(int(unit.get("hp", 0)), 0, max_hp)
	var ratio := float(hp) / float(max_hp)
	var width := float((track as Control).size.x) * ratio
	(fill as ColorRect).size = Vector2(width, (track as Control).size.y)
	(fill as ColorRect).color = Color(0.78, 0.28, 0.2) if ratio <= 0.35 else Color(0.55, 0.72, 0.38)


func _style_chrome_button(button: Button, primary: bool) -> void:
	var fill := Color(0.11, 0.1, 0.08, 0.96) if primary else Color(0.06, 0.07, 0.11, 0.94)
	var border := GOLD_BRIGHT if primary else GOLD
	button.add_theme_stylebox_override("normal", _rect_style(fill, border, 2))
	button.add_theme_stylebox_override("hover", _rect_style(fill.lightened(0.08), GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", _rect_style(fill.darkened(0.08), GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("focus", _rect_style(fill, GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("disabled", _rect_style(Color(0.08, 0.08, 0.1, 0.7), GOLD_DIM, 1))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.42))


func _rect_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _card_panel() -> StyleBoxFlat:
	var box := _fighter_frame(false, GOLD)
	box.bg_color = Color(0.97, 0.94, 0.86, 0.98)
	box.border_color = GOLD
	return box


func _sync_spell_buttons(offered: Array) -> void:
	var offered_ids: Array = []
	for spell_id in offered:
		var id := str(spell_id)
		if id != "" and not offered_ids.has(id):
			offered_ids.append(id)
	var stale: Array = []
	for spell_id in _spell_buttons.keys():
		if not offered_ids.has(spell_id):
			stale.append(spell_id)
	for spell_id in stale:
		var host: Control = _spell_hosts.get(spell_id)
		_spell_buttons.erase(spell_id)
		_spell_hosts.erase(spell_id)
		if is_instance_valid(host):
			var parent := host.get_parent()
			if parent != null:
				parent.remove_child(host)
			host.free()
	var primary := TOUCH.primary_spell_id(offered_ids)
	var arc: Array = []
	for spell_id in offered_ids:
		if spell_id != primary:
			arc.append(spell_id)
	for spell_id in offered_ids:
		var def: Dictionary = SpellKits.spell(spell_id)
		if def.is_empty():
			continue
		if not _spell_buttons.has(spell_id):
			_create_spell_button(spell_id, def)
	_layout_ability_cluster(primary, arc)
	_sync_bottom_inset()


func _create_spell_button(spell_id: String, def: Dictionary) -> void:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_spell_hover(host, spell_id)
	host.gui_input.connect(_on_spell_host_input.bind(spell_id))
	var button := Button.new()
	button.text = _spell_button_text(def)
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_spell_pressed.bind(spell_id))
	button.button_down.connect(_on_spell_button_down.bind(spell_id))
	button.button_up.connect(_on_spell_button_up)
	button.gui_input.connect(_on_spell_host_input.bind(spell_id))
	# Enabled buttons are the hover target; greyed buttons IGNORE so the host still previews.
	_bind_spell_hover(button, spell_id)
	host.add_child(button)
	_bind_ability_icon(button, spell_id, _spell_button_text(def))
	if _ability_cluster != null:
		_ability_cluster.add_child(host)
	_spell_buttons[spell_id] = button
	_spell_hosts[spell_id] = host


func _layout_ability_cluster(primary: String, arc: Array) -> void:
	if _ability_cluster == null:
		return
	var centers: Dictionary = TOUCH.cluster_centers(arc.size())
	var primary_center: Vector2 = centers.get("primary", Vector2.ZERO)
	var arc_centers: Array = centers.get("arc", [])
	if primary != "" and _spell_hosts.has(primary):
		_place_spell_host(primary, primary_center, true)
	for i in arc.size():
		var spell_id := str(arc[i])
		if i < arc_centers.size() and _spell_hosts.has(spell_id):
			_place_spell_host(spell_id, arc_centers[i], false)
	_ability_cluster.visible = primary != "" or not arc.is_empty()


func _place_spell_host(spell_id: String, center: Vector2, primary: bool) -> void:
	var host: Control = _spell_hosts[spell_id]
	var size := TOUCH.cluster_button_size(primary)
	host.custom_minimum_size = size
	host.size = size
	host.position = center - size * 0.5
	host.set_meta("cluster_primary", primary)
	var button: Button = _spell_buttons[spell_id]
	button.add_theme_font_size_override("font_size", 15 if primary else 12)
	button.set_meta("ability_fallback_text", _spell_button_text(SpellKits.spell(spell_id)))
	_apply_circle_style(button, size.x, primary)


func _apply_circle_style(button: Button, diameter: float, primary: bool) -> void:
	var fill := Color(0.42, 0.16, 0.14, 0.96) if primary else Color(0.07, 0.08, 0.12, 0.94)
	var border := GOLD_BRIGHT if primary else GOLD
	button.add_theme_stylebox_override("normal", _circle_style(fill, diameter, border, 3 if primary else 2))
	button.add_theme_stylebox_override("hover", _circle_style(fill.lightened(0.12), diameter, border, 3 if primary else 2))
	button.add_theme_stylebox_override("pressed", _circle_style(fill.darkened(0.1), diameter, Color(0.98, 0.84, 0.4), 4))
	button.add_theme_stylebox_override("focus", _circle_style(fill, diameter, border, 3 if primary else 2))
	button.add_theme_stylebox_override("disabled", _circle_style(Color(0.28, 0.28, 0.32, 0.78), diameter, Color(1, 1, 1, 0.12), 2))
	_sync_ability_icon(button)


func _circle_style(fill: Color, diameter: float, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	var radius := int(round(diameter * 0.5))
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _sync_bottom_inset() -> void:
	if _bottom_box == null:
		return
	var cluster_open := _ability_cluster != null and _ability_cluster.visible
	_bottom_box.offset_right = -(TOUCH.CLUSTER_SIZE.x + 12.0) if cluster_open else -16.0


func _spell_button_text(def: Dictionary) -> String:
	if def.is_empty():
		return ""
	var ap := int(def.get("ap", 0))
	var mp := int(def.get("mp", 0))
	if mp > 0:
		return "%s\n%d AP\n%d MP" % [str(def.get("name", "")), ap, mp]
	return "%s\n%d AP" % [str(def.get("name", "")), ap]


## Disabled buttons still hover via the host: ignore their mouse so the wrapper receives it.
func _set_spell_button_clickable(button: Button, clickable: bool) -> void:
	button.disabled = not clickable
	button.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	_sync_ability_icon(button)


## res://art/ui/mobile/abilities/<spell_id>_icon.png and _icon_disabled.png.
static func _ability_icon_path(spell_id: String, disabled: bool) -> String:
	return "res://art/ui/mobile/abilities/%s_icon%s.png" % [spell_id, "_disabled" if disabled else ""]


func _bind_ability_icon(button: Button, spell_id: String, fallback_text: String) -> void:
	button.set_meta("ability_spell_id", spell_id)
	button.set_meta("ability_fallback_text", fallback_text)
	_ensure_ability_icon(button)
	_sync_ability_icon(button)


func _ensure_ability_icon(button: Button) -> TextureRect:
	var existing := button.get_node_or_null("AbilityIcon")
	if existing is TextureRect:
		return existing as TextureRect
	var icon := TextureRect.new()
	icon.name = "AbilityIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	# No EXPAND_FIT in Godot 4.7. Ignore Size fills the circle; Keep Aspect Centered fits the stub.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	button.add_child(icon)
	return icon


func _load_ability_texture(spell_id: String, disabled: bool) -> Texture2D:
	var path := _ability_icon_path(spell_id, disabled)
	if path == "":
		return null
	if _ability_textures.has(path):
		var cached: Variant = _ability_textures[path]
		return cached as Texture2D if cached is Texture2D else null
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res as Texture2D
	_ability_textures[path] = tex
	return tex


## Disabled / illegal uses the _disabled stub. If that file is missing, keep the
## enabled texture and let the button modulate grey it.
func _ability_texture_for_state(spell_id: String, disabled: bool) -> Texture2D:
	if disabled:
		var off := _load_ability_texture(spell_id, true)
		if off != null:
			return off
	return _load_ability_texture(spell_id, false)


func _sync_ability_icon(button: Button) -> void:
	if button == null or not is_instance_valid(button) or not button.has_meta("ability_spell_id"):
		return
	var spell_id := str(button.get_meta("ability_spell_id"))
	var fallback := str(button.get_meta("ability_fallback_text", ""))
	var icon := _ensure_ability_icon(button)
	var tex := _ability_texture_for_state(spell_id, button.disabled)
	if tex == null:
		icon.texture = null
		icon.visible = false
		button.text = fallback
		return
	icon.texture = tex
	icon.visible = true
	button.text = ""


func _on_walk_pressed() -> void:
	select_walk()


func _on_spell_button_down(spell_id: String) -> void:
	_begin_long_press(spell_id)
	_arm_spell_from_press(spell_id)


func _on_spell_button_up() -> void:
	_finish_touch_tooltip()
	# pressed() runs in this same release when the finger is still on the button.
	# A drag-off never emits pressed, so drop the toggle lock after that.
	_press_release_token += 1
	var token := _press_release_token
	if is_inside_tree():
		_clear_press_lock.call_deferred(token)


func _clear_press_lock(token: int) -> void:
	if token != _press_release_token:
		return
	_suppress_toggle_spell = ""
	_press_gesture_armed = ""


func _arm_spell_from_press(spell_id: String) -> void:
	if not _spell_buttons.has(spell_id):
		return
	# Locked: Ambush arms only when legal_intents already has the cast.
	if spell_id == SpellKits.AMBUSH and not legal_cast_ids(_last_legal).has(SpellKits.AMBUSH):
		return
	var button: Button = _spell_buttons[spell_id]
	if button.disabled:
		return
	if _press_gesture_armed == spell_id:
		return
	if _selected_spell == spell_id:
		_press_gesture_armed = ""
		return
	_press_gesture_armed = spell_id
	_suppress_toggle_spell = spell_id
	_selected_spell = spell_id
	_refresh_spell_buttons()
	_update_selected_label()
	spell_selected.emit(_selected_spell)


func _on_spell_pressed(spell_id: String) -> void:
	if not _spell_buttons.has(spell_id):
		return
	if spell_id == SpellKits.AMBUSH and not legal_cast_ids(_last_legal).has(SpellKits.AMBUSH):
		return
	if _suppress_toggle_spell == spell_id:
		_suppress_toggle_spell = ""
		_press_gesture_armed = ""
		_press_release_token += 1
		return
	_press_gesture_armed = ""
	if _selected_spell == spell_id:
		select_walk()
		return
	_selected_spell = spell_id
	_refresh_spell_buttons()
	_update_selected_label()
	spell_selected.emit(_selected_spell)


func _on_face_pressed(dir: String) -> void:
	face_requested.emit(dir)


func _refresh_spell_buttons() -> void:
	_drop_illegal_ambush_selection()
	_refresh_walk_button()
	var legal_spells := legal_cast_ids(_last_legal)
	var match_over := bool(_last_snap.get("match_over", false))
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		var can_submit: bool = legal_spells.has(spell_id) and not match_over and not _stunned and not _deploying and is_local_turn(_last_snap)
		_set_spell_button_clickable(button, can_submit)
		_apply_spell_modulate(str(spell_id), button, can_submit)


## Ambush gold / shade highlight only while the cast is in legal_intents.
## Otherwise the button stays soft-grey, including after another spell is tapped.
func _apply_spell_modulate(spell_id: String, button: Button, can_submit: bool) -> void:
	if _stunned:
		button.modulate = STUN_GREY
		return
	if spell_id == SpellKits.AMBUSH and not legal_cast_ids(_last_legal).has(SpellKits.AMBUSH):
		button.modulate = AMBUSH_DISARMED_MODULATE
		return
	if _selected_spell == spell_id:
		button.modulate = Color(1.15, 1.1, 0.7)
		return
	if spell_id == SpellKits.AMBUSH and can_submit:
		button.modulate = AMBUSH_SHADE_MODULATE
		return
	if can_submit:
		button.modulate = Color(1, 1, 1, 1)
		return
	button.modulate = Color(1, 1, 1, 0.72)


func _drop_illegal_ambush_selection() -> void:
	if _selected_spell != SpellKits.AMBUSH:
		return
	if legal_cast_ids(_last_legal).has(SpellKits.AMBUSH):
		return
	_selected_spell = ""
	_aim_hit_chance = -1
	_press_gesture_armed = ""
	_suppress_toggle_spell = ""
	if _aim_hit_label != null:
		_aim_hit_label.text = ""
		_aim_hit_label.visible = false


func _refresh_walk_button() -> void:
	if _walk_button == null:
		return
	var waiting := snap_local_seat(_last_snap) >= 0 and not is_local_turn(_last_snap)
	if _stunned or _deploying or waiting:
		_walk_button.modulate = STUN_GREY
	elif _selected_spell == "":
		_walk_button.modulate = Color(1.15, 1.1, 0.7)
	else:
		_walk_button.modulate = Color.WHITE


func _update_selected_label() -> void:
	if _selected_label == null:
		return
	if _deploying:
		_selected_label.text = "Place on your deploy zone  ·  Ready when placed"
		return
	if snap_local_seat(_last_snap) >= 0 and not is_local_turn(_last_snap):
		_selected_label.text = "Opponent's turn — watching"
		return
	if _stunned:
		_selected_label.text = "Stunned — turn auto-ends"
		return
	if _selected_spell == "":
		_selected_label.text = _with_shade_tip("Selected: Walk  ·  tap a destination  ·  Face pad turns")
		return
	var def: Dictionary = SpellKits.spell(_selected_spell)
	var text := "Selected: %s  ·  %d AP / %d MP  ·  %s" % [
		def.get("name", _selected_spell),
		int(def.get("ap", 0)),
		int(def.get("mp", 0)),
		SpellKits.range_text(def),
	]
	if bool(def.get("rolls", false)) and _aim_hit_chance >= 0:
		text += "  ·  %s" % aim_hit_caption(_aim_hit_chance)
	text += "  ·  tap a cell  ·  Walk / Esc to cancel"
	_selected_label.text = _with_shade_tip(text)


func _with_shade_tip(text: String) -> String:
	# A live Shade, or a forced selection, is not the cue. The tip appears
	# only when legal_intents already contains an Ambush cast.
	if not legal_cast_ids(_last_legal).has(SpellKits.AMBUSH):
		return text
	return "%s  ·  %s" % [text, AMBUSH_SHADE_TIP]


func show_spell_tooltip(spell_id: String) -> void:
	var preview := preview_for_spell(spell_id)
	var text := SpellTooltip.card_text(preview)
	if text == "" or _tooltip_panel == null or _tooltip_label == null:
		hide_spell_tooltip()
		return
	_tooltip_spell = spell_id
	_tooltip_label.text = text
	_tooltip_panel.visible = true


func preview_for_spell(spell_id: String) -> Dictionary:
	var sim := _preview_sim()
	if sim == null or spell_id == "":
		return {}
	var args := _preview_dest_args(spell_id)
	return sim.preview_cast(spell_id, args["from"], args["to"], int(args["target_seat"]))


func _preview_sim() -> Node:
	if _preview_source != null and is_instance_valid(_preview_source):
		return _preview_source
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.get_node_or_null("CombatSim")
	return null


func _preview_dest_args(spell_id: String) -> Dictionary:
	var units: Array = _last_snap.get("units", [])
	var seat := kit_seat(_last_snap)
	var actor := _unit(units, seat)
	var enemy := _unit(units, 1 - seat)
	var from: Vector2i = _as_cell(actor.get("pos", Vector2i.ZERO))
	if spell_id == SpellKits.ADVANCE:
		return {
			"from": from,
			"to": _advance_hover_dest(from),
			"target_seat": -1,
		}
	var to: Vector2i = _as_cell(enemy.get("pos", from))
	return {
		"from": from,
		"to": to,
		"target_seat": int(enemy.get("seat", -1)),
	}


## Hover sample is a sim-legal Advance dest. No client neighbor scan.
func _advance_hover_dest(from: Vector2i) -> Vector2i:
	var dests: Array[Vector2i] = SNAPSHOT_TILES.cast_dests(_last_legal, SpellKits.ADVANCE)
	if dests.is_empty():
		return from
	return dests[0]


func _as_cell(value: Variant) -> Vector2i:
	if value == null:
		return Vector2i(-1, -1)
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func hide_spell_tooltip() -> void:
	_tooltip_spell = ""
	_tooltip_pinned = false
	_cancel_long_press()
	if _tooltip_panel != null:
		_tooltip_panel.visible = false
	if _tooltip_label != null:
		_tooltip_label.text = ""


func tooltip_visible() -> bool:
	return _tooltip_panel != null and _tooltip_panel.visible


func tooltip_caption() -> String:
	if _tooltip_label == null or not tooltip_visible():
		return ""
	return _tooltip_label.text


func tooltip_pinned() -> bool:
	return _tooltip_pinned


## Board touch dismisses a card that was opened by a finger, not a mouse hover.
func dismiss_pinned_tooltip() -> void:
	if _tooltip_pinned:
		hide_spell_tooltip()


func _bind_spell_hover(control: Control, spell_id: String) -> void:
	control.mouse_entered.connect(_on_spell_hover.bind(spell_id))
	control.mouse_exited.connect(_on_spell_unhover)


func _on_spell_hover(spell_id: String) -> void:
	if _hover_suppressed:
		return
	show_spell_tooltip(spell_id)


func _on_spell_unhover() -> void:
	# A touch card stays until Walk, a cell tap, or another explicit dismiss.
	if _tooltip_pinned:
		return
	hide_spell_tooltip()


func claims_screen_point(point: Vector2) -> bool:
	if not is_inside_tree():
		return false
	for spell_id in _spell_hosts.keys():
		if _control_claims(_spell_hosts[spell_id], point):
			return true
	if _control_claims(_walk_button, point):
		return true
	if _control_claims(_end_turn_button, point):
		return true
	if _control_claims(_new_match_button, point):
		return true
	if _control_claims(_ready_p1_button, point):
		return true
	if _control_claims(_ready_p2_button, point):
		return true
	for button in _face_buttons.values():
		if _control_claims(button, point):
			return true
	return false


func _control_claims(control: Control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control) or not control.visible:
		return false
	if not control.is_inside_tree():
		return false
	return control.get_global_rect().has_point(point)


func _on_spell_host_input(event: InputEvent, spell_id: String) -> void:
	if TOUCH.is_emulated_mouse(event):
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var screen_pos := TOUCH.pointer_position(event)
		var committing := TOUCH.is_touch_release(event)
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.index != 0:
				return
			if touch.pressed:
				# Tap arms only. The card waits for the long-press timer.
				hide_spell_tooltip()
				_hover_suppressed = true
				_arm_spell_from_press(spell_id)
				_begin_long_press(spell_id, true)
			else:
				_on_spell_button_up()
		elif (event as InputEventScreenDrag).index != 0:
			return
		else:
			_drop_hold_if_finger_left(spell_id, screen_pos)
		if _selected_spell != "":
			aim_dragged.emit(screen_pos, committing)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_long_press(spell_id)
		else:
			_cancel_long_press()


func _begin_long_press(spell_id: String, from_touch: bool = false) -> void:
	# Emulated mouse button_down follows the finger and must not reset the hold.
	if _long_press_spell == spell_id and _long_press_touch and not from_touch:
		return
	_long_press_spell = spell_id
	_long_press_touch = from_touch
	_long_press_elapsed = 0.0
	set_process(true)


func _cancel_long_press() -> void:
	_long_press_spell = ""
	_long_press_touch = false
	_long_press_elapsed = 0.0
	set_process(false)


## Finger up. Drops a hold card. Mouse hover cards stay unpinned.
func _finish_touch_tooltip() -> void:
	var dismiss_hold_card := _tooltip_pinned
	_cancel_long_press()
	_hover_suppressed = false
	if dismiss_hold_card:
		hide_spell_tooltip()


## A drag off the circle is aim, not a hold. Keep the card off the board.
func _drop_hold_if_finger_left(spell_id: String, screen_pos: Vector2) -> void:
	var host: Control = _spell_hosts.get(spell_id)
	if host == null or not is_instance_valid(host) or not host.visible:
		return
	if host.get_global_rect().has_point(screen_pos):
		return
	_cancel_long_press()
	if _tooltip_pinned:
		hide_spell_tooltip()


func show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = text != ""
	_toast_token += 1
	var token := _toast_token
	if text == "" or not is_inside_tree():
		return
	await get_tree().create_timer(TOAST_SEC).timeout
	if not is_instance_valid(self) or _toast_label == null:
		return
	if token == _toast_token:
		_toast_label.visible = false


func toast_caption() -> String:
	if _toast_label == null or not _toast_label.visible:
		return ""
	return _toast_label.text


func stun_badge_visible() -> bool:
	return _stun_badge != null and _stun_badge.visible


func set_deploy_note(text: String) -> void:
	_deploy_note = text
	if _coach_label != null and text != "":
		_coach_label.text = text


func clear_deploy_note() -> void:
	_deploy_note = ""


func _sync_deploy_chrome(snap: Dictionary) -> void:
	var deploying := is_deployment_phase(snap)
	var ready: Dictionary = snap.get("ready", {})
	var local_seat := snap_local_seat(snap)
	if _ready_p1_button != null:
		_ready_p1_button.visible = deploying and (local_seat < 0 or local_seat == 0)
		_ready_p1_button.disabled = not can_ready_from_snap(snap, 0)
		_ready_p1_button.text = "P1 ready" if bool(ready.get(0, false)) else "Ready P1"
	if _ready_p2_button != null:
		_ready_p2_button.visible = deploying and (local_seat < 0 or local_seat == 1)
		_ready_p2_button.disabled = not can_ready_from_snap(snap, 1)
		_ready_p2_button.text = "P2 ready" if bool(ready.get(1, false)) else "Ready P2"
	if _clock_row != null:
		_clock_row.visible = not deploying
	if _clock_label != null:
		_clock_label.visible = not deploying
	if _clock_bar != null:
		_clock_bar.visible = not deploying
	if _walk_button != null:
		_walk_button.visible = not deploying
	if _end_turn_button != null:
		_end_turn_button.visible = not deploying
	if _face_bar != null:
		_face_bar.visible = not deploying
	for button in _face_buttons.values():
		(button as Button).visible = not deploying
	if _ability_cluster != null and deploying:
		_ability_cluster.visible = false
	_sync_bottom_inset()


func deploy_chrome_visible() -> bool:
	return _ready_p1_button != null and _ready_p1_button.visible


func ready_p1_enabled() -> bool:
	return _ready_p1_button != null and _ready_p1_button.visible and not _ready_p1_button.disabled


func ready_p2_enabled() -> bool:
	return _ready_p2_button != null and _ready_p2_button.visible and not _ready_p2_button.disabled


func clock_visible() -> bool:
	return _clock_row != null and _clock_row.visible


func walk_suppressed() -> bool:
	return _walk_button != null and _walk_button.disabled


func end_turn_enabled() -> bool:
	return _end_turn_button != null and not _end_turn_button.disabled


func face_suppressed() -> bool:
	for button in _face_buttons.values():
		if not (button as Button).disabled:
			return false
	return not _face_buttons.is_empty()


func spells_suppressed() -> bool:
	if _spell_buttons.is_empty():
		return false
	for button in _spell_buttons.values():
		if not (button as Button).disabled:
			return false
	return true


func _net_prefix(snap: Dictionary) -> String:
	var seat := snap_local_seat(snap)
	if seat == 0:
		return "HOST · "
	if seat == 1:
		return "GUEST · "
	return ""


func _apply_turn_label_clock() -> void:
	if _turn_label == null or _turn_label_base == "":
		return
	if _deploying or _turn_label_base.begins_with("Match over"):
		_turn_label.text = _turn_label_base
		return
	_turn_label.text = "%s  ·  %ds" % [_turn_label_base, _clock_seconds]


func _sync_stun_badge(active: Dictionary, _units: Array, match_over: bool) -> void:
	if _stun_badge == null:
		return
	var stun_visible := (not match_over) and unit_is_stunned(active)
	_stun_badge.visible = stun_visible
	if stun_visible:
		_stun_badge.text = "STUN"
