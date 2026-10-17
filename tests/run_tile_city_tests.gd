extends SceneTree

## Modular Crosshaven (tile map + kit): data, autotiling, pieces, walking,
## and the view. Runs on whatever kit tilemap.json names (placeholder first).

const View := preload("res://scenes/world/crosshaven/tile_city_view.gd")

var passed := 0
var failed := 0
var tc: TileCity


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tc = TileCity.load_path()
	check(tc.ok(), "tilemap and kit load (%s)" % [tc.errors])
	print("kit: ", tc.kit.get("name", ""))
	if not tc.ok():
		_finish()
		return
	_test_kit()
	_test_autotile()
	_test_pieces()
	_test_walk()
	await _test_view()
	_finish()


func _finish() -> void:
	print("tile city tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_kit() -> void:
	check((tc.kit["terrains"] as Array).size() >= 5, "the kit has the ground terrains")
	for t in tc.kit["terrains"]:
		check(FileAccess.file_exists(tc.kit_dir.path_join(str(t["atlas"]))), "atlas for %s" % t["id"])
	for k in tc.kit["pieces"].keys():
		var sp: Dictionary = tc.kit["pieces"][k]
		check(FileAccess.file_exists(tc.kit_dir.path_join(str(sp["file"]))), "sprite for piece %s" % k)
		check((sp["foot"] as Array).size() == 2 and (sp["footprint"] as Array).size() == 2, "%s has a foot anchor and a footprint" % k)
	# 2:1 tiles; hero scale from the kit
	check(is_equal_approx(tc.tile.x, tc.tile.y * 2.0) or absf(tc.tile.x - tc.tile.y * 2.0) < 0.05, "tiles are 2:1 (%s)" % tc.tile)
	var hero := float(tc.doc["hero_world_px"])
	check(absf(tc.tile.x / hero - 128.0 / 156.0) < 0.02, "a tile is 128/156 of the hero (%.3f)" % (tc.tile.x / hero))


func _test_autotile() -> void:
	# find vertices of known kinds and check their layer masks
	var all_grass := Vector2i(-1, -1)
	var mixed := Vector2i(-1, -1)
	for y in range(1, tc.height):
		for x in range(1, tc.width):
			var v := Vector2i(x, y)
			var q := [tc.terrain_char(Vector2i(x - 1, y - 1)), tc.terrain_char(Vector2i(x, y - 1)), tc.terrain_char(v), tc.terrain_char(Vector2i(x - 1, y))]
			if all_grass.x < 0 and q.count("g") == 4:
				all_grass = v
			if mixed.x < 0 and q.count("g") == 2 and q.count("c") == 2:
				mixed = v
	check(all_grass.x >= 0 and mixed.x >= 0, "the map has plain and mixed vertices")
	var l1 := tc.corner_layers(all_grass)
	check(l1.size() == 1 and int(l1[0][1]) == 15 and str(l1[0][0]["id"]) == "grass", "plain grass vertex is one full grass tile")
	var l2 := tc.corner_layers(mixed)
	check(l2.size() == 2 and int(l2[0][1]) == 15 and str(l2[1][0]["id"]) == "cobble", "grass/cobble vertex: grass base, cobble overlay")
	if l2.size() == 2:
		var m := int(l2[1][1])
		var bits := 0
		for i in 4:
			if m & (1 << i):
				bits += 1
		check(bits == 2, "the cobble overlay sets two quarters (%d)" % m)
	check(tc.corner_layers(Vector2i(0, 0)).is_empty() or tc.terrain_char(Vector2i(0, 0)) != ".", "void corners draw nothing")


func _count(kind: String) -> int:
	var n := 0
	for p in tc.pieces():
		if str(p["kind"]) == kind or TileCity.kind_group(str(p["kind"])) == kind:
			n += 1
	return n


func _test_pieces() -> void:
	check(_count("tower") == 12, "12 towers (%d)" % _count("tower"))
	check(_count("gate") == 4, "4 gates (%d)" % _count("gate"))
	for k in ["castle", "cathedral", "townhall", "bank", "mill", "fountain"]:
		check(_count(k) == 1, "one %s (%d)" % [k, _count(k)])
	check(_count("stall") == 3, "3 stalls")
	check(_count("workshop") == 6, "6 workshops (%d)" % _count("workshop"))
	check(_count("house") >= 45, "about 50 NPC houses (%d)" % _count("house"))
	check(_count("lamp") >= 20, "lamps along the streets (%d)" % _count("lamp"))
	var plots: Array = tc.doc["plots"]
	check(plots.size() == 10, "10 player plots (%d)" % plots.size())
	var tiers := {}
	for p in plots:
		tiers[str(p["tier"])] = true
	check(tiers.size() == 3, "plots in 3 tiers")
	check((tc.doc["dropped"] as Array).is_empty(), "nothing from the layout dropped (%s)" % [tc.doc["dropped"]])
	# blocking footprints never overlap, and buildings keep off roads and water
	var owner := {}
	var overlaps := 0
	var on_road := 0
	var i := 0
	for p in tc.pieces():
		if tc.piece_blocks(p):
			for c in tc.footprint(p):
				if owner.has(c):
					overlaps += 1
				owner[c] = i
				if not (TileCity.kind_group(str(p["kind"])) in ["wall", "tower", "fountain", "stall", "well", "bench", "crate", "barrel", "lamp", "fence", "cart_hay", "signpost", "notice_board"]) and tc.terrain_char(c) in ["c", "p", "w", "d"]:
					on_road += 1
		i += 1
	check(overlaps == 0, "blocking footprints do not overlap (%d)" % overlaps)
	check(on_road == 0, "buildings keep off roads, the plaza and water (%d tiles)" % on_road)
	# round 26: the ring is made of kit runs; every house door opens on a street
	check(_count("wall") > 40 and _count("tunnel") == 2, "the ring: wall runs and 2 water tunnels (%d, %d)" % [_count("wall"), _count("tunnel")])
	var doors_ok := 0
	var houses := 0
	for p in tc.pieces():
		if TileCity.kind_group(str(p["kind"])) == "house":
			houses += 1
			var d: Array = p.get("door_cell", [])
			if not d.is_empty() and tc.terrain_char(Vector2i(int(d[0]), int(d[1]))) in ["c", "d", "p"]:
				doors_ok += 1
	check(houses >= 45 and doors_ok == houses, "every house door opens on a street (%d of %d)" % [doors_ok, houses])
	var variants := {}
	var flipped := 0
	for p in tc.pieces():
		if TileCity.kind_group(str(p["kind"])) == "house":
			variants[str(p["kind"])] = true
			if bool(p.get("flip", false)):
				flipped += 1
	check(variants.size() == 9 and flipped > 5, "all 9 house designs, some mirrored (%d, %d)" % [variants.size(), flipped])
	# the big walls dwarf the hero
	var hero := float(tc.doc["hero_world_px"])
	var k := tc.kit_scale()
	var tower_h := float(tc.kit["pieces"]["tower"]["height_px"]) * k
	var hk := "house"
	for kk in tc.kit["pieces"].keys():
		if str(kk).begins_with("house_npc"):
			hk = kk
	var house_h := float(tc.kit["pieces"][hk]["height_px"]) * k
	var wall_h := float(tc.kit["pieces"]["wall_h" if tc.kit["pieces"].has("wall_h") else "wall"]["height_px"]) * k
	check(tower_h / hero > 5.0, "a tower is over 5 hero heights (%.1f)" % (tower_h / hero))
	check(house_h / hero > 2.6 and house_h / hero < 3.6 and house_h < wall_h, "a house is about 3 hero heights and below the wall")


func _test_walk() -> void:
	var spawn := tc.spawn()
	check(tc.passable(spawn), "spawn is walkable")
	var reach := tc.reach(spawn)
	check(reach.size() > 5000, "the town is one walk area (%d tiles)" % reach.size())
	for g in tc.doc["gates"]:
		var ins: Array = g["inside"]
		var outs: Array = g["outside"]
		check(not ins.is_empty() and not outs.is_empty(), "gate %s has tiles both sides" % g["id"])
		for c in ins + outs:
			check(reach.has(Vector2i(int(c[0]), int(c[1]))), "gate %s tile %s is reached" % [g["id"], c])
	for p in tc.doc["plots"]:
		var f := Vector2i(int(p["front"][0]), int(p["front"][1]))
		check(reach.has(f), "plot %s entrance is reached" % p["id"])
	# no leaks: with every gate shut, the inside never reaches the outside
	var shut := tc.gate_cells()
	var g0: Dictionary = tc.doc["gates"][0]
	var start := Vector2i(int(g0["inside"][g0["inside"].size() - 1][0]), int(g0["inside"][g0["inside"].size() - 1][1]))
	var inside := tc.reach(start, shut)
	var leaks := 0
	for g in tc.doc["gates"]:
		for c in g["outside"]:
			if inside.has(Vector2i(int(c[0]), int(c[1]))):
				leaks += 1
	check(not inside.has(spawn) and leaks == 0, "no way out of the ring but the gates (%d)" % leaks)
	check(inside.size() > 3000, "the inside is one area (%d tiles)" % inside.size())


func _test_view() -> void:
	var v: Node2D = View.new()
	root.add_child(v)
	v.setup(tc)
	v.ground.queue_redraw()
	await process_frame
	await process_frame
	check(v.ground_tiles_drawn > 20000, "the autotiled ground draws (%d tiles)" % v.ground_tiles_drawn)
	check(v.piece_nodes.size() == tc.pieces().size(), "every piece has a sprite")
	var bad := 0
	for pn in v.piece_nodes:
		var s: Sprite2D = pn["node"]
		if s.texture == null:
			bad += 1
	check(bad == 0, "every piece sprite has its texture (%d missing)" % bad)
	# y-sort: of two pieces, the one further south draws on top
	var a: Dictionary = v.piece_nodes[v.piece_nodes.size() - 1]
	var b: Dictionary = v.piece_nodes[v.piece_nodes.size() - 1]
	for pn in v.piece_nodes:
		if bool((pn["piece"] as Dictionary).get("under", false)):
			continue
		if (pn["foot"] as Vector2).y < (a["foot"] as Vector2).y:
			a = pn
		if (pn["foot"] as Vector2).y > (b["foot"] as Vector2).y:
			b = pn
	check((b["node"] as Sprite2D).z_index > (a["node"] as Sprite2D).z_index, "pieces y-sort by their foot")
	# the hero standing 2 px south of a piece's foot sorts in front of it
	var p0: Dictionary = v.piece_nodes[v.piece_nodes.size() / 2]
	check(View.z_at((p0["foot"] as Vector2) + Vector2(0, 20)) > (p0["node"] as Sprite2D).z_index, "a body in front of a piece sorts over it")
	v.queue_free()
	await process_frame
