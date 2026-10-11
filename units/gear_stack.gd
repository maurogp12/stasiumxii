extends RefCounted

## Visible gear (paper doll): draws a hero's worn looks on top of one body
## drawable (the world walker's Sprite2D, a pawn's Sprite or strip, or a
## portrait TextureRect). The strips are children of the host, so they take
## its position, scale and modulate and play the same frame.
##
## With nothing worn the host draws the single base sheet and this adds no
## node. With anything worn the host is hidden (self_modulate alpha 0; its
## children still draw) and one child per strip of GearLooks.stack_for draws,
## bottom to top, each showing the cell the host shows.

const LOOKS := preload("res://units/gear_looks.gd")
const PAINTED := preload("res://units/painted_looks.gd")
const NODE_PREFIX := "Gear_"

var host: CanvasItem
var class_id := ""
## slot -> look strip (GearLooks.looks_for).
var looks: Dictionary = {}
var _nodes: Dictionary = {}
var _host_alpha := 1.0
var _hiding := false


func _init(on: CanvasItem = null, cls: String = "") -> void:
	host = on
	class_id = cls.strip_edges().to_lower()


func is_active() -> bool:
	return not looks.is_empty() and host != null and is_instance_valid(host)


## Worn looks changed. Clears every strip node when nothing is worn.
func set_looks(next: Dictionary) -> void:
	looks = next.duplicate()
	if looks.is_empty():
		clear()


func clear() -> void:
	for n in _nodes.values():
		if is_instance_valid(n):
			(n as Node).queue_free()
	_nodes.clear()
	_show_host(true)


## Strip ids currently drawn (bottom to top).
func shown_strips() -> Array[String]:
	var out: Array[String] = []
	if host == null or not is_instance_valid(host):
		return out
	for c in host.get_children():
		if str(c.name).begins_with(NODE_PREFIX) and (c as CanvasItem).visible:
			out.append(str(c.name).trim_prefix(NODE_PREFIX))
	return out


func node_count() -> int:
	return _nodes.size()


func _show_host(on: bool) -> void:
	if host == null or not is_instance_valid(host):
		return
	if on and _hiding:
		host.self_modulate.a = _host_alpha
		_hiding = false
	elif not on and not _hiding:
		_host_alpha = host.self_modulate.a
		host.self_modulate.a = 0.0
		_hiding = true


func _node_for(strip: String, make_rect: bool) -> CanvasItem:
	var n: Variant = _nodes.get(strip, null)
	if n != null and is_instance_valid(n):
		return n
	var made: CanvasItem
	if make_rect:
		var r := TextureRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		made = r
	else:
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		made = s
	made.name = NODE_PREFIX + strip
	host.add_child(made)
	_nodes[strip] = made
	return made


## Order the strip nodes and hide the ones not in `stack`. Returns the nodes.
func _arrange(stack: Array[String], make_rect: bool) -> Array:
	var keep := {}
	for s in stack:
		keep[s] = true
	for strip in _nodes.keys():
		var n: Variant = _nodes[strip]
		if is_instance_valid(n) and not keep.has(strip):
			(n as CanvasItem).visible = false
	var out: Array = []
	for strip in stack:
		var n := _node_for(strip, make_rect)
		host.move_child(n, host.get_child_count() - 1)
		out.append(n)
	return out


## World walker: the host shows `region` of the base sheet of `kind` for art
## facing `art` (S or E), flipped or not, at `offset`.
func sync_region(kind: String, art: String, region: Rect2, flip: bool, offset: Vector2, centered: bool = true) -> void:
	if not is_active():
		_show_host(true)
		return
	var stack := LOOKS.stack_for(class_id, looks, art)
	if stack.is_empty():
		_show_host(true)
		return
	_show_host(false)
	var nodes := _arrange(stack, false)
	for i in stack.size():
		var s := nodes[i] as Sprite2D
		var tex := LOOKS.sheet(class_id, stack[i], kind, art)
		s.texture = tex
		s.visible = tex != null
		s.centered = centered
		s.region_enabled = true
		s.region_rect = region
		s.flip_h = flip
		s.offset = offset


## Pawn: the host shows painted cell `tex` (PAINTED.KEY_META) at `offset`.
func sync_cell(tex: Texture2D, offset: Vector2, centered: bool = true, flip: bool = false) -> void:
	if not is_active() or tex == null or not tex.has_meta(PAINTED.KEY_META):
		_hide_nodes()
		_show_host(true)
		return
	var key: Array = tex.get_meta(PAINTED.KEY_META)
	var kind := str(key[1])
	var letter := str(key[2])
	var idx := int(key[3])
	var stack := LOOKS.stack_for(class_id, looks, PAINTED.art_letter(letter))
	if stack.is_empty():
		_show_host(true)
		return
	_show_host(false)
	var nodes := _arrange(stack, false)
	for i in stack.size():
		var s := nodes[i] as Sprite2D
		var cells := LOOKS.cells(class_id, stack[i], kind, letter)
		var cell: Texture2D = cells[idx] if idx < cells.size() else null
		s.texture = cell
		s.visible = cell != null
		s.centered = centered
		s.region_enabled = false
		s.flip_h = flip
		s.offset = offset


## Portrait: a TextureRect host showing cell 0 of the front idle.
func sync_portrait(kind: String = "idle") -> void:
	if not is_active():
		_show_host(true)
		return
	var stack := LOOKS.stack_for(class_id, looks, "S")
	if stack.is_empty():
		_show_host(true)
		return
	_show_host(false)
	var nodes := _arrange(stack, true)
	var src := host as TextureRect
	var cell: Vector2i = LOOKS.spec(class_id, kind).get("cell", Vector2i.ZERO)
	for i in stack.size():
		var r := nodes[i] as TextureRect
		var sheet := LOOKS.sheet(class_id, stack[i], kind, "S")
		if sheet == null:
			r.visible = false
			continue
		var first := AtlasTexture.new()
		first.atlas = sheet
		first.region = Rect2(Vector2.ZERO, Vector2(cell))
		r.texture = first
		r.visible = true
		if src != null:
			r.expand_mode = src.expand_mode
			r.stretch_mode = src.stretch_mode


func _hide_nodes() -> void:
	for n in _nodes.values():
		if is_instance_valid(n):
			(n as CanvasItem).visible = false
