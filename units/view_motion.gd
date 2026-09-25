extends RefCounted
class_name ViewMotion

## View-only motion tunables. CombatSim never reads this file.
## One-shot motions stay within ACTION_LOCK_MAX. Idle is a loop whose
## period is the breathe cycle (longer than one action beat).
## Flip REDUCE_MOTION to true to skip idle, hop arc, lunge, wind-up,
## knockback, lift, and slump. Walks still step along the path.
## A project setting named stasium/view/reduce_motion does the same when set.

const REDUCE_MOTION := false
const ACTION_LOCK_MAX := 0.6

const IDLE_PERIOD := 1.9
const IDLE_BOB_PX := 1.5
const IDLE_PHASE_STEP := 0.73

const HOP_PX := 5.0

const ATTACK_OUT_SEC := 0.14
const ATTACK_BACK_SEC := 0.12
const ATTACK_LUNGE_PX := 10.0

const CAST_RISE_SEC := 0.16
const CAST_HOLD_SEC := 0.10
const CAST_RELEASE_SEC := 0.14
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
const DEATH_SQUASH_X := 1.08
const DEATH_SQUASH_Y := 0.76
const DEATH_TILT_DEG := 7.0
const DEATH_FADE_ALPHA := 0.78

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
	return ATTACK_OUT_SEC + ATTACK_BACK_SEC


static func cast_sec() -> float:
	return CAST_RISE_SEC + CAST_HOLD_SEC + CAST_RELEASE_SEC


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
		steps.append({"kind": "attack", "sec": attack_sec(), "dir": plan.get("aim", Vector2.ZERO)})
	elif cast:
		steps.append({"kind": "cast", "sec": cast_sec()})
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


static func attack_offset(t: float, dir: Vector2) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var aim := _unit(dir)
	var total := attack_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var k := 0.0
	if time <= ATTACK_OUT_SEC:
		k = _ease_out(time / ATTACK_OUT_SEC)
	else:
		k = 1.0 - _ease_in((time - ATTACK_OUT_SEC) / ATTACK_BACK_SEC)
	return aim * ATTACK_LUNGE_PX * k


static func cast_pose(t: float) -> Dictionary:
	var rest := {"pos": Vector2.ZERO, "scale": Vector2.ONE}
	if t <= 0.0 or t >= 1.0:
		return rest
	var total := cast_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var k := 0.0
	if time <= CAST_RISE_SEC:
		k = _ease_out(time / CAST_RISE_SEC)
	elif time <= CAST_RISE_SEC + CAST_HOLD_SEC:
		k = 1.0
	else:
		k = 1.0 - _ease_in((time - CAST_RISE_SEC - CAST_HOLD_SEC) / CAST_RELEASE_SEC)
	var s := lerpf(1.0, CAST_SCALE, k)
	return {
		"pos": Vector2(0.0, -CAST_RISE_PX * k),
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
