extends RefCounted
class_name TurnClock

## Display helper for the host-owned 30s seat clock.
## Remaining comes from snapshot.turn_time_remaining. Do not treat this as
## authority on a guest. Change DURATION_SEC with CombatSim.TURN_TIME_LIMIT.
const DURATION_SEC := 30.0

var remaining: float = DURATION_SEC
var running: bool = false
var duration: float = DURATION_SEC


func hydrate(remaining_sec: float, is_running: bool, limit: float = DURATION_SEC) -> void:
	remaining = remaining_sec
	running = is_running
	duration = limit if limit > 0.0 else DURATION_SEC


func start() -> void:
	remaining = DURATION_SEC
	duration = DURATION_SEC
	running = true


func pause() -> void:
	running = false


func resume() -> void:
	if remaining > 0.0:
		running = true


func stop() -> void:
	running = false


func tick(delta: float) -> bool:
	if not running:
		return false
	remaining -= delta
	if remaining > 0.0:
		return false
	remaining = 0.0
	running = false
	return true


func display_seconds() -> int:
	if remaining <= 0.0:
		return 0
	return int(ceili(remaining))


func fraction_left() -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(remaining / duration, 0.0, 1.0)
