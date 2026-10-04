extends RefCounted

## VIEW-SIDE hero stamina for the PC open world. Not saved; starts full.
## Running drains it, walking or standing refills it after a short pause.
## At zero the hero is winded and walks until stamina is back above the
## resume threshold.

## Seconds of continuous running from full to empty.
const RUN_SECONDS := 8.0
## Seconds from empty to full while walking or idle.
const REGEN_SECONDS := 6.0
## Pause after the last running frame before regen starts.
const REGEN_DELAY := 1.0
## Fraction stamina must climb back above before a winded hero may run again.
const RESUME_AT := 0.2

var value := 1.0
var winded := false
var _since_run := REGEN_DELAY


func reset() -> void:
	value = 1.0
	winded = false
	_since_run = REGEN_DELAY


func can_run() -> bool:
	return not winded and value > 0.0


func is_full() -> bool:
	return value >= 1.0


## `running` is true while the hero is actually on the run strip.
func tick(delta: float, running: bool) -> void:
	if delta <= 0.0:
		return
	if running:
		_since_run = 0.0
		value -= delta / RUN_SECONDS
		# Snap float dust so 8 s of 0.1 s ticks reads as empty.
		if value <= 1e-5:
			value = 0.0
			winded = true
		return
	_since_run += delta
	if _since_run >= REGEN_DELAY:
		# Only the part of this tick past the delay refills.
		var live := minf(delta, _since_run - REGEN_DELAY)
		value = minf(1.0, value + live / REGEN_SECONDS)
	if winded and value > RESUME_AT:
		winded = false
