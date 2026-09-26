extends RefCounted
class_name ViewMotion

## View-only motion tunables. CombatSim never reads this file.
## Mobile-track chrome (`mobile` only). Kits, hit bands, AP/MP, and marks stay put.
## Batch 1 walk/attack strips load from art/export_2x/characters when the
## files exist (SE→e, SW→s, NE→n, NW→w). Walk slides through cell centers
## while `walk_<facing>` loops. The tactical cell stays on the pawn.
## The visual foot is the pawn origin; the body rises off that foot and
## the contact shadow stays on it. A missing strip keeps the bounce and adds
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
## at rest. Arena zoom is about 0.64, so 6px is a planted step, not a hop.
const WALK_BOUNCE_PX := 6.0
const HOP_PX := 6.0
## Two plants in one authored walk cycle (6 frames at 12 fps = 0.5s).
## The path loops this period. It is not one hop per tile.
const WALK_STEP_SEC := 0.25

const ATTACK_OUT_SEC := 0.12
const ATTACK_BACK_SEC := 0.10
## Melee lunge reaches the shared tile edge. A cardinal iso step is
## hypot(32, 16) ≈ 36px center to center, so the edge is ~18px.
## Ambush keeps the longer reach.
const ATTACK_LUNGE_PX := 18.0
## Contact slash after the snap. It is a local reach, not a board dash.
## Facing damage stays the sim's existing resolution. This reach is view-only.
const AMBUSH_LUNGE_PX := 36.0
## Body collapses on the origin tile, then the snap. Kept inside the 0.6s lock
## together with the contact slash.
const AMBUSH_COLLAPSE_SEC := 0.08
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
const DEATH_FADE_ALPHA := 0.0
const DEATH_DROP_PX := 18.0
## Collapse finishes here, then the pose holds through the rest of the beat.
const DEATH_COLLAPSE_AT := 0.42
## Two authored walk frames (12 fps) planted before a facing change translates.
const TURN_FRAME_SEC := 1.0 / 12.0
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


## Success: collapse at the origin, snap, slash, then the sim's facing damage.
## Miss: whiff only. No snap and no damage beat.
static func ambush_beats(event: Dictionary) -> Array:
	if str(event.get("spell", "")) != SpellKits.AMBUSH and str(event.get("spell", "")) != "ambush":
		return []
	var typ := str(event.get("type", ""))
	if typ == "hit" and bool(event.get("teleported", false)):
		return [
			{"beat": "collapse", "sec": AMBUSH_COLLAPSE_SEC},
			{"beat": "snap"},
			{"beat": "slash"},
			{"beat": "damage"},
		]
	if typ == "miss" or typ == "hit":
		return [{"beat": "whiff"}]
	return []


static func attack_phase(t: float) -> String:
	return _phase(t, attack_sec(), ATTACK_OUT_SEC, ATTACK_BACK_SEC)


static func cast_phase(t: float) -> String:
	return _phase(t, cast_sec(), CAST_RISE_SEC, CAST_RELEASE_SEC)


static func hit_sec() -> float:
	return HIT_OUT_SEC + HIT_STOP_SEC + HIT_SHAKE_SEC + HIT_RETURN_SEC


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
	var whiff := bool(plan.get("whiff", false)) and not attack and not cast
	var hit := bool(plan.get("hit", false))
	var lift := bool(plan.get("lift", false)) and not cast
	var death := bool(plan.get("death", false))
	var delay := bool(plan.get("delay", false)) and not attack and not cast and not whiff and (hit or lift or death)
	if delay:
		steps.append({"kind": "wait", "sec": REACTION_DELAY})
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
## Share the hop's press and settle so the foot is down while travel is held.
const STEP_PRESS_END := 0.16
const STEP_SETTLE_START := 0.82


## 0 on the departure tile through the press, 1 on the arrival tile through
## the settle. The stride eases between those plants. No sideways term: the
## caller moves along the segment. It is not a raw lerp of t.
static func step_travel(t: float) -> float:
	if t <= STEP_PRESS_END:
		return 0.0
	if t >= STEP_SETTLE_START:
		return 1.0
	var u := (t - STEP_PRESS_END) / (STEP_SETTLE_START - STEP_PRESS_END)
	return u * u * (3.0 - 2.0 * u)


## Frame of the facing walk strip for this tile.
## One tile plays half the cycle, contact to contact. The press holds the
## departure plant. The settle holds the next plant, so arrival cannot freeze
## on a passing frame. step_index continues that cycle onto the next segment.
## An open stride never stays on the departure plant: that is an idle slide.
static func walk_cycle_frame(t: float, frame_count: int, step_index: int = 0) -> int:
	var count := maxi(frame_count, 1)
	if count <= 1:
		return 0
	var half := maxi(count / 2, 1)
	var start := (maxi(step_index, 0) * half) % count
	var along := 0.0
	if t <= STEP_PRESS_END:
		along = 0.0
	elif t >= STEP_SETTLE_START:
		along = float(half)
	else:
		var u := (t - STEP_PRESS_END) / (STEP_SETTLE_START - STEP_PRESS_END)
		var eased := u * u * (3.0 - 2.0 * u)
		along = eased * float(half)
	var idx := (start + int(round(along))) % count
	if t > STEP_PRESS_END and t < STEP_SETTLE_START and idx == start:
		idx = (start + 1) % count
	return idx


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


## One plant. Anticipation presses into the tile, push-off reaches the crest
## at t=0.5, then the body settles. The rise stays inside HOP_PX.
static func hop_offset(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	if t < 0.16:
		var wind := sin((t / 0.16) * PI)
		return Vector2(0.0, wind * 1.4)
	if t <= 0.50:
		var push := _ease_out((t - 0.16) / 0.34)
		return Vector2(0.0, lerpf(0.0, -HOP_PX, push))
	if t < 0.82:
		var fall := _ease_in((t - 0.50) / 0.32)
		return Vector2(0.0, lerpf(-HOP_PX, 0.0, fall))
	var settle := sin(((t - 0.82) / 0.18) * PI)
	return Vector2(0.0, settle * 1.1)


## 1 on the plant, smaller while the body is off the tile. The shadow
## stays on the foot; it does not rise with the sprite.
static func contact_shadow(t: float) -> float:
	var lift := maxf(0.0, -hop_offset(t).y)
	if HOP_PX <= 0.0:
		return 1.0
	return lerpf(1.0, 0.62, clampf(lift / HOP_PX, 0.0, 1.0))


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
static func hit_squash(t: float) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ONE
	var total := hit_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var stop_end := HIT_OUT_SEC + HIT_STOP_SEC
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


static func hit_offset(t: float, away: Vector2) -> Vector2:
	if t <= 0.0 or t >= 1.0:
		return Vector2.ZERO
	var total := hit_sec()
	var time := clampf(t, 0.0, 1.0) * total
	var dir := _unit(away)
	var perp := Vector2(-dir.y, dir.x) if dir != Vector2.ZERO else Vector2.RIGHT
	var stop_end := HIT_OUT_SEC + HIT_STOP_SEC
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
