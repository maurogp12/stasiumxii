extends Control

## Contained 3D stage for the PC character select pedestal and island.
## P1 instances this scene and drops it in the pedestal slot.
## The 3D world exists only inside this viewport. release() frees it.
##
## Body colours are skin, hair, and eyes (§11). Armour is not tinted here.
## Gear dye is a hook: set_gear_dye_mask() stores a mask and leaves
## dye_enabled at 0 for a later premium package.

const ART_ROOT := "res://art/pc/characters_3d"
const SHADER_PATH := "res://scenes/pc/character_select/recolour.gdshader"
const GEAR_SLOTS: PackedStringArray = ["weapon", "head", "chest", "legs", "boots"]
const GENDERS: PackedStringArray = ["m", "f"]
const FACE_MIN := 3
const FACE_MAX := 5
const VIEW_FULL := Vector2i(768, 1024)
const VIEW_HALF := Vector2i(384, 512)
const REST_YAW := -20.0
const DEG_PER_PX := 0.4
const RETURN_DELAY := 2.0
const RETURN_SPEED := 90.0

const DEFAULT_SKIN := Color(0.76, 0.58, 0.46)
const DEFAULT_HAIR := Color(0.25, 0.14, 0.08)
const DEFAULT_EYES := Color(0.22, 0.40, 0.62)

const RIM_BY_CLASS := {
	"kestrel": Color(0.55, 0.78, 1.0),
	"ironjaw": Color(0.88, 0.58, 0.28),
	"mender": Color(0.44, 0.82, 0.72),
	"gloam": Color(0.55, 0.38, 0.85),
	"bastion": Color(0.78, 0.72, 0.48),
	"test": Color(0.88, 0.70, 0.40),
}

var yaw_degrees := REST_YAW

var _view: TextureRect
var _vp: SubViewport
var _camera: Camera3D
var _key: DirectionalLight3D
var _rim: OmniLight3D
var _env: Environment
var _turntable: Node3D
var _model: Node
var _packed: PackedScene
var _player: AnimationPlayer
var _mat: ShaderMaterial
var _class_id := ""
var _gender := ""
var _loaded_path := ""
var _face := 0
var _slots := {}
var _list_mode := false
var _performance := false
var _dragging := false
var _return_hold := RETURN_DELAY
var _focused := true
var _active := true
var _released := false
var _skin := DEFAULT_SKIN
var _hair := DEFAULT_HAIR
var _eyes := DEFAULT_EYES
var _dye_mask: Texture2D


func _ready() -> void:
	_build_world()
	_apply_yaw()
	_sync_updates()


func _exit_tree() -> void:
	_active = false
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_model = null
	_packed = null
	_player = null
	_mat = null
	_vp = null
	_released = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_updates()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		_sync_updates()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true
		_sync_updates()


func _process(delta: float) -> void:
	advance(delta)


static func model_path(class_id: String, gender: String) -> String:
	if not _safe_token(class_id) or not GENDERS.has(gender):
		return ""
	return "%s/%s/%s_%s.glb" % [ART_ROOT, class_id, class_id, gender]


static func placeholder_path(class_id: String) -> String:
	if not _safe_token(class_id):
		return ""
	return "%s/%s/placeholder.glb" % [ART_ROOT, class_id]


## Gendered file if it exists, otherwise the shared placeholder for that class.
## The test capsule is one GLB and serves both m and f.
static func resolve_model_path(class_id: String, gender: String) -> String:
	var gendered := model_path(class_id, gender)
	if gendered != "" and FileAccess.file_exists(gendered):
		return gendered
	var shared := placeholder_path(class_id)
	if shared != "" and FileAccess.file_exists(shared):
		return shared
	return ""


static func _safe_token(token: String) -> bool:
	if token == "" or token.contains("/") or token.contains("\\") or token.contains(".."):
		return false
	return true


## Luminance tint, R then G then B, using the painted albedo's luminance
## for every channel. dye_enabled 0 leaves gear untouched.
static func shade_recolour(
	albedo: Color,
	mask: Color,
	skin: Color,
	hair: Color,
	eyes: Color,
	dye_mask_r: float = 0.0,
	dye: Color = Color.WHITE,
	dye_enabled: float = 0.0
) -> Color:
	var lum := albedo.r * 0.299 + albedo.g * 0.587 + albedo.b * 0.114
	var rgb := Vector3(albedo.r, albedo.g, albedo.b)
	rgb = rgb.lerp(Vector3(lum, lum, lum) * 2.0 * Vector3(skin.r, skin.g, skin.b), mask.r)
	rgb = rgb.lerp(Vector3(lum, lum, lum) * 2.0 * Vector3(hair.r, hair.g, hair.b), mask.g)
	rgb = rgb.lerp(Vector3(lum, lum, lum) * 2.0 * Vector3(eyes.r, eyes.g, eyes.b), mask.b)
	var dye_amt := clampf(dye_mask_r, 0.0, 1.0) * clampf(dye_enabled, 0.0, 1.0)
	rgb = rgb.lerp(Vector3(lum, lum, lum) * 2.0 * Vector3(dye.r, dye.g, dye.b), dye_amt)
	return Color(rgb.x, rgb.y, rgb.z, albedo.a)


func show_model(class_id: String, gender: String) -> bool:
	if _released or _turntable == null:
		return false
	if not _safe_token(class_id) or not GENDERS.has(gender):
		_clear_model()
		return false
	var path := resolve_model_path(class_id, gender)
	if path == "":
		_clear_model()
		_class_id = class_id
		_gender = gender
		return false
	if path != _loaded_path or _packed == null:
		_clear_model()
		var loaded := load(path)
		_packed = loaded as PackedScene
		if _packed == null:
			_loaded_path = ""
			return false
		_loaded_path = path
	else:
		_free_instance()
	_class_id = class_id
	_gender = gender
	_model = _packed.instantiate()
	_turntable.add_child(_model)
	_prepare_model()
	_apply_rim()
	if _list_mode:
		play_idle()
	else:
		play_select()
	return true


func set_body_colors(skin: Color, hair: Color, eyes: Color) -> void:
	_skin = skin
	_hair = hair
	_eyes = eyes
	_push_colors()


func set_face(index: int) -> bool:
	var faces := _face_nodes()
	var ids := {}
	for node in faces:
		ids[_face_ordinal(node)] = true
	if not ids.has(index):
		return false
	_face = index
	for node in faces:
		node.visible = _face_ordinal(node) == index
	if _mat:
		_mat.set_shader_parameter("face_index", float(index))
	return true


func face_index() -> int:
	return _face


func face_count() -> int:
	var ids := {}
	for node in _face_nodes():
		ids[_face_ordinal(node)] = true
	return ids.size()


func set_slot(slot: String, equipped: bool) -> void:
	if not GEAR_SLOTS.has(slot):
		return
	_slots[slot] = equipped
	_apply_slot(slot)


func slot_equipped(slot: String) -> bool:
	return bool(_slots.get(slot, false))


## Stores a gear dye mask. Does not enable dye and does not recolour armour.
func set_gear_dye_mask(mask: Texture2D) -> void:
	_dye_mask = mask
	if _mat:
		_mat.set_shader_parameter("dye_mask", mask)
		_mat.set_shader_parameter("dye_enabled", 0.0)


func dye_enabled() -> bool:
	if _mat == null:
		return false
	return float(_mat.get_shader_parameter("dye_enabled")) > 0.0


func body_material() -> ShaderMaterial:
	return _mat


func set_list_mode(on: bool) -> void:
	_list_mode = on
	if _turntable:
		_turntable.scale = Vector3.ONE * (0.8 if on else 1.0)
	if on:
		play_idle()


func set_performance(on: bool) -> void:
	_performance = on
	_apply_viewport()
	if _player:
		_player.speed_scale = 0.5 if on else 1.0


func play_select() -> void:
	if _list_mode or _player == null:
		return
	if _player.has_animation("select"):
		_player.speed_scale = 0.5 if _performance else 1.0
		_player.play("select")


func play_idle() -> void:
	if _player and _player.has_animation("idle"):
		_player.speed_scale = 0.5 if _performance else 1.0
		_player.play("idle")


func release() -> void:
	if _released:
		return
	_released = true
	_active = false
	_clear_model()
	if _vp and is_inside_tree():
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_vp.queue_free()
	_vp = null


func turn_by_pixels(dx: float) -> void:
	yaw_degrees += dx * DEG_PER_PX
	_return_hold = 0.0
	_apply_yaw()


func advance(delta: float) -> void:
	if _dragging:
		return
	var was := _return_hold
	_return_hold += delta
	if _return_hold < RETURN_DELAY:
		return
	var easing := delta
	if was < RETURN_DELAY:
		easing = _return_hold - RETURN_DELAY
	var next := move_toward(yaw_degrees, REST_YAW, RETURN_SPEED * easing)
	if not is_equal_approx(next, yaw_degrees):
		yaw_degrees = next
		_apply_yaw()


func loaded_path() -> String:
	return _loaded_path


func class_id() -> String:
	return _class_id


func gender() -> String:
	return _gender


func current_animation() -> String:
	if _player == null:
		return ""
	return String(_player.current_animation)


func list_mode() -> bool:
	return _list_mode


func performance_on() -> bool:
	return _performance


func model_root() -> Node:
	return _model


func viewport() -> SubViewport:
	return _vp


func camera() -> Camera3D:
	return _camera


func key_light() -> DirectionalLight3D:
	return _key


func rim_light() -> OmniLight3D:
	return _rim


func fill_environment() -> Environment:
	return _env


func turntable() -> Node3D:
	return _turntable


func zone_node(node_name: String) -> Node:
	return _find(node_name)


func _build_world() -> void:
	var shadow := TextureRect.new()
	shadow.name = "ContactShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.texture = _contact_blob()
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.anchor_left = 0.5
	shadow.anchor_right = 0.5
	shadow.anchor_top = 1.0
	shadow.anchor_bottom = 1.0
	shadow.offset_left = -110.0
	shadow.offset_right = 110.0
	shadow.offset_top = -48.0
	shadow.offset_bottom = -12.0
	add_child(shadow)

	# A SubViewportContainer rewrites the update mode on show and, with
	# stretch on, replaces 768x1024 with the control size. The portrait is
	# a texture rect so the render size stays put and still fills the slot.
	_vp = SubViewport.new()
	_vp.name = "Stage"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.handle_input_locally = false
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)

	_view = TextureRect.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture = _vp.get_texture()
	add_child(_view)
	_view.gui_input.connect(_on_view_gui_input)

	var fill := WorldEnvironment.new()
	fill.name = "Fill"
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1, 1, 1, 1)
	_env.ambient_light_energy = 0.35
	_env.sdfgi_enabled = false
	_env.ssr_enabled = false
	_env.ssao_enabled = false
	_env.glow_enabled = false
	_env.volumetric_fog_enabled = false
	fill.environment = _env
	_vp.add_child(fill)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 28.0
	_camera.current = true
	_camera.position = Vector3(0, 1.25, 4.2)
	_vp.add_child(_camera)
	_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)

	_key = DirectionalLight3D.new()
	_key.name = "Key"
	_key.light_color = Color(1.0, 0.93, 0.82)
	_key.light_energy = 1.2
	_key.shadow_enabled = false
	_key.rotation_degrees = Vector3(-35, 35, 0)
	_vp.add_child(_key)

	_rim = OmniLight3D.new()
	_rim.name = "Rim"
	_rim.light_energy = 2.0
	_rim.omni_range = 4.0
	_rim.shadow_enabled = false
	_rim.position = Vector3(-0.45, 2.15, -1.25)
	_rim.light_color = RIM_BY_CLASS["test"]
	_vp.add_child(_rim)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_vp.add_child(_turntable)
	_apply_viewport()


func _apply_viewport() -> void:
	if _vp == null:
		return
	if _performance:
		_vp.size = VIEW_HALF
		_vp.msaa_3d = Viewport.MSAA_DISABLED
	else:
		_vp.size = VIEW_FULL
		_vp.msaa_3d = Viewport.MSAA_2X


func _sync_updates() -> void:
	if _vp == null:
		return
	var on := _active and _focused and visible
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if on else SubViewport.UPDATE_DISABLED


func _on_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if not event.pressed:
			_return_hold = 0.0
	elif event is InputEventMouseMotion and _dragging:
		turn_by_pixels(event.relative.x)


func _apply_yaw() -> void:
	if _turntable:
		_turntable.rotation_degrees = Vector3(0, yaw_degrees, 0)
		if _list_mode:
			_turntable.scale = Vector3.ONE * 0.8


func _prepare_model() -> void:
	_slots.clear()
	for slot in GEAR_SLOTS:
		_slots[slot] = false
	_face = 0
	_bind_material()
	_apply_gear_visibility()
	set_face(0)
	_bind_anims()


func _bind_material() -> void:
	var shader := load(SHADER_PATH) as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	var folder := _loaded_path.get_base_dir()
	var albedo_path := folder.path_join("albedo.png")
	var mask_path := folder.path_join("mask.png")
	if FileAccess.file_exists(albedo_path):
		_mat.set_shader_parameter("albedo_tex", load(albedo_path))
	if FileAccess.file_exists(mask_path):
		_mat.set_shader_parameter("mask_tex", load(mask_path))
	_mat.set_shader_parameter("dye_enabled", 0.0)
	_mat.set_shader_parameter("face_index", 0.0)
	if _dye_mask:
		_mat.set_shader_parameter("dye_mask", _dye_mask)
	_push_colors()
	_apply_mat(_model)


func _push_colors() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("skin", Vector3(_skin.r, _skin.g, _skin.b))
	_mat.set_shader_parameter("hair", Vector3(_hair.r, _hair.g, _hair.b))
	_mat.set_shader_parameter("eyes", Vector3(_eyes.r, _eyes.g, _eyes.b))


func _apply_mat(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var surfaces := mi.mesh.get_surface_count() if mi.mesh else 0
		for i in surfaces:
			mi.set_surface_override_material(i, _mat)
	for child in node.get_children():
		_apply_mat(child)


func _bind_anims() -> void:
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	if _player.has_animation("idle"):
		_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	if _player.has_animation("select"):
		_player.get_animation("select").loop_mode = Animation.LOOP_NONE
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	_player.speed_scale = 0.5 if _performance else 1.0


func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == "select":
		play_idle()


func _apply_gear_visibility() -> void:
	for slot in GEAR_SLOTS:
		_apply_slot(slot)


func _apply_slot(slot: String) -> void:
	var equipped := bool(_slots.get(slot, false))
	var base := _find("base_" + slot)
	var gear := _find("gear_" + slot)
	if base:
		base.visible = not equipped
	if gear:
		gear.visible = equipped


func _apply_rim() -> void:
	if _rim == null:
		return
	_rim.light_color = RIM_BY_CLASS.get(_class_id, RIM_BY_CLASS["test"])


func _face_nodes() -> Array:
	var found: Array = []
	if _model:
		_collect_faces(_model, found)
	found.sort_custom(func(a: Node, b: Node) -> bool:
		return _face_ordinal(a) < _face_ordinal(b)
	)
	return found


func _collect_faces(node: Node, found: Array) -> void:
	if _face_ordinal(node) >= 0 and node != _model:
		found.append(node)
	for child in node.get_children():
		_collect_faces(child, found)


func _face_ordinal(node: Node) -> int:
	var text := String(node.name)
	if not text.begins_with("face_"):
		return -1
	var suffix := text.trim_prefix("face_")
	var head := suffix.split("_")[0]
	if not head.is_valid_int():
		return -1
	return head.to_int()


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _free_instance() -> void:
	if _model:
		_model.queue_free()
		_model = null
	_player = null
	_mat = null


func _clear_model() -> void:
	_free_instance()
	_packed = null
	_loaded_path = ""


func _contact_blob() -> Texture2D:
	var image := Image.create(128, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(64, 24)
	for y in 48:
		for x in 128:
			var d := Vector2((float(x) - center.x) / 58.0, (float(y) - center.y) / 16.0).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(0, 0, 0, a * a * 0.45))
	return ImageTexture.create_from_image(image)
