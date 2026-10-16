extends Node2D

## VIEW ONLY. The open-world monster packs and rare bosses on the map
## (package Z1). backend/world_monsters.gd decides where packs stand, their
## size and levels, respawn and the boss clock; this node draws them and
## hands clicks and walk-ins to the world.
##
## - A pack reads as a group (Mauro's pick): up to `visible_bodies` bodies
##   stand together on their own cells; a bigger pack adds a count badge.
## - Bodies idle on their painted S/E loops (W/N mirrored) and the pack
##   wanders a little round its home every few seconds.
## - Hover shows the Wakfu plate: size, level range, total level; red when
##   the pack is 5+ levels above the hero.
## - A boss up has a stronger rim glow, an aura and a marker above it.
## - Performance mode: no wander, idle loops held on their first frame.
##
## Packs and the boss clock live in `state` (static), so they survive the
## scene swap into a fight and back.

signal fight_requested(entry: Dictionary)
signal boss_event(event: Dictionary)

const Mobs := preload("res://backend/world_monsters.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Levels := preload("res://backend/world_levels.gd")
## The painted hero is ~255 px tall in a 512x360 monster cell.
const CELL_HERO_PX := 255.0
const BADGE_FONT := 15

## chunk_id -> {entries: [...], dead: {entry_id: respawn_at_s}}; clock; trophies.
static var state: Dictionary = {}
static var clock_s := 0.0

var book = null
var levels = null
var host: Node = null
var zone: WorldZone
var plane_origin := Vector2i.ZERO
var hero_px := 54.0
var performance := false
var forbidden: Dictionary = {}
var plates: CanvasLayer
var _plate: PanelContainer
var _plate_label: RichTextLabel
var _nodes: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _manifest: Dictionary = {}
var _hover_id := ""
var _boss_clock = null


func setup(the_host: Node, plate_layer: CanvasLayer) -> void:
	host = the_host
	plates = plate_layer
	var loaded: Dictionary = Mobs.load_default()
	book = loaded["book"] if bool(loaded.get("ok", false)) else null
	var lv: Dictionary = Levels.load_default()
	levels = lv["levels"] if bool(lv.get("ok", false)) else null
	_rng.seed = 41017
	z_as_relative = false
	_build_plate()


static func reset_state() -> void:
	state = {}
	clock_s = 0.0


## The boss clock for a zone (one per zone, kept in `state`).
func boss_clock(zone_id: String):
	var key := "clock:" + zone_id
	if not state.has(key):
		state[key] = Mobs.BossClock.new(book, zone_id)
	return state[key]


## Spawn the loaded chunk's packs (and any boss that is up in it).
## `npc_cells` / `door_cells` are the chunk's safe marks.
func restock(z: WorldZone, origin: Vector2i, npc_cells: Array = [], door_cells: Array = []) -> void:
	for n in _nodes.values():
		(n as Node).free()
	_nodes.clear()
	_hover_id = ""
	_hide_plate()
	zone = z
	plane_origin = origin
	if book == null or z == null:
		return
	forbidden = book.forbidden_cells(z, npc_cells, door_cells)
	var zid: String = book.zone_of_chunk(z.zone_id)
	if zid == "":
		return
	_manifest = Art.manifest(book.art_path(zid))
	var cs := _chunk_state(z)
	for entry in cs["entries"]:
		if not (cs["dead"] as Dictionary).has(entry["id"]):
			_spawn_node(entry)
	_sync_bosses()


func _chunk_state(z: WorldZone) -> Dictionary:
	if not state.has(z.zone_id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(z.zone_id) & 0x7fffffff
		state[z.zone_id] = {"entries": book.place_packs(z, levels, rng, forbidden), "dead": {}, "bosses": {}}
	return state[z.zone_id]


## Entries standing in the loaded chunk (packs and bosses up).
func live_entries() -> Array:
	var out: Array = []
	for id in _nodes.keys():
		out.append((_nodes[id] as Node).get_meta("entry"))
	return out


func entry_at(cell: Vector2i) -> Dictionary:
	for id in _nodes.keys():
		var e: Dictionary = (_nodes[id] as Node).get_meta("entry")
		if (e["cells"] as Array).has(cell):
			return e
	return {}


## A pack whose body is next to (or on) `cell` - the hero walked into it.
func entry_touching(cell: Vector2i) -> Dictionary:
	for id in _nodes.keys():
		var e: Dictionary = (_nodes[id] as Node).get_meta("entry")
		for c in e["cells"]:
			if maxi(absi((c as Vector2i).x - cell.x), absi((c as Vector2i).y - cell.y)) <= 1:
				return e
	return {}


func occupied() -> Dictionary:
	var out := {}
	for e in live_entries():
		for c in e["cells"]:
			out[c] = true
	return out


## Defeated: hide it, respawn later (bosses go on cooldown instead).
func mark_defeated(entry_id: String, boss_id: String = "") -> void:
	for cid in state.keys():
		if typeof(state[cid]) != TYPE_DICTIONARY or not (state[cid] as Dictionary).has("dead"):
			continue
		var cs: Dictionary = state[cid]
		for e in cs["entries"]:
			if str(e["id"]) == entry_id:
				cs["dead"][entry_id] = clock_s + float(book.rule("respawn_s", 90))
		if boss_id != "" and (cs["bosses"] as Dictionary).has(boss_id):
			cs["bosses"].erase(boss_id)
	if boss_id != "" and book != null:
		var zid := str(book.row(boss_id).get("zone", ""))
		boss_clock(zid).defeated(boss_id)
	if _nodes.has(entry_id):
		(_nodes[entry_id] as Node).queue_free()
		_nodes.erase(entry_id)


## Advance timers: respawns (away from the hero), wander, boss clock.
func tick(delta: float, env: Dictionary, hero_cell: Vector2i) -> void:
	clock_s += delta
	if book == null or zone == null:
		return
	var cs: Dictionary = state.get(zone.zone_id, {})
	if not cs.is_empty():
		for id in (cs["dead"] as Dictionary).keys():
			if clock_s >= float(cs["dead"][id]):
				var entry := _entry_by_id(cs, str(id))
				if entry.is_empty():
					cs["dead"].erase(id)
					continue
				if _near(entry, hero_cell, 6):
					continue
				# A fresh pack (size and levels re-rolled) on its old home.
				var fresh: Dictionary = book.make_pack(levels, zone.zone_id, _rng)
				var cells: Array = book.body_cells(zone, entry["home"], mini(int(fresh["size"]), int(book.rule("visible_bodies", 6))), forbidden, _taken_except(str(id)))
				if cells.size() < mini(int(fresh["size"]), int(book.rule("visible_bodies", 6))):
					continue
				entry["pack"] = fresh
				entry["cells"] = cells
				cs["dead"].erase(id)
				_spawn_node(entry)
	var zid: String = book.zone_of_chunk(zone.zone_id)
	if zid != "":
		for ev in boss_clock(zid).tick(delta, env, _rng):
			_on_boss_event(ev)
	if performance:
		return
	for id in _nodes.keys():
		var node: Node2D = _nodes[id]
		var t := float(node.get_meta("next_wander", 0.0)) - delta
		if t > 0.0:
			node.set_meta("next_wander", t)
			continue
		var w: Array = book.rule("wander_every_s", [6.0, 12.0])
		node.set_meta("next_wander", _rng.randf_range(float(w[0]), float(w[1])))
		var entry: Dictionary = node.get_meta("entry")
		if bool(entry.get("pack", {}).get("boss", false)) or _near(entry, hero_cell, 2):
			continue
		var step: Dictionary = book.wander(zone, entry, entry.get("anchor", entry["home"]), _rng, forbidden, _taken_except(str(id)))
		if step.is_empty():
			continue
		if not entry.has("anchor"):
			entry["anchor"] = entry["home"]
		entry["home"] = step["home"]
		entry["cells"] = step["cells"]
		_walk_bodies(node, entry)


## Force a boss up now (dev / capture command): `/boss <id>` in the world.
func force_boss(boss_id: String) -> Dictionary:
	if book == null or not book.has(boss_id):
		return {}
	var zid := str(book.row(boss_id).get("zone", ""))
	var ev: Dictionary = boss_clock(zid).spawn(boss_id, "forced")
	if not ev.is_empty():
		_on_boss_event(ev)
	return ev


func _on_boss_event(ev: Dictionary) -> void:
	var boss_id := str(ev.get("boss", ""))
	var info: Dictionary = book.row(boss_id).get("boss", {})
	var chunk := str((info.get("chunks", [""]) as Array)[0])
	if not state.has(chunk):
		state[chunk] = {"entries": [], "dead": {}, "bosses": {}}
	var cs: Dictionary = state[chunk]
	if str(ev["type"]) == "spawn":
		var entry := {"id": "boss:" + boss_id, "chunk": chunk, "pack": book.boss_pack(boss_id), "home": Vector2i(-1, -1), "cells": []}
		cs["bosses"][boss_id] = entry
		if zone != null and zone.zone_id == chunk:
			_place_boss(entry)
			_play_entrance(str(entry["id"]))
		ev["banner"] = str(info.get("banner", ""))
	else:
		cs["bosses"].erase(boss_id)
		var nid := "boss:" + boss_id
		if _nodes.has(nid):
			(_nodes[nid] as Node).queue_free()
			_nodes.erase(nid)
		ev["banner"] = str(info.get("leave_text", ""))
	boss_event.emit(ev)


## A boss that just came plays its entrance (owl drops in, toad heaves out
## of the mud, stag strides in), then idles.
func _play_entrance(entry_id: String) -> void:
	if not _nodes.has(entry_id) or performance:
		return
	for child in (_nodes[entry_id] as Node).get_children():
		if child.has_meta("monster") and child.get_node_or_null("Aura") != null:
			var spr: AnimatedSprite2D = child.get_node("Body")
			var face := "S" if str(spr.animation).ends_with("_s") else "E"
			if spr.sprite_frames != null and spr.sprite_frames.has_animation("enter_" + face.to_lower()):
				spr.play("enter_" + face.to_lower())
				spr.animation_finished.connect(func(): _play(spr, "idle", face, spr.flip_h), CONNECT_ONE_SHOT)


func _sync_bosses() -> void:
	var cs: Dictionary = state.get(zone.zone_id, {})
	for boss_id in (cs.get("bosses", {}) as Dictionary).keys():
		_place_boss(cs["bosses"][boss_id])


func _place_boss(entry: Dictionary) -> void:
	if zone == null:
		return
	if entry["home"] == Vector2i(-1, -1) or not book.spawn_ok(zone, entry["home"], forbidden):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(entry["id"]) + str(clock_s)) & 0x7fffffff
		for i in 300:
			var home := Vector2i(rng.randi_range(3, zone.width - 4), rng.randi_range(3, zone.height - 4))
			if not book.spawn_ok(zone, home, forbidden) or occupied().has(home):
				continue
			var cells: Array = book.body_cells(zone, home, mini(int(entry["pack"]["size"]), int(book.rule("visible_bodies", 6))), forbidden, occupied())
			if cells.size() >= 3:
				entry["home"] = home
				entry["cells"] = cells
				break
	if entry["home"] == Vector2i(-1, -1):
		return
	_spawn_node(entry)


# ------------------------------------------------------------------ hover

func hover(cell: Vector2i, screen_pos: Vector2, hero_level: int) -> bool:
	var e := entry_at(cell)
	if e.is_empty():
		if _hover_id != "":
			_set_rim(_hover_id, false)
		_hover_id = ""
		_hide_plate()
		return false
	if _hover_id != str(e["id"]):
		if _hover_id != "":
			_set_rim(_hover_id, false)
		_hover_id = str(e["id"])
		_set_rim(_hover_id, true)
	var lines: Dictionary = book.plate_lines(e["pack"], hero_level)
	var col := "#ff7a66" if bool(lines["red"]) else "#f5d27a"
	_plate_label.text = "[b][color=%s]%s[/color][/b]\n[color=%s]%s[/color]\n[font_size=12][color=#d9cfbd]%s[/color][/font_size]" % ["#ff9a88" if bool(lines["red"]) else "#fff3dc", lines["title"], col, lines["total"], lines["members"]]
	(_plate.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(col)
	_plate.visible = true
	_plate.reset_size()
	_plate.position = screen_pos + Vector2(18, -_plate.size.y - 12)
	return true


func plate_text() -> String:
	return _plate_label.text if _plate != null and _plate.visible else ""


func _build_plate() -> void:
	if plates == null:
		return
	_plate = PanelContainer.new()
	_plate.name = "MobPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.09, 0.92)
	sb.border_color = Color(0.96, 0.82, 0.48)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	_plate.add_theme_stylebox_override("panel", sb)
	_plate_label = RichTextLabel.new()
	_plate_label.bbcode_enabled = true
	_plate_label.fit_content = true
	_plate_label.scroll_active = false
	_plate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_plate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_label.add_theme_font_size_override("normal_font_size", 15)
	_plate_label.add_theme_font_size_override("bold_font_size", 16)
	_plate.add_child(_plate_label)
	_plate.visible = false
	plates.add_child(_plate)


func _hide_plate() -> void:
	if _plate != null:
		_plate.visible = false


# ------------------------------------------------------------------ drawing

func _spawn_node(entry: Dictionary) -> void:
	var node := Node2D.new()
	node.name = "Pack_" + str(entry["id"]).replace("#", "_").replace(":", "_")
	node.z_as_relative = false
	node.set_meta("entry", entry)
	node.set_meta("next_wander", _rng.randf_range(2.0, 9.0))
	add_child(node)
	_nodes[entry["id"]] = node
	var pack: Dictionary = entry["pack"]
	var members: Array = pack["members"]
	var shown := mini(members.size(), (entry["cells"] as Array).size())
	for i in shown:
		var m: Dictionary = members[i]
		var body := _make_body(str(m["monster"]), bool(pack.get("boss", false)) and i == 0)
		node.add_child(body)
	_place_bodies(node, entry, false)
	if int(pack["size"]) > shown:
		var badge := _Badge.new()
		badge.count = int(pack["size"])
		badge.name = "Badge"
		node.add_child(badge)
	if bool(pack.get("boss", false)):
		var mark := _BossMark.new()
		mark.name = "BossMark"
		var aura: Array = (book.row(str(pack["boss_id"])).get("boss", {}) as Dictionary).get("aura", [1, 0.9, 0.6])
		mark.tint = Color(float(aura[0]), float(aura[1]), float(aura[2]))
		node.add_child(mark)
	_place_extras(node, entry)


func _make_body(monster_id: String, boss: bool) -> Node2D:
	var holder := Node2D.new()
	holder.z_as_relative = false
	holder.set_meta("monster", monster_id)
	var art: Dictionary = Art.monster_frames(_manifest, monster_id)
	var spr := AnimatedSprite2D.new()
	spr.name = "Body"
	spr.centered = false
	spr.sprite_frames = art["frames"]
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Kit frames are cut at Art.MONSTER_KEEP of the 512x360 cell.
	var s := hero_px / CELL_HERO_PX / Art.MONSTER_KEEP * float(book.row(monster_id).get("map_scale", 1.0))
	if not bool(art.get("painted", false)):
		# Drawn stand-in (no kit frames yet): 128x160 cells.
		s = hero_px * 0.8 / 160.0
	spr.scale = Vector2(s, s)
	var piv: Vector2 = art.get("pivot", Vector2(256, 329))
	if piv.x < 0:
		piv = Vector2(256, 329)
	spr.offset = -piv
	holder.add_child(spr)
	holder.set_meta("art", art)
	if boss:
		var glow := Sprite2D.new()
		glow.name = "Aura"
		glow.texture = _aura_tex()
		glow.scale = Vector2(hero_px / 40.0, hero_px / 80.0)
		glow.modulate = Color(1, 0.9, 0.6, 0.55)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.show_behind_parent = false
		glow.z_index = -1
		holder.add_child(glow)
		holder.move_child(glow, 0)
		var rim := _rim_material(Color(1.0, 0.85, 0.5), 2.2)
		spr.material = rim
	# No pack in lockstep: each body runs its loops a little faster or slower.
	spr.speed_scale = _rng.randf_range(0.88, 1.12)
	holder.set_meta("anim_rate", spr.speed_scale)
	_play(spr, "idle", "S" if _rng.randf() < 0.5 else "E", _rng.randf() < 0.5)
	return holder


func _play(spr: AnimatedSprite2D, anim: String, face: String, flip: bool) -> void:
	var name := "%s_%s" % [anim, face.to_lower()]
	if spr.sprite_frames == null or not spr.sprite_frames.has_animation(name):
		name = "idle_s"
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(name):
			return
	spr.flip_h = flip
	if spr.animation != name:
		spr.animation = name
	if performance:
		spr.stop()
		spr.frame = 0
	else:
		spr.play(name)
		spr.frame = _rng.randi() % maxi(spr.sprite_frames.get_frame_count(name), 1)


func _cell_px(c: Vector2i) -> Vector2:
	var h := float(zone.height_at(c)) if zone != null and zone.in_bounds(c) else 0.0
	return BoardVisualSort.cell_to_local(plane_origin + c, h)


func _z_of(c: Vector2i) -> int:
	var w := plane_origin + c
	return clampi((w.x + w.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS, -4096, 4096)


func _place_bodies(node: Node2D, entry: Dictionary, _walk: bool) -> void:
	var cells: Array = entry["cells"]
	var i := 0
	for child in node.get_children():
		if not child.has_meta("monster"):
			continue
		if i >= cells.size():
			break
		var c: Vector2i = cells[i]
		(child as Node2D).position = _cell_px(c)
		(child as Node2D).z_index = _z_of(c)
		i += 1


func _place_extras(node: Node2D, entry: Dictionary) -> void:
	var lead: Vector2i = (entry["cells"] as Array)[0]
	var top := _cell_px(lead)
	for child in node.get_children():
		if child is _Badge:
			(child as Node2D).position = top + Vector2(hero_px * 0.55, -hero_px * 0.25)
			(child as Node2D).z_index = clampi(_z_of(lead) + 40, -4096, 4096)
		elif child is _BossMark:
			(child as Node2D).position = top + Vector2(0, -hero_px * 1.9)
			(child as Node2D).z_index = clampi(_z_of(lead) + 40, -4096, 4096)


## Walk the bodies to their new cells. The leader goes first and the others
## follow loosely (a short random delay, a slightly different pace). Each
## body eases in and out, and its walk cycle runs at the speed it moves, so
## the feet stay planted (the cycle's ground speed is in the kit meta). A turn
## to the opposite diagonal goes through the in-between facing.
func _walk_bodies(node: Node2D, entry: Dictionary) -> void:
	var cells: Array = entry["cells"]
	var i := 0
	for child in node.get_children():
		if not child.has_meta("monster"):
			continue
		if i >= cells.size():
			break
		var holder: Node2D = child
		var to := _cell_px(cells[i])
		var delay := 0.0 if i == 0 else _rng.randf_range(0.12, 0.55)
		var pace := 1.0 if i == 0 else _rng.randf_range(0.9, 1.08)
		_walk_one(holder, to, delay, pace)
		holder.z_index = _z_of(cells[i])
		i += 1
	_place_extras(node, entry)


func _walk_one(holder: Node2D, to: Vector2, delay: float, pace: float) -> void:
	var spr: AnimatedSprite2D = holder.get_node("Body")
	var from := holder.position
	var d := to - from
	if d.length() < 0.5:
		return
	var face := "S" if d.y >= 0 else "E"
	var flip := d.x < 0
	var rate := float(holder.get_meta("anim_rate", 1.0)) * pace
	var cruise := stride_speed(str(holder.get_meta("monster")), spr, rate)
	var dur := d.length() / maxf(cruise, 1.0)
	# Ease in / out over a short ramp; the cycle's rate follows the speed.
	var ramp := minf(0.35, dur * 0.3)
	var total := dur + ramp
	if holder.has_meta("walk_tween"):
		var old: Tween = holder.get_meta("walk_tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := holder.create_tween()
	holder.set_meta("walk_tween", tw)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): _turn_to(spr, face, flip, "walk"))
	tw.tween_method(func(u: float) -> void:
		var s := _ramp_pos(u, ramp / total)
		holder.position = from.lerp(to, s)
		spr.speed_scale = rate * maxf(_ramp_speed(u, ramp / total), 0.05)
	, 0.0, 1.0, total)
	tw.tween_callback(func():
		spr.speed_scale = holder.get_meta("anim_rate", 1.0)
		# Settle, and now and then look round before idling.
		_play(spr, "idle2" if _rng.randf() < 0.35 else "idle", face, flip))


## Position along a move with eased start and stop: constant speed in the
## middle, smooth ramps of fraction r at both ends (u, r in 0..1).
static func _ramp_pos(u: float, r: float) -> float:
	r = clampf(r, 0.001, 0.49)
	var vmax := 1.0 / (1.0 - r)
	if u < r:
		return 0.5 * vmax * u * u / r
	if u > 1.0 - r:
		var w := 1.0 - u
		return 1.0 - 0.5 * vmax * w * w / r
	return 0.5 * vmax * r + vmax * (u - r)


static func _ramp_speed(u: float, r: float) -> float:
	r = clampf(r, 0.001, 0.49)
	if u < r:
		return u / r
	if u > 1.0 - r:
		return (1.0 - u) / r
	return 1.0


## Map px per second at which this creature's walk cycle plants its feet:
## the kit's gait speed (cell px per frame) x fps x the sprite's scale.
func stride_speed(monster_id: String, spr: AnimatedSprite2D, rate: float = 1.0) -> float:
	var g := _gait(monster_id)
	var per_frame := float(g.get("speed_px_per_frame", 0.0))
	if per_frame <= 0.0:
		per_frame = 3.0  # flyers drift at about a walker's pace
	return per_frame * 17.144 * Art.MONSTER_KEEP * spr.scale.x * rate


static var _gaits: Dictionary = {}


func _gait(monster_id: String) -> Dictionary:
	if not _gaits.has(monster_id):
		var p := "%s/monsters/%s/meta.json" % [str(_manifest.get("dir", "")), monster_id]
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
		var g: Dictionary = (meta as Dictionary).get("gait", {}).get("S", {}) if typeof(meta) == TYPE_DICTIONARY else {}
		_gaits[monster_id] = g
	return _gaits[monster_id]


## Face a new way. To the opposite diagonal (front <-> back, or a mirror
## flip) it passes through the in-between facing for a beat.
func _turn_to(spr: AnimatedSprite2D, face: String, flip: bool, anim: String) -> void:
	var cur_face := "S" if str(spr.animation).ends_with("_s") else "E"
	var cur_flip := spr.flip_h
	if cur_face != face and cur_flip != flip and not performance:
		_play(spr, anim, face, cur_flip)
		var t := get_tree().create_timer(0.12) if is_inside_tree() else null
		if t != null:
			t.timeout.connect(func(): _play(spr, anim, face, flip))
			return
	_play(spr, anim, face, flip)


func _set_rim(entry_id: String, on: bool) -> void:
	if not _nodes.has(entry_id):
		return
	for child in (_nodes[entry_id] as Node).get_children():
		if not child.has_meta("monster"):
			continue
		var spr: AnimatedSprite2D = child.get_node("Body")
		var boss := (child as Node).get_node_or_null("Aura") != null
		if on:
			spr.material = _rim_material(Color(1.0, 0.95, 0.7) if not boss else Color(1.0, 0.85, 0.5), 2.6 if boss else 1.6)
		else:
			spr.material = _rim_material(Color(1.0, 0.85, 0.5), 2.2) if boss else null


static var _rim_shader: Shader
static var _aura: Texture2D


static func _rim_material(col: Color, width: float) -> ShaderMaterial:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = """
shader_type canvas_item;
uniform vec4 rim : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float width = 1.6;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width * 3.0;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float edge = clamp(a - c.a, 0.0, 1.0);
	COLOR = mix(c, vec4(rim.rgb, 1.0), edge * rim.a);
	COLOR.a = max(c.a, edge * rim.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _rim_shader
	m.set_shader_parameter("rim", col)
	m.set_shader_parameter("width", width)
	return m


static func _aura_tex() -> Texture2D:
	if _aura == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.9))
		g.set_color(1, Color(1, 1, 1, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_aura = t
	return _aura


func set_performance(on: bool) -> void:
	performance = on
	for node in _nodes.values():
		for child in (node as Node).get_children():
			if child.has_meta("monster"):
				var spr: AnimatedSprite2D = child.get_node("Body")
				if on:
					spr.stop()
					spr.frame = 0
				else:
					spr.play()


## Bodies animating now (Performance mode keeps this at 0).
func playing_count() -> int:
	var n := 0
	for node in _nodes.values():
		for child in (node as Node).get_children():
			if child.has_meta("monster") and (child.get_node("Body") as AnimatedSprite2D).is_playing():
				n += 1
	return n


func _entry_by_id(cs: Dictionary, id: String) -> Dictionary:
	for e in cs["entries"]:
		if str(e["id"]) == id:
			return e
	return {}


func _taken_except(id: String) -> Dictionary:
	var out := {}
	for e in live_entries():
		if str(e["id"]) == id:
			continue
		for c in e["cells"]:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					out[(c as Vector2i) + Vector2i(dx, dy)] = true
	return out


static func _near(entry: Dictionary, cell: Vector2i, r: int) -> bool:
	for c in entry["cells"]:
		if maxi(absi((c as Vector2i).x - cell.x), absi((c as Vector2i).y - cell.y)) <= r:
			return true
	return false


class _Badge extends Node2D:
	var count := 0

	func _ready() -> void:
		z_as_relative = false

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 12.0, Color(0.08, 0.07, 0.09, 0.92))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 28, Color(0.96, 0.82, 0.48), 2.0)
		var f := ThemeDB.fallback_font
		var t := "×%d" % count
		var sz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(f, Vector2(-sz.x * 0.5, 4.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.86, 0.55))


class _BossMark extends Node2D:
	var tint := Color(1, 0.9, 0.6)
	var _t := 0.0

	func _ready() -> void:
		z_as_relative = false

	func _process(delta: float) -> void:
		if not VisualSettings.still():
			_t += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_t * 2.4) * 3.0
		var c := Vector2(0, bob)
		var pts := PackedVector2Array([c + Vector2(-11, -2), c + Vector2(-7, -14), c + Vector2(-2, -5), c + Vector2(0, -17), c + Vector2(2, -5), c + Vector2(7, -14), c + Vector2(11, -2)])
		draw_circle(c + Vector2(0, -8), 17.0, Color(tint.r, tint.g, tint.b, 0.22))
		draw_colored_polygon(pts, Color(0.98, 0.78, 0.3))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.25, 0.12, 0.05), 1.5)
		draw_line(c + Vector2(0, 2), c + Vector2(0, 10), Color(0.98, 0.78, 0.3), 2.0)
