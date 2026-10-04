extends SceneTree
const JB := preload("res://board/pc/jungle_backdrop.gd")
func _initialize() -> void:
	var n := 2000
	var t0 := Time.get_ticks_usec()
	var r := false
	for i in n:
		r = JB.v1_ready()
	var dt := float(Time.get_ticks_usec() - t0) / n
	print("TA_BENCH v1_ready=%s usec_per_call=%.1f" % [str(r), dt])
	quit(0)
