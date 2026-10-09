extends RefCounted

## Second presenter, a refresh during the plant hold, and a hit whose
## `teleported` flag was stripped. shade_marker_live only covers one _submit.
## The snap is instant. The slash and the damage float stay off until that plant.


static func run(host: SceneTree) -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	host.get_root().add_child(main)
	await host.process_frame
	await host.process_frame
	var board: Node = main.get_node("BoardView")
	host.truthy(bool(board.get("_booted")), "ambush race board finished boot")
	var cast_cell := Vector2i(6, 0)
	var prey_cell := Vector2i(4, 0)
	var back_cell := Vector2i(3, 0)
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [cast_cell, prey_cell],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	var faded: Dictionary = CombatSim.submit({"type": "cast", "spell": "fade", "to": cast_cell, "seat": 0})
	host.eq(bool(faded.get("ok", false)), true, "ambush race Fade resolves")
	board._present_resolve(faded.get("events", []))
	board._settle_motions()
	board._refresh()
	var faced: Dictionary = CombatSim.submit({"type": "face", "dir": "N", "seat": 0})
	host.eq(bool(faced.get("ok", false)), true, "ambush race Gloam faces away")
	board._present_resolve(faced.get("events", []))
	board._refresh()
	var gloam: Node2D = board.pawns_by_seat[0]
	var kestrel: Node = board.pawns_by_seat[1]
	host.eq(gloam.grid_position, cast_cell, "ambush race starts on the cast cell")
	host.eq(str(gloam.facing), "N", "ambush race pre-strike facing is north")
	var hp_before := int(kestrel.hp)
	var hud: Node = main.get_node("HUD")
	var card_before := str(hud.get("_ironjaw_body").text)
	var resolved: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": prey_cell,
		"seat": 0,
	})
	host.eq(bool(resolved.get("ok", false)), true, "ambush race hit resolves")
	var sim_hit := _ambush_hit(resolved.get("events", []))
	host.eq(str(sim_hit.get("type", "")), "hit", "ambush race connects")
	host.eq(int(sim_hit.get("damage", 0)), 29, "front Ambush is 26 + Fade's 1 Umbral")
	host.eq(bool(sim_hit.get("teleported", false)), true, "the sim still marks the hit as teleported")
	host.eq(sim_hit.get("destination", Vector2i(-1, -1)), back_cell, "the sim lands on the back tile")
	# A second presenter (net echo, coach from last_events) can drop the flag.
	# The phone used to slash from the cast cell for any shape other than
	# ambush + hit + teleported.
	var stripped := _strip_teleported(resolved.get("events", []))
	var stripped_hit := _ambush_hit(stripped)
	host.eq(bool(stripped_hit.get("teleported", false)), false, "the presented copy omits teleported")
	board._present_resolve(stripped)
	var token := int(board.get("_ambush_arrival_token"))
	host.eq(gloam.grid_position, back_cell, "stripped Ambush snaps to the back tile before the slash")
	host.eq(gloam.position.distance_to(board._cell_to_local(back_cell)) <= 1.0, true, "stripped Ambush is standing on the back tile")
	host.eq(str(gloam.facing), "E", "stripped Ambush faces the prey on the snap")
	host.eq(int(kestrel.hp), hp_before, "stripped Ambush does not drop vitals during present")
	host.eq(_attack_strip_visible(gloam), false, "stripped Ambush does not start the strike strip during present")
	host.eq(_ambush_strike_live(board), false, "stripped Ambush does not slash or float during present")
	host.eq(str(hud.toast_caption()).contains("Ambush"), false, "stripped Ambush does not toast during present")
	host.eq(int(board.get("_ambush_open_seat")), 0, "the arrival stays open until the slash")
	# Same hit again, and the original sim batch, while the plant hold is open.
	board._present_resolve(stripped)
	board._present_resolve(resolved.get("events", []))
	host.eq(int(board.get("_ambush_arrival_token")), token, "a second presenter does not restart the arrival")
	host.eq(gloam.grid_position, back_cell, "a second presenter leaves the planted tile")
	host.eq(str(gloam.facing), "E", "a second presenter does not spin off the prey")
	host.eq(_attack_strip_visible(gloam), false, "a second presenter does not arm the strike strip")
	host.eq(_ambush_strike_live(board), false, "a second presenter does not arm the slash or the float")
	host.eq(int(kestrel.hp), hp_before, "a second presenter does not drop vitals")
	# Snapshot is already post-hit. Refresh keeps the planted tile and facing.
	board._refresh()
	host.eq(gloam.grid_position, back_cell, "refresh during the plant hold keeps the back tile")
	host.eq(gloam.position.distance_to(board._cell_to_local(back_cell)) <= 1.0, true, "refresh during the plant hold keeps the sprite planted")
	host.eq(str(gloam.facing), "E", "refresh during the plant hold keeps the strike facing")
	host.eq(int(kestrel.hp), hp_before, "refresh during the plant hold keeps the pre-hit vitals")
	host.eq(str(hud.get("_ironjaw_body").text), card_before, "refresh during the plant hold does not reprint the side card")
	host.eq(_ambush_strike_live(board), false, "refresh during the plant hold does not stamp the slash")
	var faced_on_cast := false
	var slashed_on_cast := false
	var damaged_early := false
	var strike_early := false
	var attack_early := false
	var card_early := false
	var saw_back := false
	var slashed_on_back := false
	for _i in 180:
		await host.process_frame
		var on_back: bool = (
			gloam.grid_position == back_cell
			and gloam.position.distance_to(board._cell_to_local(back_cell)) <= 1.0
		)
		var on_cast: bool = gloam.grid_position == cast_cell
		var offset := _body_offset(gloam)
		if on_cast and str(gloam.facing) != "N":
			faced_on_cast = true
		if on_cast and offset > 10.0:
			slashed_on_cast = true
		if int(kestrel.hp) < hp_before and not on_back:
			damaged_early = true
		if not on_back and _ambush_strike_live(board):
			strike_early = true
		if not on_back and _attack_strip_visible(gloam):
			attack_early = true
		if not on_back and str(hud.get("_ironjaw_body").text) != card_before:
			card_early = true
		if on_back and str(gloam.facing) == "E":
			saw_back = true
		# A painted attack strip is the slash itself (no lunge offset on top).
		if on_back and str(gloam.facing) == "E" and (offset > 10.0 or _attack_strip_visible(gloam)):
			slashed_on_back = true
			break
	host.eq(faced_on_cast, false, "Ambush does not turn toward the prey on the cast cell")
	host.eq(slashed_on_cast, false, "Ambush does not lunge from the cast cell")
	host.eq(damaged_early, false, "Ambush does not drop vitals before the back-tile plant")
	host.eq(strike_early, false, "Ambush does not slash or float before the back-tile plant")
	host.eq(attack_early, false, "Ambush does not play the strike strip before the back-tile plant")
	host.eq(card_early, false, "Ambush does not reprint the side card before the back-tile plant")
	host.eq(saw_back, true, "Ambush plants on the back tile facing the prey")
	host.eq(slashed_on_back, true, "the slash plays only after the back-tile plant")
	host.eq(gloam.grid_position, back_cell, "contact grid is the back tile")
	host.eq(str(gloam.facing), "E", "contact facing is toward Kestrel")
	host.eq(int(kestrel.hp), hp_before - 29, "front Ambush deals 26 + Fade's 1 Umbral only after the plant")
	board._settle_motions()
	host.eq(bool(stripped_hit.get("teleported", false)), false, "contact does not write teleported back onto the presented event")
	host.eq(board._as_cell("nope"), Vector2i(-1, -1), "a failed cell read is not the origin tile")
	host.eq(board._event_cell({"destination": "nope"}, "destination"), Vector2i(-1, -1), "a failed event cell is not the origin tile")
	var bogus: Vector2i = board._ambush_event_dest({
		"type": "hit",
		"spell": "ambush",
		"seat": 0,
		"destination": "nope",
		"to": "nope",
	})
	host.eq(bogus == Vector2i.ZERO, false, "Ambush does not plant a failed cell on the origin")
	# A miss stays a whiff on the cast cell. It must not open the arrival hold.
	CombatSim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [cast_cell, prey_cell],
		"kestrel_facing": "W",
		"rolls": [100],
	})
	board._rebuild_pawns()
	board._refresh()
	var miss_fade: Dictionary = CombatSim.submit({"type": "cast", "spell": "fade", "to": cast_cell, "seat": 0})
	board._present_resolve(miss_fade.get("events", []))
	board._settle_motions()
	board._refresh()
	CombatSim.submit({"type": "face", "dir": "N", "seat": 0})
	board._refresh()
	var missed: Dictionary = CombatSim.submit({
		"type": "cast",
		"spell": "ambush",
		"to": prey_cell,
		"seat": 0,
	})
	host.eq(bool(missed.get("ok", false)), true, "ambush race miss resolves")
	host.eq(str(missed.get("events", [{}])[0].get("type", "")), "miss", "ambush race miss is a miss")
	board._present_resolve(missed.get("events", []))
	var miss_pawn: Node2D = board.pawns_by_seat[0]
	host.eq(miss_pawn.grid_position, cast_cell, "Ambush miss does not leave the cast cell")
	host.eq(int(board.get("_ambush_open_seat")), -1, "Ambush miss does not open the arrival hold")
	host.eq(int(board.pawns_by_seat[1].hp), hp_before, "Ambush miss deals no damage")
	for _miss_frame in 8:
		await host.process_frame
	host.eq(miss_pawn.grid_position, cast_cell, "Ambush miss still has not relocated")
	host.eq(int(board.pawns_by_seat[1].hp), hp_before, "Ambush miss still deals no damage")
	host.eq(_ambush_strike_live(board), false, "Ambush miss does not slash or float damage from the cast cell")
	main.queue_free()
	await host.process_frame


static func _ambush_hit(events: Array) -> Dictionary:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("spell", "")) == "ambush" and str(event.get("type", "")) == "hit":
			return event
	return {}


static func _strip_teleported(events: Array) -> Array:
	var out: Array = []
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			out.append(event)
			continue
		var row: Dictionary = (event as Dictionary).duplicate(true)
		if str(row.get("spell", "")) == "ambush" and str(row.get("type", "")) == "hit":
			row.erase("teleported")
		out.append(row)
	return out


static func _body_offset(pawn: Node) -> float:
	var offset := 0.0
	var sprite := pawn.get_node_or_null("Sprite") as Node2D
	if sprite != null:
		offset = sprite.position.length()
	var body := pawn.get_node_or_null("BodyStrip") as Node2D
	if body != null:
		offset = maxf(offset, body.position.length())
	return offset


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
