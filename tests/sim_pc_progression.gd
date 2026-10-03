extends SceneTree

## Dev tool, not a suite. Prints the WP15 balance table.
## Run: godot --headless --path . -s res://tests/sim_pc_progression.gd

const Balance = preload("res://backend/pc_balance.gd")


func _initialize() -> void:
	var result: Dictionary = Balance.run()
	print(result["text"])
	quit(0 if bool(result["ok"]) else 1)
