extends RefCounted

## Blightwood Hollow kit. Zone terrain ids stay the Crosshaven grammar
## (farm_* reads as grass or ash, dirt_road as stone). This only picks art.

const ROOT := "res://art/world/blightwood_hollow/"
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

const SOIL := ["blight_soil_a", "blight_soil_b", "blight_soil_c", "blight_soil_d"]
const ROOTS := ["root_ground_a", "root_ground_b", "root_ground_c"]
const STONE := ["watch_flagstone_a", "watch_flagstone_b", "watch_flagstone_c"]
const TREES := [
	"tw_tree_small", "tw_tree_mid", "tw_tree_large_a", "tw_tree_large_b",
	"tw_tree_bare_hanging", "tw_tree_giant",
]

static var _cache := {}


static func texture(kind: String, id: String) -> Dictionary:
	var key := kind + "/" + id
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var hi := ROOT + kind + "/_2x/" + id + ".png"
	var lo := ROOT + kind + "/" + id + ".png"
	if Art.lite and ResourceLoader.exists(lo):
		out = {"tex": load(lo), "scale": 1.0}
	elif ResourceLoader.exists(hi):
		out = {"tex": load(hi), "scale": 0.5}
	elif ResourceLoader.exists(lo):
		out = {"tex": load(lo), "scale": 1.0}
	_cache[key] = out
	return out


## Visual floor for one cell. The entry's west and north edges are the
## Rowanvale and Windmere joins: three blend cells, then the road gap.
static func floor_id(zone: WorldZone, cell: Vector2i, origin: Vector2i) -> String:
	var terrain := Art.terrain_seen(zone, cell)
	var wc := cell + origin
	if zone.zone_id == "blightwood_hollow_entry":
		var joined := _join_floor(cell, terrain)
		if joined != "":
			return joined
	if terrain == "dirt_road":
		return STONE[Art.h(wc.x, wc.y, STONE.size())]
	if terrain == "farm_fallow":
		return ROOTS[Art.h(wc.x, wc.y, ROOTS.size())]
	return SOIL[Art.h(wc.x, wc.y, SOIL.size())]


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


static func draw_floor(ci: CanvasItem, zone: WorldZone, cell: Vector2i, origin: Vector2i, steps: int) -> void:
	var art := texture("tiles", floor_id(zone, cell, origin))
	if art.is_empty():
		return
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south := center + Vector2(0, 16.0)
	var size := Art.size_of(art)
	Art.draw_at(ci, art, south + Vector2(-size.x * 0.5, -size.y))


static func prop_file(prop_type: String, prop_id: String, origin: Vector2i, zone_id: String) -> String:
	if prop_id.ends_with("_landmark"):
		if zone_id.ends_with("_door"):
			return "heart_of_the_blight"
		return "tw_tree_giant"
	match prop_type:
		"stone_wall_high_nesw":
			return "watch_wall_nesw_high"
		"stone_wall_high_nwse":
			return "watch_wall_nwse_high"
		"wall_tower":
			return "watch_tower_broken_tall" if Art.h(origin.x, origin.y, 2) == 0 else "watch_tower_broken_stump"
		"tree", "tree_cluster_2x2_a":
			return TREES[Art.h(origin.x, origin.y, TREES.size())]
		"fence", "barrel":
			return "dead_snag_broken"
		"well", "lamp_post", "quarry_rocks_a":
			return "dead_snag_tall"
		_:
			return TREES[Art.h(origin.x, origin.y, TREES.size())]


static func decor_file(decor_type: String, cell: Vector2i) -> String:
	if decor_type.begins_with("decal_"):
		var roots := ["roots_decal_a", "roots_decal_b", "roots_decal_c", "roots_decal_d"]
		return roots[Art.h(cell.x, cell.y, roots.size())]
	return "blight_mushrooms_a" if Art.h(cell.x, cell.y, 2) == 0 else "blight_mushrooms_b"


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


static func attach_sap(prop: Node2D) -> void:
	var frames := _frames(
		ROOT + "animated/heart_sap_pulse_8f.png", 8, Vector2i(192, 192), 6.0, "sap"
	)
	var spr := AnimatedSprite2D.new()
	spr.name = "HeartSap"
	spr.sprite_frames = frames
	spr.animation = "sap"
	spr.centered = true
	# Wound sits above the south-tip anchor (1x pixels).
	spr.position = Vector2(0, -181)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	spr.modulate = Color(1, 1, 1, 0.45)
	spr.z_as_relative = true
	spr.z_index = 1
	prop.add_child(spr)
	if animated():
		spr.play("sap")
	else:
		spr.frame = 0
		spr.pause()
