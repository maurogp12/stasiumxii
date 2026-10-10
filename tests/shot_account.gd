extends SceneTree

## 2400×1080 phone shots of the account screen (Step 1: email + guest):
## hub with the Account button, welcome page, create form, guest page.
## Uses a fake Supabase answer, no network, and a scratch login file.
## godot --rendering-driver opengl3 -s res://tests/shot_account.gd -- <dir>

const Logic := preload("res://backend/account_logic.gd")

var _dir := "user://shot_account"
var _frames := 0
var _phase := 0
var _hub: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("-"):
			_dir = str(arg)
	DirAccess.make_dir_recursive_absolute(_dir)
	Logic.save_path = "user://shot_account.json"
	Logic.clear_session()
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	MobileHub.stay_on_hub = true
	change_scene_to_file("res://scenes/mobile_hub.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	_frames = 0
	match _phase:
		0:
			_hub = current_scene
			var client: Node = _hub.account_client()
			client.url = "https://demo.supabase.co"
			client.anon_key = "public-anon"
			client.transport = _fake
			_save("1_hub.png")
			_hub.open_account()
		1:
			_save("2_welcome.png")
			var screen: Node = _hub.find_child("AccountScreen", true, false)
			screen.show_mode("create")
			screen.field("name").text = "Mauro"
			screen.field("email").text = "mauro@mail.com"
			screen.field("password").text = "secret123"
		2:
			_save("3_create.png")
			var screen: Node = _hub.find_child("AccountScreen", true, false)
			screen.show_mode("guest")
			screen.field("name").text = "Mauro"
			screen.submit()
		3:
			_save("4_guest.png")
			_hub.find_child("AccountScreen", true, false).close()
		4:
			_save("5_hub_guest.png")
			Logic.clear_session()
			return true
	_phase += 1
	return false


func _fake(_request: Dictionary) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify({
		"access_token": "AT", "refresh_token": "RT", "expires_in": 3600,
		"user": {"id": "g1", "email": "", "is_anonymous": true, "user_metadata": {"display_name": "Mauro"}},
	})}


func _save(file_name: String) -> void:
	root.get_texture().get_image().save_png(_dir.path_join(file_name))
	print("saved ", _dir.path_join(file_name))
