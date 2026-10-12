extends SceneTree

## Seam survey (not a test). Builds every chunk ground of the Crosshaven
## plane, then walks every boundary between two chunks and compares what the
## ground draws on the three cells either side:
##   - draw seams: the same terrain on both sides but a different look (beach,
##     snow cover, sea kind, tint) that changes exactly on the chunk edge;
##   - data seams: the terrain id itself changes on the chunk edge;
##   - two grounds that draw the same cell differently (which one shows
##     depends on draw order);
##   - roads that stop at a chunk edge.
## Runs longer than RUN_MIN cells are flagged. Writes a JSON list of them
## (with a camera spot each) for `capture_seams.gd`.
##   godot --headless --path . -s res://tests/pc/survey_seams.gd -- --out=/tmp/seams.json

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const RUN_MIN := 3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]

var _out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	var report := await survey(w)
	for line in report["lines"]:
		print(line)
	print("SEAMS draw=%d data=%d order=%d road=%d" % [report["draw"], report["data"], report["order"], report["road"]])
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"flagged": report["spots"], "bounds": report["bounds"]}, "  "))
		f.close()
	quit(0)


## Survey the whole plane. Also used by run_shoreline_tests.
static func survey(w: Node2D) -> Dictionary:
	var start: String = w.map.start_zone
	await w.enter_zone(start, w.map.zone(start).spawn, false)
	w._mount_neighbours(w.zone.zone_id, true)
	var grounds := {}
	for g in w._grounds_root.get_children():
		if g.zone != null:
			grounds[g.zone.zone_id] = g
	var owner := {}
	for zid in w.plane_offsets.keys():
		var z: WorldZone = w.map.zone(str(zid))
		if z == null or not grounds.has(str(zid)):
			continue
		var o: Vector2i = w.plane_offsets[zid]
		for y in z.height:
			for x in z.width:
				owner[o + Vector2i(x, y)] = str(zid)
	var runs := {}
	var edges := {}
	var order := 0
	var order_seen := {}
	var road := 0
	var lines: Array[String] = []
	var spots: Array = []
	for cell in owner.keys():
		var a: Vector2i = cell
		for dir in DIRS:
			var b := a + dir
			if not owner.has(b) or owner[b] == owner[a]:
				continue
			var ekey := "%s|%s|%s" % [owner[a], owner[b], dir]
			if not edges.has(ekey):
				edges[ekey] = []
			(edges[ekey] as Array).append(a)
			var ga: Node2D = grounds[owner[a]]
			var gb: Node2D = grounds[owner[b]]
			var ca := _class_of(ga, a)
			var cb := _class_of(gb, b)
			# Both grounds draw both cells near the seam: they must agree.
			for pair in [[gb, a, ca], [ga, b, cb]]:
				var other: Node2D = pair[0]
				var at: Vector2i = pair[1]
				var mine: Dictionary = pair[2]
				if not _draws(other, at):
					continue
				var theirs := _class_of(other, at)
				if theirs["look"] != mine["look"] and not order_seen.has(at):
					order_seen[at] = true
					order += 1
					if order <= 40:
						lines.append("ORDER %s %s drawn as %s by %s, %s by its owner" % [owner[at], at, theirs["look"], other.zone.zone_id, mine["look"]])
			# Roads should carry on over the edge.
			if ca["terrain"] == "dirt_road" and cb["terrain"] != "dirt_road":
				var side := Vector2i(dir.y, dir.x)
				var near := false
				for k in [-1, 1]:
					if owner.has(b + side * k) and _class_of(gb, b + side * k)["terrain"] == "dirt_road":
						near = true
				if not near:
					road += 1
					lines.append("ROAD ends %s %s -> %s %s" % [owner[a], a, owner[b], b])
			elif cb["terrain"] == "dirt_road" and ca["terrain"] != "dirt_road":
				var side2 := Vector2i(dir.y, dir.x)
				var near2 := false
				for k in [-1, 1]:
					if owner.has(a + side2 * k) and _class_of(ga, a + side2 * k)["terrain"] == "dirt_road":
						near2 = true
				if not near2:
					road += 1
					lines.append("ROAD ends %s %s -> %s %s" % [owner[b], b, owner[a], a])
			if ca["look"] == cb["look"]:
				continue
			# Edge-aligned: each side keeps its look three cells deep.
			var steady := true
			for k in range(1, 3):
				var a2 := a - dir * k
				var b2 := b + dir * k
				if not owner.has(a2) or owner[a2] != owner[a] or not owner.has(b2) or owner[b2] != owner[b]:
					steady = false
					break
				if _class_of(ga, a2)["look"] != ca["look"] or _class_of(gb, b2)["look"] != cb["look"]:
					steady = false
					break
			if not steady:
				continue
			var kind := "data" if ca["terrain"] != cb["terrain"] else "draw"
			var key := "%s|%s|%s|%s|%s|%s" % [kind, owner[a], owner[b], dir, ca["look"], cb["look"]]
			if not runs.has(key):
				runs[key] = []
			(runs[key] as Array).append(a)
	var draw := 0
	var data := 0
	for key in runs.keys():
		var cells: Array = runs[key]
		var parts := str(key).split("|")
		for seg in _segments(cells, parts[3]):
			if seg.size() < RUN_MIN:
				continue
			var mid: Vector2i = seg[seg.size() / 2]
			if parts[0] == "draw":
				draw += 1
			else:
				data += 1
			lines.append("%s %s|%s len=%d at %s: %s / %s" % [parts[0].to_upper(), parts[1], parts[2], seg.size(), mid, parts[4], parts[5]])
			var z: String = owner[mid]
			spots.append({"kind": parts[0], "zone": z, "cell": [mid.x - w.plane_offsets[z].x, mid.y - w.plane_offsets[z].y], "len": seg.size(), "a": parts[4], "b": parts[5], "pair": "%s|%s" % [parts[1], parts[2]]})
	var bounds: Array = []
	for key in edges.keys():
		var parts2 := str(key).split("|")
		for seg in _segments(edges[key], parts2[2]):
			if seg.size() < 3:
				continue
			var mid2: Vector2i = seg[seg.size() / 2]
			var z2: String = owner[mid2]
			bounds.append({"kind": "edge", "zone": z2, "cell": [mid2.x - w.plane_offsets[z2].x, mid2.y - w.plane_offsets[z2].y], "len": seg.size(), "pair": "%s|%s" % [parts2[0], parts2[1]]})
	return {"lines": lines, "spots": spots, "bounds": bounds, "draw": draw, "data": data, "order": order, "road": road}


## Consecutive cells along a boundary line (they share x for a (1,0) edge).
static func _segments(cells: Array, dir_text: String) -> Array:
	var along_y := dir_text == "(1, 0)"
	var groups := {}
	for c in cells:
		var at: Vector2i = c
		var key := at.x if along_y else at.y
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(at.y if along_y else at.x)
	var out: Array = []
	for key in groups.keys():
		var vals: Array = groups[key]
		vals.sort()
		var seg: Array = []
		var last := -99999
		for v in vals:
			if v != last + 1 and not seg.is_empty():
				out.append(seg)
				seg = []
			seg.append(Vector2i(key, v) if along_y else Vector2i(v, key))
			last = v
		if not seg.is_empty():
			out.append(seg)
	return out


static func _draws(g: Node2D, world: Vector2i) -> bool:
	var local: Vector2i = world - g.world_origin
	var m := int(g.call("_view_margin"))
	return local.x >= -m and local.y >= -m and local.x < g.zone.width + m and local.y < g.zone.height + m


## What a ground paints on a world cell, coarsely: terrain, height, beach,
## snow, sea kind and tint. `look` is the part a viewer would see change.
static func _class_of(g: Node2D, world: Vector2i) -> Dictionary:
	var cell: Vector2i = world - g.world_origin
	var terrain := Art.terrain_seen(g.zone, cell)
	var steps := Art.height_seen(g.zone, cell)
	var look := terrain
	var beach := str(g.call("_beach_at", cell))
	var cover := float(g.call("cover_at", cell))
	if terrain == "water":
		var grade := str(g.call("_water_grade", cell))
		# A river cell at the mouth draws the sea surface fading in over it.
		if grade == "river" and float((g.get("_mouth_mix") as Dictionary).get(cell, 0.0)) >= 0.7:
			grade = "sea"
		look = "water_" + grade + ("_kit" if beach.begins_with("sea") else "")
	elif beach == "sand" or beach == "wet_sand":
		look = "sand"
	elif terrain == "golden_plains" and bool(g.call("_shore_land", cell)):
		look = "sand"
	if terrain != "water" and terrain != "":
		# Heavy snow (patchy past 0.7 is still mostly white) and thin snow.
		if cover >= 0.7:
			look += "+snow"
		elif cover > 0.3:
			look += "+snowthin"
		# Under heavy snow the floor tint hardly shows.
		if cover < 0.7:
			var tint: Color = g.call("_floor_modulate", cell, terrain)
			look += "#%d%d%d" % [roundi(tint.r * 8.0), roundi(tint.g * 8.0), roundi(tint.b * 8.0)]
	look += "@%d" % steps
	return {"terrain": terrain, "look": look}
