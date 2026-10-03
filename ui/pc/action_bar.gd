extends Control
class_name PcActionBar

## One combat bar. View only. Spell costs, hit text and dim reasons come from
## CombatSim.preview_cast through the HUD. The bar draws when that state
## changes. It has no per-frame redraw.

const BAR_H := 176.0
const INK := Color(0.96, 0.93, 0.86)
const GOLD := Color(0.98, 0.82, 0.35)
const DIM := Color(0.55, 0.54, 0.52, 1.0)
const END_FILL := Color(0.62, 0.34, 0.08, 0.98)
const SLOT_FILL := Color(0.20, 0.16, 0.13, 0.96)
const SLOT_DIM := Color(0.10, 0.09, 0.10, 0.92)

var _hud: CombatHUD
var _stamp := ""
var _revision := 0
var _hover := ""
var _view: Dictionary = {}


static func phrase_reason(reason: String) -> String:
	if reason == "needs_marks":
		return "needs Marks"
	if reason == "":
		return ""
	return reason.replace("_", " ")


func revision() -> int:
	return _revision


func banner_text() -> String:
	return str(_view.get("banner", ""))


func resource_ap() -> int:
	return int(_view.get("ap", 0))


func resource_mp() -> int:
	return int(_view.get("mp", 0))


func portrait_hp(seat: int) -> int:
	var who := _portrait_for_seat(seat)
	return int(who.get("hp", -1))


func portrait_name(seat: int) -> String:
	var who := _portrait_for_seat(seat)
	return str(who.get("name", ""))


func turn_order(seat: int) -> int:
	var who := _portrait_for_seat(seat)
	return int(who.get("order", seat + 1))


func slot_ids() -> Array:
	var ids: Array = []
	for slot in _slots():
		ids.append(str(slot.get("id", "")))
	return ids


func slot_usable(id: String) -> bool:
	var slot := _find(id)
	return bool(slot.get("usable", false))


func slot_ap(id: String) -> int:
	var slot := _find(id)
	return int(slot.get("ap", -1))


func slot_reason(id: String) -> String:
	var slot := _find(id)
	return str(slot.get("reason", ""))


func slot_rect(id: String) -> Rect2:
	var slot := _find(id)
	return slot.get("rect", Rect2())


func slot_has_icon(id: String) -> bool:
	var slot := _find(id)
	return slot.get("icon", null) is Texture2D


func hover_reason() -> String:
	return slot_reason(_hover)


func hover_slot(id: String) -> void:
	_set_hover(id)


func activate(id: String) -> void:
	_press(_find(id))


func present(hud: CombatHUD) -> void:
	_hud = hud
	hud.fold_legacy_chrome()
	var next := _gather(hud)
	var stamp := str(next.get("stamp", ""))
	_view = next
	if stamp == _stamp:
		return
	_stamp = stamp
	_revision += 1
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	offset_top = -BAR_H
	custom_minimum_size = Vector2(0, BAR_H)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(_id_at((event as InputEventMouseMotion).position))
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		_press(_find(_id_at(button.position)))
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover("")


func _set_hover(id: String) -> void:
	if id == _hover:
		return
	_hover = id
	queue_redraw()
	if _hud == null:
		return
	var slot := _find(id)
	if str(slot.get("kind", "")) == "spell" and id != "":
		_hud.show_spell_tooltip(id)
		_hud.place_tooltip_above(_anchor(slot))
		return
	if not _hud.tooltip_pinned():
		_hud.hide_spell_tooltip()


func _press(slot: Dictionary) -> void:
	if slot.is_empty() or _hud == null or not bool(slot.get("usable", false)):
		return
	var id := str(slot.get("id", ""))
	match str(slot.get("kind", "")):
		"spell":
			_hud._on_spell_pressed(id)
		"walk":
			_hud._on_walk_pressed()
		"face":
			_hud._on_face_pressed(str(slot.get("dir", "")))
		"end":
			_hud.end_turn_requested.emit()
		"ready":
			_hud.ready_requested.emit(int(slot.get("seat", 0)))
		"match":
			_hud.new_match_requested.emit()


func _gather(hud: CombatHUD) -> Dictionary:
	var snap: Dictionary = hud._last_snap
	var width := _bar_width()
	var hero_seat := CombatHUD.kit_seat(snap)
	var foe_seat := 1 - hero_seat if hero_seat == 0 or hero_seat == 1 else -1
	var units: Array = snap.get("units", [])
	var hero := _portrait(CombatHUD.unit_for_seat(units, hero_seat), hero_seat, snap)
	var foe := _portrait(CombatHUD.unit_for_seat(units, foe_seat), foe_seat, snap)
	var kit := CombatHUD.unit_for_seat(units, hero_seat)
	var ap := int(kit.get("ap", 0))
	var mp := int(kit.get("mp", 0))
	var banner := ""
	if CombatHUD.is_local_turn(snap) and not bool(snap.get("match_over", false)) and not CombatHUD.is_deployment_phase(snap):
		banner = "YOUR TURN"
	var slots: Array = []
	_add_button_slot(slots, hud, "walk", "walk", hud._walk_button, "Walk", "walk")
	if hud._face_bar != null and hud._face_bar.visible:
		for dir in ["N", "E", "S", "W"]:
			var face := hud._face_buttons.get(dir) as Button
			_add_button_slot(slots, hud, "face:%s" % dir, "face", face, dir, "")
	for spell_id in hud._spell_buttons.keys():
		var id := str(spell_id)
		var button: Button = hud._spell_buttons[id]
		_add_spell_slot(slots, hud, id, button)
	_add_button_slot(slots, hud, "end", "end", hud._end_turn_button, "End Turn", "end_turn")
	_add_button_slot(slots, hud, "new_match", "match", hud._new_match_button, "New Match", "")
	if hud._ready_p1_button != null and hud._ready_p1_button.visible:
		_add_button_slot(slots, hud, "ready:0", "ready", hud._ready_p1_button, hud._ready_p1_button.text, "")
		slots[slots.size() - 1]["seat"] = 0
	if hud._ready_p2_button != null and hud._ready_p2_button.visible:
		_add_button_slot(slots, hud, "ready:1", "ready", hud._ready_p2_button, hud._ready_p2_button.text, "")
		slots[slots.size() - 1]["seat"] = 1
	_place(slots, width)
	var status := ""
	if hud._selected_label != null:
		status = hud._selected_label.text
	var stamp := _make_stamp(hero, foe, ap, mp, banner, slots, status, width)
	return {
		"stamp": stamp,
		"slots": slots,
		"hero": hero,
		"foe": foe,
		"ap": ap,
		"mp": mp,
		"banner": banner,
		"status": status,
		"width": width,
	}


func _add_button_slot(slots: Array, hud: CombatHUD, id: String, kind: String, button: Button, label: String, icon_id: String) -> void:
	if button == null or not button.visible:
		return
	var usable := not button.disabled
	var reason := ""
	if not usable and kind != "ready" and kind != "match":
		reason = _block_reason(hud)
	var icon: Texture2D = null
	if icon_id != "":
		icon = hud._load_ability_texture(icon_id, false)
	var slot := {
		"id": id,
		"kind": kind,
		"label": label,
		"usable": usable,
		"reason": reason,
		"ap": -1,
		"icon": icon,
		"selected": kind == "walk" and usable and hud.selected_spell() == "",
		"rect": Rect2(),
	}
	if kind == "face":
		slot["dir"] = label
	slots.append(slot)


func _add_spell_slot(slots: Array, hud: CombatHUD, spell_id: String, button: Button) -> void:
	if button == null:
		return
	var preview := hud.preview_for_spell(spell_id)
	var ap := int(preview.get("ap", SpellKits.spell(spell_id).get("ap", 0))) if not preview.is_empty() else int(SpellKits.spell(spell_id).get("ap", 0))
	var usable := not button.disabled
	var reason := ""
	if not usable:
		reason = phrase_reason(str(preview.get("reason", "")))
		if reason == "":
			reason = _block_reason(hud)
	var icon: Texture2D = hud._load_ability_texture(spell_id, false)
	slots.append({
		"id": spell_id,
		"kind": "spell",
		"label": str(preview.get("name", SpellKits.spell(spell_id).get("name", spell_id))),
		"usable": usable,
		"reason": reason,
		"ap": ap,
		"icon": icon,
		"selected": hud.selected_spell() == spell_id,
		"rect": Rect2(),
	})


func _block_reason(hud: CombatHUD) -> String:
	if hud._stunned:
		return "stunned"
	if CombatHUD.is_deployment_phase(hud._last_snap):
		return "deployment"
	if not CombatHUD.is_local_turn(hud._last_snap):
		return "opponent's turn"
	return "unavailable"


func _place(slots: Array, width: float) -> void:
	var left := 12.0 + 104.0 + 8.0 + 58.0
	var right := width - 12.0 - 104.0 - 8.0
	var gap := 6.0
	var preferred := 0.0
	for slot in slots:
		preferred += _pref_width(slot) + gap
	if not slots.is_empty():
		preferred -= gap
	var room := maxf(right - left, 64.0)
	var scale := 1.0 if preferred <= room else room / preferred
	var used := 0.0
	for slot in slots:
		used += _pref_width(slot) * scale
	used += gap * float(maxi(slots.size() - 1, 0))
	var x := left + maxf(room - used, 0.0) * 0.5
	var base_y := 46.0
	for slot in slots:
		var kind := str(slot.get("kind", ""))
		var w := _pref_width(slot) * scale
		var h := 92.0 if kind == "end" else 74.0
		var y := base_y - (8.0 if kind == "end" else 0.0)
		slot["rect"] = Rect2(x, y, w, h)
		x += w + gap


func _pref_width(slot: Dictionary) -> float:
	match str(slot.get("kind", "")):
		"end":
			return 108.0
		"face":
			return 36.0
		"walk":
			return 72.0
		"ready":
			return 112.0
		"match":
			return 78.0
		_:
			return 72.0


func _make_stamp(hero: Dictionary, foe: Dictionary, ap: int, mp: int, banner: String, slots: Array, status: String, width: float) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%s|%s|%d|%d|%s|%.0f" % [str(hero.get("name", "")), str(foe.get("name", "")), ap, mp, banner, width])
	parts.append("%s:%s:%s" % [str(hero.get("hp", 0)), str(hero.get("max_hp", 0)), str(hero.get("active", false))])
	parts.append("%s:%s:%s" % [str(foe.get("hp", 0)), str(foe.get("max_hp", 0)), str(foe.get("active", false))])
	parts.append(status)
	for slot in slots:
		parts.append("%s:%s:%s:%s:%s" % [
			str(slot.get("id", "")),
			str(slot.get("usable", false)),
			str(slot.get("ap", -1)),
			str(slot.get("reason", "")),
			str(slot.get("selected", false)),
		])
	return "\n".join(parts)


func _portrait(unit: Dictionary, seat: int, snap: Dictionary) -> Dictionary:
	if unit.is_empty() or seat < 0:
		return {}
	var class_id := str(unit.get("class_id", ""))
	var name := str(unit.get("name", ""))
	if name == "":
		name = SpellKits.display_name(class_id)
	return {
		"seat": seat,
		"name": name,
		"class_id": class_id,
		"hp": int(unit.get("hp", 0)),
		"max_hp": int(unit.get("max_hp", 1)),
		"order": seat + 1,
		"active": seat == CombatHUD.snap_active_seat(snap),
		"icon": _portrait_texture(class_id),
	}


func _portrait_texture(class_id: String) -> Texture2D:
	var path := Pawn.sprite_path(class_id, "S")
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res as Texture2D if res is Texture2D else null


func _bar_width() -> float:
	if size.x >= 200.0:
		return size.x
	return 960.0


func _slots() -> Array:
	var raw: Variant = _view.get("slots", [])
	return raw if raw is Array else []


func _find(id: String) -> Dictionary:
	for slot in _slots():
		if str(slot.get("id", "")) == id:
			return slot
	return {}


func _portrait_for_seat(seat: int) -> Dictionary:
	for key in ["hero", "foe"]:
		var who: Dictionary = _view.get(key, {})
		if int(who.get("seat", -2)) == seat:
			return who
	return {}


func _id_at(point: Vector2) -> String:
	for slot in _slots():
		var rect: Rect2 = slot.get("rect", Rect2())
		if rect.has_point(point):
			return str(slot.get("id", ""))
	return ""


func _anchor(slot: Dictionary) -> Vector2:
	var rect: Rect2 = slot.get("rect", Rect2())
	return global_position + Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)


func _draw() -> void:
	var width := float(_view.get("width", _bar_width()))
	draw_rect(Rect2(0, 28, width, BAR_H - 28), Color(0.05, 0.04, 0.04, 0.92))
	draw_rect(Rect2(0, 28, width, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.85))
	var banner := str(_view.get("banner", ""))
	if banner != "":
		_draw_banner(banner, width)
	_draw_portrait(_view.get("hero", {}), 12.0)
	_draw_portrait(_view.get("foe", {}), width - 12.0 - 100.0)
	_draw_resources(12.0 + 104.0)
	for slot in _slots():
		_draw_slot(slot)
	var reason := hover_reason()
	if reason != "" and _hover != "":
		_draw_reason(_find(_hover), reason)


func _draw_banner(text: String, width: float) -> void:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var box := Rect2(width * 0.5 - size.x * 0.5 - 14.0, 2.0, size.x + 28.0, 22.0)
	draw_rect(box, Color(0.45, 0.26, 0.05, 0.95))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), GOLD)
	draw_string(font, Vector2(box.position.x + 14.0, box.position.y + font.get_ascent(16)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.82))


func _draw_portrait(who: Dictionary, x: float) -> void:
	if who.is_empty():
		return
	var frame := Rect2(x, 40, 100, 100)
	var team := OverheadPlate.team_color(int(who.get("seat", 0)))
	var rim := GOLD if bool(who.get("active", false)) else team
	draw_rect(frame, Color(0.08, 0.07, 0.07, 0.95))
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 2)), rim)
	draw_rect(Rect2(frame.position, Vector2(2, frame.size.y)), rim)
	draw_rect(Rect2(frame.position + Vector2(frame.size.x - 2, 0), Vector2(2, frame.size.y)), rim)
	var icon: Variant = who.get("icon", null)
	if icon is Texture2D:
		var tex := icon as Texture2D
		var src_h := float(tex.get_height()) * 0.72
		draw_texture_rect_region(tex, Rect2(frame.position + Vector2(8, 4), Vector2(84, 70)), Rect2(0, 0, tex.get_width(), src_h))
	var hp := int(who.get("hp", 0))
	var cap := maxi(int(who.get("max_hp", 1)), 1)
	var ratio := clampf(float(hp) / float(cap), 0.0, 1.0)
	var bar := Rect2(frame.position.x + 6, frame.position.y + frame.size.y - 16, frame.size.x - 12, 6)
	draw_rect(bar, Color(0.04, 0.03, 0.03, 0.95))
	var ink := OverheadPlate.life_color(team, hp, cap)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), ink)
	var font := ThemeDB.fallback_font
	var order := str(int(who.get("order", 0)))
	draw_circle(frame.position + Vector2(12, 12), 8, Color(0.05, 0.04, 0.04, 0.92))
	draw_string(font, frame.position + Vector2(8, 16), order, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	var hp_text := "%d/%d" % [hp, cap]
	draw_string(font, Vector2(frame.position.x + 6, frame.position.y + frame.size.y + 12), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	draw_string(font, Vector2(frame.position.x, frame.position.y + frame.size.y + 26), str(who.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


func _draw_resources(x: float) -> void:
	var font := ThemeDB.fallback_font
	var ap := int(_view.get("ap", 0))
	var mp := int(_view.get("mp", 0))
	draw_string(font, Vector2(x, 78), "AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	draw_string(font, Vector2(x, 98), str(ap), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(font, Vector2(x, 124), "MP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.78, 0.95))
	draw_string(font, Vector2(x, 144), str(mp), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)


func _draw_slot(slot: Dictionary) -> void:
	var rect: Rect2 = slot.get("rect", Rect2())
	if rect.size.x < 2.0:
		return
	var kind := str(slot.get("kind", ""))
	var usable := bool(slot.get("usable", false))
	var selected := bool(slot.get("selected", false))
	var hovered := str(slot.get("id", "")) == _hover
	var fill := END_FILL if kind == "end" and usable else (SLOT_FILL if usable else SLOT_DIM)
	if hovered and usable:
		fill = fill.lightened(0.08)
	draw_rect(rect, fill)
	var rim := GOLD if kind == "end" or selected else (Color(0.93, 0.84, 0.62, 0.9) if usable else Color(0.35, 0.33, 0.32, 0.8))
	var thick := 3.0 if kind == "end" else 1.0
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, thick)), rim)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - thick), Vector2(rect.size.x, thick)), rim)
	draw_rect(Rect2(rect.position, Vector2(thick, rect.size.y)), rim)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - thick, 0), Vector2(thick, rect.size.y)), rim)
	var icon: Variant = slot.get("icon", null)
	var modulate := Color.WHITE if usable else DIM
	var font := ThemeDB.fallback_font
	if icon is Texture2D and kind != "face":
		var pad := 8.0 if kind != "end" else 10.0
		var icon_rect := Rect2(rect.position + Vector2(pad, 6), Vector2(rect.size.x - pad * 2.0, rect.size.y - 28))
		draw_texture_rect(icon as Texture2D, icon_rect, false, modulate)
	var label := str(slot.get("label", ""))
	if kind == "face" or kind == "ready" or kind == "match" or icon == null:
		var label_size := 18 if kind == "face" else 13
		var measured := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
		var origin := rect.position + Vector2((rect.size.x - measured.x) * 0.5, rect.size.y * 0.62)
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, INK if usable else DIM)
	elif kind == "end" or kind == "walk":
		var caption := "End Turn" if kind == "end" else "Walk"
		var measured := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var ink := Color(1, 0.95, 0.82) if kind == "end" else (INK if usable else DIM)
		draw_string(font, rect.position + Vector2((rect.size.x - measured.x) * 0.5, rect.size.y - 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	var ap := int(slot.get("ap", -1))
	if kind == "spell" and ap >= 0:
		var badge := Rect2(rect.position.x + rect.size.x - 22, rect.position.y + rect.size.y - 16, 20, 14)
		draw_rect(badge, Color(0.05, 0.04, 0.03, 0.92))
		draw_string(font, badge.position + Vector2(4, 11), str(ap), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD if usable else DIM)


func _draw_reason(slot: Dictionary, reason: String) -> void:
	if slot.is_empty():
		return
	var rect: Rect2 = slot.get("rect", Rect2())
	var font := ThemeDB.fallback_font
	var text := reason
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var x := clampf(rect.position.x + rect.size.x * 0.5 - measured.x * 0.5, 8.0, float(_view.get("width", 960.0)) - measured.x - 8.0)
	var box := Rect2(x - 6, rect.position.y - 20, measured.x + 12, 16)
	draw_rect(box, Color(0.08, 0.05, 0.04, 0.94))
	draw_string(font, Vector2(box.position.x + 6, box.position.y + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.72, 0.42))
