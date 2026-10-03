extends RefCounted

## One cell plane for a region map. Chunk origins come from exit links.
## The index start zone sits at (0, 0). A neighbour sits where
## from + edge step = to. No class_name: tests preload this file.


static func layout(map: WorldMap) -> Dictionary:
	var offsets := {}
	var conflicts: Array = []
	if map == null or map.start_zone == "" or map.zone(map.start_zone) == null:
		return {"ok": false, "offsets": offsets, "conflicts": conflicts, "overlaps": []}
	offsets[map.start_zone] = Vector2i.ZERO
	var queue: Array = [map.start_zone]
	var head := 0
	while head < queue.size():
		var here := str(queue[head])
		head += 1
		var zone: WorldZone = map.zone(here)
		if zone == null:
			continue
		var origin: Vector2i = offsets[here]
		for exit_rec in zone.exits:
			var edge := str(exit_rec.get("edge", ""))
			var dir: Vector2i = WorldZone.EDGE_DIR.get(edge, Vector2i.ZERO)
			var target := str(exit_rec.get("target_zone", ""))
			if target == "" or map.zone(target) == null:
				continue
			var links: Array = exit_rec.get("links", [])
			for link in links:
				if typeof(link) != TYPE_DICTIONARY:
					continue
				var frm: Dictionary = link.get("from", {})
				var dest: Dictionary = link.get("to", {})
				var from_cell := Vector2i(int(frm.get("x", 0)), int(frm.get("y", 0)))
				var to_cell := Vector2i(int(dest.get("x", 0)), int(dest.get("y", 0)))
				var placed := origin + from_cell + dir - to_cell
				if not offsets.has(target):
					offsets[target] = placed
					queue.append(target)
				elif offsets[target] != placed:
					conflicts.append("%s -> %s" % [here, target])
	var overlaps := _overlaps(map, offsets)
	var complete := offsets.size() == map.zones.size()
	return {
		"ok": conflicts.is_empty() and overlaps.is_empty() and complete,
		"offsets": offsets,
		"conflicts": conflicts,
		"overlaps": overlaps,
	}


## Zones whose cell rectangles touch this one, including exit targets.
static func touching(map: WorldMap, offsets: Dictionary, zone_id: String) -> Array:
	var out: Array = []
	var zone: WorldZone = map.zone(zone_id) if map != null else null
	if zone == null or not offsets.has(zone_id):
		return out
	var origin: Vector2i = offsets[zone_id]
	for other_id in offsets.keys():
		var oid := str(other_id)
		if oid == zone_id:
			continue
		var other: WorldZone = map.zone(oid)
		if other == null:
			continue
		var there: Vector2i = offsets[oid]
		if _touches(origin, zone.width, zone.height, there, other.width, other.height):
			out.append(oid)
	for exit_rec in zone.exits:
		var target := str(exit_rec.get("target_zone", ""))
		if target == "" or target == zone_id or out.has(target):
			continue
		if map.zone(target) != null:
			out.append(target)
	return out


static func _overlaps(map: WorldMap, offsets: Dictionary) -> Array:
	var ids: Array = offsets.keys()
	var found: Array = []
	for i in ids.size():
		var a := str(ids[i])
		var za: WorldZone = map.zone(a)
		var oa: Vector2i = offsets[a]
		for j in range(i + 1, ids.size()):
			var b := str(ids[j])
			var zb: WorldZone = map.zone(b)
			var ob: Vector2i = offsets[b]
			if za == null or zb == null:
				continue
			if _overlaps_rect(oa, za.width, za.height, ob, zb.width, zb.height):
				found.append("%s & %s" % [a, b])
	return found


static func _overlaps_rect(a: Vector2i, aw: int, ah: int, b: Vector2i, bw: int, bh: int) -> bool:
	return a.x < b.x + bw and b.x < a.x + aw and a.y < b.y + bh and b.y < a.y + ah


static func _touches(a: Vector2i, aw: int, ah: int, b: Vector2i, bw: int, bh: int) -> bool:
	var apart_x := a.x > b.x + bw or b.x > a.x + aw
	var apart_y := a.y > b.y + bh or b.y > a.y + ah
	return not apart_x and not apart_y
