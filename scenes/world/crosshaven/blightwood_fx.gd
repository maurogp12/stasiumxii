extends RefCounted

## View-only dressing for Blightwood Hollow: framing trees, amber eyes in
## the gaps, moon pools, light shafts, and wisps. Fog bands live on the world.
## Nothing here blocks a cell. The entry's west and north strips stay clear.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Kit := preload("res://scenes/world/crosshaven/blightwood_art.gd")
const Stamp := preload("res://scenes/world/crosshaven/blightwood_stamp.gd")
const Blink := preload("res://scenes/world/crosshaven/blightwood_blink.gd")
const Layers := preload("res://scenes/world/crosshaven/blightwood_layers.gd")

const TALL := ["dead_tree_tall_a", "dead_tree_tall_b", "dead_tree_tall_c"]
const NPC := {
	"blightwood_hollow_entry": [Vector2i(2, 14), Vector2i(10, 11), Vector2i(5, 4)],
	"blightwood_hollow_door": [Vector2i(20, 11)],
}


static func dress(ground: Node2D) -> void:
	var zone: WorldZone = ground.get("zone")
	if zone == null or zone.region != "blightwood_hollow":
		return
	_ensure_fog(ground)
	_scatter(ground, zone)


static func _ensure_fog(ground: Node) -> void:
	var grounds := ground.get_parent()
	if grounds == null:
		return
	var world := grounds.get_parent()
	if world == null or world.get_node_or_null("BlightFogLayers") != null:
		return
	var layers := Layers.new()
	layers.name = "BlightFogLayers"
	world.add_child(layers)


static func _scatter(ground: Node2D, zone: WorldZone) -> void:
	var origin: Vector2i = ground.get("world_origin")
	var occupied := {}
	var trees: Array[Vector2i] = []
	for prop in zone.props:
		var kind := str(prop.get("type", ""))
		var pid := str(prop.get("id", ""))
		var feet := _south(prop)
		if kind == "tree" or kind == "tree_cluster_2x2_a" or pid.ends_with("_landmark"):
			trees.append(feet)
		for foot in prop["footprint"]:
			occupied[Vector2i(int(foot["x"]), int(foot["y"]))] = true
	var host := Node2D.new()
	host.name = "BlightDress"
	host.z_as_relative = false
	host.z_index = 0
	ground.add_child(host)
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not _open(zone, cell, occupied):
				continue
			var wc := cell + origin
			var edge := x <= 1 or y <= 1 or x >= zone.width - 2 or y >= zone.height - 2
			var added := false
			if edge and Art.h(wc.x, wc.y, 5) == 0:
				_tree(host, cell, wc, true)
				trees.append(cell)
				added = true
			elif zone.zone_id.ends_with("_entry") and Art.h(wc.x, wc.y, 16) == 0:
				_tree(host, cell, wc, Art.h(wc.x, wc.y, 4) != 0)
				trees.append(cell)
				added = true
			if added:
				continue
			_ornament(host, zone, cell, wc)
	_eyes(host, zone, trees, occupied, origin)
	_wisps(host, zone, occupied, origin)


static func _open(zone: WorldZone, cell: Vector2i, occupied: Dictionary) -> bool:
	if occupied.has(cell):
		return false
	if Art.terrain_seen(zone, cell) == "dirt_road":
		return false
	if zone.zone_id.ends_with("_entry") and (cell.x < 6 or cell.y < 6):
		return false
	if _near_point(cell, zone.spawn, 2):
		return false
	for poi in zone.points_of_interest:
		if _near_point(cell, Vector2i(int(poi["x"]), int(poi["y"])), 2):
			return false
	var posts: Array = NPC.get(zone.zone_id, [])
	for post in posts:
		if _near_point(cell, post, 3):
			return false
	return true


static func _near_point(cell: Vector2i, at: Vector2i, radius: int) -> bool:
	return maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= radius


static func _south(prop: Dictionary) -> Vector2i:
	var best := Vector2i(int(prop["footprint"][0]["x"]), int(prop["footprint"][0]["y"]))
	for foot in prop["footprint"]:
		var at := Vector2i(int(foot["x"]), int(foot["y"]))
		if at.x + at.y > best.x + best.y:
			best = at
	return best


static func _tree(host: Node2D, cell: Vector2i, wc: Vector2i, tall: bool) -> void:
	var id: String = TALL[Art.h(wc.x, wc.y, TALL.size())] if tall else Kit.MID[Art.h(wc.y, wc.x, Kit.MID.size())]
	var art := Kit.v2_texture("trees", id)
	var n := _stamp(host, art, _foot(cell), _z(cell, 2), "bottom")
	if n == null:
		return
	n.scale = Vector2.ONE * Kit.prop_scale(id, wc)
	if tall and Art.h(wc.x, wc.y, 8) == 0:
		var cage_art := Kit.v2_texture("props", "hanging_cage")
		var cage := _stamp(n, cage_art, Vector2(float(Art.h(wc.x, wc.y, 40) - 20), -160.0 - float(Art.h(wc.y, wc.x, 60))), 1, "top")
		if cage != null:
			cage.scale = Vector2.ONE * 0.85


static func _ornament(host: Node2D, zone: WorldZone, cell: Vector2i, wc: Vector2i) -> void:
	var roll := Art.h(wc.x, wc.y, 46)
	if roll == 0 and not _beside_road(zone, cell):
		_pool(host, cell, Kit.v2_texture("fx", "moonlight_pool"), 0.62)
		return
	if roll == 1:
		var shaft := _stamp(host, Kit.v2_texture("fx", "light_shaft"), _foot(cell), _z(cell, 3), "bottom")
		if shaft != null:
			shaft.scale = Vector2.ONE * (0.55 + float(Art.h(wc.y, wc.x, 4)) * 0.12)
			shaft.material = Kit._additive()
			shaft.modulate = Color(0.75, 0.9, 1.0, 0.38)
		return
	if roll == 2:
		var id: String = Kit.STONES[Art.h(wc.x, wc.y, Kit.STONES.size())]
		var stone := _stamp(host, Kit.v2_texture("props", id), _foot(cell), _z(cell, 2), "bottom")
		if stone != null:
			stone.scale = Vector2.ONE * 0.55
		return
	if roll == 3:
		var crow := "crow_walking" if Art.h(wc.x, wc.y, 2) == 0 else "crow_perched"
		var bird := _stamp(host, Kit.v2_texture("props", crow), _foot(cell), _z(cell, 2), "bottom")
		if bird != null:
			bird.scale = Vector2.ONE * 0.5


static func _eyes(host: Node2D, zone: WorldZone, trees: Array[Vector2i], occupied: Dictionary, origin: Vector2i) -> void:
	var frames: Array[Texture2D] = []
	for i in 4:
		var art := Kit.v2_texture("fx", "eyes_blink_f%d" % i)
		if art.is_empty():
			return
		frames.append(art["tex"])
	var eye_scale := float(Kit.v2_texture("fx", "eyes_blink_f0")["scale"])
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not _open(zone, cell, occupied):
				continue
			var near := 0
			for trunk in trees:
				var d := maxi(absi(trunk.x - cell.x), absi(trunk.y - cell.y))
				if d >= 2 and d <= 4:
					near += 1
					if near >= 2:
						break
			if near < 1:
				continue
			var wc := cell + origin
			if Art.h(wc.x, wc.y, 11) != 0:
				continue
			var at := _foot(cell) + Vector2(float(Art.h(wc.x, wc.y, 18) - 9), -64.0 - float(Art.h(wc.y, wc.x, 48)))
			_blink_at(host, frames, eye_scale, at, _z(cell, 3), wc, 2.6)
			if Art.h(wc.x + 3, wc.y, 4) == 0:
				_blink_at(host, frames, eye_scale, at + Vector2(28, 10), _z(cell, 3), wc + Vector2i(2, 1), 1.0)


static func _blink_at(host: Node2D, frames: Array[Texture2D], eye_scale: float, at: Vector2, z: int, salt: Vector2i, extra: float) -> void:
	var spr: Sprite2D = Blink.new()
	spr.position = at
	spr.z_as_relative = true
	spr.z_index = z
	spr.scale = Vector2.ONE * eye_scale * extra
	spr.material = Kit._additive()
	spr.modulate = Color(1.8, 1.05, 0.32, 1.0)
	host.add_child(spr)
	var hold := 2.0 + float(Art.h(salt.x, salt.y, 300)) / 100.0
	(spr as Node).call("arm", frames, hold, Kit.animated())


static func _wisps(host: Node2D, zone: WorldZone, occupied: Dictionary, origin: Vector2i) -> void:
	var body := Kit.v2_texture("props", "wisp")
	var glow := Kit.v2_texture("fx", "wisp_glow")
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not _open(zone, cell, occupied):
				continue
			var wc := cell + origin
			if Art.h(wc.x, wc.y, 70) != 0:
				continue
			var at := _foot(cell) + Vector2(0, -70 - float(Art.h(wc.x, wc.y, 30)))
			var bob := Node2D.new()
			bob.position = at
			bob.z_as_relative = true
			bob.z_index = _z(cell, 4)
			bob.set_meta("base_y", at.y)
			bob.set_meta("phase", float(Art.h(wc.y, wc.x, 100)) / 16.0)
			host.add_child(bob)
			var light := _stamp(bob, glow, Vector2(0, 8), 0, "center")
			if light != null:
				light.material = Kit._additive()
				light.modulate = Color(0.7, 0.85, 1.0, 0.55)
				light.scale = Vector2(0.45, 0.45)
			var orb := _stamp(bob, body, Vector2.ZERO, 1, "bottom")
			if orb != null:
				orb.scale = Vector2.ONE * 0.42
			if Kit.animated():
				bob.set_meta("bob", true)
	if Kit.animated():
		var driver := preload("res://scenes/world/crosshaven/blightwood_bob.gd").new()
		driver.name = "Bob"
		host.add_child(driver)


static func _pool(host: Node2D, cell: Vector2i, art: Dictionary, alpha: float) -> void:
	var n := _stamp(host, art, BoardVisualSort.cell_to_local(cell), _z(cell, 1), "center")
	if n == null:
		return
	n.material = Kit._additive()
	n.modulate = Color(0.75, 0.88, 1.0, alpha)


static func _stamp(parent: Node, art: Dictionary, at: Vector2, z: int, pivot: String) -> Node2D:
	if art.is_empty():
		return null
	var n: Node2D = Stamp.new()
	n.art = art
	n.pivot = pivot
	n.position = at
	n.z_as_relative = true
	n.z_index = z
	parent.add_child(n)
	return n


static func _foot(cell: Vector2i) -> Vector2:
	return BoardVisualSort.cell_to_local(cell) + Vector2(0, 16)


static func _z(cell: Vector2i, bias: int) -> int:
	return (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + bias


static func _beside_road(zone: WorldZone, cell: Vector2i) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i.ZERO]:
		if Art.terrain_seen(zone, cell + step) == "dirt_road":
			return true
	return false
