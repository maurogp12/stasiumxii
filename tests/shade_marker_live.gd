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
	# Prey is Manhattan 2 cardinal east of the Shade. The plate stays Shade until
	# the opponent completes a turn, then reads Ambush.
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [origin, Vector2i(7, 4)],
		"kestrel_facing": "W",
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
	host.eq(token.offset, load("res://board/shade_marker.gd").TOKEN_OFFSET, "Shade token uses the clicked-tile pivot")
	var cloak_y := float(load("res://board/shade_marker.gd").cloak_center_world_y())
	host.eq(absf(cloak_y) < absf(cloak_y + 32.0), true, "the cloak center is nearer the clicked tile than the screen-north hex")
	host.eq(token.scale, Vector2(0.5, 0.5), "Shade token uses the unit scale")
	host.truthy(token.texture != null, "Shade token texture is loaded")
	host.truthy(tile.texture != null, "Shade tile decal texture is loaded")
	host.eq(marker.plate_text(), "Shade", "a fresh Shade is not an Ambush origin yet")
	host.eq(bool(marker.get("_as_origin")), false, "an unarmed Shade does not lift the origin token")
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
	CombatSim.submit({"type": "end_turn", "seat": 0})
	CombatSim.submit({"type": "end_turn", "seat": 1})
	board._refresh()
	var armed: Node = board._shade_markers.get(dest)
	host.truthy(armed != null and is_instance_valid(armed), "the armed Shade marker is still on the board")
	host.eq(armed.plate_text(), "Ambush", "after the opponent completes a turn the Shade plate reads Ambush")
	host.eq(bool(armed.get("_as_origin")), true, "an armed Shade lifts the origin token")
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [origin, Vector2i(7, 4)],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	var planted_hit: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "drop_shade",
		"to": dest,
		"seat": 0,
	})
	host.eq(bool(planted_hit.get("ok", false)), true, "Ambush fixture plants the Shade")
	CombatSim.submit({"type": "end_turn", "seat": 0})
	CombatSim.submit({"type": "end_turn", "seat": 1})
	CombatSim.submit({"type": "face", "dir": "N", "seat": 0})
	board._refresh()
	var shade_ambush: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": Vector2i(7, 4),
		"seat": 0,
	})
	host.eq(bool(shade_ambush.get("ok", false)), true, "armed Shade Ambush resolves")
	host.eq(str(shade_ambush.get("events", [{}])[0].get("type", "")), "hit", "scripted Ambush roll connects")
	board._present_resolve(shade_ambush.get("events", []))
	var spent: Node = board._shade_markers.get(dest)
	host.eq(spent == null or not is_instance_valid(spent), true, "Ambush consumes the Shade marker in the teleport beat")
	var gloam_pawn: Node = board.pawns_by_seat[0]
	host.eq(gloam_pawn.grid_position, origin, "Ambush fades on the origin tile before the snap")
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + 0.12).timeout
	host.eq(gloam_pawn.grid_position, Vector2i(8, 4), "Ambush snaps onto the back tile")
	host.eq(gloam_pawn.position, board._cell_to_local(Vector2i(8, 4)), "the snap is the back tile, not a body path")
	host.eq(str(gloam_pawn.facing), "W", "Ambush faces the prey")
	var ambush_from := Vector2i(4, 4)
	var ambush_prey := Vector2i(6, 4)
	var ambush_back := Vector2i(7, 4)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [ambush_from, ambush_prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	var before: Node = board.pawns_by_seat[0]
	host.eq(before.grid_position, ambush_from, "Invisible Gloam starts on the cast cell")
	var ambush: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": ambush_prey,
		"seat": 0,
	})
	host.eq(bool(ambush.get("ok", false)), true, "Invisible Ambush still resolves")
	host.eq(_seat_pos(CombatSim.snapshot(), 0), ambush_back, "Invisible Ambush is still the blink")
	host.eq(bool(ambush.get("events", [{}])[0].get("teleported", false)), true, "Invisible Ambush hit teleports")
	board._present_resolve(ambush.get("events", []))
	var blinked: Node = board.pawns_by_seat[0]
	host.eq(blinked.grid_position, ambush_from, "Invisible Ambush fades on the cast cell before the snap")
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + 0.12).timeout
	host.eq(blinked.grid_position, ambush_back, "Invisible Ambush snaps onto the back tile")
	host.eq(blinked.position, board._cell_to_local(ambush_back), "the Invisible snap is the back tile, not a body path")
	host.eq(blinked.grid_position == ambush_from, false, "Invisible Ambush does not slash from the cast cell")
	board._settle_motions()
	host.eq(blinked.grid_position, ambush_back, "the local slash leaves Invisible Gloam on the back tile")
	host.eq(blinked.position, board._cell_to_local(ambush_back), "settling the slash does not walk Gloam back")
	# Adjacent in front, not already on the back tile. The blink is still past the foe.
	var near_from := Vector2i(5, 4)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [near_from, ambush_prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	var near: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": ambush_prey,
		"seat": 0,
	})
	host.eq(bool(near.get("ok", false)), true, "adjacent Invisible Ambush resolves")
	host.eq(_seat_pos(CombatSim.snapshot(), 0), ambush_back, "adjacent Invisible Ambush lands past the foe")
	board._present_resolve(near.get("events", []))
	var near_pawn: Node = board.pawns_by_seat[0]
	host.eq(near_pawn.grid_position, near_from, "adjacent Invisible Ambush fades before the snap")
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + 0.12).timeout
	host.eq(near_pawn.grid_position, ambush_back, "adjacent Invisible Ambush snaps past the foe")
	host.eq(near_pawn.position, board._cell_to_local(ambush_back), "adjacent Invisible snap is not the cast cell")
	# MISS keeps the cast cell. No snap.
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [ambush_from, ambush_prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [100],
	})
	board._rebuild_pawns()
	board._refresh()
	var missed: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": ambush_prey,
		"seat": 0,
	})
	host.eq(bool(missed.get("ok", false)), true, "Invisible Ambush miss resolves")
	host.eq(bool(missed.get("events", [{}])[0].get("teleported", true)), false, "Invisible Ambush miss does not teleport")
	board._present_resolve(missed.get("events", []))
	var stayed: Node = board.pawns_by_seat[0]
	host.eq(stayed.grid_position, ambush_from, "Invisible Ambush miss leaves the pawn on the cast cell")
	host.eq(stayed.position, board._cell_to_local(ambush_from), "Invisible Ambush miss does not snap")
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
