class_name MatchQueue
extends RefCounted

## Pre-match queue for the Locked allowlist only
## (kestrel, ironjaw, mender, gloam, bastion).
## SELECT_CLASS is stored on the session. Any other class_id is rejected
## and does not confirm the session. Two confirmed sessions pair in queue
## order unless both sessions have a bound transport seat: then the class
## stays on that seat. Seats are not remapped so that seat 0 is always Kestrel.

const SELECT_CLASS := "SELECT_CLASS"
const ENQUEUE := "ENQUEUE"

var _sessions: Dictionary = {}
var _queue: Array[String] = []
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
	_sessions[id] = {
		"id": id,
		"class_id": normalized,
		"confirmed": true,
		"queued": false,
		"match_id": "",
		"seat": -1,
		"bound_seat": bound,
	}
	return _ok(id, normalized)


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
	_queue.append(id)
	var paired := _try_pair()
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


func drop(session_id: String) -> void:
	var id := str(session_id)
	if not _sessions.has(id):
		return
	var session: Dictionary = _sessions[id]
	if bool(session.get("queued", false)):
		session["queued"] = false
		_queue.erase(id)
		_sessions[id] = session


func _try_pair() -> Dictionary:
	if _queue.size() < 2:
		return {}
	var first: String = str(_queue.pop_front())
	var second: String = str(_queue.pop_front())
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
	var class_ids: Array[String] = [str(a.get("class_id", "")), str(b.get("class_id", ""))]
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
		"class_ids": class_ids,
		"seats": [
			{"session_id": first, "seat": 0, "class_id": class_ids[0]},
			{"session_id": second, "seat": 1, "class_id": class_ids[1]},
		],
	}
	_matches[match_id] = match
	return match.duplicate(true)


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
