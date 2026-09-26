extends Node

## Host core shared by listen-host (--host) and the dedicated process (--dedicated).
## Authority owns CombatSim: match, turn, 30s timer, HP/MP, Marks, Impact, Burn,
## terrain, elevation, pushes, and death. Clients send Intent and apply
## snapshot/events. Clients never roll, never tick the clock, never mutate sim.
## Transport: Godot 4 MultiplayerAPI + ENet (direct IP). RPC only; no scene sync.
## Another machine is a different --join address on this same host core.
## Hot-seat is the default (mode HOTSEAT → CombatSim.submit directly).
## Dedicated disconnect is a stub: the seat stays reserved. No reconnect.

enum Mode { HOTSEAT, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 7777
const HOST_SEAT := 0
const GUEST_SEAT := 1
const LISTEN_HOST_CLIENTS := 1
const DEDICATED_CLIENTS := 2
const TRANSPORT := "enet"
const _MatchQueueScript := preload("res://backend/matchmaking.gd")

signal state_changed(events: Array, snapshot: Dictionary)
signal connection_changed(status: String)

var mode: int = Mode.HOTSEAT
var local_seat: int = -1
var last_events: Array = []
var last_snapshot: Dictionary = {}
var last_result: Dictionary = {}
var last_legal: Dictionary = {0: [], 1: []}
var last_legal_deploy: Dictionary = {0: [], 1: []}
var last_packed: Dictionary = {}
var guest_peer_id: int = 0
var listen_port: int = DEFAULT_PORT
var join_address: String = "127.0.0.1"

var _sim: Node = null
var _cli_host: bool = false
var _cli_join: bool = false
var _cli_dedicated: bool = false
var _signals_wired: bool = false
## peer id per seat. 0 means no live peer. Server peer id is 1 and is never stored.
var _seat_peer: Array[int] = [0, 0]
## True once a seat has been given out. Dedicated keeps this after disconnect.
var _seat_held: Array[bool] = [false, false]
## SELECT_CLASS on the dedicated queue. Listen-host ignores this and stays fixed.
var selected_class_id: String = ""
var lobby_text: String = ""
var _queue_client: bool = false
var _match_queue: MatchQueue
var _match_class_ids: Array[String] = []
var _cli_class: String = ""
var _cli_queue: bool = false
var _local_queued: bool = false
var _opponent_queued: bool = false
var _match_live: bool = false
var _prematch_phase: String = "MATCH"


func _ready() -> void:
	_parse_user_args()
	if _cli_class != "":
		select_class(_cli_class)
	if _cli_dedicated:
		start_dedicated(listen_port)
	elif _cli_host:
		start_host(listen_port)
	elif _cli_queue:
		var queued: Dictionary = start_queue_client(join_address, listen_port)
		if not bool(queued.get("ok", false)):
			print("STASIUM XII queue failed: %s" % str(queued.get("reason", "")))
	elif _cli_join:
		start_client(join_address, listen_port)
	_update_window_title()


func attach_sim(node: Node) -> void:
	_sim = node


func sim() -> Node:
	if _sim != null and is_instance_valid(_sim):
		return _sim
	if is_inside_tree():
		return get_tree().root.get_node_or_null("CombatSim")
	return null


func is_online() -> bool:
	return mode == Mode.HOST or mode == Mode.CLIENT or mode == Mode.DEDICATED


## Listen-host window: this process is seat 0 and the authority.
func is_host() -> bool:
	return mode == Mode.HOST


## Headless (or windowed) authority with no seat. Same host core as listen-host.
func is_dedicated() -> bool:
	return mode == Mode.DEDICATED


## Listen-host and dedicated share this. Clients and hot-seat do not.
func is_authority() -> bool:
	return mode == Mode.HOST or mode == Mode.DEDICATED


func is_client() -> bool:
	return mode == Mode.CLIENT


func is_hotseat() -> bool:
	return mode == Mode.HOTSEAT


func is_connecting() -> bool:
	return mode == Mode.CLIENT and last_snapshot.is_empty()


func has_view_state() -> bool:
	if not last_snapshot.is_empty():
		return true
	return is_authority() and sim() != null


func owns_seat(seat: int) -> bool:
	if mode == Mode.HOTSEAT:
		return true
	return seat == local_seat


## Authority may reset. A dedicated client may ask only for seat 0.
func can_reset_match() -> bool:
	if mode == Mode.CLIENT:
		return local_seat == HOST_SEAT
	return true


func enter_host_offline() -> void:
	mode = Mode.HOST
	local_seat = HOST_SEAT
	_reset_seats()


func enter_dedicated_offline() -> void:
	mode = Mode.DEDICATED
	local_seat = -1
	_reset_seats()


func enter_client_offline() -> void:
	mode = Mode.CLIENT
	local_seat = GUEST_SEAT
	guest_peer_id = 0


func enter_client_unassigned() -> void:
	mode = Mode.CLIENT
	local_seat = -1
	guest_peer_id = 0


func return_to_hotseat() -> void:
	_close_peer()
	mode = Mode.HOTSEAT
	local_seat = -1
	guest_peer_id = 0
	last_snapshot = {}
	last_events = []
	last_result = {}
	connection_changed.emit("hotseat")
	_update_window_title()


func start_host(port: int = DEFAULT_PORT) -> Dictionary:
	return _open_server(port, LISTEN_HOST_CLIENTS, Mode.HOST, HOST_SEAT, "host_listening")


func start_dedicated(port: int = DEFAULT_PORT) -> Dictionary:
	var opened := _open_server(port, DEDICATED_CLIENTS, Mode.DEDICATED, -1, "dedicated_listening")
	if bool(opened.get("ok", false)):
		_match_live = false
		_match_class_ids = []
		_prematch_phase = "SELECT_CLASS"
		lobby_text = "Dedicated queue listening on UDP %d. Pick a Locked class, then join." % port
		print("STASIUM XII dedicated host listening on UDP %d" % port)
	return opened


func start_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		connection_changed.emit("join_failed")
		return {"ok": false, "reason": "connect_failed", "address": address, "port": port}
	_close_peer()
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	# Seat comes from the authority packet (listen-host guest = 1, dedicated = join order).
	local_seat = -1
	join_address = address
	listen_port = port
	_wire_peer_signals()
	connection_changed.emit("connecting")
	_update_window_title()
	return {"ok": true, "reason": "", "address": address, "port": port, "transport": TRANSPORT}


func _open_server(port: int, max_clients: int, next_mode: int, seat: int, status: String) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		connection_changed.emit("host_bind_failed")
		return {"ok": false, "reason": "bind_failed", "port": port}
	_close_peer()
	multiplayer.multiplayer_peer = peer
	mode = next_mode
	local_seat = seat
	listen_port = port
	_reset_seats()
	_wire_peer_signals()
	connection_changed.emit(status)
	_update_window_title()
	return {"ok": true, "reason": "", "port": port, "transport": TRANSPORT, "mode": mode_name()}


func is_queue_client() -> bool:
	return _queue_client


func match_is_live() -> bool:
	return _match_live


## Chrome name for the dedicated match. True after both seats are queued and paired.
func match_assigned() -> bool:
	return _match_live


## Local confirm before connect. Invalid ids do not clear a stored class.
func select_class(class_id: String) -> Dictionary:
	var normalized := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(normalized):
		return {
			"ok": false,
			"illegal": true,
			"reason": "invalid_class",
			"class_id": selected_class_id,
		}
	selected_class_id = normalized
	if not _match_live:
		_prematch_phase = "SELECT_CLASS"
	if _queue_client and mode == Mode.CLIENT and _rpc_ready():
		rpc_select_class.rpc_id(1, normalized)
	return {"ok": true, "illegal": false, "reason": "", "class_id": normalized}


func start_queue_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	if not SpellKits.is_roster_class(selected_class_id):
		return {"ok": false, "illegal": true, "reason": "class_required", "class_id": selected_class_id}
	_queue_client = true
	var opened: Dictionary = start_client(address, port)
	if not bool(opened.get("ok", false)):
		_queue_client = false
		return opened
	return opened


func server_select_class(session_id: String, class_id: String) -> Dictionary:
	return _queue().select_class(session_id, class_id)


func server_enqueue(session_id: String) -> Dictionary:
	var result: Dictionary = _queue().enqueue(session_id)
	if bool(result.get("matched", false)) and mode == Mode.DEDICATED:
		var match: Dictionary = result.get("match", {})
		_boot_dedicated_match(match)
	return result


func server_session(session_id: String) -> Dictionary:
	return _queue().session(session_id)


func server_bind_seat(session_id: String, seat: int) -> void:
	_queue().bind_seat(session_id, seat)


func reset_match(config: Dictionary = {}) -> Dictionary:
	if mode == Mode.CLIENT:
		if local_seat != HOST_SEAT:
			return last_view_result()
		if not is_inside_tree() or multiplayer.multiplayer_peer == null:
			return _fail("not_connected")
		rpc_request_reset.rpc_id(1, IntentCodec.encode(config) as Dictionary)
		return {"ok": true, "pending": true, "reason": "", "events": [], "snapshot": snapshot()}
	if mode == Mode.HOTSEAT:
		var local_sim := sim()
		if local_sim == null:
			return _fail("no_sim")
		return local_sim.reset_match(config)
	if mode == Mode.DEDICATED:
		var chosen: Array[String] = _class_ids_from_config(config)
		if chosen.size() == 2:
			_match_class_ids = chosen
			_match_live = true
			_prematch_phase = "MATCH"
	var fixture := bool(config.get("fixture", false)) or bool(config.get("skip_deploy", false)) or config.has("rolls")
	var gate: Dictionary = HostValidate.validate_match_config(config, fixture)
	if not bool(gate.get("ok", false)):
		return _gate_reject(str(gate.get("reason", "client_must_not_roll")))
	var host_sim := sim()
	if host_sim == null:
		return _fail("no_sim")
	var snap: Dictionary = host_sim.reset_match(config)
	var result := {
		"ok": true,
		"illegal": false,
		"reason": "",
		"events": snap.get("last_events", []),
		"snapshot": snap,
	}
	_cache_and_broadcast(result)
	return last_view_result()


func submit(intent: Dictionary) -> Dictionary:
	if mode == Mode.HOTSEAT:
		var local_sim := sim()
		if local_sim == null:
			return _fail("no_sim")
		return local_sim.submit(intent)
	if mode == Mode.CLIENT:
		if not is_inside_tree() or multiplayer.multiplayer_peer == null:
			return _fail("not_connected")
		rpc_submit_intent.rpc_id(1, IntentCodec.encode_intent(intent))
		return {"ok": true, "pending": true, "reason": "", "events": [], "snapshot": snapshot()}
	_authoritative_submit(intent, local_seat)
	return last_view_result()


func submit_wait(intent: Dictionary) -> Dictionary:
	if mode != Mode.CLIENT:
		return submit(intent)
	var sent: Dictionary = submit(intent)
	if not bool(sent.get("pending", false)):
		return sent
	await state_changed
	return last_view_result()


func place_unit(seat: int, cell: Variant) -> Dictionary:
	return submit({"type": "place", "seat": seat, "to": cell})


func ready_seat(seat: int) -> Dictionary:
	return submit({"type": "ready", "seat": seat})


func place_unit_wait(seat: int, cell: Variant) -> Dictionary:
	return await submit_wait({"type": "place", "seat": seat, "to": cell})


func ready_seat_wait(seat: int) -> Dictionary:
	return await submit_wait({"type": "ready", "seat": seat})


func snapshot() -> Dictionary:
	if mode == Mode.CLIENT and not last_snapshot.is_empty():
		return decorate_snapshot(last_snapshot)
	var local_sim := sim()
	if local_sim == null:
		return decorate_snapshot({})
	return decorate_snapshot(local_sim.snapshot())


func legal_intents(seat: int) -> Array:
	if mode == Mode.CLIENT and last_legal.has(seat):
		return last_legal[seat]
	var local_sim := sim()
	if local_sim == null:
		return []
	return local_sim.legal_intents(seat)


func legal_deploy_cells(seat: int) -> Array[Vector2i]:
	if mode == Mode.CLIENT and last_legal_deploy.has(seat):
		return _as_cell_array(last_legal_deploy[seat])
	var local_sim := sim()
	if local_sim == null:
		return []
	return local_sim.legal_deploy_cells(seat)


func deploy_zone_cells(seat: int) -> Array[Vector2i]:
	var local_sim := sim()
	if local_sim == null:
		return []
	return local_sim.deploy_zone_cells(seat)


func range_highlight_cells(seat: int, spell_id: String) -> Array:
	var local_sim := sim()
	if local_sim == null:
		return []
	return local_sim.range_highlight_cells(seat, spell_id)


func ambush_origin(seat: int) -> Dictionary:
	var local_sim := sim()
	if local_sim == null:
		return {"show": false, "from_self": false, "origin": Vector2i(-1, -1)}
	return local_sim.ambush_origin(seat)


func ambush_landing_preview(seat: int) -> Dictionary:
	var local_sim := sim()
	if local_sim == null:
		return {"ok": false}
	return local_sim.ambush_landing_preview(seat)


func aim_hit_preview(seat: int, spell_id: String, dest: Variant = null) -> Dictionary:
	var local_sim := sim()
	if local_sim == null:
		return {}
	return local_sim.aim_hit_preview(seat, spell_id, dest)


func preview_cast(spell_or_intent: Variant, from: Variant = null, to: Variant = null, target_seat: int = -1) -> Dictionary:
	var local_sim := sim()
	if local_sim == null:
		return {}
	return local_sim.preview_cast(spell_or_intent, from, to, target_seat)


func decorate_snapshot(snap: Dictionary) -> Dictionary:
	var out: Dictionary = snap.duplicate(true) if not snap.is_empty() else {}
	var active_seat := int(out.get("active_seat", -1))
	# local_seat = this window. active_seat = whose turn it is (CombatSim).
	# Godot kit chrome reads local_seat. Do not encode "show active kit".
	out["local_seat"] = local_seat
	out["active_seat"] = active_seat
	out["net_active"] = is_online()
	var packed_net: Dictionary = snap.get("net", {})
	var dedicated := mode == Mode.DEDICATED or (mode == Mode.CLIENT and bool(packed_net.get("dedicated", false)))
	var listen_host := mode == Mode.HOST or (mode == Mode.CLIENT and bool(packed_net.get("listen_host", false)))
	var server_mode := ""
	if mode == Mode.DEDICATED:
		server_mode = "dedicated"
	elif mode == Mode.HOST:
		server_mode = "host"
	elif snap.has("server_mode"):
		server_mode = str(snap.get("server_mode", ""))
	if server_mode == "":
		server_mode = mode_name()
	out["server_mode"] = server_mode
	out["prematch"] = _prematch_block()
	out["net"] = {
		"transport": TRANSPORT,
		"mode": mode_name(),
		"listen_host": listen_host,
		"dedicated": dedicated,
		"authority": is_authority(),
		"local_seat": local_seat,
		"active_seat": active_seat,
		"guest_connected": guest_peer_id != 0 or int(_seat_peer[0]) != 0 or int(_seat_peer[1]) != 0,
		"port": listen_port,
	}
	return out


## Host / hot-seat: tick CombatSim. Client: no-op (hydrate from snapshot only).
## Host broadcasts events + snapshot + seat-filtered legal_intents when the
## displayed remaining seconds change, and again on expiry auto end_turn.
func tick_turn_timer(delta: float) -> Dictionary:
	if mode == Mode.CLIENT:
		return last_view_result()
	var host_sim := sim()
	if host_sim == null or not host_sim.has_method("tick_turn_timer"):
		return _fail("no_sim")
	var before := _clock_wire(host_sim.snapshot())
	var result: Dictionary = host_sim.tick_turn_timer(delta)
	if not is_authority():
		return result
	var after := _clock_wire(host_sim.snapshot())
	var expired := bool(result.get("expired", false))
	if expired or before != after:
		if not expired:
			result = {
				"ok": true,
				"illegal": false,
				"reason": "",
				"events": [],
				"snapshot": host_sim.snapshot(),
			}
		_cache_and_broadcast(result)
		var view: Dictionary = last_view_result()
		view["expired"] = expired
		return view
	result["expired"] = expired
	return result


func mode_name() -> String:
	match mode:
		Mode.HOST:
			return "host"
		Mode.CLIENT:
			return "client"
		Mode.DEDICATED:
			return "dedicated"
		_:
			return "hotseat"


func pack_result(result: Dictionary, viewer_seat: int = -1) -> Dictionary:
	var host_sim := sim()
	var snap: Dictionary = result.get("snapshot", {})
	if snap.is_empty() and host_sim != null:
		snap = host_sim.snapshot()
	var viewed := _redact_invisible_for_viewer(snap, result.get("events", []), viewer_seat)
	snap = viewed["snapshot"]
	var events: Array = viewed["events"]
	var hidden_cells: Array = viewed["hidden_cells"]
	var legal0: Array = []
	var legal1: Array = []
	var deploy0: Array[Vector2i] = []
	var deploy1: Array[Vector2i] = []
	if host_sim != null:
		if viewer_seat != 1:
			legal0 = host_sim.legal_intents(0)
			deploy0 = host_sim.legal_deploy_cells(0)
		if viewer_seat != 0:
			legal1 = host_sim.legal_intents(1)
			deploy1 = host_sim.legal_deploy_cells(1)
	if viewer_seat == HOST_SEAT:
		legal0 = _redact_hidden_intent_cells(legal0, hidden_cells)
	elif viewer_seat == GUEST_SEAT:
		legal1 = _redact_hidden_intent_cells(legal1, hidden_cells)
	return IntentCodec.encode({
		"ok": bool(result.get("ok", false)),
		"illegal": bool(result.get("illegal", false)),
		"reason": str(result.get("reason", "")),
		"events": events,
		"snapshot": decorate_snapshot(snap),
		"legal_intents": {0: legal0, 1: legal1},
		"legal_deploy_cells": {0: deploy0, 1: deploy1},
		"viewer_seat": viewer_seat,
	}) as Dictionary


## Per-viewer wire copy. Does not mutate CombatSim.
## viewer_seat < 0 (hot-seat, listen-host local cache) stays full-fidelity.
## For seat 0 or 1, a unit with invisible=true and a different seat loses its tile:
## pos is null, pos_hidden is true, x/y are omitted. Event fields that name that
## unit's tile (current or the cell it just left) become null; path and cone are
## omitted. range and hit_chance become null when the event locates that unit.
## Coach text replaces those coordinates with (?,?). Shade / wall / plant tokens
## stay, including their cells. legal_intents omit `to` when it was the hidden tile.
func _redact_invisible_for_viewer(snap: Dictionary, events: Array, viewer_seat: int) -> Dictionary:
	var out_snap: Dictionary = snap.duplicate(true) if not snap.is_empty() else {}
	var out_events: Array = events.duplicate(true)
	var hidden_cells: Array = []
	if viewer_seat != HOST_SEAT and viewer_seat != GUEST_SEAT:
		return {"snapshot": out_snap, "events": out_events, "hidden_cells": hidden_cells}
	var hidden_seats := {}
	var secret: Array = []
	for unit in out_snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = unit
		if not bool(rec.get("invisible", false)):
			continue
		var seat := int(rec.get("seat", -1))
		if seat == viewer_seat:
			continue
		hidden_seats[seat] = true
		_remember_cells(hidden_cells, rec.get("pos", null))
		_remember_cells(secret, rec.get("pos", null))
		rec["pos"] = null
		rec.erase("x")
		rec.erase("y")
		rec["pos_hidden"] = true
	if hidden_seats.is_empty():
		return {"snapshot": out_snap, "events": out_events, "hidden_cells": hidden_cells}
	_redact_events(out_events, hidden_seats, hidden_cells, secret)
	var last: Variant = out_snap.get("last_events", [])
	if last is Array:
		_redact_events(last, hidden_seats, hidden_cells, secret)
	if out_snap.has("coach"):
		out_snap["coach"] = _scrub_coach(str(out_snap.get("coach", "")), secret)
	return {"snapshot": out_snap, "events": out_events, "hidden_cells": hidden_cells}


func _redact_events(events: Array, hidden_seats: Dictionary, hidden_cells: Array, secret: Array) -> void:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		_redact_event(event, hidden_seats, hidden_cells, secret)


func _redact_event(event: Dictionary, hidden_seats: Dictionary, hidden_cells: Array, secret: Array) -> void:
	var kind := str(event.get("type", ""))
	var status := str(event.get("status", ""))
	# Board tokens stay public even when their owner is invisible.
	if kind == "expire" and status in ["shade", "wall", "plant"]:
		return
	var actor := int(event.get("seat", -999))
	var target := int(event.get("target_seat", -999))
	var owner := int(event.get("owner_seat", -999))
	var actor_hidden := hidden_seats.has(actor)
	var target_hidden := hidden_seats.has(target)
	var spell := str(event.get("spell", ""))
	if actor_hidden:
		for key in ["caster_cell", "origin", "destination", "path", "cone"]:
			_null_cell_field(event, key, secret)
		if kind in ["move", "advance", "place", "reposition"]:
			_null_cell_field(event, "from", secret)
			_null_cell_field(event, "to", secret)
		if spell == SpellKits.AMBUSH and bool(event.get("teleported", false)):
			_null_cell_field(event, "to", secret)
	if spell == SpellKits.AMBUSH:
		if bool(event.get("teleported", false)):
			if target_hidden:
				_null_cell_field(event, "from", secret)
		elif target_hidden:
			_null_cell_field(event, "to", secret)
	elif target_hidden:
		_null_cell_field(event, "to", secret)
	if target_hidden:
		for key in ["push_from", "push_to", "push_attempted", "pos", "cell"]:
			_null_cell_field(event, key, secret)
		if kind in ["push_blocked", "push_bounce"]:
			_null_cell_field(event, "from", secret)
			_null_cell_field(event, "to", secret)
			_null_cell_field(event, "attempted", secret)
	if kind == "expire" and (actor_hidden or target_hidden or hidden_seats.has(owner)):
		_null_cell_field(event, "pos", secret)
	if hidden_seats.has(int(event.get("for_seat", -999))):
		_null_cell_field(event, "for_cell", secret)
	if hidden_seats.has(int(event.get("interceptor_seat", -999))):
		_null_cell_field(event, "interceptor_cell", secret)
	if event.has("targets") and event["targets"] is Array:
		for row in event["targets"]:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = row
			if hidden_seats.has(int(rec.get("target_seat", -999))):
				_null_cell_field(rec, "cell", secret)
	if typeof(event.get("intent", null)) == TYPE_DICTIONARY:
		var intent: Dictionary = event["intent"]
		var intent_seat := int(intent.get("seat", actor))
		if hidden_seats.has(intent_seat):
			_null_cell_field(intent, "to", secret)
			_null_cell_field(intent, "from", secret)
			_null_cell_field(intent, "path", secret)
	_scrub_matching_cells(event, hidden_cells, secret)
	if actor_hidden or target_hidden or hidden_seats.has(owner):
		if event.has("range"):
			event["range"] = null
		if event.has("hit_chance"):
			event["hit_chance"] = null
	if event.has("coach"):
		event["coach"] = _scrub_coach(str(event["coach"]), secret)


func _null_cell_field(event: Dictionary, key: String, secret: Array) -> void:
	if not event.has(key):
		return
	var value: Variant = event[key]
	if value == null or typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return
	_remember_cells(secret, value)
	if typeof(value) == TYPE_ARRAY:
		event.erase(key)
	else:
		event[key] = null


func _remember_cells(secret: Array, value: Variant) -> void:
	if value is Vector2i:
		var cell: Vector2i = value
		if not secret.has(cell):
			secret.append(cell)
		return
	if value is Array:
		for item in value:
			_remember_cells(secret, item)


func _scrub_matching_cells(node: Variant, hidden_cells: Array, secret: Array) -> Variant:
	if node is Vector2i:
		var cell: Vector2i = node
		if hidden_cells.has(cell):
			_remember_cells(secret, cell)
			return null
		return node
	if node is Dictionary:
		var rec: Dictionary = node
		for key in rec.keys():
			rec[key] = _scrub_matching_cells(rec[key], hidden_cells, secret)
		return rec
	if node is Array:
		var items: Array = node
		for i in range(items.size()):
			items[i] = _scrub_matching_cells(items[i], hidden_cells, secret)
		return items
	return node


func _scrub_coach(text: String, secret: Array) -> String:
	var out := text
	for cell in secret:
		if cell is Vector2i:
			var tile: Vector2i = cell
			out = out.replace("(%d,%d)" % [tile.x, tile.y], "(?,?)")
	return out


func _redact_hidden_intent_cells(intents: Array, hidden_cells: Array) -> Array:
	if hidden_cells.is_empty():
		return intents
	var out: Array = []
	for item in intents:
		if typeof(item) != TYPE_DICTIONARY:
			out.append(item)
			continue
		var intent: Dictionary = (item as Dictionary).duplicate(true)
		if intent.has("to") and intent["to"] is Vector2i and hidden_cells.has(intent["to"]):
			intent.erase("to")
		if intent.has("path") and _value_has_hidden_cell(intent.get("path"), hidden_cells):
			intent.erase("path")
		out.append(intent)
	return out


func _value_has_hidden_cell(value: Variant, hidden_cells: Array) -> bool:
	if value is Vector2i:
		return hidden_cells.has(value)
	if value is Array:
		for item in value:
			if _value_has_hidden_cell(item, hidden_cells):
				return true
	return false


func apply_packed_state(packed: Dictionary, hydrate: bool = true) -> Dictionary:
	var state: Variant = IntentCodec.decode(packed)
	if typeof(state) != TYPE_DICTIONARY:
		return _fail("bad_state")
	var decoded: Dictionary = state
	last_packed = packed.duplicate(true)
	last_result = {
		"ok": bool(decoded.get("ok", false)),
		"illegal": bool(decoded.get("illegal", false)),
		"reason": str(decoded.get("reason", "")),
		"events": decoded.get("events", []),
		"snapshot": decoded.get("snapshot", {}),
	}
	last_events = last_result["events"]
	last_snapshot = last_result["snapshot"]
	var legal_raw: Dictionary = decoded.get("legal_intents", {})
	last_legal = {
		0: legal_raw.get(0, legal_raw.get("0", [])),
		1: legal_raw.get(1, legal_raw.get("1", [])),
	}
	var deploy_raw: Dictionary = decoded.get("legal_deploy_cells", {})
	last_legal_deploy = {
		0: deploy_raw.get(0, deploy_raw.get("0", [])),
		1: deploy_raw.get(1, deploy_raw.get("1", [])),
	}
	if mode == Mode.CLIENT:
		var viewer := int(decoded.get("viewer_seat", -1))
		if viewer >= 0 and viewer != local_seat:
			local_seat = viewer
			if is_inside_tree():
				print("STASIUM XII client assigned seat %d" % local_seat)
			_update_window_title()
	if hydrate and mode == Mode.CLIENT:
		var view := sim()
		if view != null and view.has_method("apply_host_snapshot"):
			view.apply_host_snapshot(last_snapshot)
	state_changed.emit(last_events, decorate_snapshot(last_snapshot))
	return last_view_result()


func last_view_result() -> Dictionary:
	var out := last_result.duplicate(true)
	if out.is_empty():
		out = {
			"ok": true,
			"illegal": false,
			"reason": "",
			"events": last_events,
			"snapshot": snapshot(),
		}
	else:
		out["snapshot"] = decorate_snapshot(out.get("snapshot", last_snapshot))
		out["events"] = last_events
	return out


func submit_for_seat(intent: Dictionary, seat: int) -> Dictionary:
	_authoritative_submit(intent, seat)
	return last_view_result()


@rpc("any_peer", "reliable")
func rpc_submit_intent(encoded: Dictionary) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	var seat := seat_for_peer(sender)
	var intent := IntentCodec.decode_intent(encoded)
	_authoritative_submit(intent, seat)


@rpc("any_peer", "reliable")
func rpc_request_reset(encoded: Dictionary) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	var decoded: Variant = IntentCodec.decode(encoded)
	var config: Dictionary = decoded if typeof(decoded) == TYPE_DICTIONARY else {}
	accept_reset_request(config, seat_for_peer(sender))


@rpc("authority", "reliable")
func rpc_push_state(packed: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	apply_packed_state(packed)


## Client → dedicated authority. class_id must be on the Locked allowlist.
@rpc("any_peer", "reliable")
func rpc_select_class(class_id: String) -> void:
	if not is_authority():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if mode != Mode.DEDICATED:
		_send_class_result(peer_id, false, class_id, "not_dedicated")
		return
	var seat := seat_for_peer(peer_id)
	if seat < 0:
		_send_class_result(peer_id, false, class_id, "no_seat")
		return
	var session_id := _session_for_peer(peer_id)
	_queue().bind_seat(session_id, seat)
	var result: Dictionary = _queue().select_class(session_id, class_id)
	if not bool(result.get("ok", false)):
		_send_class_result(peer_id, false, class_id, str(result.get("reason", "invalid_class")))
		return
	_send_class_result(peer_id, true, str(result.get("class_id", "")), "")


## Authority → client. Fields: ok, class_id, reason.
@rpc("authority", "reliable")
func rpc_class_result(payload: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	var class_id := str(payload.get("class_id", ""))
	var reason := str(payload.get("reason", ""))
	if bool(payload.get("ok", false)):
		selected_class_id = class_id
		connection_changed.emit("class_selected")
		return
	lobby_text = "Class rejected (%s)." % reason
	connection_changed.emit("class_rejected")
	if class_id == selected_class_id and reason == "invalid_class":
		selected_class_id = ""


## Client → dedicated authority. Requires a confirmed class on that peer.
@rpc("any_peer", "reliable")
func rpc_enqueue() -> void:
	if not is_authority():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if mode != Mode.DEDICATED:
		_send_queue_result(peer_id, "rejected", "not_dedicated")
		return
	var seat := seat_for_peer(peer_id)
	if seat < 0:
		_send_queue_result(peer_id, "rejected", "no_seat")
		return
	var session_id := _session_for_peer(peer_id)
	_queue().bind_seat(session_id, seat)
	var result: Dictionary = _queue().enqueue(session_id)
	if not bool(result.get("ok", false)):
		_send_queue_result(peer_id, "rejected", str(result.get("reason", "class_required")))
		return
	if bool(result.get("matched", false)):
		var match: Dictionary = result.get("match", {})
		_boot_dedicated_match(match)
		return
	_send_queue_result(peer_id, "waiting", "")


## Authority → client. Fields: status (waiting | matched | rejected), reason.
@rpc("authority", "reliable")
func rpc_queue_result(payload: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	var status := str(payload.get("status", ""))
	if status == "waiting":
		_local_queued = true
		_opponent_queued = false
		_prematch_phase = "MATCHMAKING"
		lobby_text = "Queued as %s. Waiting for an opponent." % SpellKits.display_name(selected_class_id)
		connection_changed.emit("waiting")
		return
	if status == "matched":
		_local_queued = true
		_opponent_queued = true
		_match_live = true
		_prematch_phase = "MATCH"
		return
	if status == "rejected":
		lobby_text = "Queue rejected (%s)." % str(payload.get("reason", ""))
		connection_changed.emit("queue_rejected")


## Authority → client after the match snapshot push. Carries this seat's class_id.
@rpc("authority", "reliable")
func rpc_match_assigned(payload: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	var seat := int(payload.get("seat", -1))
	if seat >= 0:
		local_seat = seat
	var class_id := str(payload.get("class_id", ""))
	if class_id != "":
		selected_class_id = class_id
	_local_queued = true
	_opponent_queued = true
	_match_live = true
	_prematch_phase = "MATCH"
	connection_changed.emit("matched")
	_update_window_title()


func _authoritative_submit(intent: Dictionary, seat: int) -> Dictionary:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		return _cache_and_broadcast(_gate_reject("not_your_seat"))
	var stamped: Dictionary = intent.duplicate(true)
	if stamped.has("seat") and int(stamped["seat"]) != seat:
		return _cache_and_broadcast(_gate_reject("not_your_seat"))
	stamped["seat"] = seat
	var gate: Dictionary = HostValidate.validate_intent(stamped)
	if not bool(gate.get("ok", false)):
		return _cache_and_broadcast(_gate_reject(str(gate.get("reason", "unknown_intent"))))
	var host_sim := sim()
	if host_sim == null:
		return _cache_and_broadcast(_fail("no_sim"))
	var result: Dictionary = host_sim.submit(stamped)
	return _cache_and_broadcast(result)


func _cache_and_broadcast(result: Dictionary) -> Dictionary:
	var packed := pack_result(result)
	last_packed = packed
	# Host caches packed state for the guest; do not hydrate over the live brain.
	apply_packed_state(packed, mode == Mode.CLIENT)
	_push_viewers(result)
	return last_view_result()


func _push_viewers(result: Dictionary) -> void:
	if not is_authority() or not is_inside_tree():
		return
	if multiplayer.multiplayer_peer == null:
		return
	for seat in [HOST_SEAT, GUEST_SEAT]:
		var peer_id := int(_seat_peer[seat])
		if peer_id <= 1:
			continue
		rpc_push_state.rpc_id(peer_id, pack_result(result, seat))


## Seat 0 may request a fresh match. The server ignores client seed/rolls/positions.
func accept_reset_request(_config: Dictionary, seat: int) -> Dictionary:
	if not is_authority():
		return _fail("not_authority")
	if seat != HOST_SEAT:
		return _cache_and_broadcast(_gate_reject("not_your_seat"))
	if mode == Mode.DEDICATED and _match_class_ids.size() == 2:
		var again: Array[String] = []
		again.append(_match_class_ids[0])
		again.append(_match_class_ids[1])
		return reset_match({"classes": again})
	return reset_match({})


func assign_peer_seat(peer_id: int) -> int:
	if peer_id <= 1:
		return -1
	for seat in [HOST_SEAT, GUEST_SEAT]:
		if int(_seat_peer[seat]) == peer_id:
			return seat
	if mode == Mode.HOST:
		if _seat_held[GUEST_SEAT]:
			return -1
		_seat_peer[GUEST_SEAT] = peer_id
		_seat_held[GUEST_SEAT] = true
		guest_peer_id = peer_id
		return GUEST_SEAT
	if mode != Mode.DEDICATED:
		return -1
	for seat in [HOST_SEAT, GUEST_SEAT]:
		if not _seat_held[seat]:
			_seat_peer[seat] = peer_id
			_seat_held[seat] = true
			if seat == GUEST_SEAT:
				guest_peer_id = peer_id
			return seat
	return -1


## Listen-host frees the guest slot. Dedicated keeps the seat reserved (stub).
func release_peer(peer_id: int) -> int:
	for seat in [HOST_SEAT, GUEST_SEAT]:
		if int(_seat_peer[seat]) != peer_id or peer_id == 0:
			continue
		_seat_peer[seat] = 0
		if mode == Mode.HOST:
			_seat_held[seat] = false
		if guest_peer_id == peer_id:
			guest_peer_id = int(_seat_peer[GUEST_SEAT])
		return seat
	return -1


func peer_for_seat(seat: int) -> int:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		return 0
	return int(_seat_peer[seat])


func seat_reserved(seat: int) -> bool:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		return false
	return bool(_seat_held[seat])


func seat_for_peer(peer_id: int) -> int:
	if mode == Mode.HOST and (peer_id == 0 or peer_id == 1):
		return HOST_SEAT
	if peer_id <= 1:
		return -1
	for seat in [HOST_SEAT, GUEST_SEAT]:
		if int(_seat_peer[seat]) == peer_id:
			return seat
	return -1


func _seat_for_peer(peer_id: int) -> int:
	return seat_for_peer(peer_id)


func _reset_seats() -> void:
	_seat_peer[HOST_SEAT] = 0
	_seat_peer[GUEST_SEAT] = 0
	_seat_held[HOST_SEAT] = false
	_seat_held[GUEST_SEAT] = false
	guest_peer_id = 0


func _wire_peer_signals() -> void:
	if _signals_wired:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_signals_wired = true


func _on_peer_connected(id: int) -> void:
	if not is_authority():
		return
	var seat := assign_peer_seat(id)
	if seat < 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		connection_changed.emit("seat_refused")
		return
	connection_changed.emit("seat_%d_joined" % seat)
	print("STASIUM XII seat %d joined (peer %d)" % [seat, id])
	if mode == Mode.HOST:
		connection_changed.emit("guest_joined")
	if sim() == null and last_packed.is_empty():
		return
	var snap: Dictionary = sim().snapshot() if sim() != null else last_snapshot
	var events: Array = last_events if not last_events.is_empty() else snap.get("last_events", [])
	rpc_push_state.rpc_id(id, pack_result({
		"ok": true,
		"illegal": false,
		"reason": "",
		"events": events,
		"snapshot": snap,
	}, seat))


func _on_peer_disconnected(id: int) -> void:
	if not is_authority():
		return
	var seat := release_peer(id)
	if seat < 0:
		return
	# Dedicated: seat stays reserved. Listen-host: guest slot can be taken again.
	connection_changed.emit("seat_%d_left" % seat)
	print("STASIUM XII seat %d left (peer %d)" % [seat, id])
	if mode == Mode.HOST:
		connection_changed.emit("guest_left")


func _on_connected_to_server() -> void:
	if mode == Mode.CLIENT:
		connection_changed.emit("joined")
		print("STASIUM XII client connected to %s:%d" % [join_address, listen_port])
		if _queue_client and SpellKits.is_roster_class(selected_class_id):
			rpc_select_class.rpc_id(1, selected_class_id)
			rpc_enqueue.rpc_id(1)
		_update_window_title()


func _on_connection_failed() -> void:
	connection_changed.emit("join_failed")
	print("STASIUM XII client join failed for %s:%d" % [join_address, listen_port])


func _on_server_disconnected() -> void:
	connection_changed.emit("host_left")


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


static func plan_from_args(args: PackedStringArray) -> Dictionary:
	var planned := "hotseat"
	var port := DEFAULT_PORT
	var address := "127.0.0.1"
	var class_id := ""
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--host":
			planned = "host"
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				port = int(args[i])
		elif arg == "--dedicated":
			planned = "dedicated"
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				port = int(args[i])
		elif arg == "--join" or arg == "--queue":
			planned = "client" if arg == "--join" else "queue"
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				var spec := str(args[i])
				if spec.contains(":"):
					var parts := spec.split(":")
					address = parts[0]
					port = int(parts[1])
				else:
					address = spec
		elif arg == "--class":
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				class_id = str(args[i])
		elif arg == "--hotseat":
			planned = "hotseat"
		i += 1
	return {"mode": planned, "port": port, "address": address, "class_id": class_id}


func _parse_user_args() -> void:
	var plan := plan_from_args(OS.get_cmdline_user_args())
	listen_port = int(plan["port"])
	join_address = str(plan["address"])
	_cli_class = str(plan.get("class_id", ""))
	var planned := str(plan["mode"])
	_cli_dedicated = planned == "dedicated"
	_cli_host = planned == "host"
	_cli_join = planned == "client"
	_cli_queue = planned == "queue"


func _update_window_title() -> void:
	if not is_inside_tree():
		return
	var win := get_window()
	if win == null:
		return
	match mode:
		Mode.HOST:
			win.title = "STASIUM XII — HOST (Kestrel / seat 0)"
		Mode.DEDICATED:
			win.title = "STASIUM XII — DEDICATED (no seat)"
		Mode.CLIENT:
			if _queue_client:
				var who := SpellKits.display_name(selected_class_id)
				if who == "":
					who = "queue"
				if local_seat >= 0:
					win.title = "STASIUM XII — CLIENT (%s / seat %d)" % [who, local_seat]
				else:
					win.title = "STASIUM XII — CLIENT (%s / queue)" % who
			elif local_seat == HOST_SEAT:
				win.title = "STASIUM XII — CLIENT (Kestrel / seat 0)"
			elif local_seat == GUEST_SEAT:
				win.title = "STASIUM XII — CLIENT (Ironjaw / seat 1)"
			else:
				win.title = "STASIUM XII — CLIENT (joining)"
		_:
			win.title = "STASIUM XII"


func _as_cell_array(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in raw:
		if item is Vector2i:
			out.append(item)
		elif typeof(item) == TYPE_DICTIONARY:
			out.append(Vector2i(int(item.get("x", 0)), int(item.get("y", 0))))
		elif typeof(item) == TYPE_ARRAY and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out


func _gate_reject(reason: String) -> Dictionary:
	var snap := {}
	var host_sim := sim()
	if host_sim != null:
		snap = host_sim.snapshot()
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": [{
			"type": "reject",
			"reason": reason,
			"coach": "REJECT — %s." % reason,
		}],
		"snapshot": snap,
	}


func _clock_wire(snap: Dictionary) -> Dictionary:
	return {
		"seconds": _clock_display_seconds(snap),
		"running": bool(snap.get("turn_time_running", false)),
		"active_seat": int(snap.get("active_seat", -1)),
	}


func _clock_display_seconds(snap: Dictionary) -> int:
	if snap.has("turn_time_seconds"):
		return int(snap.get("turn_time_seconds", 0))
	var remaining := float(snap.get("turn_time_remaining", 0.0))
	if remaining <= 0.0:
		return 0
	return int(ceili(remaining))


func _queue() -> MatchQueue:
	if _match_queue == null:
		_match_queue = _MatchQueueScript.new() as MatchQueue
	return _match_queue


func _session_for_peer(peer_id: int) -> String:
	return "peer:%d" % peer_id


func _rpc_ready() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null


func _class_ids_from_config(config: Dictionary) -> Array[String]:
	var raw: Variant = null
	if config.has("classes"):
		raw = config["classes"]
	elif config.has("seat_classes"):
		raw = config["seat_classes"]
	var incoming: Array = []
	if raw is Array:
		incoming = raw
	elif raw is Dictionary:
		var keyed: Dictionary = raw
		incoming = [keyed.get(0, keyed.get("0", "")), keyed.get(1, keyed.get("1", ""))]
	else:
		return []
	if incoming.size() < 2:
		return []
	var out: Array[String] = []
	for i in 2:
		var id := SpellKits.normalize_class_id(str(incoming[i]))
		if not SpellKits.is_roster_class(id):
			return []
		out.append(id)
	return out


func _send_class_result(peer_id: int, ok: bool, class_id: String, reason: String) -> void:
	if peer_id <= 1:
		return
	rpc_class_result.rpc_id(peer_id, {
		"ok": ok,
		"class_id": class_id,
		"reason": reason,
	})


func _send_queue_result(peer_id: int, status: String, reason: String) -> void:
	if peer_id <= 1:
		return
	rpc_queue_result.rpc_id(peer_id, {
		"status": status,
		"reason": reason,
	})


func _boot_dedicated_match(match: Dictionary) -> void:
	var raw: Array = match.get("class_ids", [])
	if raw.size() < 2:
		return
	var ids: Array[String] = [str(raw[0]), str(raw[1])]
	var match_id := str(match.get("id", ""))
	lobby_text = "Match %s — seat 0 %s, seat 1 %s" % [match_id, SpellKits.display_name(ids[0]), SpellKits.display_name(ids[1])]
	reset_match({"classes": ids})
	if not _rpc_ready():
		connection_changed.emit("matched")
		return
	for seat in [HOST_SEAT, GUEST_SEAT]:
		var peer_id := peer_for_seat(seat)
		if peer_id <= 1:
			continue
		_send_queue_result(peer_id, "matched", "")
		var payload: Dictionary = {
			"type": "match_assigned",
			"seat": seat,
			"class_id": ids[seat],
			"classes": ids,
			"match_id": match_id,
		}
		rpc_match_assigned.rpc_id(peer_id, payload)
	connection_changed.emit("matched")


func _prematch_block() -> Dictionary:
	var phase := _prematch_phase
	var live := _match_live
	if mode == Mode.HOTSEAT or mode == Mode.HOST:
		phase = "MATCH"
		live = true
	elif mode == Mode.DEDICATED and _match_class_ids.size() == 2:
		phase = "MATCH"
		live = true
	elif mode == Mode.DEDICATED and not _match_live:
		phase = "SELECT_CLASS" if _prematch_phase == "MATCH" else _prematch_phase
	return {
		"phase": phase,
		"local_class_id": selected_class_id,
		"local_queued": _local_queued,
		"opponent_queued": _opponent_queued,
		"match_live": live,
	}


func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": [],
		"snapshot": last_snapshot,
	}
