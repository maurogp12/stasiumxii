extends RefCounted

## Pure launcher logic: manifest checks, version order, update plans,
## hashing, chunk joins and the local install record.
## No scene-tree access, so the headless tests and the worker thread can use it.

const FORMAT := 1
const INSTALL_FILE := "install.json"
const CONTENT_DIR := "content"
const DOWNLOAD_DIR := "content/.download"
const HASH_BLOCK := 1 << 20


# --- versions ---------------------------------------------------------------

## Dotted numeric compare: "2026.10.11.2" > "2026.10.11.1", "1.10" > "1.9".
## Missing parts count as 0. Anything after "-" or "+" is ignored.
## Returns -1, 0 or 1.
static func compare_versions(a: String, b: String) -> int:
	var pa := _version_parts(a)
	var pb := _version_parts(b)
	for i in maxi(pa.size(), pb.size()):
		var x: int = pa[i] if i < pa.size() else 0
		var y: int = pb[i] if i < pb.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


static func is_valid_version(v: String) -> bool:
	var core := v.split("-")[0].split("+")[0]
	if core.is_empty():
		return false
	for part in core.split("."):
		if part.is_empty() or not part.is_valid_int() or int(part) < 0:
			return false
	return true


static func _version_parts(v: String) -> Array[int]:
	var out: Array[int] = []
	var core := v.strip_edges().split("-")[0].split("+")[0]
	for part in core.split("."):
		out.append(int(part) if part.is_valid_int() else 0)
	return out


# --- manifest ---------------------------------------------------------------

## Parses and validates manifest text. Returns {ok, manifest, errors}.
static func parse_manifest(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "manifest": {}, "errors": ["manifest is not JSON: %s" % json.get_error_message()]}
	var data: Variant = json.data
	var errors := validate_manifest(data)
	return {"ok": errors.is_empty(), "manifest": data if data is Dictionary else {}, "errors": errors}


static func validate_manifest(m: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not (m is Dictionary):
		errors.append("manifest must be an object")
		return errors
	if int(m.get("format", 0)) != FORMAT:
		errors.append("unsupported manifest format %s" % str(m.get("format")))
		return errors
	if not is_valid_version(str(m.get("version", ""))):
		errors.append("bad version '%s'" % str(m.get("version", "")))
	for role in ["exe", "launcher"]:
		if not (m.get(role) is Dictionary):
			errors.append("missing %s entry" % role)
		else:
			_validate_file(m[role], role, errors)
	var packs: Variant = m.get("packs")
	if not (packs is Array) or (packs as Array).is_empty():
		errors.append("packs must be a non-empty list")
		return errors
	var names := {}
	var last_patch := ""
	for i in (packs as Array).size():
		var p: Variant = packs[i]
		if not (p is Dictionary):
			errors.append("pack %d is not an object" % i)
			continue
		_validate_file(p, "pack %d" % i, errors)
		var kind := str(p.get("kind", ""))
		if i == 0 and kind != "base":
			errors.append("first pack must be the base")
		elif i > 0 and kind != "patch":
			errors.append("pack %d must be a patch" % i)
		var name := str(p.get("name", ""))
		if names.has(name):
			errors.append("duplicate pack %s" % name)
		names[name] = true
		if kind == "patch":
			var pv := str(p.get("version", ""))
			if not is_valid_version(pv):
				errors.append("patch %s has a bad version" % name)
			elif last_patch != "" and compare_versions(pv, last_patch) <= 0:
				errors.append("patches are not oldest first (%s after %s)" % [pv, last_patch])
			last_patch = pv
	return errors


static func _validate_file(e: Dictionary, label: String, errors: Array[String]) -> void:
	var name := str(e.get("name", ""))
	if not is_safe_name(name):
		errors.append("%s has an unsafe name '%s'" % [label, name])
	var sha := str(e.get("sha256", ""))
	if sha.length() != 64 or not _is_hex(sha):
		errors.append("%s has a bad sha256" % label)
	var size := int(e.get("size", -1))
	if size < 0:
		errors.append("%s has a bad size" % label)
	var chunks: Variant = e.get("chunks")
	if not (chunks is Array) or (chunks as Array).is_empty():
		errors.append("%s has no chunks" % label)
		return
	var total := 0
	for c in chunks:
		if not (c is Dictionary) or str(c.get("url", "")).is_empty():
			errors.append("%s has a chunk without url" % label)
			return
		var cs := str(c.get("sha256", ""))
		if cs.length() != 64 or not _is_hex(cs):
			errors.append("%s has a chunk with a bad sha256" % label)
		total += int(c.get("size", 0))
	if total != size:
		errors.append("%s chunks add up to %d, not %d" % [label, total, size])


## A bare file name: no folders, no "..", nothing Windows rejects.
static func is_safe_name(n: String) -> bool:
	if n.is_empty() or n.length() > 120 or n.begins_with("."):
		return false
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", ".."]:
		if n.contains(ch):
			return false
	return true


static func _is_hex(s: String) -> bool:
	for ch in s:
		if not "0123456789abcdef".contains(ch):
			return false
	return true


## Directory part of a URL, ending in "/".
static func url_dir(url: String) -> String:
	var q := url.find("?")
	var clean := url if q < 0 else url.substr(0, q)
	return clean.substr(0, clean.rfind("/") + 1)


## Chunk urls may be absolute or relative to the manifest's folder.
## "../" segments are folded so any host gets a clean path.
static func resolve_url(manifest_url: String, rel: String) -> String:
	if rel.begins_with("http://") or rel.begins_with("https://"):
		return rel
	var joined := url_dir(manifest_url) + rel.trim_prefix("/")
	var scheme_end := joined.find("://")
	var host_end := joined.find("/", scheme_end + 3)
	if scheme_end < 0 or host_end < 0:
		return joined
	var out: PackedStringArray = []
	for seg in joined.substr(host_end + 1).split("/"):
		if seg == "..":
			if not out.is_empty():
				out.remove_at(out.size() - 1)
		elif seg != ".":
			out.append(seg)
	return joined.substr(0, host_end + 1) + "/".join(out)


# --- hashing and chunk joins ------------------------------------------------

## Streams a file through sha256. Returns "" when the file cannot be read.
## progress (optional) gets the byte count of each block.
static func file_sha256(path: String, progress: Callable = Callable()) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		var block := f.get_buffer(HASH_BLOCK)
		if block.is_empty():
			break
		ctx.update(block)
		if progress.is_valid():
			progress.call(block.size())
	return ctx.finish().hex_encode()


static func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	return -1 if f == null else int(f.get_length())


## Joins chunk files into out_path and checks the whole-file sha256 and size.
## On a mismatch the output is deleted. Returns {ok, sha256, size, error}.
static func join_chunks(chunk_paths: Array, out_path: String, expected_sha: String, expected_size: int) -> Dictionary:
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		return {"ok": false, "error": "cannot write %s" % out_path}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var total := 0
	for cp in chunk_paths:
		var f := FileAccess.open(cp, FileAccess.READ)
		if f == null:
			out.close()
			DirAccess.remove_absolute(out_path)
			return {"ok": false, "error": "missing chunk %s" % cp}
		while f.get_position() < f.get_length():
			var block := f.get_buffer(HASH_BLOCK)
			if block.is_empty():
				break
			ctx.update(block)
			out.store_buffer(block)
			total += block.size()
	out.close()
	var sha := ctx.finish().hex_encode()
	if sha != expected_sha or total != expected_size:
		DirAccess.remove_absolute(out_path)
		return {"ok": false, "sha256": sha, "size": total,
			"error": "joined file failed verification (%d bytes, sha %s)" % [total, sha.substr(0, 12)]}
	return {"ok": true, "sha256": sha, "size": total, "error": ""}


# --- install record ---------------------------------------------------------

static func read_install(install_dir: String) -> Dictionary:
	var path := install_dir.path_join(INSTALL_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func write_install(install_dir: String, record: Dictionary) -> bool:
	var path := install_dir.path_join(INSTALL_FILE)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(record, "  "))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## Where each manifest entry lives on disk.
static func target_path(install_dir: String, role: String, entry: Dictionary) -> String:
	if role == "pack":
		return install_dir.path_join(CONTENT_DIR).path_join(str(entry["name"]))
	return install_dir.path_join(str(entry["name"]))


## Pack files to mount, in order: the base, then patches oldest first.
## Returns [] when the record is incomplete or a file is missing or the wrong size.
static func mount_order(install_dir: String, record: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not bool(record.get("complete", false)):
		return out
	var packs: Variant = record.get("packs")
	if not (packs is Array) or (packs as Array).is_empty():
		return out
	var base: Array = []
	var patches: Array = []
	for p in packs:
		if not (p is Dictionary):
			return []
		if str(p.get("kind", "")) == "base":
			base.append(p)
		else:
			patches.append(p)
	if base.size() != 1:
		return out
	patches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return compare_versions(str(a.get("version", "")), str(b.get("version", ""))) < 0)
	for p in base + patches:
		var path := install_dir.path_join(CONTENT_DIR).path_join(str(p.get("name", "")))
		if file_size(path) != int(p.get("size", -2)):
			return []
		out.append(path)
	return out


# --- update plan ------------------------------------------------------------

## Works out what to fetch. A file is kept when it exists, has the right size
## and its sha256 matches: from the install record (fast) or by hashing it
## (deep, or when the record has no sha for it). Returns:
##   fetch: [{role, entry, path, reason}]   keep: [path]   remove: [path]
##   download_bytes, restart (exe or launcher pack changes), up_to_date
static func plan_update(manifest: Dictionary, install_dir: String, record: Dictionary, deep: bool = false) -> Dictionary:
	var known: Dictionary = record.get("files", {}) if record.get("files") is Dictionary else {}
	var fetch: Array = []
	var keep: Array = []
	var targets: Array = [["exe", manifest["exe"]], ["launcher", manifest["launcher"]]]
	for p in manifest["packs"]:
		targets.append(["pack", p])
	var bytes := 0
	var restart := false
	for t in targets:
		var role: String = t[0]
		var entry: Dictionary = t[1]
		var path := target_path(install_dir, role, entry)
		var reason := check_file(path, entry, known, deep)
		if reason == "":
			keep.append(path)
		else:
			fetch.append({"role": role, "entry": entry, "path": path, "reason": reason})
			bytes += int(entry["size"])
			if role != "pack":
				restart = true
	# Packs on disk that the manifest no longer lists (after a re-base, say).
	var wanted := {}
	for p in manifest["packs"]:
		wanted[str(p["name"])] = true
	var remove: Array = []
	var cdir := install_dir.path_join(CONTENT_DIR)
	if DirAccess.dir_exists_absolute(cdir):
		for f in DirAccess.get_files_at(cdir):
			if f.get_extension() == "pck" and not wanted.has(f):
				remove.append(cdir.path_join(f))
	var installed_version := str(record.get("version", ""))
	var newer := installed_version == "" or compare_versions(str(manifest["version"]), installed_version) != 0
	return {
		"fetch": fetch, "keep": keep, "remove": remove, "download_bytes": bytes,
		"restart": restart,
		"up_to_date": fetch.is_empty() and remove.is_empty() and not newer and bool(record.get("complete", false)),
	}


## "" when the file is good, else why it must be fetched.
static func check_file(path: String, entry: Dictionary, known: Dictionary, deep: bool) -> String:
	var size := file_size(path)
	if size < 0:
		return "missing"
	if size != int(entry["size"]):
		return "size"
	var rec: Variant = known.get(path.get_file())
	var recorded_sha := str(rec.get("sha256", "")) if rec is Dictionary else ""
	if not deep and recorded_sha != "":
		return "" if recorded_sha == str(entry["sha256"]) else "outdated"
	return "" if file_sha256(path) == str(entry["sha256"]) else ("corrupt" if recorded_sha == str(entry["sha256"]) else "outdated")


## The install record once every file in the manifest is in place.
static func record_for(manifest: Dictionary, previous: Dictionary) -> Dictionary:
	var files := {}
	var packs: Array = []
	files[str(manifest["exe"]["name"])] = {"sha256": manifest["exe"]["sha256"], "size": manifest["exe"]["size"]}
	files[str(manifest["launcher"]["name"])] = {"sha256": manifest["launcher"]["sha256"], "size": manifest["launcher"]["size"]}
	for p in manifest["packs"]:
		files[str(p["name"])] = {"sha256": p["sha256"], "size": p["size"]}
		packs.append({"name": p["name"], "kind": p["kind"], "version": p.get("version", manifest["version"]),
			"sha256": p["sha256"], "size": p["size"]})
	var out := {"format": FORMAT, "version": manifest["version"], "complete": true,
		"files": files, "packs": packs, "updated": Time.get_datetime_string_from_system(true) + "Z"}
	if previous.has("manifest_url"):
		out["manifest_url"] = previous["manifest_url"]
	return out


## Marks one file as verified in the record without claiming the install is complete.
static func note_file(record: Dictionary, name: String, sha: String, size: int) -> Dictionary:
	var files: Dictionary = record.get("files", {}) if record.get("files") is Dictionary else {}
	files[name] = {"sha256": sha, "size": size}
	record["files"] = files
	return record


static func human_bytes(n: float) -> String:
	if n >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (n / (1024.0 * 1024.0 * 1024.0))
	if n >= 1024.0 * 1024.0:
		return "%.1f MB" % (n / (1024.0 * 1024.0))
	if n >= 1024.0:
		return "%.0f KB" % (n / 1024.0)
	return "%d B" % int(n)
