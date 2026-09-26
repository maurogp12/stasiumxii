extends RefCounted
class_name VfxBudget

## Presentation caps only. CombatSim never reads this file.
## Input lock for one action stays at or under LOCK_MAX. The host turn clock is not paused.
## Particle bursts stay small so a pooled emitter cannot flood the board.

const LOCK_MAX := 0.6

const SHAKE_PX := 4.0
const SHAKE_SEC := 0.16

const NUMBER_SIZE := 42
const NUMBER_SIZE_SMALL := 28
const NUMBER_RISE_PX := 28.0
const NUMBER_STACK_PX := 22.0
const NUMBER_POP_SEC := 0.12
const NUMBER_RISE_SEC := 0.55
const NUMBER_FADE_SEC := 0.20
const NUMBER_TILT_DEG := 6.0

const SPARK_AMOUNT := 12
const SPARK_CAP := 24
const PUFF_AMOUNT := 8
const MOTE_AMOUNT := 6
const SPARK_LIFE := 0.25
const PUFF_LIFE := 0.30
const MOTE_LIFE := 0.55

const POOL_SPARK := 4
const POOL_NUMBER := 6
const POOL_PROJECTILE := 2
const POOL_RING := 8
const POOL_PUFF := 4
const POOL_MOTE := 2
const POOL_STATUS := 12

const BLOCK_SLIDE := 0.18
const BLOCK_JOLT := 0.12
const BLOCK_BOUNCE := 0.22
const BLOCK_BLINK := 0.20

const CHEST_OFFSET := Vector2(0, -30)
const HEAD_OFFSET := Vector2(0, -52)
## Bow / hand. Feet are the pawn origin. This lifts the emitter off the ground
## onto the weapon, then the director pushes it along the facing.
const HAND_OFFSET := Vector2(0, -46)
## cast_mark frame 3 at 12 fps. The bolt waits for that release, not the feet.
const MARK_RELEASE_DELAY := 0.25
## Kestrel cast frame 3 at 10 fps. Detonate's line waits for the cast pose.
const CAST_RELEASE_DELAY := 0.30
## Attack frame 3 at 12 fps. Melee sparks wait for that cell.
const MELEE_IMPACT_DELAY := 0.25
const STAGGER_DELAY := 0.12
const NUMBER_LIFE := 0.75
