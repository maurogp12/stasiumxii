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
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + ViewMotion.AMBUSH_ARRIVE_HOLD_SEC + 0.05).timeout
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
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + ViewMotion.AMBUSH_ARRIVE_HOLD_SEC + 0.05).timeout
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
	await host.create_timer(ViewMotion.AMBUSH_COLLAPSE_SEC + ViewMotion.AMBUSH_ARRIVE_HOLD_SEC + 0.05).timeout
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
	# Player path. Fade, then _submit, not only _present_resolve. The body fades
	# on the cast cell, stands on the back tile before the slash, and a miss
	# keeps Invisible.
	var submit_from := Vector2i(6, 0)
	var submit_prey := Vector2i(4, 0)
	var submit_back := Vector2i(3, 0)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [submit_from, submit_prey],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	var submit_fade: Dictionary = CombatSim.submit({"type": "cast", "spell": "fade", "to": submit_from, "seat": 0})
	host.eq(bool(submit_fade.get("ok", false)), true, "submit-path Fade resolves")
	board._present_resolve(submit_fade.get("events", []))
	board._settle_motions()
	board._refresh()
	var submit_pawn: Node2D = board.pawns_by_seat[0]
	host.eq(submit_pawn.grid_position, submit_from, "submit-path Gloam starts on the cast cell")
	var turned: Dictionary = CombatSim.submit({"type": "face", "dir": "N", "seat": 0})
	host.eq(bool(turned.get("ok", false)), true, "submit-path Gloam faces away before Ambush")
	board._present_resolve(turned.get("events", []))
	board._refresh()
	host.eq(submit_pawn.facing, "N", "submit-path facing is not the strike facing yet")
	for _warm in 4:
		await host.process_frame
	var hud: Node = main.get_node("HUD")
	var foe_card_before := str(hud.get("_ironjaw_body").text)
	var coach_before := str(hud.get("_coach_label").text)
	board._submit({"type": "cast", "spell": "ambush", "to": submit_prey, "seat": 0})
	# The collapse tween has not stepped yet. The body is still on the cast cell.
	# Hit chrome that lands in this beat is the Invisible Ambush regression:
	# slash, toast, coach, and HP while Gloam has not snapped.
	host.eq(submit_pawn.grid_position, submit_from, "submit-path collapse starts on the cast cell")
	host.eq(submit_pawn.facing, "N", "submit-path collapse does not face the prey early")
	host.eq(str(hud.get("_ironjaw_body").text), foe_card_before, "Invisible Ambush does not drop prey HP before the snap")
	host.eq(_hit_line(str(hud.get("_coach_label").text)), false, "Invisible Ambush does not announce the hit before the snap")
	host.eq(str(hud.toast_caption()).contains("Ambush"), false, "Invisible Ambush does not toast before the snap")
	host.eq(_ambush_strike_live(board), false, "Invisible Ambush does not slash or float damage before the snap")
	var foe_pawn: Node = board.pawns_by_seat[1]
	var hp_before := int(foe_pawn.hp)
	var saw_collapse := true
	var saw_hold := false
	var faced_on_back := false
	var faced_on_cast := false
	var slashed_before_hold := false
	var damaged_on_cast := false
	var early_card := false
	var early_coach := false
	var early_toast := false
	var early_strike := false
	var early_attack := false
	for _i in 90:
		await host.process_frame
		var on_back_facing: bool = submit_pawn.grid_position == submit_back and str(submit_pawn.facing) == "E"
		var sprite := submit_pawn.get_node_or_null("Sprite") as Node2D
		var offset := 0.0
		if sprite != null:
			offset = sprite.position.length()
		var body := submit_pawn.get_node_or_null("BodyStrip") as Node2D
		if body != null:
			offset = maxf(offset, body.position.length())
		if submit_pawn.grid_position == submit_from and offset < 4.0:
			saw_collapse = true
		if submit_pawn.grid_position == submit_from and submit_pawn.facing == "E":
			faced_on_cast = true
		if saw_collapse and on_back_facing and offset < 4.0:
			saw_hold = true
			faced_on_back = true
		if not saw_hold and submit_pawn.grid_position == submit_from and offset > 10.0:
			slashed_before_hold = true
		if int(foe_pawn.hp) < hp_before and not on_back_facing:
			damaged_on_cast = true
		if not on_back_facing and str(hud.get("_ironjaw_body").text) != foe_card_before:
			early_card = true
		if not on_back_facing and _hit_line(str(hud.get("_coach_label").text)) and str(hud.get("_coach_label").text) != coach_before:
			early_coach = true
		if not on_back_facing and str(hud.toast_caption()).contains("Ambush"):
			early_toast = true
		if not on_back_facing and _ambush_strike_live(board):
			early_strike = true
		if not on_back_facing and _attack_strip_visible(submit_pawn):
			early_attack = true
		if saw_hold and offset > 10.0:
			break
		if not bool(board.get("_view_locked")) and saw_hold:
			break
	host.eq(saw_collapse, true, "submit-path Invisible Ambush fades on the cast cell")
	host.eq(faced_on_cast, false, "Invisible Ambush does not face the prey from the cast cell")
	host.eq(faced_on_back, true, "Invisible Ambush faces the prey on the back tile before the slash")
	host.eq(saw_hold, true, "submit-path Invisible Ambush stands on the back tile before the slash")
	host.eq(slashed_before_hold, false, "submit-path Invisible Ambush does not slash from the cast cell")
	host.eq(damaged_on_cast, false, "Instant Invisible Ambush does not deal damage before the back-tile snap")
	host.eq(early_card, false, "Invisible Ambush does not drop the HUD HP before the back-tile face")
	host.eq(early_coach, false, "Invisible Ambush does not print the hit line before the back-tile face")
	host.eq(early_toast, false, "Invisible Ambush does not toast before the back-tile face")
	host.eq(early_strike, false, "Invisible Ambush does not stamp the slash or float damage before the back-tile face")
	host.eq(early_attack, false, "Invisible Ambush does not play the strike strip before the back-tile face")
	host.eq(submit_pawn.grid_position, submit_back, "submit-path contact is on the back tile")
	host.eq(submit_pawn.facing, "E", "submit-path contact faces Kestrel")
	host.eq(int(foe_pawn.hp) < hp_before, true, "Invisible Ambush deals damage only after the back-tile face")
	host.eq(str(hud.get("_ironjaw_body").text) != foe_card_before, true, "prey HP drops once Gloam is facing from the back tile")
	var locked_for := 0
	while bool(board.get("_view_locked")) and locked_for < 90:
		await host.process_frame
		locked_for += 1
	board._settle_motions()
	host.eq(submit_pawn.grid_position, submit_back, "submit-path settle leaves Gloam on the back tile")
	host.eq(submit_pawn.position, board._cell_to_local(submit_back), "submit-path settle does not walk Gloam back")
	var submit_sprite := submit_pawn.get_node_or_null("Sprite") as CanvasItem
	host.eq(submit_sprite != null and submit_sprite.modulate.a > 0.9, true, "submit-path arrival restores the body")
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [submit_from, submit_prey],
		"kestrel_facing": "W",
		"rolls": [100],
	})
	board._rebuild_pawns()
	board._refresh()
	var miss_fade: Dictionary = CombatSim.submit({"type": "cast", "spell": "fade", "to": submit_from, "seat": 0})
	board._present_resolve(miss_fade.get("events", []))
	board._settle_motions()
	board._refresh()
	await board._submit({"type": "cast", "spell": "ambush", "to": submit_prey, "seat": 0})
	var miss_pawn: Node2D = board.pawns_by_seat[0]
	host.eq(miss_pawn.grid_position, submit_from, "submit-path Invisible miss does not teleport")
	host.eq(miss_pawn.position, board._cell_to_local(submit_from), "submit-path Invisible miss stays on the cast cell")
	var miss_snap: Dictionary = CombatSim.snapshot()
	var miss_unit: Dictionary = {}
	for unit in miss_snap.get("units", []):
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -1)) == 0:
			miss_unit = unit
	host.eq(bool(miss_unit.get("invisible", false)), true, "submit-path Ambush miss keeps Invisible")
	main.queue_free()
	await host.process_frame


static func _hit_line(text: String) -> bool:
	return text.contains("HIT") and text.contains("Ambush")


static func _attack_strip_visible(pawn: Node) -> bool:
	for child in pawn.get_children():
		if not (child is AnimatedSprite2D):
			continue
		var strip := child as AnimatedSprite2D
		if strip.visible and String(strip.animation).begins_with("attack"):
			return true
	return false


static func _ambush_strike_live(board: Node) -> bool:
	var vfx: Node = board.get("_vfx")
	if vfx == null:
		return false
	var pools: Variant = vfx.get("_pools")
	if typeof(pools) != TYPE_DICTIONARY:
		return false
	var slash_tex: Texture2D = load("res://vfx/vfx_stamp.gd").texture_for("ambush_slash")
	for node in pools.get("stamp", []):
		if node == null or not bool(node.get("in_use")):
			continue
		var sprite: Sprite2D = node.get("_sprite") as Sprite2D
		if sprite != null and slash_tex != null and sprite.texture == slash_tex:
			return true
	for node in pools.get("number", []):
		if node == null or not bool(node.get("in_use")):
			continue
		if str(node.get("_kind")) == "damage":
			return true
	return false


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
