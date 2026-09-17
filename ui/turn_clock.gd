extends RefCounted
class_name TurnClock

## Proposed playtest seat clock. Change DURATION_SEC to retune.
## CombatSim does not own this; expiry submits the same end_turn as the HUD button.
const DURATION_SEC := 30.0

var remaining: float = DURATION_SEC
var running: bool = false


func start() -> void:
	remaining = DURATION_SEC
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
	if DURATION_SEC <= 0.0:
		return 0.0
	return clampf(remaining / DURATION_SEC, 0.0, 1.0)
