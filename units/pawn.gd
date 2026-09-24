extends Node2D
class_name Pawn

## One Sprite2D child ("Sprite") at the pawn origin. Feet sit on that origin:
## centered, offset (0, -72), scale 0.5. Replace this node with an
## AnimatedSprite2D later; facings stay `<class>_<n|e|s|w>`. Mirrors are baked
## into the files — never set flip_h. Bastion _n/_w are placeholder back views
## loaded from those same filenames.
## `debug_draw_tokens` keeps the old circle token as a fallback.

var grid_position: Vector2i = Vector2i.ZERO
var unit_name: String = ""
var class_id: String = ""
var facing: String = "E"
var seat: int = 0
var hp: int = 80
var max_hp: int = 80
var alive: bool = true
var is_active: bool = false
var stunned: bool = false
var burning: bool = false
var burn_remaining: int = 0
var debug_draw_tokens: bool = false
var _hit_flash: bool = false
var _flashing: bool = false
var _sprite: Sprite2D
var _chrome: StatusChrome

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}
const FACING_ORDER: Array[String] = ["n", "e", "s", "w"]
const SPRITE_OFFSET := Vector2(0, -72)
const SPRITE_SCALE := Vector2(0.5, 0.5)
## Clears the tallest shipped figure (Ironjaw / Bastion ~68px).
const HEAD_HP_Y := -76.0
const NAME_Y := 14.0

static var _sprite_cache: Dictionary = {}


class StatusChrome extends Node2D:
	var host: Pawn

	func _draw() -> void:
		if host != null:
			host._paint_status(self)


## `events` supply Burn only when the unit dict has no `burn_remaining`.
## This pawn does not tick Burn; the next host snapshot replaces the number.
func apply_snapshot(unit: Dictionary, active_seat: int, events: Array = []) -> void:
	grid_position = unit["pos"]
	unit_name = str(unit["name"])
	class_id = str(unit["class_id"])
	facing = str(unit["facing"])
	seat = int(unit.get("seat", seat))
	hp = int(unit["hp"])
	max_hp = int(unit["max_hp"])
	alive = bool(unit["alive"])
	is_active = int(unit["seat"]) == active_seat and alive
	_hit_flash = false
	stunned = int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))
	burn_remaining = CombatHUD.unit_burn_remaining(unit, events)
	burning = burn_remaining > 0
	_sync_sprite()


func burn_badge_label() -> String:
	return CombatHUD.burn_badge_text(burn_remaining)


func set_facing(dir: String) -> void:
	if dir == "" or dir == facing:
		return
	facing = dir
	_sync_sprite()


func flash_hit() -> void:
	_hit_flash = true
	_apply_flash(Color(1.85, 1.55, 1.15))


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
	if _sprite != null:
		return _sprite
	return self


func rest_modulate() -> Color:
	if not alive:
		return Color(0.45, 0.45, 0.45, 1)
	return Color.WHITE


func note_flash_settled() -> void:
	_flashing = false
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = rest_modulate()


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
	var path := sprite_path(class_id, facing)
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
	_request_paint()


func _ensure_visuals() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	_sprite.offset = SPRITE_OFFSET
	_sprite.scale = SPRITE_SCALE
	_sprite.flip_h = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_index = 0
	_sprite.z_as_relative = true
	add_child(_sprite)
	_chrome = StatusChrome.new()
	_chrome.name = "Chrome"
	_chrome.host = self
	_chrome.z_index = 2
	_chrome.z_as_relative = true
	add_child(_chrome)


func _sync_sprite() -> void:
	_ensure_visuals()
	_sprite.flip_h = false
	_sprite.texture = sprite_texture(class_id, facing)
	if not _flashing:
		_sprite.modulate = rest_modulate()
	_request_paint()


func _request_paint() -> void:
	queue_redraw()
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.queue_redraw()


func _sprite_ready() -> bool:
	return _sprite != null and _sprite.texture != null


func _draw() -> void:
	if _sprite_ready():
		_draw_ground_mark()
	if debug_draw_tokens or not _sprite_ready():
		_draw_legacy_token()


func _draw_ground_mark() -> void:
	var foot := Vector2(0, 3)
	_draw_ellipse(foot, 18.0, 7.0, _seat_color())
	_draw_ellipse_ring(foot, 18.0, 7.0, Color(0.1, 0.07, 0.08, 0.85), 1.3)
	if burning:
		_draw_ellipse_ring(foot, 27.0, 10.5, Color(0.95, 0.32, 0.1, 0.95), 2.0)
	if stunned:
		_draw_ellipse_ring(foot, 24.0, 9.2, Color(0.95, 0.78, 0.2, 0.95), 2.0)
	if is_active:
		_draw_ellipse_ring(foot, 21.0, 8.2, Color(1.0, 0.92, 0.45, 1.0), 2.6)


func _paint_status(canvas: CanvasItem) -> void:
	if debug_draw_tokens or not _sprite_ready():
		return
	_paint_unit_chrome(canvas, HEAD_HP_Y, NAME_Y)


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
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	var label_x := -size.x * 0.5
	if class_id == SpellKits.CLASS_IRONJAW:
		label_x += 10.0
	else:
		label_x -= 10.0
	canvas.draw_string(font, Vector2(label_x, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.08, 0.1))
	if stunned:
		var stun_size := font.get_string_size("STUN", HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var stun_y := hp_y - 16.0
		var badge := Rect2(Vector2(-stun_size.x * 0.5 - 3, stun_y), Vector2(stun_size.x + 6, 12))
		canvas.draw_rect(badge, Color(0.95, 0.78, 0.18, 0.95))
		canvas.draw_string(font, Vector2(-stun_size.x * 0.5, stun_y + 10), "STUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.12, 0.08, 0.1))
	if burning:
		var burn_label := burn_badge_label()
		if burn_label == "":
			burn_label = "BURN"
		var burn_size := font.get_string_size(burn_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var burn_y := hp_y - 30.0 if stunned else hp_y - 16.0
		var burn_badge := Rect2(Vector2(-burn_size.x * 0.5 - 3, burn_y), Vector2(burn_size.x + 6, 12))
		canvas.draw_rect(burn_badge, Color(0.92, 0.28, 0.1, 0.95))
		_paint_flame(canvas, Vector2(burn_badge.position.x - 8.0, burn_y + 6.0))
		canvas.draw_string(font, Vector2(-burn_size.x * 0.5, burn_y + 10), burn_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.99, 0.94, 0.88))


func _seat_color() -> Color:
	# Same greens / reds as the P1 / P2 deploy zone highlights.
	if seat == 1:
		return Color(0.78, 0.42, 0.42, 0.92)
	return Color(0.36, 0.72, 0.52, 0.92)


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
	draw_colored_polygon(_ellipse_points(center, rx, ry), color)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := _ellipse_points(center, rx, ry)
	if pts.is_empty():
		return
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


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

