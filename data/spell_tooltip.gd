extends RefCounted
class_name SpellTooltip

## Proposed attack-card chrome. Formats CombatSim.preview_cast only.
## Does not invent kit numbers, rolls, or Open rules. Mastery 0 is omitted.
## Resist is shown only if the preview notes it (provisional/Open, never Locked).

const LONG_PRESS_SEC := 0.45


static func card_text(preview: Dictionary) -> String:
	return "\n".join(card_lines(preview))


static func card_lines(preview: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if preview.is_empty():
		return lines
	var name := str(preview.get("name", ""))
	if name == "" and str(preview.get("spell_id", "")) == "":
		return lines
	if name == "":
		name = str(preview.get("spell_id", ""))
	lines.append(name)
	# Presentation only: preview_cast reason / marks_on_target. No client kit math.
	var needs_marks := _preview_needs_marks(preview)
	if needs_marks:
		var gate := str(preview.get("gate_text", "")).strip_edges()
		lines.append(gate if gate != "" else "needs Marks")
	var range_line := str(preview.get("range_text", "")).strip_edges()
	if range_line == "":
		range_line = SpellKits.range_text(preview)
	lines.append("%d AP / %d MP · %s" % [
		int(preview.get("ap", 0)),
		int(preview.get("mp", 0)),
		range_line,
	])
	# Mauro 6 Oct 2026: every spell explained on hold so "even a 5 year old
	# can understand" — cost, reach and what it does, in plain words.
	var simple := simple_lines(str(preview.get("spell_id", "")), preview)
	if not simple.is_empty():
		lines.append_array(simple)
		lines.append("— Details —")
	var on_connect := str(preview.get("on_connect_text", "")).strip_edges()
	if on_connect != "":
		lines.append("On hit: %s" % on_connect)
	var miss := str(preview.get("on_miss_text", "")).strip_edges()
	if miss != "":
		lines.append("On miss: %s" % miss)
	if preview.get("hit_chance", null) != null:
		lines.append("HIT %d%% (Locked)" % int(preview["hit_chance"]))
	if preview.get("sample_damage", null) != null and int(preview["sample_damage"]) > 0 and not needs_marks:
		var sample := "sample %d  ·  CritMult(1.0) × live Facing" % int(preview["sample_damage"])
		if preview.has("marks_on_target"):
			var formula := str(preview.get("formula", "6+6*M"))
			sample += "  ·  M=%d (%s)" % [int(preview["marks_on_target"]), formula]
		lines.append(sample)
	if str(preview.get("reason", "")) == "needs_marks":
		# Do not lead with a fake sample 6 when M=0; on_connect already has 6+6×M.
		lines.append("Needs 1+ Marks. 6+6×M when Marks exist.")
	if bool(preview.get("would_stun", false)):
		lines.append("Stun 1 (Locked A′) this cast.")
	for note in preview.get("notes", []):
		var text := str(note)
		if text == "":
			continue
		if text.contains("Push") or text.contains("push_blocked") or text.contains("bounce") or text.contains("stagger"):
			lines.append(text)
		elif text.contains("Resist"):
			lines.append(text)
		elif text.contains("teleport") or text.contains("Facing unchanged"):
			if not on_connect.contains("Teleport") and not on_connect.contains("Facing unchanged"):
				lines.append(text)
	return lines


static func _preview_needs_marks(preview: Dictionary) -> bool:
	if str(preview.get("reason", "")) == "needs_marks":
		return true
	if bool(preview.get("needs_marks", false)):
		return true
	if preview.has("marks_on_target") and int(preview["marks_on_target"]) == 0:
		return true
	return false


## Plain-words card (Mauro 6 Oct 2026). Numbers come from the kit data and
## the live preview, so a balance change updates the text too.
static func simple_lines(spell_id: String, preview: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	# Raw kit numbers: the element riders (Water +4 heal, Air +1 range) are
	# per player pick; the live preview range below already carries them.
	var def: Dictionary = SpellKits.SPELLS.get(spell_id, {})
	if def.is_empty():
		return out
	var ap := int(preview.get("ap", def.get("ap", 0)))
	var mp := int(preview.get("mp", def.get("mp", 0)))
	var cost := "Costs %d AP (blue dots)" % ap
	if mp > 0:
		cost += " and %d MP (green dots)" % mp
	out.append(cost + ".")
	var reach := _reach_words(def, preview)
	if reach != "":
		out.append("Reach: %s." % reach)
	var dmg := int(def.get("base_damage", 0))
	var heal := int(def.get("base_heal", 0))
	match spell_id:
		SpellKits.MARK_SHOT:
			out.append("Shoot an arrow at an enemy for %d damage and stick a Mark on them (up to %d Marks)." % [dmg, SpellKits.MARKS_CAP])
			out.append("More Marks = a bigger Detonate later.")
		SpellKits.DETONATE:
			out.append("Blow up the Marks on an enemy: %d damage + %d more for each Mark (3 Marks = %d)." % [dmg, int(def.get("damage_per_mark", 6)), dmg + 3 * int(def.get("damage_per_mark", 6))])
			out.append("The enemy needs at least 1 Mark. All their Marks get used up.")
		SpellKits.VAULT:
			out.append("Jump exactly 2 tiles in a straight line (up, down, left or right) to get away. Only works when an enemy is right next to you. Once per turn. Never misses.")
			out.append("You cannot jump over rocks, crates, walls or steam.")
		SpellKits.SNARE_TRAP:
			out.append("Hide a trap on an empty tile. Enemies cannot see it. The first enemy who steps on it stops there, takes %d damage and cannot walk on their next turn." % int(def.get("trap_damage", 6)))
			out.append("You can have 1 trap at a time. It lasts %d of your turns." % int(def.get("trap_turns", 3)))
		SpellKits.ADVANCE:
			out.append("Jump exactly 2 tiles in a straight line (up, down, left or right). It never misses.")
			out.append("Land next to an enemy = +1 Impact. You can jump over water, mud and lava, but not over rocks, crates, walls or steam. Max 2 jumps per turn.")
		SpellKits.STRIKE:
			out.append("Punch an enemy right next to you for %d damage. Hit = +1 Impact." % dmg)
		SpellKits.SHOULDER:
			out.append("Shove an enemy next to you: %d damage and push them 1 tile away. Hit = +1 Impact." % dmg)
			out.append("If they crash into a wall or the edge, you get +2 Impact instead.")
		SpellKits.CRUSH:
			out.append("A big smash on an enemy next to you for %d damage. Needs 2 Impact and uses 2." % dmg)
			out.append("If your Impact is full (%d), the enemy is Stunned and skips their next turn, and it uses ALL your Impact." % SpellKits.IMPACT_CAP)

		SpellKits.MEND:
			out.append("Heal a teammate or yourself for %d HP. Very hurt friends (under 40%% HP) get 25%% more. +1 Pulse." % heal)
		SpellKits.PULSE_TAP:
			out.append("Tap a teammate (or yourself) to heal %d HP. Uses 1 Pulse." % heal)
			out.append("Last Stand: when you are the last one alive and cannot Rekindle anyone, it can also hit an enemy for %d." % int(SpellKits.LAST_STAND_DAMAGE[SpellKits.PULSE_TAP]))
		SpellKits.WARD:
			out.append("Give every teammate within %d tiles, you too, a shield of +%d. Cast it again to stack it up to %d. Hits break the shield before they hurt you; it stays until it breaks. Uses %d Aegis." % [int(def.get("ward_radius", 3)), int(def.get("shield", 20)), int(def.get("shield_cap", 60)), int(def.get("spend_aegis", 3))])
			out.append("Thorns (always on): enemies who hit Bastion from right next to him take 20% of that hit back.")
		SpellKits.CLEANSE:
			out.append("Take away 1 bad effect from a teammate (Stun first). 3 bad effects? Use it 3 times. +1 Pulse.")
		SpellKits.HEARTSTOP:
			out.append("Heal a teammate (or yourself) %d HP, and the next hit on them does nothing. Uses 2 Pulse." % heal)
			out.append("Last Stand: when you are the last one alive and cannot Rekindle anyone, it can also hit an enemy for %d and stop them walking next turn." % int(SpellKits.LAST_STAND_DAMAGE[SpellKits.HEARTSTOP]))
		SpellKits.REKINDLE:
			out.append("Bring a knocked-out teammate back with %d%% HP. Needs full Pulse (%d) and uses all of it. Once per match." % [int(def.get("revive_pct", 30)), SpellKits.PULSE_CAP])
		SpellKits.CUT:
			out.append("Slash an enemy next to you for %d damage. Hit = +1 Umbral." % dmg)
		SpellKits.DROP_SHADE:
			out.append("Put a secret shadow on an empty tile. Only you can see it. Max %d, lasts %d turns." % [SpellKits.SHADE_CAP, int(def.get("shade_turns", 3))])
			out.append("After the enemy plays one turn, Ambush can jump from it.")
		SpellKits.AMBUSH:
			out.append("Teleport behind an enemy and stab them for %d damage." % dmg)
			out.append("The enemy must be 1-2 tiles away in a straight line from you or from your Shade. Behind them blocked? You land in front. Their back = 35% more damage. Miss = you stay put.")
		SpellKits.FADE:
			out.append("Turn invisible until your next turn: enemies cannot see you. Getting hurt or attacking shows you again. +1 Umbral.")
		SpellKits.NIGHTFOLD:
			out.append("Not ready yet. This spell comes later.")
		SpellKits.BASH:
			out.append("Hit an enemy next to you with your shield for %d damage. Hit = +1 Aegis." % dmg)
		SpellKits.PLANT:
			out.append("Plant your flag on a tile. +1 Aegis. Stand on it and the first push against you does nothing. Lasts %d turns." % int(def.get("plant_turns", 3)))
		SpellKits.HOLD_LINE:
			out.append("Swing at the 3 tiles in front of you: %d damage to every enemy there. They need 1 extra MP to walk away next turn. +1 Aegis." % dmg)
		SpellKits.SNAP_WALL:
			out.append("Build a wall on an empty tile. Nobody can walk or shoot through it. Lasts %d of your turns. Uses 2 Aegis." % int(def.get("wall_turns", 2)))
			out.append("Use it on your own wall to knock it down and get the 2 Aegis back.")
		SpellKits.AEGIS_BREAK:
			out.append("Slam the ground: %d damage to every enemy 1-2 tiles from you, and push them 1 tile. Needs %d Aegis." % [dmg, int(def.get("requires_aegis", 3))])
			out.append("A hit uses all your Aegis. A miss keeps it.")
		_:
			pass
	var engine := _engine_words(_class_of(spell_id), spell_id)
	if engine != "":
		out.append(engine)
	if bool(def.get("rolls", false)) and not bool(def.get("gated", false)):
		var chance := ""
		if preview.get("hit_chance", null) != null:
			chance = " Chance right now: %d%%." % int(preview["hit_chance"])
		if def.has("hit_by_distance"):
			out.append("It can miss. Kestrel aims better from far away: the farther, the easier to hit.%s" % chance)
		else:
			out.append("It can miss. Closer = easier to hit.%s" % chance)
		if dmg > 0:
			out.append("Hit their back: +%d%% damage." % (35 if _class_of(spell_id) == SpellKits.CLASS_GLOAM else 20))
	elif not bool(def.get("gated", false)):
		out.append("No dice: it always works.")
	if SpellKits.is_flex(spell_id):
		out.append("Element: the one you picked on the Elements screen.")
	return out


static func _reach_words(def: Dictionary, preview: Dictionary) -> String:
	var target := str(def.get("target", ""))
	if def.has("ward_radius"):
		return "you and every teammate within %d tiles" % int(def["ward_radius"])
	if target == "self":
		return "only you"
	if bool(def.get("gated", false)):
		return ""
	var lo := int(preview.get("min_range", def.get("min_range", 0)))
	var hi := int(preview.get("max_range", def.get("max_range", 0)))
	if target == "burst":
		return "everyone %d-%d tiles around you" % [lo, hi]
	if target == "cone":
		return "the 3 tiles in front of you"
	var line := " in a straight line" if str(def.get("range_mode", "")) == "cardinal" else ""
	if lo == hi:
		if lo == 1:
			return "right next to you"
		return "exactly %d tiles away%s" % [lo, line]
	if lo == 0:
		return "you, or up to %d tiles away%s" % [hi, line]
	return "%d to %d tiles away%s" % [lo, hi, line]


static func _engine_words(class_id: String, spell_id: String) -> String:
	match class_id:
		SpellKits.CLASS_IRONJAW:
			if spell_id == SpellKits.ADVANCE:
				return ""
			return "Impact = Ironjaw's power dots (max %d). They fade on a turn you do not attack. Shield breaker: any Ironjaw hit shatters the target's whole shield." % SpellKits.IMPACT_CAP
		SpellKits.CLASS_MENDER:
			return "Pulse = Mender's power dots (max %d). They fade on a turn you cast no spell." % SpellKits.PULSE_CAP
		SpellKits.CLASS_BASTION:
			return "Aegis = Bastion's power dots (max %d). They fade on a turn you do not attack." % SpellKits.AEGIS_CAP
		SpellKits.CLASS_GLOAM:
			if spell_id == SpellKits.CUT or spell_id == SpellKits.FADE:
				return "Umbral = Gloam's power dots (max %d), saved for Nightfold." % SpellKits.UMBRAL_CAP
	return ""


static func _class_of(spell_id: String) -> String:
	for class_id in SpellKits.CLASS_SPELLS:
		if (SpellKits.CLASS_SPELLS[class_id] as Array).has(spell_id):
			return str(class_id)
	return ""
