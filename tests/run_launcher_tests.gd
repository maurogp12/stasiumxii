extends SceneTree

## PC launcher: manifest checks, version order, chunk joins, resume after a
## cut download, update plans, re-base, mount order, repair of a damaged file.
## Spins up tests/launcher_fixture_server.py (python3) on a free local port.
## Run: godot --headless --path . -s res://tests/run_launcher_tests.gd

const Core := preload("res://launcher/launcher_core.gd")
const Http := preload("res://launcher/launcher_http.gd")
const Updater := preload("res://launcher/launcher_updater.gd")

var passed := 0
var failed := 0
var troot := ""
var srv_root := ""
var log_path := ""
var base_url := ""
var _pid := -1


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	troot = OS.get_user_data_dir().path_join("launcher_tests")
	_wipe(troot)
	DirAccess.make_dir_recursive_absolute(troot)
	srv_root = troot.path_join("server")
	DirAccess.make_dir_recursive_absolute(srv_root)
	log_path = troot.path_join("server.log")
	_test_versions()
	_test_manifest_validation()
	_test_urls()
	_test_join_and_verify()
	_test_mount_order()
	_test_real_mount()
	_test_swap_in()
	if _start_server():
		_test_http_resume()
		_test_plans_and_updates()
		_test_retry_after_cuts()
		_test_corrupt_chunk_on_disk()
	else:
		check(false, "fixture server started")
	if _pid > 0:
		OS.kill(_pid)
	print("launcher tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# --- helpers -------------------------------------------------------------------

func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _bytes(n: int, seed_value: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := PackedByteArray()
	b.resize(n)
	for i in range(0, n, 4):
		var v := rng.randi()
		for k in mini(4, n - i):
			b[i + k] = (v >> (8 * k)) & 0xff
	return b


func _sha(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()


func _write(path: String, b: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


## Publishes bytes as chunks under server/launcher/<folder>/ (next to latest.json)
## and returns a manifest entry with urls relative to the manifest.
func _publish(folder: String, name: String, data: PackedByteArray, chunk: int, query := "") -> Dictionary:
	var chunks: Array = []
	var i := 0
	var off := 0
	while off < data.size():
		var part := data.slice(off, mini(off + chunk, data.size()))
		var rel := "%s/%s.part%02d" % [folder, name, i]
		_write(srv_root.path_join("launcher").path_join(rel), part)
		chunks.append({"url": rel + query, "size": part.size(), "sha256": _sha(part)})
		off += part.size()
		i += 1
	return {"name": name, "sha256": _sha(data), "size": data.size(), "chunks": chunks}


func _manifest(version: String, exe: Dictionary, launcher: Dictionary, packs: Array) -> Dictionary:
	return {"format": 1, "version": version, "date": "2026-10-11", "news": "test news",
		"exe": exe, "launcher": launcher, "packs": packs}


func _pack(entry: Dictionary, kind: String, version: String) -> Dictionary:
	var e := entry.duplicate(true)
	e["kind"] = kind
	e["version"] = version
	return e


func _start_server() -> bool:
	var port_file := troot.path_join("port.txt")
	var script := ProjectSettings.globalize_path("res://tests/launcher_fixture_server.py")
	_pid = OS.create_process("python3", [script, "--root", srv_root, "--port", "0",
		"--port-file", port_file, "--log", log_path])
	for _i in 100:
		if FileAccess.file_exists(port_file):
			base_url = "http://127.0.0.1:%s/" % FileAccess.get_file_as_string(port_file).strip_edges()
			return true
		OS.delay_msec(50)
	return false


func _log_rows() -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(log_path):
		return rows
	for line in FileAccess.get_file_as_string(log_path).split("\n"):
		if line.strip_edges() != "":
			rows.append(JSON.parse_string(line))
	return rows


func _sent_since(mark: int) -> int:
	var rows := _log_rows()
	var n := 0
	for i in range(mark, rows.size()):
		n += int(rows[i]["sent"])
	return n


# --- pure logic ------------------------------------------------------------------

func _test_versions() -> void:
	check(Core.compare_versions("2026.10.11.2", "2026.10.11.1") == 1, "later build is newer")
	check(Core.compare_versions("2026.10.11.1", "2026.10.12.1") == -1, "earlier day is older")
	check(Core.compare_versions("1.10", "1.9") == 1, "numeric, not text, compare")
	check(Core.compare_versions("1.2", "1.2.0") == 0, "missing parts are zero")
	check(Core.compare_versions("1.2-test", "1.2") == 0, "suffix ignored")
	check(Core.is_valid_version("2026.10.11.1"), "date version is valid")
	check(not Core.is_valid_version(""), "empty version invalid")
	check(not Core.is_valid_version("1..2"), "empty part invalid")
	check(not Core.is_valid_version("v1"), "letters invalid")


func _sample_entry(name: String, size := 10) -> Dictionary:
	return {"name": name, "sha256": "a".repeat(64), "size": size,
		"chunks": [{"url": "files/x/%s.part00" % name, "size": size, "sha256": "b".repeat(64)}]}


func _sample_manifest() -> Dictionary:
	return _manifest("2026.10.11.2", _sample_entry("StasiumXII.exe"), _sample_entry("StasiumXII.pck"), [
		_pack(_sample_entry("base-2026.10.11.1.pck"), "base", "2026.10.11.1"),
		_pack(_sample_entry("patch-2026.10.11.2.pck"), "patch", "2026.10.11.2")])


func _test_manifest_validation() -> void:
	var good := _sample_manifest()
	var parsed := Core.parse_manifest(JSON.stringify(good))
	check(parsed["ok"], "valid manifest parses: %s" % [parsed["errors"]])
	check(str(parsed["manifest"]["version"]) == "2026.10.11.2", "parsed version")
	check(not Core.parse_manifest("{not json")["ok"], "broken JSON rejected")
	var m := good.duplicate(true)
	m["format"] = 2
	check(not Core.validate_manifest(m).is_empty(), "unknown format rejected")
	m = good.duplicate(true)
	m["packs"].reverse()
	check(not Core.validate_manifest(m).is_empty(), "patch before base rejected")
	m = good.duplicate(true)
	m["packs"].append(_pack(_sample_entry("patch-old.pck"), "patch", "2026.10.11.1"))
	check(not Core.validate_manifest(m).is_empty(), "patches out of order rejected")
	m = good.duplicate(true)
	m["exe"]["size"] = 11
	check(not Core.validate_manifest(m).is_empty(), "chunk sizes must add up")
	m = good.duplicate(true)
	m["packs"][0]["name"] = "../../evil.pck"
	check(not Core.validate_manifest(m).is_empty(), "path in a name rejected")
	m = good.duplicate(true)
	m["packs"][1]["sha256"] = "xyz"
	check(not Core.validate_manifest(m).is_empty(), "bad sha rejected")
	m = good.duplicate(true)
	m.erase("launcher")
	check(not Core.validate_manifest(m).is_empty(), "missing launcher entry rejected")
	m = good.duplicate(true)
	m["packs"] = []
	check(not Core.validate_manifest(m).is_empty(), "empty pack list rejected")
	check(not Core.is_safe_name("a/b.pck") and not Core.is_safe_name("C:x") and Core.is_safe_name("base-1.pck"), "safe names")


func _test_urls() -> void:
	var mu := "https://host.example/pc-builds/launcher/latest.json"
	check(Core.resolve_url(mu, "files/1/a.part00") == "https://host.example/pc-builds/launcher/files/1/a.part00", "relative chunk url")
	check(Core.resolve_url(mu + "?t=5", "files/a") == "https://host.example/pc-builds/launcher/files/a", "query on manifest url ignored")
	check(Core.resolve_url(mu, "https://cdn.example/x") == "https://cdn.example/x", "absolute chunk url kept")
	check(Core.resolve_url("https://h/pc-builds/launcher-test/latest.json", "../launcher/files/a") == "https://h/pc-builds/launcher/files/a", "../ folded")
	var parts := Http._split_url("http://127.0.0.1:8123/a/b?c=1")
	check(parts["host"] == "127.0.0.1" and parts["port"] == 8123 and parts["path"] == "/a/b?c=1" and not parts["tls"], "url split")
	check(Http._split_url("https://raw.example/x")["port"] == 443, "https default port")


func _test_join_and_verify() -> void:
	var dir := troot.path_join("join")
	var data := _bytes(250_000, 7)
	var paths: Array = []
	for i in 3:
		var p := dir.path_join("p%d" % i)
		_write(p, data.slice(i * 100_000, mini((i + 1) * 100_000, data.size())))
		paths.append(p)
	var out := dir.path_join("joined.bin")
	var ok := Core.join_chunks(paths, out, _sha(data), data.size())
	check(ok["ok"], "chunks join and verify")
	check(_read(out) == data, "joined bytes match")
	check(Core.file_sha256(out) == _sha(data), "streamed sha256 matches")
	var bad := Core.join_chunks(paths, out, "0".repeat(64), data.size())
	check(not bad["ok"] and not FileAccess.file_exists(out), "wrong sha fails and removes output")
	var short := Core.join_chunks(paths.slice(0, 2), out, _sha(data), data.size())
	check(not short["ok"], "missing chunk fails verification")
	check(not Core.join_chunks([dir.path_join("nope")], out, _sha(data), 1)["ok"], "absent chunk file fails")


func _test_mount_order() -> void:
	var inst := troot.path_join("mount_install")
	var cdir := inst.path_join(Core.CONTENT_DIR)
	var sizes := {"base-1.pck": 30, "patch-2.pck": 10, "patch-10.pck": 12, "patch-3.pck": 11}
	for n in sizes:
		_write(cdir.path_join(n), _bytes(sizes[n], 1))
	var record := {"complete": true, "packs": [
		{"name": "patch-10.pck", "kind": "patch", "version": "2026.1.1.10", "size": 12},
		{"name": "patch-2.pck", "kind": "patch", "version": "2026.1.1.2", "size": 10},
		{"name": "base-1.pck", "kind": "base", "version": "2026.1.1.1", "size": 30},
		{"name": "patch-3.pck", "kind": "patch", "version": "2026.1.1.3", "size": 11}]}
	var order := Core.mount_order(inst, record)
	var names: Array = []
	for p in order:
		names.append(p.get_file())
	check(names == ["base-1.pck", "patch-2.pck", "patch-3.pck", "patch-10.pck"], "base first, patches oldest first: %s" % [names])
	var incomplete := record.duplicate(true)
	incomplete["complete"] = false
	check(Core.mount_order(inst, incomplete).is_empty(), "incomplete install mounts nothing")
	var wrong := record.duplicate(true)
	wrong["packs"][1]["size"] = 99
	check(Core.mount_order(inst, wrong).is_empty(), "size mismatch mounts nothing")
	var two_bases := record.duplicate(true)
	two_bases["packs"][0]["kind"] = "base"
	check(Core.mount_order(inst, two_bases).is_empty(), "two bases mount nothing")
	check(Core.mount_order(inst, {}).is_empty(), "no record mounts nothing")


## Builds two real packs and mounts them the way LauncherBoot does.
func _test_real_mount() -> void:
	var dir := troot.path_join("realmount")
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("a_base.txt"), "from base".to_utf8_buffer())
	_write(dir.path_join("a_patch.txt"), "from patch".to_utf8_buffer())
	_write(dir.path_join("b.txt"), "only base".to_utf8_buffer())
	var base := PCKPacker.new()
	base.pck_start(dir.path_join("base.pck"))
	base.add_file("res://launcher_test_mount/a.txt", dir.path_join("a_base.txt"))
	base.add_file("res://launcher_test_mount/b.txt", dir.path_join("b.txt"))
	base.add_file("res://launcher_test_mount/gone.txt", dir.path_join("b.txt"))
	base.flush()
	var patch := PCKPacker.new()
	patch.pck_start(dir.path_join("patch.pck"))
	patch.add_file("res://launcher_test_mount/a.txt", dir.path_join("a_patch.txt"))
	var has_removal := patch.has_method("add_file_removal")
	if has_removal:
		patch.call("add_file_removal", "res://launcher_test_mount/gone.txt")
	patch.flush()
	check(ProjectSettings.load_resource_pack(dir.path_join("base.pck"), true), "base pack mounts")
	check(FileAccess.get_file_as_string("res://launcher_test_mount/a.txt") == "from base", "base content visible")
	check(ProjectSettings.load_resource_pack(dir.path_join("patch.pck"), true), "patch pack mounts")
	check(FileAccess.get_file_as_string("res://launcher_test_mount/a.txt") == "from patch", "patch replaces base file")
	check(FileAccess.get_file_as_string("res://launcher_test_mount/b.txt") == "only base", "untouched base file stays")
	if has_removal:
		check(not FileAccess.file_exists("res://launcher_test_mount/gone.txt"), "patch removal entry deletes a file")


func _test_swap_in() -> void:
	var dir := troot.path_join("swap")
	_write(dir.path_join("game.exe"), "old".to_utf8_buffer())
	_write(dir.path_join("game.exe.part"), "new".to_utf8_buffer())
	check(Updater.swap_in(dir.path_join("game.exe.part"), dir.path_join("game.exe")) == "", "swap succeeds")
	check(_read(dir.path_join("game.exe")).get_string_from_utf8() == "new", "new file in place")
	check(_read(dir.path_join("game.exe.old")).get_string_from_utf8() == "old", "old file kept as .old for cleanup")
	_write(dir.path_join("game.exe.part"), "newer".to_utf8_buffer())
	check(Updater.swap_in(dir.path_join("game.exe.part"), dir.path_join("game.exe")) == "", "second swap replaces a stale .old")
	check(_read(dir.path_join("game.exe")).get_string_from_utf8() == "newer", "newest file in place")


# --- network -----------------------------------------------------------------------

func _test_http_resume() -> void:
	var data := _bytes(600_000, 11)
	_write(srv_root.path_join("blob.bin"), data)
	var http := Http.new()
	http.stall_timeout = 5.0
	var text := http.fetch_text(base_url + "blob.bin")
	check(text["ok"] and int(text["code"]) == 200, "plain GET works")
	var dst := troot.path_join("dl/blob.bin")
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var mark := _log_rows().size()
	var cut := http.download_to(base_url + "blob.bin?cut=250000", dst, data.size())
	check(not cut["ok"], "cut download reports failure")
	check(Core.file_size(dst) == 250_000, "partial bytes kept (%d)" % Core.file_size(dst))
	var resumed := http.download_to(base_url + "blob.bin", dst, data.size())
	check(resumed["ok"], "resume succeeds: %s" % resumed["error"])
	check(int(resumed["resumed_from"]) == 250_000 and int(resumed["bytes"]) == 350_000, "resume fetched only the rest")
	check(Core.file_sha256(dst) == _sha(data), "resumed file verifies")
	var rows := _log_rows()
	check(rows.size() >= mark + 2 and str(rows[-1]["range"]) == "bytes=250000-" and int(rows[-1]["status"]) == 206, "server saw a Range request")
	check(_sent_since(mark) == data.size(), "cut + resume sent each byte once")
	# A server that ignores Range: the client starts the file over and still verifies.
	var dst2 := troot.path_join("dl/blob2.bin")
	_write(dst2, data.slice(0, 100_000))
	var again := http.download_to(base_url + "blob.bin?norange=1", dst2, data.size())
	check(again["ok"] and int(again["resumed_from"]) == 0, "no-Range server restarts the file")
	check(Core.file_sha256(dst2) == _sha(data), "restarted file verifies")
	var missing := http.download_to(base_url + "nope.bin", troot.path_join("dl/nope"), 10)
	check(not missing["ok"] and int(missing["code"]) == 404, "404 is an error")
	var already := http.download_to(base_url + "blob.bin", dst, data.size())
	check(already["ok"] and int(already["bytes"]) == 0, "complete file is not fetched again")


func _test_plans_and_updates() -> void:
	var chunk := 200_000
	var exe_b := _bytes(450_000, 21)
	var lp_b := _bytes(50_000, 22)
	var base_b := _bytes(900_000, 23)
	var patch2_b := _bytes(120_000, 24)
	var exe := _publish("files/r1", "StasiumXII.exe", exe_b, chunk)
	var lp := _publish("files/r1", "StasiumXII.pck", lp_b, chunk)
	var base := _pack(_publish("files/r1", "base-r1.pck", base_b, chunk), "base", "2026.10.11.1")
	var r1 := _manifest("2026.10.11.1", exe, lp, [base])
	check(Core.validate_manifest(r1).is_empty(), "fixture manifest r1 valid: %s" % [Core.validate_manifest(r1)])
	var murl := base_url + "launcher/latest.json"
	var inst := troot.path_join("install")
	DirAccess.make_dir_recursive_absolute(inst)
	_write(srv_root.path_join("launcher/latest.json"), JSON.stringify(r1).to_utf8_buffer())

	var up := Updater.new()
	up.retry_base = 0.01
	var got := up.fetch_manifest(murl)
	check(got["ok"], "manifest fetched over http: %s" % got["error"])
	var plan := Core.plan_update(got["manifest"], inst, {}, false)
	check(plan["fetch"].size() == 3 and not plan["up_to_date"], "fresh install fetches exe, launcher and base")
	check(plan["download_bytes"] == exe_b.size() + lp_b.size() + base_b.size(), "fresh plan byte count")
	check(plan["restart"], "exe/launcher change needs a restart")
	var mark := _log_rows().size()
	var res := up.apply(plan, got["manifest"], murl, inst)
	check(res["ok"], "fresh install applies: %s" % res["error"])
	check(Core.file_sha256(inst.path_join("content/base-r1.pck")) == _sha(base_b), "base installed and verified")
	check(Core.file_sha256(inst.path_join("StasiumXII.exe")) == _sha(exe_b), "exe installed")
	var rec := Core.read_install(inst)
	check(rec.get("complete", false) and str(rec.get("version")) == "2026.10.11.1", "install.json written complete")
	check(Core.mount_order(inst, rec).size() == 1, "installed base is mountable")
	check(_sent_since(mark) - 0 >= base_b.size() and int(res["downloaded"]) == exe_b.size() + lp_b.size() + base_b.size(), "downloaded byte count reported")
	check(not DirAccess.dir_exists_absolute(inst.path_join(Core.DOWNLOAD_DIR)) or DirAccess.get_directories_at(inst.path_join(Core.DOWNLOAD_DIR)).is_empty(), "download scratch cleared")
	var again := Core.plan_update(r1, inst, rec, false)
	check(again["up_to_date"] and again["fetch"].is_empty(), "same manifest: up to date")

	# Release 2: one small patch. Only the patch is fetched.
	var patch2 := _pack(_publish("files/r2", "patch-r2.pck", patch2_b, chunk), "patch", "2026.10.11.2")
	var r2 := _manifest("2026.10.11.2", exe, lp, [base, patch2])
	_write(srv_root.path_join("launcher/latest.json"), JSON.stringify(r2).to_utf8_buffer())
	got = up.fetch_manifest(murl)
	plan = Core.plan_update(got["manifest"], inst, Core.read_install(inst), false)
	check(plan["fetch"].size() == 1 and plan["fetch"][0]["entry"]["name"] == "patch-r2.pck", "patch release fetches only the patch")
	check(plan["download_bytes"] == patch2_b.size() and not plan["restart"], "patch plan bytes, no exe swap")
	mark = _log_rows().size()
	res = up.apply(plan, got["manifest"], murl, inst)
	check(res["ok"], "patch applies: %s" % res["error"])
	check(_sent_since(mark) == patch2_b.size(), "server sent exactly the patch (%d bytes)" % _sent_since(mark))
	rec = Core.read_install(inst)
	var order := Core.mount_order(inst, rec)
	check(order.size() == 2 and order[0].ends_with("base-r1.pck") and order[1].ends_with("patch-r2.pck"), "mount order base then patch")

	# A damaged pack of the right size: a quick check trusts install.json, Repair finds it.
	var f := FileAccess.open(inst.path_join("content/base-r1.pck"), FileAccess.READ_WRITE)
	f.seek(500_000)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5]))
	f.close()
	var quick := Core.plan_update(r2, inst, rec, false)
	check(quick["fetch"].is_empty(), "quick check trusts the record")
	var deep := Core.plan_update(r2, inst, rec, true)
	check(deep["fetch"].size() == 1 and deep["fetch"][0]["reason"] == "corrupt", "Repair flags the damaged base as corrupt")
	res = up.apply(deep, r2, murl, inst)
	check(res["ok"] and Core.file_sha256(inst.path_join("content/base-r1.pck")) == _sha(base_b), "Repair re-downloads and verifies the base")
	# A truncated file is caught even without Repair.
	var t := FileAccess.open(inst.path_join("content/patch-r2.pck"), FileAccess.WRITE)
	t.store_buffer(patch2_b.slice(0, 1000))
	t.close()
	var trunc := Core.plan_update(r2, inst, Core.read_install(inst), false)
	check(trunc["fetch"].size() == 1 and trunc["fetch"][0]["reason"] == "size", "truncated patch is re-fetched")
	check(up.apply(trunc, r2, murl, inst)["ok"], "truncated patch repaired")

	# Re-base: release 3 is a new full base. Old base and patch are removed.
	var base3_b := _bytes(700_000, 25)
	var base3 := _pack(_publish("files/r3", "base-r3.pck", base3_b, chunk), "base", "2026.10.12.1")
	var r3 := _manifest("2026.10.12.1", exe, lp, [base3])
	plan = Core.plan_update(r3, inst, Core.read_install(inst), false)
	check(plan["fetch"].size() == 1 and plan["fetch"][0]["entry"]["name"] == "base-r3.pck", "re-base fetches the new base")
	check(plan["remove"].size() == 2, "re-base drops the old base and patch")
	res = up.apply(plan, r3, murl, inst)
	check(res["ok"], "re-base applies")
	var left := Array(DirAccess.get_files_at(inst.path_join("content")))
	check(left == ["base-r3.pck"], "only the new base is left: %s" % [left])
	order = Core.mount_order(inst, Core.read_install(inst))
	check(order.size() == 1 and order[0].ends_with("base-r3.pck"), "mount order after re-base")

	# Engine update: a new exe swaps in, the old one waits as .old.
	var exe2_b := _bytes(300_000, 26)
	var exe2 := _publish("files/r4", "StasiumXII.exe", exe2_b, chunk)
	var r4 := _manifest("2026.10.12.2", exe2, lp, [base3])
	plan = Core.plan_update(r4, inst, Core.read_install(inst), false)
	check(plan["fetch"].size() == 1 and plan["restart"], "engine update fetches the exe and asks for a restart")
	check(up.apply(plan, r4, murl, inst)["ok"], "engine update applies")
	check(Core.file_sha256(inst.path_join("StasiumXII.exe")) == _sha(exe2_b), "new exe in place")
	check(FileAccess.file_exists(inst.path_join("StasiumXII.exe.old")), "old exe kept as .old until next start")

	# Bad manifest from the server is refused.
	_write(srv_root.path_join("launcher/latest.json"), "{\"format\": 1}".to_utf8_buffer())
	check(not up.fetch_manifest(murl)["ok"], "invalid manifest from server refused")
	check(not up.fetch_manifest(base_url + "missing/latest.json")["ok"], "missing manifest is an error")


## Every request is cut part way: retries with backoff resume until done.
func _test_retry_after_cuts() -> void:
	var data := _bytes(300_000, 31)
	var entry := _publish("files/cut", "base-cut.pck", data, 300_000, "?cut=110000")
	var m := _manifest("2026.10.13.1", _sample_entry("StasiumXII.exe"), _sample_entry("StasiumXII.pck"),
		[_pack(entry, "base", "2026.10.13.1")])
	var inst := troot.path_join("install_cut")
	DirAccess.make_dir_recursive_absolute(inst)
	var plan := {"fetch": [{"role": "pack", "entry": m["packs"][0], "path": Core.target_path(inst, "pack", m["packs"][0]), "reason": "missing"}],
		"remove": [], "restart": false, "download_bytes": data.size()}
	var up := Updater.new()
	up.retry_base = 0.01
	var mark := _log_rows().size()
	var t0 := Time.get_ticks_msec()
	var res := up.apply(plan, m, base_url + "launcher/latest.json", inst)
	check(res["ok"], "download finishes through repeated cuts: %s" % res["error"])
	check(Core.file_sha256(inst.path_join("content/base-cut.pck")) == _sha(data), "cut-up download verifies")
	var rows := _log_rows().slice(mark)
	check(rows.size() == 3, "three tries for three cuts (%d)" % rows.size())
	check(_sent_since(mark) == data.size(), "no byte sent twice across retries")
	check(Time.get_ticks_msec() - t0 < 10_000, "backoff stays short in tests")
	up.max_attempts = 1
	var inst2 := troot.path_join("install_cut2")
	DirAccess.make_dir_recursive_absolute(inst2)
	plan["fetch"][0]["path"] = Core.target_path(inst2, "pack", m["packs"][0])
	var fail := up.apply(plan, m, base_url + "launcher/latest.json", inst2)
	check(not fail["ok"] and str(fail["error"]).contains("failed"), "gives up after max attempts")
	check(not bool(Core.read_install(inst2).get("complete", false)), "failed update leaves the install marked incomplete")


## A full-size but wrong chunk left in the download folder is thrown away.
func _test_corrupt_chunk_on_disk() -> void:
	var data := _bytes(200_000, 41)
	var entry := _publish("files/cc", "base-cc.pck", data, 100_000)
	var m := _manifest("2026.10.14.1", _sample_entry("StasiumXII.exe"), _sample_entry("StasiumXII.pck"),
		[_pack(entry, "base", "2026.10.14.1")])
	var inst := troot.path_join("install_cc")
	var work := inst.path_join(Core.DOWNLOAD_DIR).path_join("base-cc.pck." + str(entry["sha256"]).substr(0, 12))
	_write(work.path_join("part00"), _bytes(100_000, 999))  # right size, wrong bytes
	_write(work.path_join("part01"), data.slice(100_000, 150_000))  # half a chunk: resume
	var plan := {"fetch": [{"role": "pack", "entry": m["packs"][0], "path": Core.target_path(inst, "pack", m["packs"][0]), "reason": "missing"}],
		"remove": [], "restart": false, "download_bytes": data.size()}
	var up := Updater.new()
	up.retry_base = 0.01
	var mark := _log_rows().size()
	var res := up.apply(plan, m, base_url + "launcher/latest.json", inst)
	check(res["ok"], "update with a bad leftover chunk succeeds: %s" % res["error"])
	check(Core.file_sha256(inst.path_join("content/base-cc.pck")) == _sha(data), "result verifies")
	check(_sent_since(mark) == 150_000, "bad chunk re-fetched, half chunk resumed (%d bytes)" % _sent_since(mark))
