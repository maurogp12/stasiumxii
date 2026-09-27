extends SceneTree

## Phone-style bake: idle and mid-walk share one costume, and the face letter matches the body.
## Run: godot --path . -s res://tests/bake_class_identity.gd
## Headless can leave the viewport blank, so this prefers a real display.

const OUT := "/tmp/identity_bake.png"


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var size := Vector2i(1280, 980)
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var host := Node2D.new()
	vp.add_child(host)
	var bg := Polygon2D.new()
	bg.color = Color(0.73, 0.86, 0.93)
	bg.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y),
	])
	host.add_child(bg)
	_tag(host, "Ironjaw  —  idle and mid-stride are one sheet, N/E/S/W", Vector2(36, 28))
	_pair(host, "ironjaw", 200)
	_tag(host, "Bastion  —  idle and mid-stride are one sheet, N/E/S/W", Vector2(36, 500))
	_pair(host, "bastion", 680)
	for _i in 4:
		await process_frame
	var image := vp.get_texture().get_image()
	if image == null or image.is_empty():
		print("BAKE EMPTY")
		quit(1)
		return
	image.save_png(OUT)
	print("BAKE WROTE %s %dx%d" % [OUT, image.get_width(), image.get_height()])
	quit(0)


func _pair(host: Node2D, class_id: String, foot_y: float) -> void:
	var faces: Array[String] = ["N", "E", "S", "W"]
	var x0 := 150.0
	var step := 280.0
	for i in faces.size():
		var face: String = faces[i]
		_tag(host, "idle " + face, Vector2(x0 + step * i - 36.0, foot_y - 160.0))
		_pawn(host, class_id, face, Vector2(x0 + step * i, foot_y), false)
		_tag(host, "stride " + face, Vector2(x0 + step * i + 90.0, foot_y - 160.0))
		_pawn(host, class_id, face, Vector2(x0 + step * i + 130.0, foot_y), true)


func _pawn(host: Node2D, class_id: String, facing: String, foot: Vector2, walking: bool) -> void:
	var pawn := Pawn.new()
	host.add_child(pawn)
	pawn.position = foot
	pawn.apply_snapshot({
		"pos": Vector2i(2, 2),
		"name": SpellKits.display_name(class_id),
		"class_id": class_id,
		"facing": facing,
		"seat": 0,
		"hp": 80,
		"max_hp": 80,
		"alive": true,
		"stun_remaining": 0,
	}, 0)
	if not walking:
		return
	pawn.arm_driven_walk()
	var strip := _visible_strip(pawn)
	if strip == null:
		return
	var count := strip.sprite_frames.get_frame_count(strip.animation)
	strip.frame = mini(3, count - 1)
	strip.frame_progress = 0.0


func _visible_strip(pawn: Pawn) -> AnimatedSprite2D:
	for child in pawn.get_children():
		if child is AnimatedSprite2D and (child as AnimatedSprite2D).visible:
			return child as AnimatedSprite2D
	return null


func _tag(host: Node2D, text: String, at: Vector2) -> void:
	var tag := Tag.new()
	tag.text = text
	tag.position = at
	host.add_child(tag)


class Tag extends Node2D:
	var text: String = ""

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.08, 0.07, 0.08))
