extends RefCounted

## Blightwood Hollow kit. Zone terrain ids stay the Crosshaven grammar
## (farm_* reads as grass or ash, dirt_road as stone). This only picks art.
## Kit v2 (trees, props, ground, fx) lives under v2/ and is drawn on top of
## that grammar. The meadow joins stay the v1 blend tiles.

const ROOT := "res://art/world/blightwood_hollow/"
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

const TALL := ["dead_tree_tall_a", "dead_tree_tall_b", "dead_tree_tall_c"]
const MID := ["dead_tree_mid_a", "dead_tree_mid_b"]
const STONES := ["gravestone_cross", "gravestone_split", "gravestone_cracked"]
const CLUTTER := ["bones_skull", "crow_walking", "crow_perched", "bones_skull"]

## The screen grade pushes blue. The v2 ground tiles are pre-balanced so leaf
## litter stays brown, the path stays darker, and moss stays a dull green.
const FLOOR_MOD := {
	"leaf_litter": Color.WHITE,
	"root_soil": Color.WHITE,
	"trodden_path": Color.WHITE,
	"moss_mushroom": Color.WHITE,
}

static var _cache := {}


static func texture(kind: String, id: String) -> Dictionary:
	var key := kind + "/" + id
	if _cache.has(key):
		return _cache[key]
	var out := _load(ROOT + kind, id)
	if out.is_empty():
		for folder in ["props", "trees", "ground", "fx"]:
			out = v2_texture(folder, id)
			if not out.is_empty():
				break
	_cache[key] = out
	return out


static func v2_texture(folder: String, id: String) -> Dictionary:
	var key := "v2/" + folder + "/" + id
	if _cache.has(key):
		return _cache[key]
	var out := _load(ROOT + "v2/" + folder, id)
	_cache[key] = out
	return out


static func _load(dir: String, id: String) -> Dictionary:
	var hi := dir + "/_2x/" + id + ".png"
	var lo := dir + "/" + id + ".png"
	if Art.lite and ResourceLoader.exists(lo):
		return {"tex": load(lo), "scale": 1.0}
	if ResourceLoader.exists(hi):
		return {"tex": load(hi), "scale": 0.5}
	if ResourceLoader.exists(lo):
		return {"tex": load(lo), "scale": 1.0}
	return {}


## Visual floor for one cell. The entry's west and north edges are the
## Rowanvale and Windmere joins: three blend cells, then the road gap.
static func floor_id(zone: WorldZone, cell: Vector2i, origin: Vector2i) -> String:
	var terrain := Art.terrain_seen(zone, cell)
	if zone.zone_id == "blightwood_hollow_entry":
		var joined := _join_floor(cell, terrain)
		if joined != "":
			return joined
	return _v2_floor(zone, cell, origin)


static func _v2_floor(zone: WorldZone, cell: Vector2i, origin: Vector2i) -> String:
	var terrain := Art.terrain_seen(zone, cell)
	var wc := cell + origin
	if terrain == "dirt_road":
		return "trodden_path"
	# Mushrooms are a rare patch, and never a line along the road.
	if not _near_road(zone, cell) and Art.h(wc.x, wc.y, 17) == 0:
		return "moss_mushroom"
	if Art.h(int(wc.x / 3), int(wc.y / 3), 5) <= 1:
		return "root_soil"
	return "leaf_litter"


static func _near_road(zone: WorldZone, cell: Vector2i) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if Art.terrain_seen(zone, cell + step) == "dirt_road":
			return true
	return false


static func _join_floor(cell: Vector2i, terrain: String) -> String:
	# Corner of the two joins, off the roads.
	if cell.x < 3 and cell.y < 3 and terrain != "dirt_road":
		return "blend_meadow_nw_ne"
	# Rowanvale road, along y = 16. s1 sits on the meadow gate.
	if terrain == "dirt_road" and cell.y == 16 and cell.x <= 3:
		if cell.x <= 2:
			return "road_gap_s%d" % (cell.x + 1)
		return "road_gap_wall"
	# Windmere road, along x = 16.
	if terrain == "dirt_road" and cell.x == 16 and cell.y <= 3:
		if cell.y <= 2:
			return "road_gap_s%d" % (cell.y + 1)
		return "road_gap_wall"
	# The cross road meets the west wall. It does not open a second gap.
	if terrain == "dirt_road" and cell.x <= 2:
		return "blend_meadow_nw_s%d" % (cell.x + 1)
	if cell.x <= 2 and cell.y >= 3 and terrain != "dirt_road":
		return "blend_meadow_nw_s%d" % (cell.x + 1)
	if cell.y <= 2 and cell.x >= 3 and terrain != "dirt_road":
		return "blend_meadow_ne_s%d" % (cell.y + 1)
	return ""


static func _is_join(id: String) -> bool:
	return id.begins_with("blend_") or id.begins_with("road_gap")


static func draw_floor(ci: CanvasItem, zone: WorldZone, cell: Vector2i, origin: Vector2i, steps: int) -> void:
	var id := floor_id(zone, cell, origin)
	var art: Dictionary
	var mod := Color.WHITE
	if _is_join(id):
		art = texture("tiles", id)
	else:
		art = v2_texture("ground", id)
		mod = FLOOR_MOD.get(id, Color.WHITE)
		if art.is_empty():
			art = texture("tiles", "blight_soil_a")
			mod = Color.WHITE
	if art.is_empty():
		return
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south := center + Vector2(0, 16.0)
	var size := Art.size_of(art)
	Art.draw_at(ci, art, south + Vector2(-size.x * 0.5, -size.y), mod)


static func prop_file(prop_type: String, prop_id: String, origin: Vector2i, zone_id: String) -> String:
	if prop_id.ends_with("_landmark"):
		if zone_id.ends_with("_door"):
			return "heart_of_the_blight"
		return TALL[Art.h(origin.x, origin.y, TALL.size())]
	match prop_type:
		"stone_wall_high_nesw":
			return "watch_wall_nesw_high"
		"stone_wall_high_nwse":
			return "watch_wall_nwse_high"
		"wall_tower":
			return "watch_tower_broken_tall" if Art.h(origin.x, origin.y, 2) == 0 else "watch_tower_broken_stump"
		"tree", "tree_cluster_2x2_a":
			var bag: Array = TALL if Art.h(origin.x, origin.y, 5) < 3 else MID
			return bag[Art.h(origin.y, origin.x, bag.size())]
		"fence":
			return "fence_broken" if Art.h(origin.x, origin.y, 3) == 0 else "fence_a"
		"barrel":
			return CLUTTER[Art.h(origin.x, origin.y, CLUTTER.size())]
		"lamp_post":
			return "lantern"
		"well", "quarry_rocks_a":
			return STONES[Art.h(origin.x, origin.y, STONES.size())]
		_:
			return MID[Art.h(origin.x, origin.y, MID.size())]


## Extra scale on the prop node. 1 keeps walls, towers, and the Heart.
static func prop_scale(art_id: String, origin: Vector2i) -> float:
	var j := Art.h(origin.x, origin.y, 5)
	if art_id.begins_with("dead_tree_tall"):
		return 1.05 + float(j) * 0.09
	if art_id.begins_with("dead_tree_mid"):
		return 0.92 + float(j) * 0.06
	if art_id.begins_with("thorn"):
		return 0.7
	if art_id.begins_with("gravestone"):
		return 0.58
	if art_id.begins_with("fence"):
		return 0.78
	if art_id.begins_with("bones") or art_id.begins_with("crow"):
		return 0.48
	if art_id == "lantern":
		return 0.72
	if art_id.begins_with("cobweb"):
		return 0.55
	return 1.0


## Most dressed clutter draws nothing. A few cells take bones, webs, or thorns
## so mushrooms are not a uniform carpet (moss lives on the ground tile).
static func decor_file(decor_type: String, cell: Vector2i) -> String:
	var n := Art.h(cell.x, cell.y, 11)
	if decor_type.begins_with("decal_"):
		return "cobweb" if n == 0 else ""
	if n == 0:
		return "bones_skull"
	if n == 1:
		return "thorn_bush_a" if Art.h(cell.x, cell.y, 2) == 0 else "thorn_bush_b"
	if n == 2:
		return "crow_perched"
	return ""


static func _frames(path: String, count: int, size: Vector2i, fps: float, anim: String) -> SpriteFrames:
	var tex: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * size.x, 0, size.x, size.y)
		frames.add_frame(anim, atlas)
	return frames


static func animated() -> bool:
	if VisualSettings.still():
		return false
	return VisualSettings.current != null and VisualSettings.current.enabled("animations")


static func _additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## Warm pool under the Heart. Replaces the old sap pulse.
static func attach_sap(prop: Node2D) -> void:
	var art := v2_texture("fx", "heart_glow")
	if art.is_empty():
		return
	var spr := Sprite2D.new()
	spr.name = "HeartGlow"
	spr.texture = art["tex"]
	spr.scale = Vector2.ONE * float(art["scale"])
	spr.centered = true
	spr.position = Vector2(0, -64)
	spr.material = _additive()
	spr.modulate = Color(1.45, 0.72, 0.22, 0.85)
	spr.z_as_relative = true
	spr.z_index = 1
	prop.add_child(spr)


static func attach_lantern_glow(prop: Node2D) -> void:
	var art := v2_texture("fx", "lantern_glow")
	if art.is_empty():
		return
	var spr := Sprite2D.new()
	spr.name = "LanternGlow"
	spr.texture = art["tex"]
	spr.scale = Vector2.ONE * float(art["scale"]) * 1.15
	spr.centered = true
	# Flame sits near the top of the lantern sprite.
	spr.position = Vector2(0, -108)
	spr.material = _additive()
	spr.modulate = Color(1, 0.86, 0.55, 0.8)
	spr.z_as_relative = true
	spr.z_index = 2
	prop.add_child(spr)


## Chain hook is the top centre. Hang it in the bare branches.
static func attach_cage(prop: Node2D, origin: Vector2i) -> void:
	var art := v2_texture("props", "hanging_cage")
	if art.is_empty():
		return
	var Stamp := preload("res://scenes/world/crosshaven/blightwood_stamp.gd")
	var n: Node2D = Stamp.new()
	n.name = "HangingCage"
	n.art = art
	n.pivot = "top"
	var sway := float(Art.h(origin.x, origin.y, 48) - 24)
	var drop := 168.0 + float(Art.h(origin.y, origin.x, 70))
	n.position = Vector2(sway, -drop)
	n.z_as_relative = true
	n.z_index = 1
	prop.add_child(n)
