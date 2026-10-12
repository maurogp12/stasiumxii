extends Control

## PC character list and class screen. No 3D anywhere.
## Ironjaw male uses the 2D cut-out puppet. Every other class and gender
## keeps the locked painted idle (art letter S) until its puppet exists.
## Appearance is the body only: gender, face, skin, hair, eyes. Saved on the
## roster for the world and for combat. Armour dye is a later premium shop.
##
## The Koliseo picker (scenes/class_select.gd) is unchanged.
## run/main_scene stays the mobile hub. A windowed launch of the world scene
## opens this screen first.

const Roster = preload("res://backend/pc_roster.gd")
const Painted = preload("res://units/painted_looks.gd")
const Kits = preload("res://data/kits.gd")
const Koliseo = preload("res://scenes/class_select.gd")
const RadarChart = preload("res://scenes/pc/character_select/radar_chart.gd")
const GradeShader = preload("res://scenes/pc/character_select/backdrop_grade.gdshader")
const SettingsPanel = preload("res://ui/visual_settings_panel.gd")
const PuppetScene = preload("res://scenes/pc/character_select/puppet.tscn")
const PuppetScript = preload("res://scenes/pc/character_select/puppet.gd")

const WORLD_SCENE := "res://scenes/world/crosshaven/crosshaven_world.tscn"
const ART := "res://art/pc/character_select/"
const DESIGN := Vector2(1920, 1080)
const SPRITE_PX := 520.0
const ISLAND_SPRITE_SCALE := 0.8
const TRANSITION_SEC := 0.6
const MORPH_SEC := 0.2
const FLASH_SEC := 0.08
const BOB_PX := 6.0
const BOB_SEC := 4.0
## e is the S sheet with no mirror. Spec 5.6 asks for idle S.
const IDLE_LETTER := "e"
const FALLBACK_ART := "S"

## Tests set these before the node enters the tree.
var instant := false
var auto_enter_world := true
var auto_quit := true

var screen_id := "class"
var naming := false
var tab := "gameplay"
var selected_class_id := "ironjaw"
var draft: Dictionary = {}
var entered: Dictionary = {}
var quit_requested := false

var class_art: TextureRect
var pedestal_sprite: Sprite2D
var island_sprite: Sprite2D
var puppet: Node2D
var turn_left: Button
var turn_right: Button
var back_button: Button
var create_button: Button
var list_create: Button
var play_button: Button
var name_field: LineEdit
var name_error_label: Label
var delete_field: LineEdit
var radar: Control
var color_picker: ColorPicker
var gameplay_page: Control
var appearance_page: Control
var fallback_note: Label

var _roster: Dictionary = {}
var _selected_index := 0
var _performance := false
var _clock := 0.0
var _bolt_wait := 7.0
var _bolt_life := 0.0
var _flash_left := 0.0
var _shown_class := ""
var _idle_frames: Array = []
var _idle_fps := 12.0
var _idle_t := 0.0
var _picker_channel := ""
var _picker_backup: Dictionary = {}
var _grade_mat: ShaderMaterial
var _settings: VisualSettings
var _visuals: CanvasLayer

var _backdrop: TextureRect
var _flash: ColorRect
var _bolt: TextureRect
var _bolts: Array[Texture2D] = []
var _rain: GPUParticles2D
var _island: Control
var _pedestal: Control
var _pedestal_art: TextureRect
var _list_root: Control
var _class_root: Control
var _row_box: VBoxContainer
var _name_row: Control
var _delete_dialog: ColorRect
var _rename_dialog: ColorRect
var _quit_dialog: ColorRect
var _picker_popup: ColorRect
var _delete_prompt: Label
var _delete_error: Label
var _rename_field: LineEdit
var _rename_error: Label
var _role_label: Label
var _lore_label: Label
var _difficulty_label: Label
var _element_label: Label
var _spell_row: HBoxContainer
var _gameplay_tab: Button
var _appearance_tab: Button
var _face_buttons: Dictionary = {}
var _skin_buttons: Dictionary = {}
var _hair_buttons: Dictionary = {}
var _eye_buttons: Dictionary = {}
var _gender_buttons: Dictionary = {}
var _class_buttons: Dictionary = {}
var _hair_custom_button: Button
var _eye_custom_button: Button
var _drag_pad: Control
var _drag_x := 0.0

var grade_value := 0.0:
	set(v):
		grade_value = clampf(v, 0.0, 1.0)
		if _grade_mat != null:
			_grade_mat.set_shader_parameter("grade", grade_value)
		if _pedestal_art != null:
			_pedestal_art.modulate = Color.WHITE.lerp(Color(1.0, 0.78, 0.72), grade_value)
		if _bolt != null and screen_id == "class":
			_bolt.modulate.a = 0.55


class ShadowBlob extends Node2D:
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			pts.append(Vector2(cos(angle) * 54.0, sin(angle) * 16.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.35))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	draft = Roster.default_appearance()
	Roster.migrate_legacy()
	Roster.sync_levels()
	_roster = Roster.load_roster()
	_build_stage()
	_build_list()
	_build_class_ui()
	_build_chrome()
	_build_dialogs()
	_build_picker()
	_build_settings()
	_apply_route()
	_apply_window()
	resized.connect(_place_feet)
	call_deferred("_place_feet")


func _process(delta: float) -> void:
	_clock += delta
	if _island != null and _island.visible:
		var bob := sin(_clock * TAU / BOB_SEC) * BOB_PX
		_island.offset_top = bob
		_island.offset_bottom = bob
	_idle_t += delta
	_apply_idle_frame()
	_bolt_wait -= delta
	if _bolt_wait <= 0.0:
		_strike()
		var gap := lightning_gap_range()
		_bolt_wait = randf_range(gap.x, gap.y)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_flash.color.a = 0.85 * (_flash_left / FLASH_SEC)
	if _bolt_life > 0.0:
		_bolt_life = maxf(_bolt_life - delta, 0.0)
		if _bolt_life == 0.0:
			_bolt.visible = false
	if _rain != null:
		_rain.position = Vector2(size.x * 0.5, -8.0)
		var mat := _rain.process_material as ParticleProcessMaterial
		if mat != null:
			mat.emission_box_extents = Vector3(maxf(size.x * 0.5, 32.0), 8.0, 1.0)


func performance_stage_scale() -> float:
	return 0.5 if _performance else 1.0


func lightning_gap_range() -> Vector2:
	if _performance:
		return Vector2(14, 22)
	return Vector2(6, 14)


func uses_painted_fallback() -> bool:
	return puppet == null or not puppet.visible


func painted_art_letter() -> String:
	return FALLBACK_ART


func has_armour_swatches() -> bool:
	return false


func show_tab(which: String) -> void:
	tab = "appearance" if which == "appearance" else "gameplay"
	if gameplay_page != null:
		gameplay_page.visible = tab == "gameplay"
	if appearance_page != null:
		appearance_page.visible = tab == "appearance"
	_style_tab(_gameplay_tab, tab == "gameplay")
	_style_tab(_appearance_tab, tab == "appearance")


func select_class(class_id: String) -> void:
	var key := Kits.normalize_class_id(class_id)
	if not Kits.is_roster_class(key):
		return
	selected_class_id = key
	_refresh_class_grid()
	_refresh_gameplay()
	_set_idle_class(key)
	_sync_puppet(screen_id != "list")
	if radar != null:
		radar.set_values(Roster.radar_values(key), instant)


func set_gender(gender: String) -> void:
	var key := gender.strip_edges().to_lower()
	if key != Roster.GENDER_MALE and key != Roster.GENDER_FEMALE:
		return
	draft["gender"] = key
	_refresh_appearance()
	_sync_puppet(true)


func set_face(face_id: String) -> void:
	for row in Roster.face_options():
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == face_id:
			draft["face"] = face_id
			_refresh_appearance()
			_apply_puppet_colors()
			if puppet != null and puppet.visible and screen_id == "class":
				puppet.play_select()
			return


func set_skin(hex: String) -> void:
	var clean := Roster._hex(hex)
	if not Roster.skin_options().has(clean):
		return
	draft["skin"] = clean
	_refresh_appearance()
	_apply_puppet_colors()


func set_hair(hex: String, custom: bool = false) -> void:
	var clean := Roster._hex(hex)
	if clean == "":
		return
	if not custom and not Roster.hair_options().has(clean):
		return
	draft["hair"] = clean
	draft["hair_custom"] = custom
	_refresh_appearance()
	_apply_puppet_colors()


func set_eyes(hex: String, custom: bool = false) -> void:
	var clean := Roster._hex(hex)
	if clean == "":
		return
	if not custom and not Roster.eye_options().has(clean):
		return
	draft["eyes"] = clean
	draft["eyes_custom"] = custom
	_refresh_appearance()
	_apply_puppet_colors()


func reset_body() -> void:
	var gender := str(draft.get("gender", Roster.GENDER_MALE))
	draft = Roster.default_appearance()
	draft["gender"] = gender
	_refresh_appearance()
	_apply_puppet_colors()


func open_custom(channel: String) -> void:
	if channel != "hair" and channel != "eyes":
		return
	_picker_channel = channel
	_picker_backup = draft.duplicate(true)
	color_picker.color = Color.html(str(draft.get(channel, "#000000")))
	_picker_popup.show()


func apply_custom() -> void:
	_picker_popup.hide()


func cancel_custom() -> void:
	draft = _picker_backup.duplicate(true)
	_picker_popup.hide()
	_refresh_appearance()


func press_create() -> void:
	if screen_id == "list":
		_show_class(true)
		return
	if (_roster.get("characters", []) as Array).size() >= Roster.SLOT_LIMIT:
		return
	if puppet != null and puppet.visible and puppet.has_method("play_select"):
		puppet.play_select()
	naming = true
	name_error_label.text = ""
	name_error_label.visible = false
	create_button.visible = false
	_name_row.visible = true
	name_field.text = ""
	name_field.grab_focus()


func press_cancel_name() -> void:
	naming = false
	_name_row.visible = false
	create_button.visible = _slots_open()
	name_error_label.visible = false


func press_confirm_name() -> bool:
	var result: Dictionary = Roster.create_character(name_field.text, selected_class_id, draft)
	if not bool(result.get("ok", false)):
		name_error_label.text = str(result.get("reason", ""))
		name_error_label.visible = true
		return false
	_roster = Roster.load_roster()
	_enter_world(str(result.get("id", "")), "create")
	return true


func press_back() -> void:
	if naming:
		press_cancel_name()
		return
	if (_roster.get("characters", []) as Array).is_empty():
		return
	_show_list()


func press_play() -> void:
	var ch := _selected()
	if ch.is_empty() or _dialog_open():
		return
	_enter_world(str(ch.get("id", "")), "play")


func begin_delete() -> void:
	var ch := _selected()
	if ch.is_empty():
		return
	_delete_error.text = ""
	delete_field.text = ""
	_delete_prompt.text = "Type %s to delete this character." % str(ch.get("name", ""))
	_delete_dialog.show()
	delete_field.grab_focus()


func confirm_delete(typed: String) -> bool:
	var ch := _selected()
	if ch.is_empty():
		return false
	if typed.strip_edges() != str(ch.get("name", "")):
		_delete_error.text = "Type the name to confirm."
		return false
	var result: Dictionary = Roster.delete_character(str(ch.get("id", "")))
	if not bool(result.get("ok", false)):
		_delete_error.text = str(result.get("reason", ""))
		return false
	_delete_dialog.hide()
	_roster = Roster.load_roster()
	var chars: Array = _roster.get("characters", [])
	if chars.is_empty():
		_selected_index = 0
		_show_class(false)
		back_button.visible = false
	else:
		_selected_index = mini(_selected_index, chars.size() - 1)
		_show_list()
	return true


func begin_rename() -> void:
	var ch := _selected()
	if ch.is_empty():
		return
	_rename_error.text = ""
	_rename_field.text = str(ch.get("name", ""))
	_rename_dialog.show()
	_rename_field.grab_focus()


func confirm_rename(typed: String) -> bool:
	var ch := _selected()
	if ch.is_empty():
		return false
	var result: Dictionary = Roster.rename_character(str(ch.get("id", "")), typed)
	if not bool(result.get("ok", false)):
		_rename_error.text = str(result.get("reason", ""))
		return false
	_rename_dialog.hide()
	_roster = Roster.load_roster()
	if screen_id == "list":
		_show_list()
	return true


func move_selection(delta: int) -> void:
	var chars: Array = _roster.get("characters", [])
	if chars.is_empty() or screen_id != "list":
		return
	_selected_index = clampi(_selected_index + delta, 0, chars.size() - 1)
	_show_list()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if _visuals != null and _visuals.visible:
		if key == KEY_ESCAPE:
			_visuals.hide_panel()
			get_viewport().set_input_as_handled()
		return
	if _picker_popup != null and _picker_popup.visible:
		if key == KEY_ESCAPE:
			cancel_custom()
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			apply_custom()
			get_viewport().set_input_as_handled()
		return
	if _dialog_open():
		if key == KEY_ESCAPE:
			_delete_dialog.hide()
			_rename_dialog.hide()
			_quit_dialog.hide()
			get_viewport().set_input_as_handled()
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if naming:
		if key == KEY_ESCAPE:
			press_cancel_name()
			get_viewport().set_input_as_handled()
		elif (key == KEY_ENTER or key == KEY_KP_ENTER) and not typing:
			press_confirm_name()
			get_viewport().set_input_as_handled()
		return
	if typing:
		return
	if screen_id == "list":
		match key:
			KEY_UP:
				move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				press_play()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				begin_delete()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_quit_dialog.show()
				get_viewport().set_input_as_handled()
	elif screen_id == "class" and puppet != null and puppet.visible and (key == KEY_LEFT or key == KEY_RIGHT):
		puppet.turn(-1 if key == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		if back_button != null and back_button.visible:
			press_back()
		else:
			_quit_dialog.show()
		get_viewport().set_input_as_handled()


func _apply_route() -> void:
	var chars: Array = _roster.get("characters", [])
	if chars.is_empty():
		_show_class(false)
		back_button.visible = false
	else:
		_selected_index = _index_of(str(_roster.get("last", "")))
		_show_list()


func _show_list() -> void:
	screen_id = "list"
	naming = false
	_list_root.visible = true
	_class_root.visible = false
	_island.visible = true
	_pedestal.visible = false
	class_art.visible = false
	grade_value = 0.0
	_name_row.visible = false
	_rebuild_rows()
	var ch := _selected()
	if not ch.is_empty():
		_set_idle_class(str(ch.get("class_id", "ironjaw")))
		_sync_puppet(false)


func _show_class(animated: bool) -> void:
	screen_id = "class"
	_class_root.visible = true
	_pedestal.visible = true
	class_art.visible = true
	back_button.visible = not (_roster.get("characters", []) as Array).is_empty()
	create_button.visible = true
	_name_row.visible = false
	naming = false
	show_tab(tab)
	select_class(selected_class_id)
	if instant or not animated:
		_list_root.visible = false
		_island.visible = false
		grade_value = 1.0
		_class_root.modulate.a = 1.0
		return
	_class_root.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "grade_value", 1.0, TRANSITION_SEC)
	tw.tween_property(_list_root, "offset_left", -720.0, TRANSITION_SEC)
	tw.tween_property(_list_root, "offset_right", -720.0, TRANSITION_SEC)
	tw.tween_property(_island, "modulate:a", 0.0, TRANSITION_SEC)
	tw.tween_property(_class_root, "modulate:a", 1.0, TRANSITION_SEC)
	tw.chain().tween_callback(func() -> void:
		_list_root.visible = false
		_list_root.offset_left = 0.0
		_list_root.offset_right = 0.0
		_island.visible = false
		_island.modulate.a = 1.0
	)


func _enter_world(id: String, reason: String) -> void:
	_release_puppet()
	Roster.set_last(id)
	var ch := Roster.find_character(id)
	var place := _saved_place(id)
	entered = {
		"id": id,
		"reason": reason,
		"class_id": str(ch.get("class_id", "")),
		"gender": str(ch.get("gender", "")),
		"face": str(ch.get("face", "")),
		"skin": str(ch.get("skin", "")),
		"hair": str(ch.get("hair", "")),
		"eyes": str(ch.get("eyes", "")),
		"hair_custom": bool(ch.get("hair_custom", false)),
		"eyes_custom": bool(ch.get("eyes_custom", false)),
		"zone_id": str(place.get("zone_id", "")),
		"cell": place.get("cell", Vector2i.ZERO),
	}
	Roster.arm_world_entry(id)
	if auto_enter_world and is_inside_tree():
		get_tree().change_scene_to_file(WORLD_SCENE)


func _saved_place(id: String) -> Dictionary:
	var path := Roster.progress_path(id)
	var zone_id := ""
	var cell := Vector2i.ZERO
	if path != "" and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			var world: Variant = (parsed as Dictionary).get("world", {})
			if typeof(world) == TYPE_DICTIONARY:
				zone_id = str((world as Dictionary).get("zone_id", ""))
				cell = Vector2i(int((world as Dictionary).get("x", 0)), int((world as Dictionary).get("y", 0)))
	return {"zone_id": zone_id, "cell": cell}


func _selected() -> Dictionary:
	var chars: Array = _roster.get("characters", [])
	if _selected_index < 0 or _selected_index >= chars.size():
		return {}
	var row: Variant = chars[_selected_index]
	return row if typeof(row) == TYPE_DICTIONARY else {}


func _index_of(id: String) -> int:
	var chars: Array = _roster.get("characters", [])
	for i in chars.size():
		if str((chars[i] as Dictionary).get("id", "")) == id:
			return i
	return 0


func _slots_open() -> bool:
	return (_roster.get("characters", []) as Array).size() < Roster.SLOT_LIMIT


func _dialog_open() -> bool:
	return (_delete_dialog != null and _delete_dialog.visible) or (_rename_dialog != null and _rename_dialog.visible) or (_quit_dialog != null and _quit_dialog.visible)


func _set_idle_class(class_id: String) -> void:
	var key := Kits.normalize_class_id(class_id)
	if key == "":
		key = "ironjaw"
	if key == _shown_class and not _idle_frames.is_empty():
		_place_feet()
		return
	_shown_class = key
	_idle_frames = Painted.cells(key, "idle", IDLE_LETTER)
	_idle_fps = float(Painted.spec(key, "idle").get("fps", 12.0))
	_idle_t = 0.0
	_apply_idle_frame()
	_place_feet()


func _apply_idle_frame() -> void:
	if _idle_frames.is_empty() or pedestal_sprite == null:
		return
	var index := int(_idle_t * _idle_fps) % _idle_frames.size()
	var tex: Texture2D = _idle_frames[index]
	pedestal_sprite.texture = tex
	island_sprite.texture = tex


func _place_feet() -> void:
	if pedestal_sprite == null or size.y < 2.0 or _shown_class == "":
		return
	var cell := Painted.cell_of(_shown_class, "idle")
	if cell.y <= 0:
		return
	var pivot := Painted.pivot_of(_shown_class, "idle", IDLE_LETTER)
	var height := size.y * (SPRITE_PX / DESIGN.y)
	var feet_p := Vector2(_pedestal.size.x * 0.5, _pedestal.size.y * 0.30)
	var feet_i := Vector2(_island.size.x * 0.5, _island.size.y * (210.0 / 644.0))
	_fit_sprite(pedestal_sprite, feet_p, height, cell, pivot)
	_fit_sprite(island_sprite, feet_i, height * ISLAND_SPRITE_SCALE, cell, pivot)
	if puppet != null and puppet.visible:
		var on_island := puppet.get_parent() == _island
		puppet.fit_height(height)
		var feet := feet_i if on_island else feet_p
		puppet.position = feet - Vector2(0.0, puppet.feet_offset())
	var blob := _pedestal.get_node_or_null("Shadow") as Node2D
	if blob != null:
		blob.position = Vector2(_pedestal.size.x * 0.5, _pedestal.size.y * 0.32)
	var island_blob := _island.get_node_or_null("Shadow") as Node2D
	if island_blob != null:
		island_blob.position = Vector2(_island.size.x * 0.5, _island.size.y * (210.0 / 644.0))


func _fit_sprite(sprite: Sprite2D, feet: Vector2, height: float, cell: Vector2i, pivot: Vector2i) -> void:
	var sc := height / float(cell.y)
	sprite.centered = true
	sprite.scale = Vector2(sc, sc)
	sprite.position = feet - (Vector2(pivot) - Vector2(cell) * 0.5) * sc


func _figure_gender() -> String:
	if screen_id == "list":
		var ch := _selected()
		if not ch.is_empty():
			return str(ch.get("gender", Roster.GENDER_MALE))
	return str(draft.get("gender", Roster.GENDER_MALE))


func _sync_puppet(flourish: bool) -> void:
	if puppet == null:
		return
	var gender := _figure_gender()
	var show: bool = PuppetScript.has_puppet(selected_class_id, gender)
	if show:
		var changed := (not puppet.visible) or str(puppet.class_id) != selected_class_id or str(puppet.gender) != gender
		puppet.show_puppet(selected_class_id, gender)
		puppet.visible = true
		pedestal_sprite.visible = false
		island_sprite.visible = false
		var on_island := screen_id == "list"
		var host: Node = _island if on_island else _pedestal
		if puppet.get_parent() != host:
			puppet.reparent(host)
		puppet.set_list_mode(on_island)
		_apply_puppet_colors()
		if flourish and changed and not on_island:
			puppet.play_select()
	else:
		_release_puppet()
		pedestal_sprite.visible = true
		island_sprite.visible = true
	if turn_left != null:
		turn_left.visible = show and screen_id == "class"
	if turn_right != null:
		turn_right.visible = show and screen_id == "class"
	if _drag_pad != null:
		_drag_pad.visible = show and screen_id == "class"
		_drag_pad.mouse_filter = Control.MOUSE_FILTER_STOP if _drag_pad.visible else Control.MOUSE_FILTER_IGNORE
	_place_feet()
	_refresh_appearance()


func _release_puppet() -> void:
	if puppet != null and puppet.has_method("release"):
		puppet.release()
	if puppet != null:
		puppet.visible = false


func _apply_puppet_colors() -> void:
	if puppet == null or not puppet.visible:
		return
	var skin := ""
	var hair := ""
	var eyes := ""
	var face := "broad"
	if screen_id == "list":
		var ch := _selected()
		skin = str(ch.get("skin", ""))
		hair = str(ch.get("hair", ""))
		eyes = str(ch.get("eyes", ""))
		face = str(ch.get("face", "broad"))
	else:
		skin = str(draft.get("skin", ""))
		hair = str(draft.get("hair", ""))
		eyes = str(draft.get("eyes", ""))
		face = str(draft.get("face", "broad"))
	if skin != "":
		puppet.set_body_colors(Color.html(skin), Color.html(hair), Color.html(eyes))
	puppet.set_face(face)


func _on_stage_drag(event: InputEvent) -> void:
	if puppet == null or not puppet.visible or screen_id != "class":
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_drag_x = button.position.x
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		var dx := motion.position.x - _drag_x
		_drag_x = motion.position.x
		puppet.turn_by_pixels(dx)


func _strike() -> void:
	_flash_left = FLASH_SEC
	_flash.color = Color(1, 1, 1, 0.85)
	if _performance or _bolts.is_empty():
		_bolt.visible = false
		return
	_bolt.texture = _bolts[randi() % _bolts.size()]
	_bolt.visible = true
	_bolt.modulate.a = 0.55 if screen_id == "class" else 1.0
	var x := randf_range(24.0, maxf(size.x - 110.0, 24.0))
	_bolt.offset_left = x
	_bolt.offset_right = x + 96.0
	_bolt.offset_top = 0.0
	_bolt.offset_bottom = size.y * 0.7
	_bolt_life = 0.22


func _on_performance(on: bool) -> void:
	_performance = on
	if _rain != null:
		_rain.emitting = not on
		_rain.visible = not on
	if on and _bolt != null:
		_bolt.visible = false
	if puppet != null and puppet.has_method("set_performance"):
		puppet.set_performance(on)
		_place_feet()
	var gap := lightning_gap_range()
	if _bolt_wait < gap.x:
		_bolt_wait = gap.x


func _build_stage() -> void:
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.texture = _tex("backdrop_storm_sea.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = GradeShader
	_backdrop.material = _grade_mat
	add_child(_backdrop)

	_rain = GPUParticles2D.new()
	_rain.amount = 70
	_rain.lifetime = 1.3
	_rain.preprocess = 1.3
	_rain.visibility_rect = Rect2(-1200, -40, 2400, 1400)
	var streak := Image.create(2, 18, false, Image.FORMAT_RGBA8)
	streak.fill(Color(0.75, 0.82, 0.9, 0.45))
	_rain.texture = ImageTexture.create_from_image(streak)
	var particles := ParticleProcessMaterial.new()
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(960, 8, 1)
	particles.direction = Vector3(0.18, 1, 0)
	particles.spread = 6.0
	particles.initial_velocity_min = 420.0
	particles.initial_velocity_max = 680.0
	particles.gravity = Vector3(40, 180, 0)
	_rain.process_material = particles
	add_child(_rain)

	for file_name in ["lightning_bolt_1.png", "lightning_bolt_2.png", "lightning_bolt_3.png"]:
		var bolt_tex := _tex(file_name)
		if bolt_tex != null:
			_bolts.append(bolt_tex)
	_bolt = TextureRect.new()
	_bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bolt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bolt.visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bolt.material = add
	add_child(_bolt)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	class_art = TextureRect.new()
	class_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(class_art, Rect2(410, -80, 1100, 1100))
	add_child(class_art)

	_island = Control.new()
	_island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_island, Rect2(920, 430, 760, 644))
	add_child(_island)
	var island_art := TextureRect.new()
	island_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	island_art.texture = _tex("floating_island.png")
	island_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	island_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	island_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_island.add_child(island_art)
	var island_shadow := ShadowBlob.new()
	island_shadow.name = "Shadow"
	_island.add_child(island_shadow)
	island_sprite = Sprite2D.new()
	_island.add_child(island_sprite)

	_pedestal = Control.new()
	_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_pedestal, Rect2(750, 760, 420, 245))
	add_child(_pedestal)
	_pedestal_art = TextureRect.new()
	_pedestal_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pedestal_art.texture = _tex("pedestal.png")
	_pedestal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pedestal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pedestal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pedestal.add_child(_pedestal_art)
	var pedestal_shadow := ShadowBlob.new()
	pedestal_shadow.name = "Shadow"
	_pedestal.add_child(pedestal_shadow)
	pedestal_sprite = Sprite2D.new()
	_pedestal.add_child(pedestal_sprite)
	puppet = PuppetScene.instantiate()
	puppet.visible = false
	_pedestal.add_child(puppet)
	_drag_pad = Control.new()
	_drag_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_pad.visible = false
	_drag_pad.gui_input.connect(_on_stage_drag)
	_place(_drag_pad, Rect2(750, 280, 420, 560))
	add_child(_drag_pad)


func _build_list() -> void:
	_list_root = Control.new()
	_list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)
	var panel := _nine("ui_panel.png", 48, 64, 48, 56)
	_place(panel, Rect2(48, 120, 512, 840))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_list_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var title := Label.new()
	title.text = "Characters"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
	col.add_child(title)
	_row_box = VBoxContainer.new()
	_row_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row_box.add_theme_constant_override("separation", 4)
	col.add_child(_row_box)
	list_create = _text_button("+ Create a character", "ui_btn_orange.png", 22)
	list_create.custom_minimum_size = Vector2(464, 64)
	list_create.pressed.connect(press_create)
	col.add_child(list_create)

	play_button = _text_button("Play", "ui_btn_green.png", 28)
	play_button.custom_minimum_size = Vector2(320, 72)
	_place(play_button, Rect2(1552, 960, 320, 72))
	play_button.pressed.connect(press_play)
	_list_root.add_child(play_button)
	var delete_link := _link("Delete")
	_place(delete_link, Rect2(1552, 1036, 140, 32))
	delete_link.pressed.connect(begin_delete)
	_list_root.add_child(delete_link)
	var rename_link := _link("Rename")
	_place(rename_link, Rect2(1700, 1036, 160, 32))
	rename_link.pressed.connect(begin_rename)
	_list_root.add_child(rename_link)


func _build_class_ui() -> void:
	_class_root = Control.new()
	_class_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_class_root)
	_build_class_grid()
	radar = RadarChart.new()
	radar.axes = PackedStringArray(Roster.class_book().get("axes", []))
	_place(radar, Rect2(48, 660, 300, 300))
	_class_root.add_child(radar)
	_build_right_panel()
	back_button = _text_button("Back", "ui_tab_dim.png", 20)
	back_button.custom_minimum_size = Vector2(180, 64)
	_place(back_button, Rect2(48, 990, 180, 64))
	back_button.pressed.connect(press_back)
	_class_root.add_child(back_button)
	create_button = _text_button("Create", "ui_btn_orange.png", 24)
	create_button.custom_minimum_size = Vector2(360, 64)
	_place(create_button, Rect2(780, 990, 360, 64))
	create_button.pressed.connect(press_create)
	_class_root.add_child(create_button)
	turn_left = _text_button("<", "ui_tab_dim.png", 22)
	turn_left.custom_minimum_size = Vector2(72, 56)
	_place(turn_left, Rect2(760, 900, 72, 56))
	turn_left.visible = false
	turn_left.pressed.connect(func() -> void:
		if puppet != null and puppet.visible:
			puppet.turn(-1)
	)
	_class_root.add_child(turn_left)
	turn_right = _text_button(">", "ui_tab_dim.png", 22)
	turn_right.custom_minimum_size = Vector2(72, 56)
	_place(turn_right, Rect2(1090, 900, 72, 56))
	turn_right.visible = false
	turn_right.pressed.connect(func() -> void:
		if puppet != null and puppet.visible:
			puppet.turn(1)
	)
	_class_root.add_child(turn_right)
	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 8)
	_place(_name_row, Rect2(700, 990, 520, 72))
	_name_row.visible = false
	_class_root.add_child(_name_row)
	var cancel := _text_button("", "ui_btn_red.png", 16)
	cancel.custom_minimum_size = Vector2(72, 72)
	cancel.pressed.connect(press_cancel_name)
	_name_row.add_child(cancel)
	name_field = LineEdit.new()
	name_field.placeholder_text = "Name"
	name_field.max_length = Roster.NAME_MAX
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.custom_minimum_size = Vector2(200, 56)
	name_field.text_submitted.connect(func(_t): press_confirm_name())
	_name_row.add_child(name_field)
	var confirm := _text_button("", "ui_btn_ok.png", 16)
	confirm.custom_minimum_size = Vector2(72, 72)
	confirm.pressed.connect(press_confirm_name)
	_name_row.add_child(confirm)
	name_error_label = Label.new()
	name_error_label.visible = false
	name_error_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	name_error_label.add_theme_font_size_override("font_size", 16)
	_place(name_error_label, Rect2(780, 940, 420, 40))
	_class_root.add_child(name_error_label)


func _build_class_grid() -> void:
	var index := 0
	for class_id in Roster.class_order():
		var key := str(class_id)
		var tile := Button.new()
		tile.focus_mode = Control.FOCUS_NONE
		tile.custom_minimum_size = Vector2(150, 150)
		var col := index % 2
		var row := int(index / 2.0)
		_place(tile, Rect2(64 + col * 166, 140 + row * 166, 150, 150))
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_bottom = -28
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frames := Painted.cells(key, "idle", IDLE_LETTER)
		if not frames.is_empty():
			icon.texture = frames[0]
		tile.add_child(icon)
		var caption := Label.new()
		caption.text = Kits.display_name(key)
		caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -26
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
		tile.add_child(caption)
		tile.pressed.connect(select_class.bind(key))
		_class_buttons[key] = tile
		_class_root.add_child(tile)
		index += 1
	_refresh_class_grid()


func _build_right_panel() -> void:
	var panel := _nine("ui_panel.png", 48, 64, 48, 56)
	_place(panel, Rect2(1380, 120, 492, 840))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	_gameplay_tab = _text_button("Gameplay", "ui_tab_lit.png", 16)
	_gameplay_tab.custom_minimum_size = Vector2(160, 48)
	_gameplay_tab.pressed.connect(show_tab.bind("gameplay"))
	tabs.add_child(_gameplay_tab)
	_appearance_tab = _text_button("Appearance", "ui_tab_dim.png", 16)
	_appearance_tab.custom_minimum_size = Vector2(180, 48)
	_appearance_tab.pressed.connect(show_tab.bind("appearance"))
	tabs.add_child(_appearance_tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	scroll.add_child(stack)
	gameplay_page = VBoxContainer.new()
	gameplay_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_page.add_theme_constant_override("separation", 8)
	stack.add_child(gameplay_page)
	_difficulty_label = _cream(18)
	_role_label = _cream(22)
	_lore_label = _cream(16)
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_element_label = _cream(16)
	_spell_row = HBoxContainer.new()
	_spell_row.add_theme_constant_override("separation", 6)
	gameplay_page.add_child(_difficulty_label)
	gameplay_page.add_child(_role_label)
	gameplay_page.add_child(_lore_label)
	gameplay_page.add_child(_spell_row)
	gameplay_page.add_child(_element_label)
	appearance_page = VBoxContainer.new()
	appearance_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_page.visible = false
	appearance_page.add_theme_constant_override("separation", 6)
	stack.add_child(appearance_page)
	_build_appearance(appearance_page)


func _build_appearance(parent: VBoxContainer) -> void:
	parent.add_child(_section("Body"))
	var genders := HBoxContainer.new()
	genders.add_theme_constant_override("separation", 8)
	parent.add_child(genders)
	_gender_buttons["m"] = _text_button("Male", "ui_tab_dim.png", 16)
	_gender_buttons["f"] = _text_button("Female", "ui_tab_dim.png", 16)
	for key in ["m", "f"]:
		var button: Button = _gender_buttons[key]
		button.custom_minimum_size = Vector2(140, 44)
		button.pressed.connect(set_gender.bind(key))
		genders.add_child(button)
	parent.add_child(_section("Face"))
	var faces := HFlowContainer.new()
	faces.add_theme_constant_override("h_separation", 6)
	faces.add_theme_constant_override("v_separation", 6)
	parent.add_child(faces)
	for row in Roster.face_options():
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var face_id := str((row as Dictionary).get("id", ""))
		var button := Button.new()
		button.text = str((row as Dictionary).get("name", face_id))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(96, 36)
		button.pressed.connect(set_face.bind(face_id))
		_face_buttons[face_id] = button
		faces.add_child(button)
	parent.add_child(_section("Skin"))
	parent.add_child(_swatch_row(Roster.skin_options(), _skin_buttons, "skin"))
	parent.add_child(_section("Hair"))
	var hair_row := _swatch_row(Roster.hair_options(), _hair_buttons, "hair")
	_hair_custom_button = _custom_button("hair")
	hair_row.add_child(_hair_custom_button)
	parent.add_child(hair_row)
	parent.add_child(_section("Eyes"))
	var eye_row := _swatch_row(Roster.eye_options(), _eye_buttons, "eyes")
	_eye_custom_button = _custom_button("eyes")
	eye_row.add_child(_eye_custom_button)
	parent.add_child(eye_row)
	fallback_note = _cream(14)
	fallback_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(fallback_note)
	var reset := _link("Reset body")
	reset.pressed.connect(reset_body)
	parent.add_child(reset)
	_refresh_appearance()


func _build_chrome() -> void:
	var settings_button := _link("Settings")
	settings_button.custom_minimum_size = Vector2(120, 48)
	_place(settings_button, Rect2(1640, 28, 120, 48))
	settings_button.pressed.connect(func() -> void:
		if _visuals != null:
			_visuals.show_panel()
	)
	add_child(settings_button)
	var quit_button := _link("Quit")
	quit_button.custom_minimum_size = Vector2(80, 48)
	_place(quit_button, Rect2(1780, 28, 90, 48))
	quit_button.pressed.connect(func() -> void: _quit_dialog.show())
	add_child(quit_button)


func _build_dialogs() -> void:
	_delete_dialog = _dialog()
	var delete_body := _dialog_body(_delete_dialog)
	_delete_prompt = _cream(18)
	_delete_prompt.name = "Prompt"
	_delete_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_body.add_child(_delete_prompt)
	delete_field = LineEdit.new()
	delete_field.placeholder_text = "Type the name"
	delete_body.add_child(delete_field)
	_delete_error = Label.new()
	_delete_error.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	delete_body.add_child(_delete_error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	delete_body.add_child(row)
	var yes := Button.new()
	yes.text = "Delete"
	yes.pressed.connect(func() -> void: confirm_delete(delete_field.text))
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	no.pressed.connect(func() -> void: _delete_dialog.hide())
	row.add_child(no)

	_rename_dialog = _dialog()
	var rename_body := _dialog_body(_rename_dialog)
	var rename_title := _cream(18)
	rename_title.text = "Rename this character."
	rename_body.add_child(rename_title)
	_rename_field = LineEdit.new()
	_rename_field.max_length = Roster.NAME_MAX
	rename_body.add_child(_rename_field)
	_rename_error = Label.new()
	_rename_error.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	rename_body.add_child(_rename_error)
	var rename_row := HBoxContainer.new()
	rename_body.add_child(rename_row)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(func() -> void: confirm_rename(_rename_field.text))
	rename_row.add_child(save)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _rename_dialog.hide())
	rename_row.add_child(cancel)

	_quit_dialog = _dialog()
	var quit_body := _dialog_body(_quit_dialog)
	var quit_label := _cream(18)
	quit_label.text = "Quit the game?"
	quit_body.add_child(quit_label)
	var quit_row := HBoxContainer.new()
	quit_body.add_child(quit_row)
	var quit_yes := Button.new()
	quit_yes.text = "Quit"
	quit_yes.pressed.connect(_confirm_quit)
	quit_row.add_child(quit_yes)
	var quit_no := Button.new()
	quit_no.text = "Stay"
	quit_no.pressed.connect(func() -> void: _quit_dialog.hide())
	quit_row.add_child(quit_no)


func _build_picker() -> void:
	_picker_popup = _dialog()
	var body := _dialog_body(_picker_popup)
	var title := _cream(18)
	title.text = "Custom colour"
	body.add_child(title)
	color_picker = ColorPicker.new()
	color_picker.edit_alpha = false
	color_picker.presets_visible = false
	color_picker.custom_minimum_size = Vector2(320, 280)
	color_picker.color_changed.connect(_on_picker_color)
	body.add_child(color_picker)
	var row := HBoxContainer.new()
	body.add_child(row)
	var ok := Button.new()
	ok.text = "Use colour"
	ok.pressed.connect(apply_custom)
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(cancel_custom)
	row.add_child(cancel)


func _build_settings() -> void:
	_settings = VisualSettings.new()
	_visuals = SettingsPanel.new()
	_visuals.name = "VisualSettings"
	add_child(_visuals)
	_visuals.setup(_settings, true)
	_settings.bind(self, VisualSettings.PERFORMANCE, _on_performance)


func _on_picker_color(next: Color) -> void:
	if _picker_channel == "hair":
		set_hair(_hex_of(next), true)
	elif _picker_channel == "eyes":
		set_eyes(_hex_of(next), true)


func _confirm_quit() -> void:
	_quit_dialog.hide()
	if auto_quit and is_inside_tree():
		get_tree().quit()
	else:
		quit_requested = true


func _rebuild_rows() -> void:
	if _row_box == null:
		return
	for child in _row_box.get_children():
		child.free()
	list_create.visible = _slots_open()
	var chars: Array = _roster.get("characters", [])
	for i in chars.size():
		var ch: Dictionary = chars[i]
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(0, 96)
		var visual := Button.new()
		visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visual.focus_mode = Control.FOCUS_NONE
		visual.add_theme_stylebox_override("normal", _row_style(i == _selected_index))
		visual.add_theme_stylebox_override("hover", _row_style(i == _selected_index))
		visual.add_theme_stylebox_override("pressed", _row_style(true))
		visual.pressed.connect(_on_row.bind(i))
		visual.mouse_entered.connect(func() -> void:
			visual.offset_top = -2
			visual.offset_bottom = -2
		)
		visual.mouse_exited.connect(func() -> void:
			visual.offset_top = 0
			visual.offset_bottom = 0
		)
		slot.add_child(visual)
		var box := HBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 8
		box.offset_right = -8
		box.add_theme_constant_override("separation", 10)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(box)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(72, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frames := Painted.cells(str(ch.get("class_id", "")), "idle", IDLE_LETTER)
		if not frames.is_empty():
			portrait.texture = frames[0]
		box.add_child(portrait)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(words)
		var name_label := Label.new()
		name_label.text = str(ch.get("name", ""))
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
		words.add_child(name_label)
		var meta := Label.new()
		meta.text = "Lv %d · %s" % [int(ch.get("level", 1)), Kits.display_name(str(ch.get("class_id", "")))]
		meta.add_theme_font_size_override("font_size", 16)
		meta.add_theme_color_override("font_color", Color(0.86, 0.8, 0.68))
		words.add_child(meta)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not frames.is_empty():
			icon.texture = frames[0]
		box.add_child(icon)
		_row_box.add_child(slot)


func _on_row(index: int) -> void:
	_selected_index = index
	_show_list()


func _refresh_class_grid() -> void:
	for key in _class_buttons.keys():
		var tile: Button = _class_buttons[key]
		var on := str(key) == selected_class_id
		tile.add_theme_stylebox_override("normal", _tile_style(on))
		tile.add_theme_stylebox_override("hover", _tile_style(true))
		tile.add_theme_stylebox_override("pressed", _tile_style(true))


func _refresh_gameplay() -> void:
	if _role_label == null:
		return
	var row := Roster.class_row(selected_class_id)
	var stars := int(row.get("difficulty", 1))
	_difficulty_label.text = "Difficulty  " + "★".repeat(clampi(stars, 0, 3)) + "☆".repeat(maxi(3 - stars, 0))
	_role_label.text = Koliseo.role_line(selected_class_id)
	_lore_label.text = str(row.get("lore", ""))
	var element := Kits.element_of(selected_class_id)
	_element_label.text = "Element: %s" % (element.substr(0, 1).to_upper() + element.substr(1))
	for child in _spell_row.get_children():
		child.free()
	for spell_id in Kits.class_spells(selected_class_id):
		var def: Dictionary = Kits.spell(str(spell_id))
		var chip := Button.new()
		chip.text = str(def.get("name", spell_id))
		chip.custom_minimum_size = Vector2(56, 56)
		chip.focus_mode = Control.FOCUS_NONE
		chip.clip_text = true
		chip.tooltip_text = "%s\n%d AP · %s\n%s" % [str(def.get("name", "")), int(def.get("ap", 0)), Kits.range_text(def), str(def.get("element", ""))]
		chip.add_theme_font_size_override("font_size", 10)
		_spell_row.add_child(chip)


func _refresh_appearance() -> void:
	if fallback_note == null:
		return
	var coming := uses_painted_fallback()
	if coming:
		fallback_note.text = "Coming soon. This class has no puppet yet, so the pedestal keeps the locked idle sprite. Face, skin, hair and eyes are still saved."
	else:
		fallback_note.text = "Skin, hair and eyes show on the puppet. Armour dye is a later premium shop, not part of creation."
	for key in _face_buttons.keys():
		(_face_buttons[key] as Button).disabled = coming
	for key in _skin_buttons.keys():
		(_skin_buttons[key] as Button).disabled = coming
	for key in _hair_buttons.keys():
		(_hair_buttons[key] as Button).disabled = coming
	for key in _eye_buttons.keys():
		(_eye_buttons[key] as Button).disabled = coming
	if _hair_custom_button != null:
		_hair_custom_button.disabled = coming
	if _eye_custom_button != null:
		_eye_custom_button.disabled = coming
	for key in _gender_buttons.keys():
		_style_tab(_gender_buttons[key], str(key) == str(draft.get("gender", "")))
	for key in _face_buttons.keys():
		var on := str(key) == str(draft.get("face", ""))
		var button: Button = _face_buttons[key]
		button.add_theme_stylebox_override("normal", _tile_style(on))
	for hex in _skin_buttons.keys():
		_paint_swatch(_skin_buttons[hex], str(hex), str(hex) == str(draft.get("skin", "")))
	for hex in _hair_buttons.keys():
		_paint_swatch(_hair_buttons[hex], str(hex), str(hex) == str(draft.get("hair", "")) and not bool(draft.get("hair_custom", false)))
	for hex in _eye_buttons.keys():
		_paint_swatch(_eye_buttons[hex], str(hex), str(hex) == str(draft.get("eyes", "")) and not bool(draft.get("eyes_custom", false)))
	if _hair_custom_button != null:
		_paint_swatch(_hair_custom_button, str(draft.get("hair", "#ffffff")) if bool(draft.get("hair_custom", false)) else "#444444", bool(draft.get("hair_custom", false)))
		_hair_custom_button.text = "Custom"
	if _eye_custom_button != null:
		_paint_swatch(_eye_custom_button, str(draft.get("eyes", "#ffffff")) if bool(draft.get("eyes_custom", false)) else "#444444", bool(draft.get("eyes_custom", false)))
		_eye_custom_button.text = "Custom"


func _style_tab(button: Button, on: bool) -> void:
	if button == null:
		return
	var path := "ui_tab_lit.png" if on else "ui_tab_dim.png"
	var box := _box(path, 28, 24, 28, 28)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)


func _swatch_row(colors: Array, store: Dictionary, channel: String) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for hex in colors:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(36, 36)
		button.pressed.connect(_on_swatch.bind(channel, str(hex)))
		store[str(hex)] = button
		row.add_child(button)
	return row


func _custom_button(channel: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(72, 36)
	button.text = "Custom"
	button.pressed.connect(open_custom.bind(channel))
	return button


func _on_swatch(channel: String, hex: String) -> void:
	match channel:
		"skin":
			set_skin(hex)
		"hair":
			set_hair(hex, false)
		"eyes":
			set_eyes(hex, false)


func _paint_swatch(button: Button, hex: String, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.html(hex) if hex.begins_with("#") else Color(0.3, 0.3, 0.3)
	box.set_border_width_all(3 if selected else 1)
	box.border_color = Color(0.93, 0.78, 0.42) if selected else Color(0, 0, 0, 0.55)
	box.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)


func _dialog() -> ColorRect:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.visible = false
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dim.hide()
	)
	add_child(dim)
	var panel := _nine("ui_panel.png", 40, 40, 40, 40)
	panel.name = "Sheet"
	panel.custom_minimum_size = Vector2(420, 220)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_top = -140
	panel.offset_right = 210
	panel.offset_bottom = 160
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_child(panel)
	var col := VBoxContainer.new()
	col.name = "Body"
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_top = 28
	col.offset_right = -28
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return dim


func _dialog_body(dialog: ColorRect) -> VBoxContainer:
	return dialog.get_node("Sheet/Body") as VBoxContainer


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1920, 1080))


func _place(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x / DESIGN.x
	node.anchor_top = rect.position.y / DESIGN.y
	node.anchor_right = (rect.position.x + rect.size.x) / DESIGN.x
	node.anchor_bottom = (rect.position.y + rect.size.y) / DESIGN.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


func _tex(file_name: String) -> Texture2D:
	var path := ART + file_name
	if not ResourceLoader.exists(path):
		return null
	var loaded: Variant = load(path)
	return loaded if loaded is Texture2D else null


func _nine(file_name: String, left: int, top: int, right: int, bottom: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = _tex(file_name)
	patch.patch_margin_left = left
	patch.patch_margin_top = top
	patch.patch_margin_right = right
	patch.patch_margin_bottom = bottom
	return patch


func _box(file_name: String, left: int, top: int, right: int, bottom: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _tex(file_name)
	box.texture_margin_left = left
	box.texture_margin_top = top
	box.texture_margin_right = right
	box.texture_margin_bottom = bottom
	return box


func _text_button(text: String, art_name: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.96))
	var box := _box(art_name, 36, 28, 36, 28)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	return button


func _link(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	return button


func _cream(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	return label


func _section(text: String) -> Label:
	var label := _cream(16)
	label.text = text
	return label


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.22, 0.16, 0.1, 0.55) if selected else Color(0.08, 0.06, 0.05, 0.28)
	box.set_border_width_all(2)
	box.border_color = Color(0.93, 0.78, 0.42) if selected else Color(0, 0, 0, 0)
	box.set_corner_radius_all(6)
	box.content_margin_left = 4
	box.content_margin_right = 4
	return box


func _tile_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.07, 0.45)
	box.set_border_width_all(3 if selected else 1)
	box.border_color = Color(0.95, 0.8, 0.4) if selected else Color(0.4, 0.34, 0.26, 0.8)
	box.set_corner_radius_all(8)
	return box


func _hex_of(color: Color) -> String:
	return "#%02x%02x%02x" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))]
