extends Node

## Thin event pipe. CombatSim is authoritative; the view only listens.
signal combat_events(events: Array, snapshot: Dictionary)


func emit_combat(events: Array, snap: Dictionary) -> void:
	combat_events.emit(events, snap)
