extends RefCounted

## Live board check shared by the combat, motion, and VFX suites.
## Drop Shade must leave a ShadeMarkers child, and _rebuild_pawns must not free it.


static func run(host: SceneTree) -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	host.get_root().add_child(main)
	# _boot is deferred from BoardView._ready. Wait until that reset has landed.
	await host.process_frame
	await host.process_frame
	var board: Node = main.get_node("BoardView")
	host.truthy(bool(board.get("_booted")), "board finished boot before the Shade fixture")
	var origin := Vector2i(4, 4)
	var dest := Vector2i(5, 4)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [origin, Vector2i(12, 12)],
	})
	board._rebuild_pawns()
	var result: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "drop_shade",
		"to": dest,
		"seat": 0,
	})
	host.eq(bool(result.get("ok", false)), true, "Drop Shade accept succeeds")
	var snap: Dictionary = CombatSim.snapshot()
	var tokens: Array = snap.get("shade_tokens", [])
	host.eq(tokens.size(), 1, "Drop Shade writes shade_tokens on accept")
	host.eq(tokens[0].get("pos"), dest, "shade_tokens names the empty tile")
	host.eq(int(tokens[0].get("turns", 0)), 3, "shade token still lasts 3 turns")
	host.eq(_seat_pos(snap, 0), origin, "Drop Shade does not blink the caster")
	# Accept presentation syncs the marker. No second action and no extra refresh.
	board._present_resolve(result.get("events", []))
	var marker: Node = board._shade_markers.get(dest)
	host.truthy(marker != null and is_instance_valid(marker), "accept syncs a live Shade marker without another action")
	host.eq(marker.get_parent().name, "ShadeMarkers", "the marker is on the ShadeMarkers layer")
	host.eq(marker.get_parent() == board.get_node("Units"), false, "the marker is not parented under Units")
	host.eq(marker.visible, true, "the Shade marker is visible")
	host.eq(int(marker.get("turns")), 3, "the marker keeps the 3 turn count")
	var token := marker.get_node_or_null("Token") as Sprite2D
	var tile := marker.get_node_or_null("TileMarker") as Sprite2D
	host.truthy(token != null and tile != null, "Drop Shade spawns the token sprite and the tile decal")
	host.eq(token.offset, Vector2(0, -72), "Shade token uses the unit foot offset")
	host.eq(token.scale, Vector2(0.5, 0.5), "Shade token uses the unit scale")
	host.truthy(token.texture != null, "Shade token texture is loaded")
	host.truthy(tile.texture != null, "Shade tile decal texture is loaded")
	host.eq(marker.plate_text(), "Ambush", "a live Shade token reads as the Ambush origin")
	host.eq(bool(marker.get("_as_origin")), true, "the marker lifts the origin token")
	host.eq(token.texture.get_width(), 144, "Shade token is the 144px TA sheet")
	host.eq(token.texture.get_height(), 160, "Shade token is the 160px TA sheet")
	host.eq(tile.texture.get_width(), 64, "Shade decal is 64px wide")
	host.eq(tile.texture.get_height(), 48, "Shade decal is 48px tall")
	var layer := board.get_node("ShadeMarkers") as Node2D
	host.eq(layer.z_as_relative, false, "Shade layer z is absolute")
	var buried_z := BoardVisualSort.unit_z_index(Vector2i(14, 14), 2.0)
	host.eq(layer.z_index > buried_z, true, "Shade layer paints above tiles and units")
	host.eq(bool(marker.get("z_as_relative")), false, "Shade marker z is absolute so a south pawn cannot cover it")
	host.eq(int(marker.z_index) > buried_z, true, "Shade marker paints above tiles and units")
	board._settle_motions()
	board._rebuild_pawns()
	host.truthy(is_instance_valid(marker), "rebuild pawns does not free the Shade marker")
	host.eq(marker.get_parent().name, "ShadeMarkers", "rebuild leaves the marker on ShadeMarkers")
	host.eq(_units_hold_shade(board), false, "Units has no Shade marker after rebuild")
	board._refresh()
	var again: Node = board._shade_markers.get(dest)
	host.truthy(again != null and is_instance_valid(again), "refresh keeps a marker for the shade_tokens entry")
	host.eq(again.get_parent().name, "ShadeMarkers", "refresh does not reparent the marker under Units")
	host.eq(int(again.get("turns")), 3, "refresh keeps the turn count")
	host.eq(again.position, board._cell_to_local(dest), "refresh plants the marker on the shade tile")
	var ambush_from := Vector2i(4, 4)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [ambush_from, Vector2i(7, 4)],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
	})
	var ambush: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": Vector2i(7, 4),
		"seat": 0,
	})
	host.eq(bool(ambush.get("ok", false)), true, "Ambush still resolves")
	host.eq(_seat_pos(CombatSim.snapshot(), 0), Vector2i(8, 4), "Ambush is still the blink")
	main.queue_free()
	await host.process_frame


static func _seat_pos(snap: Dictionary, seat: int) -> Vector2i:
	for unit in snap.get("units", []):
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -1)) == seat:
			return unit.get("pos", Vector2i(-1, -1))
	return Vector2i(-1, -1)


static func _units_hold_shade(board: Node) -> bool:
	var marker_script: Script = load("res://board/shade_marker.gd")
	for child in board.get_node("Units").get_children():
		if child.get_script() == marker_script:
			return true
	return false
