extends Node2D

## One standing NPC. Stand-in art is a class world sprite with a role tint
## and a name plate. The character strips are not edited.
## Y-sorted with props using BoardVisualSort.UNIT_Z_BIAS.

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")

const ROLE_CLASS := {
	"warden": "bastion",
	"trader": "mender",
	"door_keeper": "ironjaw",
	"guide": "kestrel",
	"herald": "kestrel",
	"banker": "mender",
	"elder": "bastion",
	"smith": "ironjaw",
	"fisher": "kestrel",
	"farmer": "mender",
	"woodcutter": "ironjaw",
	"archivist": "gloam",
	"ferry_captain": "kestrel",
	"forge_master": "ironjaw",
	"fen_guide": "gloam",
	"hermit": "gloam",
	"seer": "gloam",
	"last_watcher": "bastion",
	"coil_engineer": "kestrel",
}
const ROLE_TINT := {
	"warden": Color("d7c4a1"),
	"trader": Color("e2b15a"),
	"door_keeper": Color("c46a4a"),
	"guide": Color("f2e6c9"),
	"herald": Color("e8d27a"),
	"banker": Color("8fd0c6"),
	"elder": Color("c9b7e0"),
	"smith": Color("e07a3d"),
	"fisher": Color("7eb6d8"),
	"farmer": Color("b7c86a"),
	"woodcutter": Color("a9845a"),
	"archivist": Color("9aa6d6"),
	"ferry_captain": Color("6fbfc4"),
	"forge_master": Color("e25b3a"),
	"fen_guide": Color("8aaa62"),
	"hermit": Color("6e8f72"),
	"seer": Color("c9a0d8"),
	"last_watcher": Color("7a6ea8"),
	"coil_engineer": Color("9ec4e6"),
}

var npc_id := ""
var role := ""
var display_name := ""
var cell := Vector2i.ZERO
var facing := "s"

var _sprite: Sprite2D
var _strips = null
var _bob := 0.0


func setup(zone: WorldZone, record: Dictionary) -> void:
	npc_id = str(record.get("id", ""))
	role = str(record.get("role", ""))
	display_name = str(record.get("name", ""))
	var at: Dictionary = record.get("cell", {})
	cell = Vector2i(int(at.get("x", 0)), int(at.get("y", 0)))
	facing = str(record.get("facing", "S")).to_lower()
	name = "Npc_%s" % npc_id
	z_as_relative = false
	z_index = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS
	position = Pick.cell_center(zone, cell)
	_strips = Strips.new()
	_strips.load_class(str(ROLE_CLASS.get(role, "kestrel")))
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.offset = _strips.pivot
	_sprite.scale = Vector2.ONE * _strips.scale
	_sprite.modulate = ROLE_TINT.get(role, Color.WHITE)
	add_child(_sprite)
	_apply_idle()
	queue_redraw()


func face(dir: String) -> void:
	var next := dir.to_lower()
	if next != "n" and next != "e" and next != "s" and next != "w":
		return
	facing = next
	_apply_idle()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_bob += delta
	_sprite.position = Vector2(0, sin(_bob * 2.2) * 1.5)


func _apply_idle() -> void:
	if _sprite == null or _strips == null:
		return
	var tex: Texture2D = _strips.idle(facing)
	if tex == null:
		tex = _strips.texture("walk", facing)
	_sprite.texture = tex
	if tex != null and _strips.frame_count("walk", facing) > 1 and _strips.idle(facing) == null:
		var frame: Vector2i = _strips.frame_size("walk")
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(0, 0, frame.x, frame.y)
	else:
		_sprite.region_enabled = false


func _draw() -> void:
	var shadow := PackedVector2Array()
	var steps := 10
	for i in steps:
		var a := float(i) / float(steps) * TAU
		shadow.append(Vector2(cos(a) * 14.0, sin(a) * 5.0 + 4.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	var font := ThemeDB.fallback_font
	var plate := display_name
	var width := font.get_string_size(plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var origin := Vector2(-width * 0.5, -108)
	for nudge in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, origin + nudge, plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.12, 0.08, 0.05))
	draw_string(font, origin, plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.96, 0.88))
