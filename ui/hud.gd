extends CanvasLayer
class_name CombatHUD

signal spell_selected(spell_id: String)
signal face_requested(dir: String)
signal end_turn_requested
signal new_match_requested
signal ready_requested(seat: int)

const KESTREL_GREEN := Color("#2E5A3C")
const IRONJAW_RED := Color("#8B2E2E")
const STUN_GREY := Color(0.58, 0.58, 0.62, 0.82)
const PUSH_BLOCKED_TOAST := "PushBlocked"
const BOUNCE_TOAST := "Bounce"
## Lava forced-push lands and applies Burn. Not a Bounce toast.
const LAVA_BURN_TOAST := "Lava - Burn"
const TOAST_SEC := 1.4
const TERRAIN_LEGEND := "G Ground 1    M Mud 2    W Water 2    L Lava    ·    tile labels = terrain + elevation    ·    z-sort is view-only"
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")

var _selected_spell: String = ""
var _spell_buttons: Dictionary = {}
var _face_buttons: Dictionary = {}
var _face_bar: HBoxContainer
var _action_bar: FlowContainer
var _kestrel_body: RichTextLabel
var _ironjaw_body: RichTextLabel
var _seat_panels: Array[Panel] = []
var _seat_titles: Array[Label] = []
var _turn_label: Label
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
var _aim_hit_chance: int = -1
var _stunned: bool = false
var _stun_badge: Label
var _toast_label: Label
var _toast_token: int = 0
var _spell_hosts: Dictionary = {}
var _tooltip_panel: Panel
var _tooltip_label: Label
var _tooltip_spell: String = ""
var _long_press_spell: String = ""
var _long_press_elapsed: float = 0.0
var _last_snap: Dictionary = {}
var _last_legal: Array = []
var _preview_source: Node = null
var _terrain_legend: Label
var _turn_label_base: String = ""


## Kit chrome uses local_seat when NetSession set it; hot-seat (local_seat < 0)
## falls back to active_seat. Snapshot does not encode "show active kit".
## Also reads net.local_seat / net.active_seat when the top-level keys are absent.
## Advance is never offered unless class_id is ironjaw.
## legal_intents cannot add a spell the kit does not own; enablement uses legal_cast_ids().
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


static func is_local_turn(snap: Dictionary) -> bool:
	var local_seat := snap_local_seat(snap)
	if local_seat < 0:
		return true
	return local_seat == snap_active_seat(snap)


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
	for spell_id in active.get("spells", []):
		var id := str(spell_id)
		if id == "":
			continue
		if id == SpellKits.ADVANCE and class_id != SpellKits.CLASS_IRONJAW:
			continue
		if id == SpellKits.DETONATE and class_id != SpellKits.CLASS_KESTREL:
			continue
		if (id == SpellKits.SHOULDER or id == SpellKits.CRUSH) and class_id != SpellKits.CLASS_IRONJAW:
			continue
		if not SpellKits.has_spell(class_id, id):
			continue
		if not offered.has(id):
			offered.append(id)
	return offered


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
		show_spell_tooltip(_long_press_spell)
		_cancel_long_press()


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
	if class_id == SpellKits.CLASS_KESTREL:
		return KESTREL_GREEN
	if class_id == SpellKits.CLASS_IRONJAW:
		return IRONJAW_RED
	# Chrome only. Not a kit stat. Open kits share one neutral panel.
	return Color("#3a3a3a")


func show_turn_banner(unit_name: String, class_id: String, caption: String = "") -> void:
	_handoff_label.text = caption if caption != "" else "%s's turn" % unit_name
	var fill := _banner_color(class_id)
	_handoff_panel.add_theme_stylebox_override("panel", _panel(fill))
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
	var color := Color(0.15, 0.12, 0.12)
	if not running:
		color = Color(0.42, 0.4, 0.42)
	elif seconds_left <= 5:
		color = Color(0.78, 0.12, 0.12)
	elif seconds_left <= 10:
		color = Color(0.72, 0.4, 0.08)
	_clock_label.add_theme_color_override("font_color", color)
	if _clock_bar == null:
		return
	var width := _clock_bar_max_width * clampf(fraction, 0.0, 1.0)
	_clock_bar.custom_minimum_size = Vector2(width, 8)
	_clock_bar.size = Vector2(width, 8)
	if not running:
		_clock_bar.color = Color(0.7, 0.7, 0.74)
	elif seconds_left <= 5:
		_clock_bar.color = Color(0.82, 0.28, 0.28)
	elif seconds_left <= 10:
		_clock_bar.color = Color(0.92, 0.68, 0.28)
	else:
		_clock_bar.color = Color(0.35, 0.7, 0.55)
	_apply_turn_label_clock()


func set_preview_source(sim: Node) -> void:
	_preview_source = sim


func render(snap: Dictionary, legal: Array) -> void:
	_last_snap = snap
	_last_legal = legal.duplicate()
	_deploying = is_deployment_phase(snap)
	var units: Array = snap.get("units", [])
	var kestrel := _unit(units, 0)
	var ironjaw := _unit(units, 1)
	var active_seat := snap_active_seat(snap)
	_apply_seat_banner(0, kestrel)
	_apply_seat_banner(1, ironjaw)
	_kestrel_body.text = _unit_card_text(kestrel, active_seat == 0, snap)
	_ironjaw_body.text = _unit_card_text(ironjaw, active_seat == 1, snap)

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

	_render_pips(_ap_pips, int(active.get("ap", 0)), int(active.get("max_ap", 6)), Color(0.95, 0.78, 0.28))
	_render_pips(_mp_pips, int(active.get("mp", 0)), int(active.get("max_mp", 3)), Color(0.45, 0.75, 0.95))
	if _deploy_note != "" and _deploying:
		_coach_label.text = _deploy_note
	else:
		_coach_label.text = str(snap.get("coach", ""))

	var offered: Array = [] if _deploying else offered_cast_ids(chrome, legal)
	_sync_spell_buttons(offered)
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
		if _selected_spell == spell_id:
			button.modulate = Color(1.15, 1.1, 0.7)
		elif can_submit:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = STUN_GREY if _stunned else Color(1, 1, 1, 0.72)
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
	if _end_turn_button != null:
		# Locked Stun (A′): End Turn stays as a fallback; CombatSim auto-skips.
		# Deploy: End Turn stays off until both Ready leave DEPLOYMENT.
		# Online: only the owner of active_seat can End Turn.
		_end_turn_button.disabled = block or not_your_turn
		_end_turn_button.modulate = Color.WHITE
	if _new_match_button != null:
		_new_match_button.disabled = _locked
		_new_match_button.visible = _show_new_match(_last_snap)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	root.add_child(_make_banner(true))
	root.add_child(_make_banner(false))

	_turn_label = Label.new()
	_turn_label.position = Vector2(280, 12)
	_turn_label.size = Vector2(400, 28)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 18)
	_turn_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	root.add_child(_turn_label)

	_terrain_legend = Label.new()
	_terrain_legend.text = TERRAIN_LEGEND
	_terrain_legend.position = Vector2(16, 122)
	_terrain_legend.size = Vector2(928, 20)
	_terrain_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terrain_legend.add_theme_font_size_override("font_size", 11)
	_terrain_legend.add_theme_color_override("font_color", Color(0.22, 0.18, 0.16))
	root.add_child(_terrain_legend)

	_stun_badge = Label.new()
	_stun_badge.text = "STUN"
	_stun_badge.position = Vector2(430, 120)
	_stun_badge.size = Vector2(100, 22)
	_stun_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_badge.add_theme_font_size_override("font_size", 14)
	_stun_badge.add_theme_color_override("font_color", Color(0.18, 0.1, 0.04))
	_stun_badge.add_theme_color_override("font_outline_color", Color(0.98, 0.82, 0.28))
	_stun_badge.add_theme_constant_override("outline_size", 6)
	_stun_badge.visible = false
	root.add_child(_stun_badge)

	var resource_panel := Panel.new()
	resource_panel.position = Vector2(300, 44)
	resource_panel.size = Vector2(360, 74)
	resource_panel.add_theme_stylebox_override("panel", _panel(Color(1, 1, 1, 0.78)))
	root.add_child(resource_panel)
	var res_box := VBoxContainer.new()
	res_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	res_box.add_theme_constant_override("separation", 4)
	resource_panel.add_child(res_box)
	_ap_pips = _make_pip_row("AP")
	_mp_pips = _make_pip_row("MP")
	res_box.add_child(_ap_pips)
	res_box.add_child(_mp_pips)
	res_box.add_child(_make_clock_row())

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -8
	bottom.offset_top = -232
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	var face_bar := HBoxContainer.new()
	_face_bar = face_bar
	face_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	face_bar.add_theme_constant_override("separation", 8)
	face_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(face_bar)
	var face_caption := Label.new()
	face_caption.text = "Face"
	face_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
			spacer.custom_minimum_size = Vector2(36, 28)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face_pad.add_child(spacer)
			continue
		var button := Button.new()
		button.text = dir
		button.custom_minimum_size = Vector2(36, 28)
		button.pressed.connect(_on_face_pressed.bind(dir))
		face_pad.add_child(button)
		_face_buttons[dir] = button

	_aim_hit_label = Label.new()
	_aim_hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_hit_label.add_theme_font_size_override("font_size", 20)
	_aim_hit_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.16))
	_aim_hit_label.visible = false
	bottom.add_child(_aim_hit_label)

	_selected_label = Label.new()
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	bottom.add_child(_selected_label)

	_action_bar = FlowContainer.new()
	_action_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	_action_bar.custom_minimum_size = Vector2(0, 72)
	_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_bar.add_theme_constant_override("h_separation", 6)
	_action_bar.add_theme_constant_override("v_separation", 6)
	bottom.add_child(_action_bar)

	_walk_button = Button.new()
	_walk_button.text = "Walk"
	_walk_button.custom_minimum_size = Vector2(88, 32)
	_walk_button.clip_text = true
	_walk_button.pressed.connect(_on_walk_pressed)
	_action_bar.add_child(_walk_button)

	_ready_p1_button = Button.new()
	_ready_p1_button.text = "Ready P1"
	_ready_p1_button.custom_minimum_size = Vector2(100, 32)
	_ready_p1_button.clip_text = true
	_ready_p1_button.pressed.connect(func() -> void: ready_requested.emit(0))
	_action_bar.add_child(_ready_p1_button)

	_ready_p2_button = Button.new()
	_ready_p2_button.text = "Ready P2"
	_ready_p2_button.custom_minimum_size = Vector2(100, 32)
	_ready_p2_button.clip_text = true
	_ready_p2_button.pressed.connect(func() -> void: ready_requested.emit(1))
	_action_bar.add_child(_ready_p2_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(112, 32)
	_end_turn_button.clip_text = true
	_end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	_action_bar.add_child(_end_turn_button)

	_new_match_button = Button.new()
	_new_match_button.text = "New Match"
	_new_match_button.custom_minimum_size = Vector2(112, 32)
	_new_match_button.clip_text = true
	_new_match_button.pressed.connect(func() -> void: new_match_requested.emit())
	_action_bar.add_child(_new_match_button)

	_coach_label = Label.new()
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.add_theme_font_size_override("font_size", 15)
	_coach_label.add_theme_color_override("font_color", Color(0.14, 0.1, 0.12))
	bottom.add_child(_coach_label)

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
	_tooltip_panel.position = Vector2(240, 348)
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

	_handoff_overlay = ColorRect.new()
	_handoff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_overlay.color = Color(0.06, 0.05, 0.07, 0.42)
	_handoff_overlay.visible = false
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_handoff_overlay)

	_handoff_panel = Panel.new()
	_handoff_panel.position = Vector2(230, 268)
	_handoff_panel.size = Vector2(500, 140)
	_handoff_panel.add_theme_stylebox_override("panel", _panel(KESTREL_GREEN))
	_handoff_overlay.add_child(_handoff_panel)

	_handoff_label = Label.new()
	_handoff_label.position = Vector2(16, 28)
	_handoff_label.size = Vector2(468, 84)
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_handoff_label.add_theme_font_size_override("font_size", 36)
	_handoff_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_handoff_label.text = "Kestrel's turn"
	_handoff_panel.add_child(_handoff_label)

	_update_selected_label()


func _show_new_match(snap: Dictionary) -> bool:
	var seat := snap_local_seat(snap)
	if seat < 0:
		return true
	var net := _net_dict(snap)
	if str(net.get("mode", "")) == "host":
		return true
	return bool(net.get("dedicated", false)) and seat == 0


func _apply_seat_banner(seat: int, unit: Dictionary) -> void:
	if seat < 0 or seat >= _seat_titles.size():
		return
	var class_id := str(unit.get("class_id", ""))
	var unit_name := str(unit.get("name", ""))
	if unit_name == "":
		unit_name = SpellKits.display_name(class_id)
	if unit_name == "":
		unit_name = "Seat %d" % seat
	_seat_titles[seat].text = unit_name
	if seat >= _seat_panels.size():
		return
	var color := _banner_color(class_id)
	_seat_panels[seat].add_theme_stylebox_override("panel", _panel(color))


func _make_banner(is_kestrel: bool) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(16, 12) if is_kestrel else Vector2(704, 12)
	panel.size = Vector2(240, 132)
	var color := KESTREL_GREEN if is_kestrel else IRONJAW_RED
	panel.add_theme_stylebox_override("panel", _panel(color))
	var title := Label.new()
	title.text = "Kestrel" if is_kestrel else "Ironjaw"
	_seat_panels.append(panel)
	_seat_titles.append(title)
	title.position = Vector2(12, 6)
	title.size = Vector2(216, 22)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(title)
	var body := RichTextLabel.new()
	body.position = Vector2(10, 30)
	body.size = Vector2(220, 96)
	body.bbcode_enabled = true
	body.scroll_active = false
	body.fit_content = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
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
	caption.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	row.add_child(caption)
	_clock_label = Label.new()
	_clock_label.text = "%ds" % int(TurnClock.DURATION_SEC)
	_clock_label.custom_minimum_size = Vector2(36, 18)
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	row.add_child(_clock_label)
	_clock_bar = ColorRect.new()
	_clock_bar.custom_minimum_size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.color = Color(0.35, 0.7, 0.55)
	row.add_child(_clock_bar)
	return row


func _render_pips(row: HBoxContainer, current: int, maximum: int, fill: Color) -> void:
	while row.get_child_count() > 1:
		var child := row.get_child(row.get_child_count() - 1)
		row.remove_child(child)
		child.free()
	for i in range(maximum):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 12)
		pip.color = fill if i < current else Color(0.75, 0.75, 0.78)
		row.add_child(pip)


func _unit_card_text(unit: Dictionary, active: bool, snap: Dictionary = {}) -> String:
	if unit.is_empty():
		return "[color=#ffffff]—[/color]"
	var status := "ACTIVE" if active and unit["alive"] else ("DOWN" if not unit["alive"] else "waiting")
	if is_deployment_phase(snap):
		var ready: Dictionary = snap.get("ready", {})
		if bool(ready.get(int(unit.get("seat", -1)), false)) or bool(unit.get("locked", false)):
			status = "READY"
		elif bool(unit.get("placed", false)):
			status = "placed"
		else:
			status = "open"
	# Locked Stun (A′): STUN badge on the unit card while remaining or stunned-this-turn.
	var stun_note := ""
	if unit_is_stunned(unit):
		stun_note = "  [b]STUN[/b]"
	# Director Locked Burn: duration left is the snapshot field host replicas already carry.
	var burn_note := ""
	if unit_is_burning(unit):
		burn_note = "  [b]BURN[/b] %d" % unit_burn_remaining(unit)
	return "[color=#ffffff]%s  HP %d/%d%s%s\nAP %d  MP %d  Face %s\nMarks %s  Impact %s\n%s[/color]" % [
		status,
		int(unit["hp"]),
		int(unit["max_hp"]),
		stun_note,
		burn_note,
		int(unit["ap"]),
		int(unit["mp"]),
		str(unit["facing"]),
		engine_pips(int(unit["marks"]), int(unit["marks_cap"])),
		engine_pips(int(unit["impact"]), int(unit["impact_cap"])),
		str(unit["element"]).capitalize() + " · " + ", ".join(PackedStringArray(unit["spells"])),
	]


func _unit(units: Array, seat: int) -> Dictionary:
	for unit in units:
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


func _panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _card_panel() -> StyleBoxFlat:
	var box := _panel(Color(0.99, 0.97, 0.9, 0.97))
	box.border_color = Color(0.18, 0.12, 0.1, 0.85)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
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
			_action_bar.remove_child(host)
			host.free()
	var insert_idx := 0
	if _walk_button != null and _walk_button.get_parent() == _action_bar:
		insert_idx = _walk_button.get_index() + 1
	for spell_id in offered_ids:
		var def: Dictionary = SpellKits.spell(spell_id)
		if def.is_empty():
			continue
		if not _spell_buttons.has(spell_id):
			var host := Control.new()
			host.custom_minimum_size = Vector2(152, 32)
			host.mouse_filter = Control.MOUSE_FILTER_STOP
			_bind_spell_hover(host, spell_id)
			host.gui_input.connect(_on_spell_host_input.bind(spell_id))
			var button := Button.new()
			button.text = _spell_button_text(def)
			button.clip_text = true
			button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.pressed.connect(_on_spell_pressed.bind(spell_id))
			button.button_down.connect(_begin_long_press.bind(spell_id))
			button.button_up.connect(_cancel_long_press)
			# Enabled buttons are the hover target; greyed buttons IGNORE so the host still previews.
			_bind_spell_hover(button, spell_id)
			host.add_child(button)
			_action_bar.add_child(host)
			_spell_buttons[spell_id] = button
			_spell_hosts[spell_id] = host
		_action_bar.move_child(_spell_hosts[spell_id], insert_idx)
		insert_idx += 1


func _spell_button_text(def: Dictionary) -> String:
	return "%s  %dAP/%dMP" % [def["name"], int(def.get("ap", 0)), int(def.get("mp", 0))]


## Disabled buttons still hover via the host: ignore their mouse so the wrapper receives it.
func _set_spell_button_clickable(button: Button, clickable: bool) -> void:
	button.disabled = not clickable
	button.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE


func _on_walk_pressed() -> void:
	select_walk()


func _on_spell_pressed(spell_id: String) -> void:
	if not _spell_buttons.has(spell_id):
		return
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
	_refresh_walk_button()
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		if _selected_spell == spell_id:
			button.modulate = Color(1.15, 1.1, 0.7)
		else:
			button.modulate = Color.WHITE


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
		_selected_label.text = "Selected: Walk  ·  click a destination  ·  right-click to face"
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
	text += "  ·  Walk / Esc to cancel"
	_selected_label.text = text


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
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func hide_spell_tooltip() -> void:
	_tooltip_spell = ""
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


func _bind_spell_hover(control: Control, spell_id: String) -> void:
	control.mouse_entered.connect(_on_spell_hover.bind(spell_id))
	control.mouse_exited.connect(_on_spell_unhover)


func _on_spell_hover(spell_id: String) -> void:
	show_spell_tooltip(spell_id)


func _on_spell_unhover() -> void:
	hide_spell_tooltip()


func _on_spell_host_input(event: InputEvent, spell_id: String) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_long_press(spell_id)
		else:
			_cancel_long_press()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_long_press(spell_id)
		else:
			_cancel_long_press()


func _begin_long_press(spell_id: String) -> void:
	_long_press_spell = spell_id
	_long_press_elapsed = 0.0
	set_process(true)


func _cancel_long_press() -> void:
	_long_press_spell = ""
	_long_press_elapsed = 0.0
	set_process(false)


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
