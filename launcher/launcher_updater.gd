extends RefCounted

## Runs an update plan: fetches each file's chunks (resuming with Range,
## retrying with backoff), joins them, checks the sha256, swaps the file in
## and records it in install.json. Meant for a worker thread; the UI reads
## snapshot() from the main thread.

const Core := preload("res://launcher/launcher_core.gd")
const Http := preload("res://launcher/launcher_http.gd")

## Tries per chunk before the update fails.
var max_attempts := 6
## First retry delay in seconds; doubles each time, capped at 20 s.
var retry_base := 1.0
var http := Http.new()

var _mutex := Mutex.new()
var _state := {
	"phase": "idle", "message": "", "error": "",
	"bytes_done": 0, "bytes_total": 0, "speed": 0.0, "file": "",
	"downloaded": 0,
}
var _window: Array = []  # [[msec, bytes]] for the speed readout


func snapshot() -> Dictionary:
	_mutex.lock()
	var s := _state.duplicate()
	_mutex.unlock()
	return s


func cancel() -> void:
	http.cancelled = true


func _put(key_values: Dictionary) -> void:
	_mutex.lock()
	_state.merge(key_values, true)
	_mutex.unlock()


func _add_bytes(n: int) -> void:
	var now := Time.get_ticks_msec()
	_mutex.lock()
	_state["bytes_done"] += n
	_state["downloaded"] += n
	_window.append([now, n])
	while _window.size() > 1 and now - int(_window[0][0]) > 2000:
		_window.pop_front()
	var span := maxf(0.25, (now - int(_window[0][0])) / 1000.0)
	var sum := 0
	for w in _window:
		sum += int(w[1])
	_state["speed"] = sum / span
	_mutex.unlock()


## Fetches and validates the manifest. Returns {ok, manifest, error}.
func fetch_manifest(manifest_url: String) -> Dictionary:
	_put({"phase": "checking", "message": "Checking for updates...", "error": ""})
	var sep := "&" if manifest_url.contains("?") else "?"
	var res := http.fetch_text(manifest_url + sep + "t=%d" % Time.get_unix_time_from_system())
	if not res["ok"]:
		return {"ok": false, "manifest": {}, "error": "Could not reach the update server (%s)." % res["error"]}
	var parsed := Core.parse_manifest(str(res["body"]))
	if not parsed["ok"]:
		return {"ok": false, "manifest": {}, "error": "The update list is damaged: %s" % ", ".join(parsed["errors"])}
	return {"ok": true, "manifest": parsed["manifest"], "error": ""}


## Builds the plan; deep = re-hash every file (Repair).
func make_plan(manifest: Dictionary, install_dir: String, deep: bool) -> Dictionary:
	_put({"phase": "checking", "message": "Checking installed files..." if deep else "Comparing versions..."})
	var record := Core.read_install(install_dir)
	return Core.plan_update(manifest, install_dir, record, deep)


## Applies the plan. Returns {ok, error, downloaded, restart}.
func apply(plan: Dictionary, manifest: Dictionary, manifest_url: String, install_dir: String) -> Dictionary:
	http.cancelled = false
	var total := 0
	for item in plan["fetch"]:
		total += int(item["entry"]["size"])
	_put({"phase": "downloading", "bytes_done": 0, "bytes_total": total, "downloaded": 0, "error": "",
		"message": "Downloading %s..." % Core.human_bytes(total)})
	DirAccess.make_dir_recursive_absolute(install_dir.path_join(Core.DOWNLOAD_DIR))
	var record := Core.read_install(install_dir)
	record["complete"] = false
	Core.write_install(install_dir, record)
	for item in plan["fetch"]:
		var res := _fetch_one(item, manifest_url, install_dir)
		if not res["ok"]:
			_put({"phase": "error", "error": res["error"], "message": res["error"]})
			return {"ok": false, "error": res["error"], "downloaded": snapshot()["downloaded"], "restart": false}
		var entry: Dictionary = item["entry"]
		record = Core.note_file(Core.read_install(install_dir), str(entry["name"]), str(entry["sha256"]), int(entry["size"]))
		record["complete"] = false
		Core.write_install(install_dir, record)
	for path in plan["remove"]:
		DirAccess.remove_absolute(path)
	_clear_downloads(install_dir)
	var final := Core.record_for(manifest, record)
	final["manifest_url"] = manifest_url
	Core.write_install(install_dir, final)
	_put({"phase": "done", "message": "Up to date (%s)." % manifest["version"], "file": ""})
	return {"ok": true, "error": "", "downloaded": snapshot()["downloaded"], "restart": plan["restart"], "changed": not plan["fetch"].is_empty() or not plan["remove"].is_empty()}


func _fetch_one(item: Dictionary, manifest_url: String, install_dir: String) -> Dictionary:
	var entry: Dictionary = item["entry"]
	var name := str(entry["name"])
	var work := install_dir.path_join(Core.DOWNLOAD_DIR).path_join(name + "." + str(entry["sha256"]).substr(0, 12))
	DirAccess.make_dir_recursive_absolute(work)
	var chunk_paths: Array = []
	var chunks: Array = entry["chunks"]
	for i in chunks.size():
		var c: Dictionary = chunks[i]
		var cpath := work.path_join("part%02d" % i)
		chunk_paths.append(cpath)
		_put({"file": "%s (%d/%d)" % [name, i + 1, chunks.size()]})
		var res := _fetch_chunk(Core.resolve_url(manifest_url, str(c["url"])), cpath, int(c["size"]), str(c["sha256"]))
		if not res["ok"]:
			return res
	_put({"phase": "verifying", "message": "Verifying %s..." % name})
	var tmp: String = str(item["path"]) + ".part"
	var joined := Core.join_chunks(chunk_paths, tmp, str(entry["sha256"]), int(entry["size"]))
	if not joined["ok"]:
		# A chunk that passed its own check cannot give a bad join, but be safe: start over.
		for cp in chunk_paths:
			DirAccess.remove_absolute(cp)
		return {"ok": false, "error": "%s: %s" % [name, joined["error"]]}
	var swapped := swap_in(tmp, str(item["path"]))
	if swapped != "" and item["role"] == "launcher":
		# Windows refused to move the launcher pack aside: stage it as .new;
		# LauncherBoot swaps it in on the next start, before anything reads it.
		var staged := str(item["path"]) + ".new"
		DirAccess.remove_absolute(staged)
		if DirAccess.rename_absolute(tmp, staged) == OK:
			swapped = ""
	if swapped != "":
		return {"ok": false, "error": swapped}
	if item["role"] == "pack":
		# Packs are not held open between reads, so the old copy can go now.
		DirAccess.remove_absolute(str(item["path"]) + ".old")
	for cp in chunk_paths:
		DirAccess.remove_absolute(cp)
	DirAccess.remove_absolute(work)
	_put({"phase": "downloading", "message": "Downloading..."})
	return {"ok": true, "error": ""}


func _fetch_chunk(url: String, path: String, size: int, sha: String) -> Dictionary:
	var counted := maxi(0, Core.file_size(path))
	if counted > size:
		DirAccess.remove_absolute(path)
		counted = 0
	_add_bytes_quiet(counted)
	var delay := retry_base
	var last_error := ""
	for attempt in max_attempts:
		if Core.file_size(path) == size:
			if Core.file_sha256(path) == sha:
				return {"ok": true, "error": ""}
			# Full size but wrong bytes: throw it away and fetch again.
			_add_bytes_quiet(-size)
			DirAccess.remove_absolute(path)
			last_error = "chunk %s failed its check" % path.get_file()
		var before := maxi(0, Core.file_size(path))
		var res := http.download_to(url, path, size, _add_bytes)
		if int(res.get("resumed_from", before)) == 0 and before > 0:
			_add_bytes_quiet(-before)  # server restarted the file from byte 0
		if res["ok"] and Core.file_size(path) == size:
			continue  # verified at the top of the loop
		if http.cancelled:
			return {"ok": false, "error": "Update cancelled."}
		last_error = str(res["error"])
		_put({"message": "Network trouble (%s), retrying in %.0f s..." % [last_error, delay]})
		OS.delay_msec(int(delay * 1000.0))
		delay = minf(delay * 2.0, 20.0)
	if Core.file_size(path) == size and Core.file_sha256(path) == sha:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "Download failed after %d tries: %s" % [max_attempts, last_error]}


func _add_bytes_quiet(n: int) -> void:
	_mutex.lock()
	_state["bytes_done"] += n
	_mutex.unlock()


## Moves a verified file into place. The old file is renamed to .old first,
## which Windows allows even for the running exe; LauncherBoot deletes it later.
## Returns "" or an error.
static func swap_in(tmp: String, final_path: String) -> String:
	if FileAccess.file_exists(final_path):
		var old := final_path + ".old"
		if FileAccess.file_exists(old) and DirAccess.remove_absolute(old) != OK:
			old = final_path + ".old%d" % Time.get_unix_time_from_system()
		if DirAccess.rename_absolute(final_path, old) != OK:
			return "Could not replace %s. Close other copies of the game and try again." % final_path.get_file()
	if DirAccess.rename_absolute(tmp, final_path) != OK:
		return "Could not move the new %s into place." % final_path.get_file()
	return ""


func _clear_downloads(install_dir: String) -> void:
	var root := install_dir.path_join(Core.DOWNLOAD_DIR)
	if not DirAccess.dir_exists_absolute(root):
		return
	for d in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(d)):
			DirAccess.remove_absolute(root.path_join(d).path_join(f))
		DirAccess.remove_absolute(root.path_join(d))
	DirAccess.remove_absolute(root)
