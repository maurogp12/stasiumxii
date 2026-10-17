extends Node3D

## High-angle 3/4 tactical camera (one camera for exploration and, later,
## combat). Follows a target with a soft lag; the player can orbit
## (right-drag or Q/E), zoom (wheel), pan (middle-drag or WASD, which lets go
## of the target) and recentre (Space / F).

var target: Node3D
var yaw := 45.0          ## degrees; 45 = from grid south-east, as the 2D view
var pitch := 52.0        ## degrees down from the horizon
var distance := 24.0
var min_distance := 7.0
var max_distance := 140.0
var follow := true
var focus := Vector3.ZERO
var lag := 6.0
var cam: Camera3D
var _drag_orbit := false
var _drag_pan := false
var bounds := Rect2(-100, -100, 1000, 1000)


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.3
	cam.far = 3000.0
	add_child(cam)
	cam.current = true


func snap() -> void:
	if target != null:
		focus = target.global_position + Vector3(0, 1.0, 0)
	_place()


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): pan.z -= 1
	if Input.is_key_pressed(KEY_S): pan.z += 1
	if Input.is_key_pressed(KEY_A): pan.x -= 1
	if Input.is_key_pressed(KEY_D): pan.x += 1
	if Input.is_key_pressed(KEY_Q): yaw -= 70.0 * delta
	if Input.is_key_pressed(KEY_E): yaw += 70.0 * delta
	if pan != Vector3.ZERO:
		follow = false
		focus += Basis(Vector3.UP, deg_to_rad(yaw)) * pan.normalized() * distance * 0.9 * delta
	if follow and target != null:
		var want := target.global_position + Vector3(0, 1.0, 0)
		focus = focus.lerp(want, minf(1.0, delta * lag))
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	_place()


## Optional: returns true where a point is inside something solid (a
## building); the camera then pulls in so it never sits inside a house.
var solid_at: Callable = Callable()


func _place() -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	var d := distance
	if solid_at.is_valid() and follow:
		var steps := int(distance / 0.75)
		for i in range(steps, 0, -1):
			var p := focus + b * Vector3(0, 0, distance * i / steps)
			if solid_at.call(p):
				d = maxf(min_distance * 0.5, distance * (i - 1) / steps)
	cam.global_transform = Transform3D(b, focus + b * Vector3(0, 0, d))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(min_distance, distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(max_distance, distance * 1.1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_pan = mb.pressed
			if mb.pressed:
				follow = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_orbit:
			yaw -= mm.relative.x * 0.3
			pitch = clampf(pitch + mm.relative.y * 0.2, 25.0, 80.0)
		elif _drag_pan:
			var right := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.RIGHT
			var fwd := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.FORWARD
			focus += (-right * mm.relative.x + fwd * mm.relative.y) * distance * 0.0025
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_F):
		follow = true


## The ground point under a screen position (ray onto y = height).
func ground_point(screen: Vector2, height := 0.0) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 1e-4:
		return null
	var t := (height - o.y) / d.y
	if t < 0.0:
		return null
	var p := o + d * t
	return Vector2(p.x, p.z)
