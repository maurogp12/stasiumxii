extends RefCounted
class_name ViewMotion

## View-only motion tunables. CombatSim never reads this file.
## Mobile-track chrome (`mobile` only). Kits, hit bands, AP/MP, and marks stay put.
## Batch 1 walk/attack strips load from art/export_2x/characters when the
## files exist (SE→e, SW→s, NE→n, NW→w). The foot eases from cell to cell
## in one tile time (ease-in-out, not a linear skate). `walk_<facing>` plays
## exactly one cycle on that tween. The foot-down cell shows when the hop is
## on Y=0 and through the plant hold. That cell is frame 0 on the v5 sheets;
## the sampler retargets when it is not. The sprite hops a few pixels, and
## squashes on the plant only. The foot, ground marks, aim rings, shade, and
## name chrome stay put. A missing strip keeps that hop and adds squash
## on launch/land plus stretch at the crest. It does not play a tile-tall hop.
## The first tile, and a direction change, settle for a short weight shift
## after the facing is already set. A 180 finishes the plant, then turns,
## then settles, then steps. It does not spin through a side facing.
## Middle tiles do not settle. Arrival holds the planted idle before a cast.
## One-shot motions stay within ACTION_LOCK_MAX. Idle is a loop whose
## period is the breathe cycle (longer than one action beat).
## Every non-teleport spell gets caster chrome: a short squash / pull-back,
## then the lunge or cast rise, then a brief hold on the impact pose.
## The hold is clamped to the time left in ACTION_LOCK_MAX. Advance stays a snap.
## Flip REDUCE_MOTION to true to skip idle, step bounce, lunge, wind-up,
## knockback, lift, and slump. Walks still step along the path.
## A project setting named stasium/view/reduce_motion does the same when set.

const REDUCE_MOTION := false
const ACTION_LOCK_MAX := 0.6
## Commit events that play the caster's body motion. Misses are included.
const CASTER_EVENT_TYPES: Array[String] = ["cast", "miss", "hit", "snap_wall"]

const IDLE_PERIOD := 1.9
const IDLE_BOB_PX := 1.5
const IDLE_PHASE_STEP := 0.73

## Sprite-local hop. The old phone hop was HOP_PX 36, about one iso tile.
## The shared crest is 3px. Bastion sits a little under that. Ironjaw uses
## the shared 3px. Kestrel and Gloam sit a little over. None clear 4px.
## Feet plant on Y=0 at both tile edges, and the last slice of the tween
## stays planted. No press into the floor. Walk strips squash on that plant
## only, never mid-hop. The rise
## is in sprite pixels, so camera zoom does not change the stride.
const WALK_BOUNCE_PX := 3.0
const HOP_PX := 3.0
## Last 18% of the tile tween. Travel has arrived, hop Y is 0, and the walk
## strip is the foot-down cell. Not a Mario bounce. Do not stretch tile time.
const HOP_PLANT_AT := 0.82
## GLIDE walk. Every tile eases (slow at the plant, faster mid-step). The
## stride plants a contact frame on each tile edge and follows that eased
## travel. A height change finishes the step, then rises in place. The hop /
## plant curves below stay for GLIDE off. A static var so that fallback stays
## testable.
static var glide: bool = true
## One step per tile (Mauro 2 Oct 2026: "one step per tile"): the stride cycle spans two tiles.
static var step_per_tile: bool = true
## Footfall bob height as a share of the class hop crest.
const GLIDE_BOB_SHARE := 0.45
## One hop per tile. Matches Pawn.WALK_TILE_SEC. Driven steps sample the
## strip from the tween, so this period is not a free clock.
const WALK_STEP_SEC := 0.34
## Weight shift before the first tile and before a direction change only.
## About one frame at the 20 fps playback rate. Facing is already set.
## A 180 uses this same settle after the plant, not a mid-tile spin.
const STEP_SETTLE_SEC := 0.05
const STEP_SETTLE_PX := 2.0
## Plant weight on the sprite child. Y eases 0.96 → 1 across the plant hold
## (0.18 * 0.30s = 54ms, inside 40–60ms). X stays 1. Mid-hop stays at rest.
const PLANT_SQUASH_Y := 0.96
## Path end. The landed contact holds long enough to read one idle before
## a cast or the face pad. Two frames at the 20 fps stride rate.
const STOP_IDLE_SEC := 0.10

const ATTACK_OUT_SEC := 0.12
const ATTACK_BACK_SEC := 0.10
## Melee lunge reaches the shared tile edge. A cardinal iso step is
## hypot(32, 16) ≈ 36px center to center, so the edge is ~18px.
## Ambush keeps the longer reach.
const ATTACK_LUNGE_PX := 18.0
## Contact slash after the snap. It is a local reach, not a board dash.
## Facing damage stays the sim's existing resolution. This reach is view-only.
const AMBUSH_LUNGE_PX := 36.0
## Kept so a later note can name the old cast-cell squash. The snap is instant.
## Origin dust is chrome in that same beat, not a delay before the plant.
const AMBUSH_COLLAPSE_SEC := 0.18
## Rest on the back tile after the snap, before the slash. Long enough that the
## blink reads as a relocation. The slash stays a local pose on that tile.
const AMBUSH_ARRIVE_HOLD_SEC := 0.28
## Miss whiff. The body stays on the cast cell.
const AMBUSH_WHIFF_SEC := 0.16

## Coil before the lunge or the cast release. Long enough to read on a phone.
## Pull stays short so the lunge is already forward a tenth of a second in.
## The squash is the readable wind-up. Cast dip is its own, deeper coil.
const ANTICIPATION_SEC := 0.08
const ANTICIPATION_PULL_PX := 6.0
const ANTICIPATION_SQUASH_X := 1.28
const ANTICIPATION_SQUASH_Y := 0.72
const CAST_DIP_PX := 6.5
## Plant after a walk. Feet stay on the tile. The squash is the landing weight.
const LAND_SEC := 0.16
const LAND_SQUASH := Vector2(1.16, 0.8)

## Impact pose. impact_hold_sec() clamps this to the lock that is still free.
const IMPACT_HOLD_SEC := 0.20

const CAST_RISE_SEC := 0.12
const CAST_HOLD_SEC := 0.20
const CAST_RELEASE_SEC := 0.10
const CAST_RISE_PX := 10.0
const CAST_SCALE := 1.14

const REACTION_DELAY := 0.06

const HIT_OUT_SEC := 0.08
## Hold the knock so the contact reads. The clock is not paused.
const HIT_STOP_SEC := 0.045
## A crit holds a little longer, still inside the 60–80ms read.
const CRIT_HIT_STOP_SEC := 0.07
## Board pixels. Big enough to read on a phone, still on the victim's tile.
const CRIT_KNOCK_PX := 22.0
const HIT_SHAKE_SEC := 0.08
const HIT_RETURN_SEC := 0.08
const HIT_KNOCK_PX := 6.0
const HIT_SHAKE_PX := 1.6
const HIT_SQUASH_X := 1.18
const HIT_SQUASH_Y := 0.74

const SUPPORT_SEC := 0.34
const SUPPORT_RISE_PX := 4.0

const DEATH_SEC := 0.55
const DEATH_SQUASH_X := 1.28
const DEATH_SQUASH_Y := 0.34
const DEATH_TILT_DEG := 26.0
## A fallen hero stays on the floor, greyed, so Mender's Rekindle can target
## the body (Mauro 3 Oct 2026). Monsters still leave the board (Pawn).
const DEATH_FADE_ALPHA := 0.8
const DEATH_DROP_PX := 18.0
## Collapse finishes here, then the pose holds through the rest of the beat.
const DEATH_COLLAPSE_AT := 0.42
const FACING_RING: Array[String] = ["N", "E", "S", "W"]
## No-strip hop only. A playing walk cycle stays at rest scale.
const FALLBACK_SQUASH := Vector2(1.2, 0.76)
const FALLBACK_STRETCH := Vector2(0.86, 1.18)
## Detonate point. Connects the caster to the effect when no cast strip exists.
const CAST_POINT_PX := 22.0

static var _force_reduce: int = -1


static func reduce_motion() -> bool:
	if _force_reduce == 1 or REDUCE_MOTION:
		return true
	if _force_reduce == 0:
		return false
	if ProjectSettings.has_setting("stasium/view/reduce_motion"):
		return bool(ProjectSettings.get_setting("stasium/view/reduce_motion"))
	return false


static func set_reduce_motion(enabled: bool) -> void:
	_force_reduce = 1 if enabled else 0


static func clear_reduce_motion() -> void:
	_force_reduce = -1


static func attack_sec() -> float:
	var body := _prelude(ATTACK_OUT_SEC, ATTACK_BACK_SEC)
	return body + impact_hold_sec(body)


static func cast_sec() -> float:
	var body := _prelude(CAST_RISE_SEC, CAST_RELEASE_SEC)
	return body + impact_hold_sec(body)


## Hold on the impact pose. `spent` is the rest of the one-shot (wind-up,
## strike, recover). The result never pushes that one-shot past the lock.
static func impact_hold_sec(spent: float = -1.0) -> float:
	var used := _prelude(ATTACK_OUT_SEC, ATTACK_BACK_SEC) if spent < 0.0 else spent
	var room := ACTION_LOCK_MAX - used
	if room <= 0.0:
		return 0.0
	return minf(IMPACT_HOLD_SEC, room)


## Seconds from the start of the contact slash to the hit. Damage waits this
## long after the snap so the number is the facing resolution, not a second hit.
static func ambush_contact_sec() -> float:
	return ANTICIPATION_SEC + ATTACK_OUT_SEC


## Wall-clock for the plant hold and the slash. The snap itself is instant.
## The 0.6s action lock is shorter than that chain, so the board waits this long.
static func ambush_sequence_sec() -> float:
	return AMBUSH_ARRIVE_HOLD_SEC + attack_sec() + 0.35


## Success, Shade and Invisible alike: instant snap to the back tile, face the
## prey, hold, then slash, then the 22. Origin dust is chrome, not a delay.
## Miss: whiff only. No snap and no damage beat. A slash from the cast cell
## is not this sequence.
static func ambush_beats(event: Dictionary) -> Array:
	if str(event.get("spell", "")) != SpellKits.AMBUSH and str(event.get("spell", "")) != "ambush":
		return []
	var typ := str(event.get("type", ""))
	if typ == "hit":
		return [
			{"beat": "snap"},
			{"beat": "face", "sec": AMBUSH_ARRIVE_HOLD_SEC},
			{"beat": "slash"},
			{"beat": "damage"},
		]
	if typ == "miss":
		return [{"beat": "whiff"}]
	return []


static func attack_phase(t: float) -> String:
	return _phase(t, attack_sec(), ATTACK_OUT_SEC, ATTACK_BACK_SEC)


static func cast_phase(t: float) -> String:
	return _phase(t, cast_sec(), CAST_RISE_SEC, CAST_RELEASE_SEC)


static func _stop_sec(stop: float) -> float:
	return HIT_STOP_SEC if stop < 0.0 else stop


static func hit_sec(stop: float = -1.0) -> float:
	return HIT_OUT_SEC + _stop_sec(stop) + HIT_SHAKE_SEC + HIT_RETURN_SEC


## Push, 70ms hold, stagger, return. Stays under the action lock on its own.
static func crit_motion_sec() -> float:
	return 0.48


static func _crit_phases(duration: float) -> Dictionary:
	var span := maxf(duration, 0.16)
	var hold := minf(CRIT_HIT_STOP_SEC, maxf(span * 0.22, 0.05))
	var push := minf(0.12, maxf((span - hold) * 0.34, 0.05))
	var stagger := minf(0.14, maxf((span - hold - push) * 0.45, 0.05))
	var back := maxf(span - push - hold - stagger, 0.04)
	return {"push": push, "hold": hold, "stagger": stagger, "back": back}


static func support_sec() -> float:
	return SUPPORT_SEC


static func death_sec() -> float:
	return DEATH_SEC


static func idle_phase_sec(seat: int, salt: String) -> float:
	var hashed := absi(salt.hash())
	var frac := float(hashed % 1000) / 1000.0
	return fposmod(float(seat) * IDLE_PHASE_STEP + frac * 0.55, IDLE_PERIOD)


## "attack" lunges. "cast" winds up. Advance (teleport) stays a snap.
## Stasis monster spells: melee / dash / cone / ring swing the body; shots,
## lines and pads are casts.
const _FoeKits := preload("res://backend/foe_kits.gd")
## Caster Bolt VFX sheet: cast flash 0–0.12, travel at 18 tiles/s, capped so
## the whole bolt lands by 0.40 s.
const FOE_BOLT_CAST_SEC := 0.12
const FOE_BOLT_TILES_PER_SEC := 18.0
const FOE_BOLT_MAX_SEC := 0.40


static func foe_bolt_travel_sec(tiles: int) -> float:
	return clampf(float(tiles) / FOE_BOLT_TILES_PER_SEC, 0.08, FOE_BOLT_MAX_SEC - FOE_BOLT_CAST_SEC)


static func caster_motion(spell_id: String) -> String:
	if _FoeKits.is_foe_spell(spell_id):
		var shape := str(_FoeKits.spell(spell_id).get("shape", ""))
		if shape in ["melee", "dash", "cone", "radius"]:
			return "attack"
		if shape in ["shot", "line", "pads", "blast", "summon"]:
			return "cast"
		return ""
	var def := SpellKits.spell(spell_id)
	if def.is_empty():
		return ""
	if str(def.get("move_mode", "")) == "teleport":
		return ""
	if spell_id == SpellKits.AMBUSH:
		return "attack"
	var max_range := int(def.get("max_range", 99))
	var damage := int(def.get("base_damage", 0))
	var target := str(def.get("target", ""))
	if damage > 0 and max_range <= 1 and (target == "enemy" or target == "cone"):
		return "attack"
	return "cast"


## Damage recoils. Heal, Ward, and Cleanse rise. Misses do neither.
static func target_motion(flash_kind: String) -> String:
	if flash_kind == "damage":
		return "hit"
	if flash_kind == "support" or flash_kind == "ward":
		return "lift"
	return ""


## Mark Shot bolt travel after the arrow leaves. Same length as
## VfxRouter.MARK_FLIGHT_SEC. Kept here so the flinch does not import VFX.
## Inside 0.2–0.4s. Not a kit number.
const MARK_BOLT_SEC := 0.24
## Bow windup before the bolt, including the arrow-tip release. Same length as
## the cast stamp holds (70 + 80 + 80 + 70 ms). Not tile time.
const MARK_WINDUP_SEC := 0.30


## Seconds from the caster motion (or the Ambush slash, which is armed on the
## back tile) until damage resolves. The victim flinch waits this long.
## A miss and a self-cast never reach it.
## Painted 5-star boss effects: the body frame that fires (artist NOTES) and
## the cannonball flight. VfxRouter.BOSS_FX draws them.
const BOSS_FX_TIMING := {
	"brine.cannon": {"body": "cast", "frames": 8, "fire": 3, "flight": 0.42},
	"slag.caldera": {"body": "attack", "frames": 6, "fire": 2, "flight": 0.0},
}


## Seconds from the resolve to the boss's fire frame.
static func boss_fx_fire_sec(spell_id: String) -> float:
	var fx: Dictionary = BOSS_FX_TIMING.get(spell_id, {})
	if fx.is_empty():
		return 0.0
	var body := cast_sec() if str(fx["body"]) == "cast" else attack_sec()
	return body * float(int(fx["fire"])) / float(maxi(int(fx["frames"]), 1))


static func boss_fx_flight_sec(spell_id: String) -> float:
	return float((BOSS_FX_TIMING.get(spell_id, {}) as Dictionary).get("flight", 0.0))


## Seconds from the resolve to the impact (explosion or eruption start).
static func boss_fx_impact_sec(spell_id: String) -> float:
	if not BOSS_FX_TIMING.has(spell_id):
		return 0.0
	return boss_fx_fire_sec(spell_id) + boss_fx_flight_sec(spell_id)


static func damage_resolve_sec(spell_id: String) -> float:
	match spell_id:
		SpellKits.STRIKE, SpellKits.SHOULDER, SpellKits.CRUSH:
			return StripLibrary.release_sec("ironjaw", "attack")
		SpellKits.CUT:
			return StripLibrary.release_sec("gloam", "attack")
		SpellKits.AMBUSH:
			return ambush_contact_sec()
		SpellKits.MARK_SHOT:
			return MARK_WINDUP_SEC + MARK_BOLT_SEC
		SpellKits.DETONATE:
			return StripLibrary.release_sec("kestrel", "cast")
		_:
			if bool(_FoeKits.spell(spell_id).get("bolt", false)):
				return FOE_BOLT_CAST_SEC + foe_bolt_travel_sec(5)
			if BOSS_FX_TIMING.has(spell_id):
				return boss_fx_impact_sec(spell_id)
			if _mender_damage_spell(spell_id) and not StripLibrary.painted_action_spec(SpellKits.CLASS_MENDER, "attack").is_empty():
				return StripLibrary.release_sec(SpellKits.CLASS_MENDER, "attack")
			if caster_motion(spell_id) == "attack":
				# A painted attack strikes on its own impact cell.
				var cls := _spell_class(spell_id)
				if cls != "" and not StripLibrary.painted_action_spec(cls, "attack").is_empty():
					return StripLibrary.release_sec(cls, "attack")
				return ANTICIPATION_SEC + ATTACK_OUT_SEC
			return 0.0


## Mender spell that can deal damage (Pulse Tap since option B, Heartstop).
static func _mender_damage_spell(spell_id: String) -> bool:
	if not SpellKits.has_spell(SpellKits.CLASS_MENDER, spell_id):
		return false
	return int(SpellKits.spell(spell_id).get("base_damage", 0)) > 0


## True when this Mender cast event strikes a foe and the painted lantern
## attack is on disk: damage landed, or a Heartstop missed (it only harms).
## A Pulse Tap miss stays the skill (it could have been a heal).
static func mender_strikes(event: Dictionary) -> bool:
	var spell_id := str(event.get("spell", ""))
	if not _mender_damage_spell(spell_id):
		return false
	if StripLibrary.painted_action_spec(SpellKits.CLASS_MENDER, "attack").is_empty():
		return false
	if int(event.get("damage", 0)) > 0 and int(event.get("target_seat", -1)) != int(event.get("seat", -2)):
		return true
	return str(event.get("type", "")) == "miss" and spell_id == SpellKits.HEARTSTOP


## Roster class that owns a hero spell, or "".
static func _spell_class(spell_id: String) -> String:
	for cls in SpellKits.CLASS_SPELLS.keys():
		if SpellKits.has_spell(str(cls), spell_id):
			return str(cls)
	return ""


## First commit event in the batch. Miss uses the same caster motion as hit.
static func caster_event(events: Array) -> Dictionary:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var spell_id := str(event.get("spell", ""))
		if spell_id == "":
			continue
		if str(event.get("type", "")) in CASTER_EVENT_TYPES:
			return event
	return {}


static func hit_event_for(events: Array, target_seat: int) -> Dictionary:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "hit":
			continue
		if int(event.get("target_seat", -1)) != target_seat:
			continue
		return event
	return {}


## Seat plans for one resolve. Caster attack/cast is armed on hit and miss.
## Target hit/lift only when the spell connects. Advance adds no body motion.
static func chrome_plans(events: Array) -> Dictionary:
	var plans := {}
	var caster_armed := false
	var dying := {}
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "dead":
			dying[int(event.get("seat", -1))] = true
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var typ := str(event.get("type", ""))
		var spell_id := str(event.get("spell", ""))
		if not caster_armed and spell_id != "" and typ in CASTER_EVENT_TYPES:
			caster_armed = true
			# A miss stays a whiff on the cast cell. The slash plays only after
			# a successful snap, and that snap is the board's beat, not a lunge.
			if spell_id == SpellKits.AMBUSH and not bool(event.get("teleported", false)):
				var whiff_seat := int(event.get("seat", -1))
				var whiff_plan: Dictionary = plans.get(whiff_seat, {})
				whiff_plan["whiff"] = true
				plans[whiff_seat] = whiff_plan
				continue
			var kind := caster_motion(spell_id)
			if kind != "":
				var seat := int(event.get("seat", -1))
				var plan: Dictionary = plans.get(seat, {})
				if kind == "attack":
					plan["attack"] = true
					if spell_id == SpellKits.AMBUSH:
						plan["reach"] = AMBUSH_LUNGE_PX
				elif not bool(plan.get("attack", false)):
					plan["cast"] = true
					# Mark Shot plays cast_mark_*. Detonate plays cast_*.
					# A missing sheet falls back in the pawn (bow, or a point pose).
					if spell_id == SpellKits.MARK_SHOT:
						plan["strip"] = "cast_mark"
					elif spell_id == SpellKits.DETONATE:
						plan["strip"] = "cast"
					elif mender_strikes(event):
						# Mender has no melee spell: a cast that hurts an enemy
						# (Pulse Tap option B, Heartstop) swings the painted
						# lantern attack; heals and wards keep the skill.
						plan["strip"] = "attack"
				plans[seat] = plan
		if typ == "trap":
			# The snare is not a spell hit, but the body still flinches.
			# Contact is immediate: the board plays this when the foot lands.
			var victim := int(event.get("target_seat", -1))
			if victim < 0:
				continue
			var trap_plan: Dictionary = plans.get(victim, {})
			trap_plan["hit"] = true
			trap_plan["delay"] = true
			trap_plan["contact"] = 0.0
			# The painted hit cell does not travel. Force a readable flinch.
			trap_plan["force_knock"] = true
			trap_plan["knock_px"] = 16.0
			plans[victim] = trap_plan
			continue
		if typ != "hit":
			continue
		var target := int(event.get("target_seat", -1))
		if target < 0:
			continue
		var react := target_motion(_flash_kind(event))
		if react == "":
			continue
		var caster_seat := int(event.get("seat", -2))
		var plan: Dictionary = plans.get(target, {})
		if react == "hit":
			# Flinch only when damage has resolved on someone else.
			# A miss never gets here. A self-cast keeps the caster wind-up.
			if int(event.get("damage", 0)) <= 0 or target == caster_seat:
				continue
			plan["hit"] = true
			plan["delay"] = true
			plan["contact"] = damage_resolve_sec(spell_id)
			if bool(event.get("crit", false)):
				plan["crit"] = true
				# The painted hit cell does not travel. Force an eased knock.
				plan["force_knock"] = true
				plan["knock_px"] = CRIT_KNOCK_PX
		elif react == "lift":
			plan["lift"] = true
			plan["delay"] = true
		plans[target] = plan
	for seat in dying.keys():
		var plan: Dictionary = plans.get(seat, {})
		plan["death"] = true
		plan["tilt"] = -1.0 if int(seat) % 2 == 0 else 1.0
		plans[seat] = plan
	return plans


static func _flash_kind(event: Dictionary) -> String:
	var pawn_script: Script = load("res://units/pawn.gd")
	return str(pawn_script.call("resolve_flash_kind", event))


static func steps_for(plan: Dictionary) -> Array:
	var steps: Array = []
	var attack := bool(plan.get("attack", false))
	var cast := bool(plan.get("cast", false))
	var whiff := bool(plan.get("whiff", false)) and not attack and not cast
	var hit := bool(plan.get("hit", false))
	var lift := bool(plan.get("lift", false)) and not cast
	var death := bool(plan.get("death", false))
	var delay := bool(plan.get("delay", false)) and not attack and not cast and not whiff and (hit or lift or death)
	if delay:
		var wait_sec := REACTION_DELAY
		# Damage flinch waits until the blow lands. Heals keep the short pause.
		if hit and float(plan.get("contact", -1.0)) >= 0.0:
			wait_sec = float(plan.get("contact"))
		if wait_sec > 0.0:
			steps.append({"kind": "wait", "sec": wait_sec})
	if whiff:
		steps.append({"kind": "whiff", "sec": AMBUSH_WHIFF_SEC})
	if attack:
		steps.append({
			"kind": "attack",
			"sec": attack_sec(),
			"dir": plan.get("aim", Vector2.ZERO),
			"reach": float(plan.get("reach", ATTACK_LUNGE_PX)),
		})
	elif cast:
		steps.append({
			"kind": "cast",
			"sec": cast_sec(),
			"dir": plan.get("aim", Vector2.ZERO),
			"strip": str(plan.get("strip", "cast")),
		})
	if hit:
		var crit_hit := bool(plan.get("crit", false))
		var stop := CRIT_HIT_STOP_SEC if crit_hit else -1.0
		var hit_step := {
			"kind": "hit",
			"sec": crit_motion_sec() if crit_hit else hit_sec(stop),
			"dir": plan.get("away", Vector2.ZERO),
			"stop": CRIT_HIT_STOP_SEC if stop >= 0.0 else 0.0,
		}
		if crit_hit:
			hit_step["force_knock"] = true
			hit_step["knock_px"] = float(plan.get("knock_px", CRIT_KNOCK_PX))
		elif bool(plan.get("force_knock", false)):
			hit_step["force_knock"] = true
			hit_step["knock_px"] = float(plan.get("knock_px", 16.0))
		steps.append(hit_step)
	elif lift:
		steps.append({"kind": "lift", "sec": support_sec()})
	if death:
		steps.append({"kind": "death", "sec": death_sec(), "tilt": float(plan.get("tilt", 1.0))})
	return _fit_budget(steps)


static func plan_sec(plan: Dictionary) -> float:
	var total := 0.0
	for step in steps_for(plan):
		total += float(step.get("sec", 0.0))
	return minf(total, ACTION_LOCK_MAX)


## Wide plant, then back to rest. t=0 and t=1 stay at rest scale.
static func landing_scale(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ONE
	if t < 0.42:
		var down := t / 0.42
		return Vector2(
			lerpf(1.0, LAND_SQUASH.x, down),
			lerpf(1.0, LAND_SQUASH.y, down),
		)
	var up := (t - 0.42) / 0.58
	return Vector2(
		lerpf(LAND_SQUASH.x, 1.0, up),
		lerpf(LAND_SQUASH.y, 1.0, up),
	)


## How far the action hand reaches, in pixels, along the aim. Rest hides it.
static func gesture_reach(phase: String) -> float:
	match phase:
		"anticipation":
			return 12.0
		"strike":
			return 22.0
		"hold":
			return 18.0
		"recover":
			return 8.0
		_:
			return 0.0


## Screen axes for a facing letter. Matches Pawn.FACING_ISO.
const FACING_SCREEN := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}
## Shared crest is HOP_PX (3px). Bastion stays at 2.5. Ironjaw uses the
## shared 3px. The v6g strip already plants every cell on the same foot row,
## so the hop does not stack on a strip bob. The crest lands on a cell whose
## feet are already on the baseline.
## Kestrel and Gloam sit in 3–4px. Mender keeps the shared crest.
## Tile time stays 0.30s.
static func hop_crest_px(class_id: String) -> float:
	match SpellKits.normalize_class_id(class_id):
		"bastion":
			return 2.5
		"ironjaw":
			return HOP_PX
		"kestrel", "gloam":
			return 3.5
		_:
			return HOP_PX


## 0 on the departure tile, 1 once the plant window starts. Cubic ease-in-out
## across the moving part of the tile. The tween itself still lasts one tile
## time. Straight tiles chain this curve with no extra settle. It is not a
## raw lerp, and it is not an expo-out hop. The glide uses the same ease on
## every tile, including the ones in the middle of a path.
static func step_travel(t: float) -> float:
	if glide:
		return tile_ease(t)
	if t <= 0.0:
		return 0.0
	if t >= HOP_PLANT_AT:
		return 1.0
	var u := clampf(t / HOP_PLANT_AT, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## One full stride per tile. `contact` is the foot-down cell. It shows when
## hop Y is 0 (the departure, and the whole plant hold). The open window
## visits every other cell once, so a moving foot never idles on the plant
## and arrival cannot freeze a passing cell. step_index does not continue a
## half-cycle. Tile time is not stretched to chase the index. Pass 0 when
## frame 0 is the contact, which is the v5 sheet.
static func walk_cycle_frame(t: float, frame_count: int, _step_index: int = 0, contact: int = 0) -> int:
	var count := maxi(frame_count, 1)
	if count <= 1:
		return 0
	var plant := clampi(contact, 0, count - 1)
	if glide and step_per_tile and count % 2 == 0:
		# One step per tile: half the stride cycle per tile, odd tiles lead
		# with the other foot, so the cycle spans two tiles.
		var half := count / 2
		var base := plant + (posmod(_step_index, 2)) * half
		if t <= 0.0:
			return base % count
		# The slowdown at the end of the tile is the plant, not one more
		# passing cell. 0.84 of the travel is the stride; the rest holds.
		if t >= 0.84:
			return (base + half) % count
		var open := clampf(t / 0.84, 0.0, 0.999999)
		return (base + clampi(int(floor(open * float(half))), 0, half - 1)) % count
	if glide:
		# Continuous stride: every cell in turn across the tile, then the next
		# tile starts on the contact again, so the seam never repeats a cell.
		if t <= 0.0 or t >= 1.0:
			return plant
		return (plant + clampi(int(floor(t * float(count))), 0, count - 1)) % count
	if t <= 0.0 or t >= 1.0 or t >= HOP_PLANT_AT:
		return plant
	var passing := count - 1
	if passing < 1:
		return plant
	var u := clampf(t / HOP_PLANT_AT, 0.0, 0.999999)
	var slot := clampi(int(floor(u * float(passing))), 0, passing - 1)
	return (plant + 1 + slot) % count


## Painted walk cell for a distance along the path, in tiles. `per_tile`
## cells pass per tile (from the strip spec), so the foot keeps pace with the
## board at any tile ease. 0 tiles is the contact cell.
static func painted_walk_frame(walked_tiles: float, per_tile: float, frame_count: int, contact: int = 0) -> int:
	var count := maxi(frame_count, 1)
	if count <= 1 or per_tile <= 0.0:
		return 0
	var step := int(floor(maxf(walked_tiles, 0.0) * per_tile + 1e-4))
	return posmod(clampi(contact, 0, count - 1) + step, count)


## Exactly one integer cycle per tile. Playback fps falls out of the frame
## count and the tile time: 6 frames → 20, 8 frames → about 27.
static func stride_cycles_per_tile() -> int:
	return 1


## Vertical gait for a driven step. Same curve as hop_offset: sprite-local,
## zero on both edges, planted before the tween ends.
static func stride_rise(t: float) -> Vector2:
	return hop_offset(t)


## Horizontal travel is the eased foot. The body does not lead off the cell.
static func stride_lead(_t: float, _facing_dir: Vector2) -> Vector2:
	return Vector2.ZERO


## First tile of a path, and a direction change. Not a straight middle tile.
static func anticipate_segment(segment_index: int, facing_changed: bool) -> bool:
	if glide:
		# The glide turns on the move; only the very first step leans in.
		return segment_index <= 0
	return segment_index <= 0 or facing_changed


## Dust when the facing changes, and on the last plant. Straight middle
## tiles stay quiet.
static func dust_on_plant(facing_changed: bool, is_final: bool) -> bool:
	if glide:
		return is_final
	return facing_changed or is_final


## A climb spends this much of the tile finishing the step on the ground.
## The rest of the tile is the rise, with the foot already planted.
const ELEVATION_MOVE_END := 0.72


static func tile_ease(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Horizontal progress (x) and elevation blend (y). Flat ground eases across
## the whole tile and does not climb. A height change eases across the cell
## first, then eases the height while the foot stays put.
static func stride_split(t: float, climbing: bool) -> Vector2:
	var u := clampf(t, 0.0, 1.0)
	if not climbing:
		return Vector2(tile_ease(u), 0.0)
	if u <= ELEVATION_MOVE_END:
		return Vector2(tile_ease(u / ELEVATION_MOVE_END), 0.0)
	var v := (u - ELEVATION_MOVE_END) / (1.0 - ELEVATION_MOVE_END)
	return Vector2(1.0, tile_ease(v))


## 0 is the departure elevation, 1 is the landing. The rise starts only after
## the step has finished. Flat ground does not call this.
static func elevation_land(t: float) -> float:
	return stride_split(t, true).y


## Screen foot for one tile clock. `src` and `dst` are cell_to_local points,
## so they already include elevation. `t` is the raw tile clock, not a
## pre-eased fraction. Equal elevations ease the whole way. A climb or drop
## finishes that travel, then changes height in place.
static func walk_foot(src: Vector2, dst: Vector2, src_elev: float, dst_elev: float, t: float) -> Vector2:
	var climbing := absf(dst_elev - src_elev) > 0.001
	var split := stride_split(t, climbing)
	return foot_at(src, dst, src_elev, dst_elev, split.x, split.y)


## `travel` is horizontal progress. `elev_u` is the height blend. Callers that
## already eased (the hop fallback) pass those in directly.
static func foot_at(src: Vector2, dst: Vector2, src_elev: float, dst_elev: float, travel: float, elev_u: float) -> Vector2:
	var px := BoardVisualSort.ELEVATION_PIXELS
	var flat_src := src + Vector2(0.0, src_elev * px)
	var flat_dst := dst + Vector2(0.0, dst_elev * px)
	var flat := flat_src.lerp(flat_dst, clampf(travel, 0.0, 1.0))
	var elev := lerpf(src_elev, dst_elev, clampf(elev_u, 0.0, 1.0))
	return flat + Vector2(0.0, -elev * px)


## Glide path ease. Every tile, including a middle tile, slows into the plant
## and speeds through the middle. `first` and `last` stay in the signature
## so the board can still name the path ends.
static func glide_travel(t: float, _first: bool = false, _last: bool = false) -> float:
	return tile_ease(t)


## Painted walks. The sheet's no-slide rate is how many frames one tile of
## foot travel takes. The body never stops on a contact: the cycle is locked
## to ground distance, so one 12-frame cycle covers that measured stride.
## A sheet that needs more than 1.5 cycles per tile walks a little slower
## (0.45s) instead of pausing. Matches Pawn.WALK_TILE_SEC for the others.
const WALK_TILE_SEC := 0.34
const WALK_SLOW_TILE_SEC := 0.45
const WALK_SHEET_FRAMES := 12.0
const WALK_CYCLE_CAP := 1.5
const CLIMB_RISE_SEC := 0.34
const STEP_BOB_PX := 4.0
const CLIMB_HOP_PX := 7.0


static func walk_cycles_per_tile(no_slide: float) -> float:
	return maxf(no_slide, 0.5) / WALK_SHEET_FRAMES


static func walk_travel_sec(no_slide: float) -> float:
	if walk_cycles_per_tile(no_slide) > WALK_CYCLE_CAP:
		return WALK_SLOW_TILE_SEC
	return WALK_TILE_SEC


## Horizontal time, plus the rise when the next tile is higher. No contact hold.
static func walk_span(no_slide: float, _frame0: float, climbing: bool) -> float:
	var travel := walk_travel_sec(no_slide)
	if climbing:
		return travel + CLIMB_RISE_SEC
	return travel


## First step eases in and arrives at cruise speed. Last step leaves at
## cruise speed and eases out. A one-tile path does both. A middle tile keeps
## cruise speed at both seams (no hitch) and surges a little through the
## stride, the way a run transfers weight onto the front foot and settles.
const WALK_WEIGHT := 0.9


static func walk_ground(k: float, first: bool, last: bool) -> float:
	var u := clampf(k, 0.0, 1.0)
	if first and last:
		return tile_ease(u)
	if first:
		return u * u * (2.0 - u)
	if last:
		return u + u * u * (1.0 - u)
	var settle := u * u * (1.0 - u) * (1.0 - u)
	return u + WALK_WEIGHT * settle


## How long one tile feels for this class. Bastion plants heavier, Kestrel and
## Gloam lighter. Ironjaw and Mender stay on the measured 0.34s stride.
## Multiplies the board tween. Does not change walk_travel_sec.
static func walk_pace(class_id: String) -> float:
	match class_id:
		"bastion":
			return 1.20
		"kestrel":
			return 0.84
		"gloam":
			return 0.76
		_:
			return 1.0


## t is 0..1 across walk_span. `u` is horizontal progress and keeps moving
## through the step. `frame` is the absolute cycle position, locked to `u`.
## A climb finishes the step, then rises in place.
static func walk_sample(t: float, no_slide: float, frame0: float, climbing: bool, first: bool = false, last: bool = false) -> Dictionary:
	var span := maxf(no_slide, 0.5)
	var travel := walk_travel_sec(no_slide)
	var total := travel + (CLIMB_RISE_SEC if climbing else 0.0)
	var time := clampf(t, 0.0, 1.0) * maxf(total, 0.0001)
	if climbing and time > travel:
		var rise := clampf((time - travel) / CLIMB_RISE_SEC, 0.0, 1.0)
		return {
			"u": 1.0,
			"elev": tile_ease(rise),
			"frame": frame0 + span,
			"bob": sin(rise * PI) * CLIMB_HOP_PX,
		}
	var k := 0.0 if travel <= 0.0 else clampf(time / travel, 0.0, 1.0)
	var along := walk_ground(k, first, last)
	var frame := frame0 + along * span
	var phase := fposmod(frame, 6.0) / 6.0
	return {
		"u": along,
		"elev": 0.0,
		"frame": frame,
		"bob": sin(phase * PI) * STEP_BOB_PX,
	}


## The puff is the landing: the sample where hop Y returns to 0.
## Takeoff is also Y=0, and so is the rest of the plant window. Neither
## of those is a puff. Mid-air is not a puff. One landing, not a trail.
static func dust_at_landing(t: float, facing_changed: bool, is_final: bool) -> bool:
	if not dust_on_plant(facing_changed, is_final):
		return false
	if not is_equal_approx(t, HOP_PLANT_AT):
		return false
	return hop_offset(t) == Vector2.ZERO


## Slight lean back along the facing, plus a small crouch. Zero at both ends
## so the tile tween starts from the foot.
static func step_anticipation_offset(t: float, facing_dir: Vector2) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var lean := sin(clampf(t, 0.0, 1.0) * PI)
	var back := Vector2.ZERO
	if facing_dir.length_squared() >= 1.0:
		back = -facing_dir.normalized() * STEP_SETTLE_PX * lean
	return back + Vector2(0.0, lean)


## Cardinal steps use the grid letter. Any other segment faces the screen
## direction of travel so the body does not slide sideways or backwards.
static func walk_segment_facing(from_cell: Vector2i, to_cell: Vector2i, screen_delta: Vector2) -> String:
	var delta := to_cell - from_cell
	if delta == Vector2i.ZERO:
		return ""
	if delta == Vector2i(0, -1):
		return "N"
	if delta == Vector2i(1, 0):
		return "E"
	if delta == Vector2i(0, 1):
		return "S"
	if delta == Vector2i(-1, 0):
		return "W"
	var along := screen_facing(screen_delta)
	if along != "":
		return along
	if delta.x != 0:
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


static func screen_facing(delta: Vector2) -> String:
	if delta.length_squared() < 1.0:
		return ""
	var best := ""
	var best_dot := -2.0
	var aim := delta.normalized()
	for face in ["N", "E", "S", "W"]:
		var axis: Vector2 = FACING_SCREEN[face]
		var dotted := aim.dot(axis.normalized())
		if dotted > best_dot:
			best_dot = dotted
			best = face
	return best


## One plant. Rise to the crest at mid-tile, back to the foot before the
## plant window, then stay there. Y is never positive: no Mario bounce.
## The offset is sprite-local. Callers must not apply it to the foot,
## the collider, or ground chrome. `crest` defaults to the shared 3px.
## Values above 4px clamp, so a class mass cannot clear the cap.
static func hop_offset(t: float, crest: float = -1.0) -> Vector2:
	var amp := HOP_PX if crest < 0.0 else clampf(crest, 0.0, 4.0)
	if glide:
		# Two footfalls per tile (t = 0, 0.5, 1): a soft rise between them.
		# One step per tile: one footfall, one rise.
		if t <= 0.0 or t >= 1.0:
			return Vector2.ZERO
		var s := sin(t * (PI if step_per_tile else TAU))
		return Vector2(0.0, -amp * GLIDE_BOB_SHARE * s * s)
	if t <= 0.0 or t >= 1.0 or t >= HOP_PLANT_AT:
		return Vector2.ZERO
	var rise := 0.0
	if t <= 0.5:
		var u := t / 0.5
		rise = sin(u * PI * 0.5)
	else:
		var u := (t - 0.5) / (HOP_PLANT_AT - 0.5)
		rise = cos(clampf(u, 0.0, 1.0) * PI * 0.5)
	return Vector2(0.0, -amp * rise)


## Sprite-child scale during a driven step. Rest through the hop. On the
## plant, Y eases from PLANT_SQUASH_Y back to 1. X stays 1. The pawn node,
## the foot, and chrome do not read this.
static func plant_scale(t: float) -> Vector2:
	if glide:
		return Vector2.ONE
	if t < HOP_PLANT_AT or t >= 1.0:
		return Vector2.ONE
	var window := maxf(1.0 - HOP_PLANT_AT, 0.0001)
	var u := clampf((t - HOP_PLANT_AT) / window, 0.0, 1.0)
	return Vector2(1.0, lerpf(PLANT_SQUASH_Y, 1.0, u))


## 1 on the plant, smaller while the body is off the tile. The shadow
## stays on the foot; it does not rise with the sprite.
static func contact_shadow(t: float) -> float:
	var lift := maxf(0.0, -hop_offset(t).y)
	if HOP_PX <= 0.0:
		return 1.0
	return lerpf(1.0, 0.62, clampf(lift / HOP_PX, 0.0, 1.0))


## Elapsed-time bounce for a whole path. A tile boundary is a plant (Y=0).
## One hop, not a phase that carries across the cell.
static func walk_bounce_offset(elapsed: float) -> Vector2:
	if WALK_STEP_SEC <= 0.0:
		return Vector2.ZERO
	var u := fposmod(elapsed, WALK_STEP_SEC) / WALK_STEP_SEC
	return hop_offset(u)


## Rest scale. Walk strips take their weight from plant_scale, which stays
## at rest through the hop. This hook does not squash mid-stride.
static func hop_scale(_t: float) -> Vector2:
	return Vector2.ONE


static func fallback_hop_scale(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ONE
	if t < 0.18:
		var launch := t / 0.18
		return Vector2(
			lerpf(1.0, FALLBACK_SQUASH.x, launch),
			lerpf(1.0, FALLBACK_SQUASH.y, launch),
		)
	if t < 0.62:
		var rise := clampf((t - 0.18) / 0.22, 0.0, 1.0)
		return Vector2(
			lerpf(FALLBACK_SQUASH.x, FALLBACK_STRETCH.x, rise),
			lerpf(FALLBACK_SQUASH.y, FALLBACK_STRETCH.y, rise),
		)
	if t < HOP_PLANT_AT:
		var settle := (t - 0.62) / (HOP_PLANT_AT - 0.62)
		return Vector2(
			lerpf(FALLBACK_STRETCH.x, 1.0, settle),
			lerpf(FALLBACK_STRETCH.y, 1.0, settle),
		)
	var land := sin((t - HOP_PLANT_AT) / (1.0 - HOP_PLANT_AT) * PI)
	return Vector2(
		lerpf(1.0, FALLBACK_SQUASH.x, land * 0.65),
		lerpf(1.0, FALLBACK_SQUASH.y, land * 0.65),
	)


## True when the new segment faces the opposite letter. The walk finishes
## the plant, sets this facing, settles, then steps. It does not travel
## while still showing the old letter, and it does not pass through a side.
static func is_about_face(from_facing: String, to_facing: String) -> bool:
	var a := from_facing.strip_edges().to_upper()
	var b := to_facing.strip_edges().to_upper()
	if a == "" or b == "" or a == b:
		return false
	if not FACING_RING.has(a) or not FACING_RING.has(b):
		return false
	var cw := (FACING_RING.find(b) - FACING_RING.find(a) + 4) % 4
	return cw == 2


## Plant, then the destination facing, held for the settle. A 180 does not
## step through a side letter. The walk path snaps this facing only while
## the foot is still on the tile.
static func facing_turn(from_facing: String, to_facing: String) -> Array:
	var a := from_facing.strip_edges().to_upper()
	var b := to_facing.strip_edges().to_upper()
	if a == "" or b == "" or a == b:
		return []
	return [b, b]


static func attack_pose(t: float, dir: Vector2, reach: float = -1.0) -> Dictionary:
	var rest := {"pos": Vector2.ZERO, "scale": Vector2.ONE}
	if t <= 0.0 or t >= 1.0:
		return rest
	var aim := _unit(dir)
	var dist := ATTACK_LUNGE_PX if reach < 0.0 else reach
	var total := attack_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var pull := ANTICIPATION_PULL_PX
	var hold := impact_hold_sec(_prelude(ATTACK_OUT_SEC, ATTACK_BACK_SEC))
	var strike_end := ANTICIPATION_SEC + ATTACK_OUT_SEC
	var hold_end := strike_end + hold
	var pos := Vector2.ZERO
	var squash := 0.0
	if time <= ANTICIPATION_SEC:
		var u := _ease_out(time / maxf(ANTICIPATION_SEC, 0.0001))
		pos = -aim * pull * u
		squash = u
	elif time <= strike_end:
		var u := _ease_out((time - ANTICIPATION_SEC) / maxf(ATTACK_OUT_SEC, 0.0001))
		pos = aim * lerpf(-pull, dist, u)
		squash = 1.0 - u
	elif time <= hold_end:
		pos = aim * dist
	else:
		var u := _ease_in((time - hold_end) / maxf(ATTACK_BACK_SEC, 0.0001))
		pos = aim * dist * (1.0 - u)
	return {
		"pos": pos,
		"scale": Vector2(
			lerpf(1.0, ANTICIPATION_SQUASH_X, squash),
			lerpf(1.0, ANTICIPATION_SQUASH_Y, squash),
		),
	}


static func attack_offset(t: float, dir: Vector2, reach: float = -1.0) -> Vector2:
	var pos: Vector2 = attack_pose(t, dir, reach)["pos"]
	return pos


static func cast_pose(t: float, dir: Vector2 = Vector2.ZERO) -> Dictionary:
	var rest := {"pos": Vector2.ZERO, "scale": Vector2.ONE}
	if t <= 0.0 or t >= 1.0:
		return rest
	var total := cast_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var hold := impact_hold_sec(_prelude(CAST_RISE_SEC, CAST_RELEASE_SEC))
	var rise_end := ANTICIPATION_SEC + CAST_RISE_SEC
	var hold_end := rise_end + hold
	if time <= ANTICIPATION_SEC:
		var u := _ease_out(time / maxf(ANTICIPATION_SEC, 0.0001))
		return {
			"pos": Vector2(0.0, CAST_DIP_PX * u),
			"scale": Vector2(
				lerpf(1.0, ANTICIPATION_SQUASH_X, u),
				lerpf(1.0, ANTICIPATION_SQUASH_Y, u),
			),
		}
	var k := 0.0
	if time <= rise_end:
		k = _ease_out((time - ANTICIPATION_SEC) / maxf(CAST_RISE_SEC, 0.0001))
	elif time <= hold_end:
		k = 1.0
	else:
		k = 1.0 - _ease_in((time - hold_end) / maxf(CAST_RELEASE_SEC, 0.0001))
	var s := lerpf(1.0, CAST_SCALE, k)
	var aim := _unit(dir)
	return {
		"pos": Vector2(aim.x * CAST_POINT_PX * k, -CAST_RISE_PX * k),
		"scale": Vector2(s, s),
	}


## Body squash through the knock. Rest at the ends so the next pose is clean.
static func hit_squash(t: float, stop: float = -1.0) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ONE
	var total := hit_sec(stop)
	var time := clampf(t, 0.0, 1.0) * total
	var stop_end := HIT_OUT_SEC + _stop_sec(stop)
	var shake_end := stop_end + HIT_SHAKE_SEC
	var k := 0.0
	if time <= HIT_OUT_SEC:
		k = _ease_out(time / maxf(HIT_OUT_SEC, 0.0001))
	elif time <= shake_end:
		k = 1.0
	else:
		var bt := (time - shake_end) / maxf(HIT_RETURN_SEC, 0.0001)
		k = 1.0 - _ease_in(bt)
	return Vector2(lerpf(1.0, HIT_SQUASH_X, k), lerpf(1.0, HIT_SQUASH_Y, k))


## Snare flinch. Eases off the tile, holds, staggers down, then eases home.
## `knock` is board pixels. Zero at both ends so the next pose is clean.
static func recoil_offset(t: float, away: Vector2, knock: float = 16.0) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var dir := _unit(away)
	if dir == Vector2.ZERO:
		dir = Vector2(0.9, 0.4).normalized()
	var u := clampf(t, 0.0, 1.0)
	var along := 0.0
	var dip := 0.0
	if u < 0.28:
		var k := u / 0.28
		along = knock * (1.0 - (1.0 - k) * (1.0 - k))
	elif u < 0.52:
		along = knock
	elif u < 0.70:
		var k := (u - 0.52) / 0.18
		along = knock + sin(k * PI) * 4.0
		dip = sin(k * PI) * 6.0
	else:
		var k := (u - 0.70) / 0.30
		along = knock * (1.0 - k) * (1.0 - k)
	return dir * along + Vector2(0.0, dip)


static func recoil_squash(t: float) -> Vector2:
	var u := clampf(t, 0.0, 1.0)
	if u < 0.52 or u >= 0.70:
		return Vector2.ONE
	var k := sin((u - 0.52) / 0.18 * PI)
	return Vector2(lerpf(1.0, 1.14, k), lerpf(1.0, 0.78, k))


static func hit_offset(t: float, away: Vector2, stop: float = -1.0) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var total := hit_sec(stop)
	var time := clampf(t, 0.0, 1.0) * total
	var dir := _unit(away)
	var perp := Vector2(-dir.y, dir.x) if dir != Vector2.ZERO else Vector2.RIGHT
	var stop_end := HIT_OUT_SEC + _stop_sec(stop)
	var shake_end := stop_end + HIT_SHAKE_SEC
	if time <= HIT_OUT_SEC:
		return dir * HIT_KNOCK_PX * _ease_out(time / HIT_OUT_SEC)
	# Contact hold. The body does not shake through the hit-stop.
	if time <= stop_end:
		return dir * HIT_KNOCK_PX
	if time <= shake_end:
		var st := (time - stop_end) / HIT_SHAKE_SEC
		var wobble := sin(st * TAU * 1.5) * (1.0 - st)
		return dir * HIT_KNOCK_PX + perp * HIT_SHAKE_PX * wobble
	var bt := (time - shake_end) / HIT_RETURN_SEC
	return dir * HIT_KNOCK_PX * (1.0 - _ease_in(bt))


## Crit knock. Eases off the tile, holds (the hit-stop), staggers, eases home.
## `t` is 0..1 across `duration` seconds. Zero at both ends.
static func crit_recoil(t: float, duration: float, away: Vector2, knock: float = CRIT_KNOCK_PX) -> Vector2:
	if t <= 0.0 or t >= 1.0 or duration <= 0.0:
		return Vector2.ZERO
	var dir := _unit(away)
	if dir == Vector2.ZERO:
		dir = Vector2(0.85, 0.45).normalized()
	var phase: Dictionary = _crit_phases(duration)
	var time := clampf(t, 0.0, 1.0) * duration
	var push: float = phase["push"]
	var hold_end: float = push + float(phase["hold"])
	var stag_end: float = hold_end + float(phase["stagger"])
	var along := 0.0
	var dip := 0.0
	if time < push:
		var k := time / maxf(push, 0.0001)
		along = knock * (1.0 - (1.0 - k) * (1.0 - k))
	elif time < hold_end:
		along = knock
	elif time < stag_end:
		var k := (time - hold_end) / maxf(float(phase["stagger"]), 0.0001)
		along = knock + sin(k * PI) * 5.0
		dip = sin(k * PI) * 8.0
	else:
		# Smoothstep home, plus a hop, so the return is a step and not a slide.
		var k := clampf((time - stag_end) / maxf(float(phase["back"]), 0.0001), 0.0, 1.0)
		var settled := k * k * (3.0 - 2.0 * k)
		along = knock * (1.0 - settled)
		dip = -sin(k * PI) * 11.0
	return dir * along + Vector2(0.0, dip)


static func crit_holding(t: float, duration: float) -> bool:
	if t <= 0.0 or t >= 1.0 or duration <= 0.0:
		return false
	var phase: Dictionary = _crit_phases(duration)
	var time := t * duration
	var push: float = phase["push"]
	return time >= push and time < push + float(phase["hold"])


## 0 until the return, then 0..1 as the body eases home.
static func crit_recover(t: float, duration: float) -> float:
	if t <= 0.0 or duration <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var phase: Dictionary = _crit_phases(duration)
	var stag_end: float = float(phase["push"]) + float(phase["hold"]) + float(phase["stagger"])
	var time := t * duration
	if time < stag_end:
		return 0.0
	return clampf((time - stag_end) / maxf(float(phase["back"]), 0.0001), 0.0, 1.0)


static func crit_squash(t: float, duration: float) -> Vector2:
	if t <= 0.0 or t >= 1.0 or duration <= 0.0:
		return Vector2.ONE
	var phase: Dictionary = _crit_phases(duration)
	var hold_end: float = float(phase["push"]) + float(phase["hold"])
	var stag_end: float = hold_end + float(phase["stagger"])
	var time := t * duration
	if time < hold_end or time >= stag_end:
		return Vector2.ONE
	var k := sin((time - hold_end) / maxf(float(phase["stagger"]), 0.0001) * PI)
	return Vector2(lerpf(1.0, 1.16, k), lerpf(1.0, 0.76, k))


static func support_offset(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	return Vector2(0.0, -sin(t * PI) * SUPPORT_RISE_PX)


static func death_pose(t: float, tilt_sign: float) -> Dictionary:
	var u := clampf(t, 0.0, 1.0)
	var k := 0.0
	if u > 0.0:
		k = _smooth(clampf(u / maxf(DEATH_COLLAPSE_AT, 0.0001), 0.0, 1.0))
	var fade_k := _smooth(clampf((u - 0.58) / 0.42, 0.0, 1.0))
	var sign := -1.0 if tilt_sign < 0.0 else 1.0
	return {
		"scale": Vector2(lerpf(1.0, DEATH_SQUASH_X, k), lerpf(1.0, DEATH_SQUASH_Y, k)),
		"rot": DEATH_TILT_DEG * sign * k,
		"fade": lerpf(1.0, DEATH_FADE_ALPHA, fade_k),
		"drop": DEATH_DROP_PX * k,
	}


static func _fit_budget(steps: Array) -> Array:
	var total := 0.0
	for step in steps:
		total += float(step.get("sec", 0.0))
	if total <= ACTION_LOCK_MAX or total <= 0.0:
		return steps
	var scale := ACTION_LOCK_MAX / total
	var fitted: Array = []
	for step in steps:
		var copy: Dictionary = (step as Dictionary).duplicate()
		copy["sec"] = float(step.get("sec", 0.0)) * scale
		fitted.append(copy)
	return fitted


static func _prelude(rise: float, release: float) -> float:
	return ANTICIPATION_SEC + rise + release


static func _phase(t: float, total: float, rise: float, release: float) -> String:
	if t <= 0.0 or t >= 1.0 or total <= 0.0:
		return "rest"
	var time := clampf(t, 0.0, 1.0) * total
	var hold := impact_hold_sec(_prelude(rise, release))
	if time <= ANTICIPATION_SEC:
		return "anticipation"
	if time <= ANTICIPATION_SEC + rise:
		return "strike"
	if time <= ANTICIPATION_SEC + rise + hold:
		return "hold"
	return "recover"


static func _unit(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2.ZERO
	return dir.normalized()


static func _ease_out(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x


static func _smooth(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
