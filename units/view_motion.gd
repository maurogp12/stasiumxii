extends RefCounted
class_name ViewMotion

## View-only motion tunables. CombatSim never reads this file.
## Mobile-track chrome (`mobile` only). Kits, hit bands, AP/MP, and marks stay put.
## Batch 1 walk/attack strips load from art/export_2x/characters when the
## files exist (SE→e, SW→s, NE→n, NW→w). Walk slides through cell centers
## while `walk_<facing>` loops. A missing strip keeps the bounce and adds
## squash on launch/land plus stretch at the crest. It does not play a
## tile-tall hop. Facing turns in place for two walk frames before the
## translate. The snapshot facing snaps only after the last land.
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

## Step bounce on the sprite root. The old phone hop was HOP_PX 36, about one
## iso tile, with squash and stretch. That read as a cartoon arc. SoT is a
## 4–6px sine: feet plant on the zeros, crest stays on the body. Scale stays
## at rest. Arena zoom is about 0.64, so 5px is a light bob, not a slide.
const WALK_BOUNCE_PX := 5.0
const HOP_PX := 5.0
## Two plants in one authored walk cycle (6 frames at 12 fps = 0.5s).
## The path loops this period. It is not one hop per tile.
const WALK_STEP_SEC := 0.25

const ATTACK_OUT_SEC := 0.12
const ATTACK_BACK_SEC := 0.10
## Melee lunge reaches the shared tile edge. A cardinal iso step is
## hypot(32, 16) ≈ 36px center to center, so the edge is ~18px.
## Ambush keeps the longer reach.
const ATTACK_LUNGE_PX := 18.0
## Ambush blinks. A shared 12px lunge is still easy to miss next to the
## BACKSTAB number, so this reach is the commit, view-only.
const AMBUSH_LUNGE_PX := 36.0

## Coil before the lunge or the cast release. Long enough to read on a phone.
const ANTICIPATION_SEC := 0.08
const ANTICIPATION_PULL_PX := 5.0
const ANTICIPATION_SQUASH_X := 1.16
const ANTICIPATION_SQUASH_Y := 0.82

## Impact pose. impact_hold_sec() clamps this to the lock that is still free.
const IMPACT_HOLD_SEC := 0.20

const CAST_RISE_SEC := 0.12
const CAST_HOLD_SEC := 0.20
const CAST_RELEASE_SEC := 0.10
const CAST_RISE_PX := 6.0
const CAST_SCALE := 1.06

const REACTION_DELAY := 0.06

const HIT_OUT_SEC := 0.08
const HIT_SHAKE_SEC := 0.10
const HIT_RETURN_SEC := 0.08
const HIT_KNOCK_PX := 5.0
const HIT_SHAKE_PX := 1.5

const SUPPORT_SEC := 0.34
const SUPPORT_RISE_PX := 4.0

const DEATH_SEC := 0.36
const DEATH_SQUASH_X := 1.22
const DEATH_SQUASH_Y := 0.40
const DEATH_TILT_DEG := 18.0
const DEATH_FADE_ALPHA := 0.0
const DEATH_DROP_PX := 14.0
## Two authored walk frames (12 fps) planted before a facing change translates.
const TURN_FRAME_SEC := 1.0 / 12.0
const FACING_RING: Array[String] = ["N", "E", "S", "W"]
## No-strip hop only. A playing walk cycle stays at rest scale.
const FALLBACK_SQUASH := Vector2(1.14, 0.82)
const FALLBACK_STRETCH := Vector2(0.90, 1.12)
## Detonate point. Connects the caster to the effect when no cast strip exists.
const CAST_POINT_PX := 16.0

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


static func attack_phase(t: float) -> String:
	return _phase(t, attack_sec(), ATTACK_OUT_SEC, ATTACK_BACK_SEC)


static func cast_phase(t: float) -> String:
	return _phase(t, cast_sec(), CAST_RISE_SEC, CAST_RELEASE_SEC)


static func hit_sec() -> float:
	return HIT_OUT_SEC + HIT_SHAKE_SEC + HIT_RETURN_SEC


static func support_sec() -> float:
	return SUPPORT_SEC


static func death_sec() -> float:
	return DEATH_SEC


static func idle_phase_sec(seat: int, salt: String) -> float:
	var hashed := absi(salt.hash())
	var frac := float(hashed % 1000) / 1000.0
	return fposmod(float(seat) * IDLE_PHASE_STEP + frac * 0.55, IDLE_PERIOD)


## "attack" lunges. "cast" winds up. Advance (teleport) stays a snap.
static func caster_motion(spell_id: String) -> String:
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
				plans[seat] = plan
		if typ != "hit":
			continue
		var target := int(event.get("target_seat", -1))
		if target < 0:
			continue
		var react := target_motion(_flash_kind(event))
		if react == "":
			continue
		var plan: Dictionary = plans.get(target, {})
		if react == "hit":
			plan["hit"] = true
			plan["delay"] = true
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
	var hit := bool(plan.get("hit", false))
	var lift := bool(plan.get("lift", false)) and not cast
	var death := bool(plan.get("death", false))
	var delay := bool(plan.get("delay", false)) and not attack and not cast and (hit or lift or death)
	if delay:
		steps.append({"kind": "wait", "sec": REACTION_DELAY})
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
		steps.append({"kind": "hit", "sec": hit_sec(), "dir": plan.get("away", Vector2.ZERO)})
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


static func hop_offset(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	return Vector2(0.0, -sin(t * PI) * HOP_PX)


## Elapsed-time bounce for a whole path. Zeros are foot plants. The phase
## does not reset when a tile boundary passes.
static func walk_bounce_offset(elapsed: float) -> Vector2:
	if WALK_STEP_SEC <= 0.0:
		return Vector2.ZERO
	var u := fposmod(elapsed, WALK_STEP_SEC) / WALK_STEP_SEC
	return hop_offset(u)


## Walk strips stay at rest scale. This is the no-strip weight curve:
## squash on launch and land, stretch through the crest.
static func hop_scale(_t: float) -> Vector2:
	return Vector2.ONE


static func fallback_hop_scale(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ONE
	if t < 0.16:
		var launch := t / 0.16
		return Vector2(
			lerpf(1.0, FALLBACK_SQUASH.x, launch),
			lerpf(1.0, FALLBACK_SQUASH.y, launch),
		)
	if t < 0.70:
		var rise := clampf((t - 0.16) / 0.22, 0.0, 1.0)
		return Vector2(
			lerpf(FALLBACK_SQUASH.x, FALLBACK_STRETCH.x, rise),
			lerpf(FALLBACK_SQUASH.y, FALLBACK_STRETCH.y, rise),
		)
	if t < 0.84:
		var settle := (t - 0.70) / 0.14
		return Vector2(
			lerpf(FALLBACK_STRETCH.x, 1.0, settle),
			lerpf(FALLBACK_STRETCH.y, 1.0, settle),
		)
	var land := sin((t - 0.84) / 0.16 * PI)
	return Vector2(
		lerpf(1.0, FALLBACK_SQUASH.x, land),
		lerpf(1.0, FALLBACK_SQUASH.y, land),
	)


## Frames to show before translating. Empty when facing does not change.
## 90° holds the new facing for two frames. 180° steps through one side facing.
static func facing_turn(from_facing: String, to_facing: String) -> Array:
	var a := from_facing.strip_edges().to_upper()
	var b := to_facing.strip_edges().to_upper()
	if a == "" or b == "" or a == b:
		return []
	if not FACING_RING.has(a) or not FACING_RING.has(b):
		return [b, b]
	var ia := FACING_RING.find(a)
	var ib := FACING_RING.find(b)
	var cw := (ib - ia + 4) % 4
	if cw == 2:
		return [FACING_RING[(ia + 1) % 4], b]
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
			"pos": Vector2(0.0, ANTICIPATION_PULL_PX * 0.45 * u),
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


static func hit_offset(t: float, away: Vector2) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var total := hit_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var dir := _unit(away)
	var perp := Vector2(-dir.y, dir.x) if dir != Vector2.ZERO else Vector2.RIGHT
	if time <= HIT_OUT_SEC:
		return dir * HIT_KNOCK_PX * _ease_out(time / HIT_OUT_SEC)
	if time <= HIT_OUT_SEC + HIT_SHAKE_SEC:
		var st := (time - HIT_OUT_SEC) / HIT_SHAKE_SEC
		var wobble := sin(st * TAU * 2.0) * (1.0 - st)
		return dir * HIT_KNOCK_PX + perp * HIT_SHAKE_PX * wobble
	var bt := (time - HIT_OUT_SEC - HIT_SHAKE_SEC) / HIT_RETURN_SEC
	return dir * HIT_KNOCK_PX * (1.0 - _ease_in(bt))


static func support_offset(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	return Vector2(0.0, -sin(t * PI) * SUPPORT_RISE_PX)


static func death_pose(t: float, tilt_sign: float) -> Dictionary:
	var k := 0.0
	if t > 0.0:
		k = _smooth(clampf(t, 0.0, 1.0))
	var sign := -1.0 if tilt_sign < 0.0 else 1.0
	return {
		"scale": Vector2(lerpf(1.0, DEATH_SQUASH_X, k), lerpf(1.0, DEATH_SQUASH_Y, k)),
		"rot": DEATH_TILT_DEG * sign * k,
		"fade": lerpf(1.0, DEATH_FADE_ALPHA, k),
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
