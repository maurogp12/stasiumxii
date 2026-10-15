class_name MatchQueue
extends RefCounted

## Pre-match queue for the Locked allowlist only
## (kestrel, ironjaw, mender, gloam, bastion).
## SELECT_CLASS is stored on the session. Any other class_id is rejected
## and does not confirm the session. Two confirmed sessions pair in queue
## order unless both sessions have a bound transport seat: then the class
## stays on that seat. Seats are not remapped so that seat 0 is always Kestrel.
## 1v1, 2v2, and 3v3 are separate queues. Different formats never pair.

const SELECT_CLASS := "SELECT_CLASS"
const ENQUEUE := "ENQUEUE"
const FORMAT_1V1 := "1v1"
const FORMAT_2V2 := "2v2"
const FORMAT_3V3 := "3v3"

var _sessions: Dictionary = {}
var _queue: Array[String] = []
var _queue_2v2: Array[String] = []
var _queue_3v3: Array[String] = []
var _matches: Dictionary = {}
var _bound_seats: Dictionary = {}
var _next_match: int = 1


func handle(session_id: String, message: Dictionary) -> Dictionary:
	var kind := str(message.get("type", "")).strip_edges()
	if kind == SELECT_CLASS:
		return select_class(session_id, str(message.get("class_id", "")))
	if kind == ENQUEUE:
		return enqueue(session_id)
	return _fail("unknown_message", session_id)


func select_class(session_id: String, class_id: String) -> Dictionary:
	var id := str(session_id)
	if id == "":
		return _fail("missing_session", id)
	var normalized := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(normalized):
		# Reject. Do not create a session and do not clear a confirmed class.
		return _fail("invalid_class", id)
	var existing: Dictionary = _sessions.get(id, {})
	if bool(existing.get("queued", false)):
		return _fail("already_queued", id)
	if str(existing.get("match_id", "")) != "":
		return _fail("already_matched", id)
	var bound := int(_bound_seats.get(id, -1))
	var ids: Array[String] = [normalized]
	_sessions[id] = {
		"id": id,
		"class_id": normalized,
		"class_ids": ids,
		"format": FORMAT_1V1,
		"confirmed": true,
		"queued": false,
		"match_id": "",
		"seat": -1,
		"bound_seat": bound,
	}
	return _ok(id, normalized)


## Two or three different Locked classes. Duplicates and any other id are
## rejected and do not confirm the session. Two classes wait on the 2v2
## queue. Three wait on the 3v3 queue.
func select_roster(session_id: String, class_ids: Array) -> Dictionary:
	var id := str(session_id)
	if id == "":
		return _fail("missing_session", id)
	var existing: Dictionary = _sessions.get(id, {})
	if bool(existing.get("queued", false)):
		return _fail("already_queued", id)
	if str(existing.get("match_id", "")) != "":
		return _fail("already_matched", id)
	if class_ids.size() != 2 and class_ids.size() != 3:
		return _fail("class_required", id)
	var normalized: Array[String] = []
	for raw in class_ids:
		var class_id := SpellKits.normalize_class_id(str(raw))
		if not SpellKits.is_roster_class(class_id):
			return _fail("invalid_class", id)
		if normalized.has(class_id):
			return _fail("duplicate_class", id)
		normalized.append(class_id)
	var bound := int(_bound_seats.get(id, -1))
	_sessions[id] = {
		"id": id,
		"class_id": normalized[0],
		"class_ids": normalized,
		"format": FORMAT_2V2 if normalized.size() == 2 else FORMAT_3V3,
		"confirmed": true,
		"queued": false,
		"match_id": "",
		"seat": -1,
		"bound_seat": bound,
	}
	return _ok(id, normalized[0])


## Transport seat from the dedicated host. Does not by itself confirm a class.
func bind_seat(session_id: String, seat: int) -> void:
	var id := str(session_id)
	if seat != 0 and seat != 1:
		return
	_bound_seats[id] = seat
	if not _sessions.has(id):
		return
	var session: Dictionary = _sessions[id]
	if str(session.get("match_id", "")) != "":
		return
	session["bound_seat"] = seat
	_sessions[id] = session


func enqueue(session_id: String) -> Dictionary:
	var id := str(session_id)
	if not _sessions.has(id):
		return _fail("class_required", id)
	var session: Dictionary = _sessions[id]
	if not bool(session.get("confirmed", false)) or str(session.get("class_id", "")) == "":
		return _fail("class_required", id)
	var format := str(session.get("format", FORMAT_1V1))
	var roster: Array = session.get("class_ids", [])
	if format == FORMAT_2V2 and roster.size() != 2:
		return _fail("class_required", id)
	if format == FORMAT_3V3 and roster.size() != 3:
		return _fail("class_required", id)
	if str(session.get("match_id", "")) != "":
		return _fail("already_matched", id)
	if bool(session.get("queued", false)):
		return {
			"ok": true,
			"illegal": false,
			"reason": "",
			"queued": true,
			"matched": false,
			"match": {},
			"session_id": id,
			"class_id": str(session.get("class_id", "")),
		}
	session["queued"] = true
	_sessions[id] = session
	_bucket(format).append(id)
	var paired := _try_pair(format)
	if paired.is_empty():
		return {
			"ok": true,
			"illegal": false,
			"reason": "",
			"queued": true,
			"matched": false,
			"match": {},
			"session_id": id,
			"class_id": str(session.get("class_id", "")),
		}
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
		"queued": false,
		"matched": true,
		"match": paired,
		"session_id": id,
		"class_id": str((_sessions[id] as Dictionary).get("class_id", "")),
	}


func session(session_id: String) -> Dictionary:
	if not _sessions.has(session_id):
		return {}
	return (_sessions[session_id] as Dictionary).duplicate(true)


func match_for(session_id: String) -> Dictionary:
	var info := session(session_id)
	var match_id := str(info.get("match_id", ""))
	if match_id == "" or not _matches.has(match_id):
		return {}
	return (_matches[match_id] as Dictionary).duplicate(true)


func queued_count() -> int:
	return _queue.size()


func queued_count_for(format: String) -> int:
	return _bucket(format).size()


## Drop every trace of a session so a reused peer id can queue again.
func forget(session_id: String) -> void:
	var id := str(session_id)
	_queue.erase(id)
	_queue_2v2.erase(id)
	_queue_3v3.erase(id)
	_sessions.erase(id)
	_bound_seats.erase(id)


func drop(session_id: String) -> void:
	var id := str(session_id)
	if not _sessions.has(id):
		return
	var session: Dictionary = _sessions[id]
	if bool(session.get("queued", false)):
		session["queued"] = false
		_queue.erase(id)
		_queue_2v2.erase(id)
		_queue_3v3.erase(id)
		_sessions[id] = session


func _try_pair(format: String = FORMAT_1V1) -> Dictionary:
	var bucket := _bucket(format)
	var team_size := 1
	if format == FORMAT_2V2:
		team_size = 2
	elif format == FORMAT_3V3:
		team_size = 3
	if bucket.size() < 2:
		return {}
	var first: String = str(bucket.pop_front())
	var second: String = str(bucket.pop_front())
	if first == second:
		return {}
	var a: Dictionary = _sessions[first]
	var b: Dictionary = _sessions[second]
	var seat_a := int(a.get("bound_seat", -1))
	var seat_b := int(b.get("bound_seat", -1))
	if seat_a == 1 and seat_b == 0:
		var swap_id := first
		first = second
		second = swap_id
		var swap_session: Dictionary = a
		a = b
		b = swap_session
	var match_id := "m%d" % _next_match
	_next_match += 1
	# Queue order is seat order. Do not force seat 0 = Kestrel.
	# 2v2 / 3v3 interleave so seat % 2 is the player: A0 B0 A1 B1 (A2 B2).
	var a_ids := _roster_of(a, team_size)
	var b_ids := _roster_of(b, team_size)
	var class_ids: Array[String] = []
	for i in team_size:
		class_ids.append(a_ids[i])
		class_ids.append(b_ids[i])
	a["queued"] = false
	a["match_id"] = match_id
	a["seat"] = 0
	b["queued"] = false
	b["match_id"] = match_id
	b["seat"] = 1
	_sessions[first] = a
	_sessions[second] = b
	var match := {
		"id": match_id,
		"format": format,
		"team_size": team_size,
		"class_ids": class_ids,
		"seats": [
			{"session_id": first, "seat": 0, "class_id": a_ids[0], "class_ids": a_ids},
			{"session_id": second, "seat": 1, "class_id": b_ids[0], "class_ids": b_ids},
		],
	}
	_matches[match_id] = match
	return match.duplicate(true)


func _roster_of(session: Dictionary, team_size: int) -> Array[String]:
	var raw: Array = session.get("class_ids", [])
	var out: Array[String] = []
	for i in mini(raw.size(), team_size):
		out.append(str(raw[i]))
	if out.is_empty():
		out.append(str(session.get("class_id", "")))
	while out.size() < team_size:
		out.append(str(session.get("class_id", "")))
	return out


func _bucket(format: String) -> Array[String]:
	if format == FORMAT_2V2:
		return _queue_2v2
	if format == FORMAT_3V3:
		return _queue_3v3
	return _queue


func _ok(session_id: String, class_id: String) -> Dictionary:
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
		"queued": false,
		"matched": false,
		"match": {},
		"session_id": session_id,
		"class_id": class_id,
	}


func _fail(reason: String, session_id: String) -> Dictionary:
	var class_id := ""
	if _sessions.has(session_id):
		class_id = str((_sessions[session_id] as Dictionary).get("class_id", ""))
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"queued": false,
		"matched": false,
		"match": {},
		"session_id": session_id,
		"class_id": class_id,
	}
