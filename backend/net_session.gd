extends Node

## Host core shared by listen-host (--host) and the dedicated process (--dedicated).
## Authority owns CombatSim: match, turn, 30s timer, HP/MP, Marks, Impact, Burn,
## terrain, elevation, pushes, and death. Clients send Intent and apply
## snapshot/events. Clients never roll, never tick the clock, never mutate sim.
## Transport: Godot 4 MultiplayerAPI + ENet (direct IP). RPC only; no scene sync.
## Another machine is a different --join address on this same host core.
## Hot-seat is the default (mode HOTSEAT → CombatSim.submit directly).
## Dedicated disconnect is a stub: the seat stays reserved. No reconnect.
## SELECT_CLASS stub for dedicated clients (Backend can replace the RPC bodies):
## select_class(class_id: String) → authority validates the Locked roster
## (kestrel, ironjaw, mender, gloam, bastion). signal class_selected(class_id) on accept.
## signal class_rejected(reason, class_id) on reject (invalid_class, no_seat, …).
## enter_matchmaking() after a confirmed class. Both seats queued → reset_match
## with seat_classes {0, 1}. Snapshot units[].class_id is the kit source.
## Clients send the call only. They do not write the roster.

enum Mode { HOTSEAT, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 7777
const HOST_SEAT := 0
const GUEST_SEAT := 1
const LISTEN_HOST_CLIENTS := 1
const DEDICATED_CLIENTS := 2
const TRANSPORT := "enet"

signal state_changed(events: Array, snapshot: Dictionary)
signal connection_changed(status: String)
## Accepted class_id. Fired on the authority and, via RPC, on that client.
signal class_selected(class_id: String)
## reason: invalid_class | no_seat | not_connected | not_your_seat | not_authority | already_queued | class_not_confirmed
signal class_rejected(reason: String, class_id: String)
## status: waiting | matched
signal matchmaking_changed(status: String)
signal match_found(snapshot: Dictionary)

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
## Server-owned roster. Clients read confirmed_class_id only after the server accepts.
var confirmed_class_id: String = ""
var queue_status: String = ""
var _client_match_live: bool = false
var _queue_match_started: bool = false
var _seat_class: Array[String] = ["", ""]
var _seat_confirmed: Array[bool] = [false, false]
var _seat_queued: Array[bool] = [false, false]


func _ready() -> void:
	_parse_user_args()
	if _cli_dedicated:
		start_dedicated(listen_port)
	elif _cli_host:
		start_host(listen_port)
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
	_clear_client_prematch()
	_clear_roster()
	connection_changed.emit("hotseat")
	_update_window_title()


func start_host(port: int = DEFAULT_PORT) -> Dictionary:
	return _open_server(port, LISTEN_HOST_CLIENTS, Mode.HOST, HOST_SEAT, "host_listening")


func start_dedicated(port: int = DEFAULT_PORT) -> Dictionary:
	var opened := _open_server(port, DEDICATED_CLIENTS, Mode.DEDICATED, -1, "dedicated_listening")
	if bool(opened.get("ok", false)):
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
	_clear_client_prematch()
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


## Client entry. Sends class_id to the authority. Does not apply it locally.
func select_class(class_id: String) -> Dictionary:
	return select_class_for_seat(local_seat, class_id)


## Authority entry (RPC and tests). Seat is the peer's seat, never a client argument.
func select_class_for_seat(seat: int, class_id: String) -> Dictionary:
	var id := _normalize_class_id(class_id)
	if is_client():
		if seat < 0:
			class_rejected.emit("no_seat", id)
			return _class_fail("no_seat", id)
		if seat != local_seat:
			class_rejected.emit("not_your_seat", id)
			return _class_fail("not_your_seat", id)
		if not _rpc_ready():
			class_rejected.emit("not_connected", id)
			return _class_fail("not_connected", id)
		rpc_select_class.rpc_id(1, id)
		return {"ok": true, "pending": true, "reason": "", "class_id": id}
	if not is_authority():
		class_rejected.emit("not_authority", id)
		return _class_fail("not_authority", id)
	return _authority_select_class(seat, id)


## Client entry. Queues the confirmed class. Match starts when both seats queue.
func enter_matchmaking() -> Dictionary:
	return enter_matchmaking_for_seat(local_seat)


func enter_matchmaking_for_seat(seat: int) -> Dictionary:
	if is_client():
		if seat < 0:
			return _class_fail("no_seat", confirmed_class_id)
		if not _rpc_ready():
			return _class_fail("not_connected", confirmed_class_id)
		rpc_enter_matchmaking.rpc_id(1)
		return {"ok": true, "pending": true, "reason": "", "status": "queued", "class_id": confirmed_class_id}
	if not is_authority():
		return _class_fail("not_authority", "")
	return _authority_enter_matchmaking(seat)


## Dedicated clients stay on class select until the server starts the duel.
## Listen-host packets set this false so that join path still opens the board.
func awaiting_class_select() -> bool:
	if not is_client():
		return false
	return not _client_match_live


## True once a dedicated queue has started the duel. Listen-host is always assigned.
func match_assigned() -> bool:
	if is_client():
		return _client_match_live
	if is_dedicated():
		return _queue_match_started
	return true


func server_mode() -> String:
	if is_authority() or is_hotseat():
		return mode_name()
	return str(last_snapshot.get("server_mode", ""))


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
	config = _apply_locked_roster(config)
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
	var incoming_mode := str(out.get("server_mode", ""))
	# local_seat = this window. active_seat = whose turn it is (CombatSim).
	# Godot kit chrome reads local_seat. Do not encode "show active kit".
	out["local_seat"] = local_seat
	out["active_seat"] = active_seat
	out["net_active"] = is_online()
	# Clients keep the authority stamp. Their own mode is "client".
	if is_authority():
		out["server_mode"] = mode_name()
	elif is_hotseat():
		out["server_mode"] = "hotseat"
	else:
		out["server_mode"] = incoming_mode
	out["net"] = {
		"transport": TRANSPORT,
		"mode": mode_name(),
		"listen_host": mode == Mode.HOST,
		"dedicated": mode == Mode.DEDICATED,
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
	var stamped := decorate_snapshot(snap)
	stamped["prematch"] = _prematch_for_viewer(viewer_seat)
	return IntentCodec.encode({
		"ok": bool(result.get("ok", false)),
		"illegal": bool(result.get("illegal", false)),
		"reason": str(result.get("reason", "")),
		"events": result.get("events", []),
		"snapshot": stamped,
		"legal_intents": {0: legal0, 1: legal1},
		"legal_deploy_cells": {0: deploy0, 1: deploy1},
		"viewer_seat": viewer_seat,
	}) as Dictionary


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
	_note_client_match(last_snapshot)
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
func rpc_select_class(class_id: String) -> void:
	if not is_authority():
		return
	var seat := seat_for_peer(multiplayer.get_remote_sender_id())
	_authority_select_class(seat, _normalize_class_id(class_id))


@rpc("any_peer", "reliable")
func rpc_enter_matchmaking() -> void:
	if not is_authority():
		return
	_authority_enter_matchmaking(seat_for_peer(multiplayer.get_remote_sender_id()))


@rpc("authority", "reliable")
func rpc_class_selected(class_id: String) -> void:
	if mode != Mode.CLIENT:
		return
	confirmed_class_id = class_id
	class_selected.emit(class_id)


@rpc("authority", "reliable")
func rpc_class_rejected(reason: String, class_id: String) -> void:
	if mode != Mode.CLIENT:
		return
	class_rejected.emit(reason, class_id)


@rpc("authority", "reliable")
func rpc_matchmaking_status(status: String) -> void:
	if mode != Mode.CLIENT:
		return
	queue_status = status
	if status == "matched":
		_client_match_live = true
	matchmaking_changed.emit(status)


@rpc("authority", "reliable")
func rpc_match_found() -> void:
	if mode != Mode.CLIENT:
		return
	_client_match_live = true
	queue_status = "matched"
	match_found.emit(snapshot())


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
	_clear_roster()


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
		elif arg == "--join":
			planned = "client"
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				var spec := str(args[i])
				if spec.contains(":"):
					var parts := spec.split(":")
					address = parts[0]
					port = int(parts[1])
				else:
					address = spec
		elif arg == "--hotseat":
			planned = "hotseat"
		i += 1
	return {"mode": planned, "port": port, "address": address}


func _parse_user_args() -> void:
	var plan := plan_from_args(OS.get_cmdline_user_args())
	listen_port = int(plan["port"])
	join_address = str(plan["address"])
	var planned := str(plan["mode"])
	_cli_dedicated = planned == "dedicated"
	_cli_host = planned == "host"
	_cli_join = planned == "client"


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
			if local_seat < 0:
				win.title = "STASIUM XII — CLIENT (joining)"
			else:
				var label := _client_class_label()
				if label == "":
					win.title = "STASIUM XII — CLIENT (seat %d)" % local_seat
				else:
					win.title = "STASIUM XII — CLIENT (%s / seat %d)" % [label, local_seat]
		_:
			win.title = "STASIUM XII"


func _authority_select_class(seat: int, class_id: String) -> Dictionary:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		_emit_class_reject(seat, "no_seat", class_id)
		return _class_fail("no_seat", class_id)
	if _seat_queued[seat] or _queue_match_started:
		_emit_class_reject(seat, "already_queued", class_id)
		return _class_fail("already_queued", class_id)
	if not SpellKits.is_locked_class(class_id):
		_emit_class_reject(seat, "invalid_class", class_id)
		return _class_fail("invalid_class", class_id)
	_seat_class[seat] = class_id
	_seat_confirmed[seat] = true
	class_selected.emit(class_id)
	_send_class_selected(seat, class_id)
	return {"ok": true, "pending": false, "reason": "", "class_id": class_id}


func _authority_enter_matchmaking(seat: int) -> Dictionary:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		return _class_fail("no_seat", "")
	if not _seat_confirmed[seat] or not SpellKits.is_locked_class(_seat_class[seat]):
		_emit_class_reject(seat, "class_not_confirmed", _seat_class[seat])
		return _class_fail("class_not_confirmed", _seat_class[seat])
	if _queue_match_started:
		_send_status(seat, "matched")
		return {"ok": true, "pending": false, "reason": "", "status": "matched", "class_id": _seat_class[seat]}
	_seat_queued[seat] = true
	if _seat_queued[HOST_SEAT] and _seat_queued[GUEST_SEAT]:
		return _start_queued_match(seat)
	queue_status = "waiting"
	matchmaking_changed.emit("waiting")
	_send_status(seat, "waiting")
	return {"ok": true, "pending": false, "reason": "", "status": "waiting", "class_id": _seat_class[seat]}


func _start_queued_match(seat: int) -> Dictionary:
	_queue_match_started = true
	var config := {
		"seat_classes": {
			0: _seat_class[0],
			1: _seat_class[1],
		},
	}
	var view := reset_match(config)
	view["status"] = "matched"
	view["class_id"] = _seat_class[seat]
	queue_status = "matched"
	_announce_matched()
	return view


func _announce_matched() -> void:
	matchmaking_changed.emit("matched")
	match_found.emit(snapshot())
	for seat in [HOST_SEAT, GUEST_SEAT]:
		_send_status(seat, "matched")
		_send_match_found(seat)


func _apply_locked_roster(config: Dictionary) -> Dictionary:
	if mode != Mode.DEDICATED:
		return config
	if not SpellKits.is_locked_class(_seat_class[0]) or not SpellKits.is_locked_class(_seat_class[1]):
		return config
	var out := config.duplicate(true)
	if not out.has("seat_classes"):
		out["seat_classes"] = {0: _seat_class[0], 1: _seat_class[1]}
	return out


func _prematch_for_viewer(viewer_seat: int) -> Dictionary:
	var local_class := ""
	var local_queued := false
	var opponent_queued := false
	if viewer_seat == HOST_SEAT or viewer_seat == GUEST_SEAT:
		local_class = _seat_class[viewer_seat]
		local_queued = _seat_queued[viewer_seat]
		var other := GUEST_SEAT if viewer_seat == HOST_SEAT else HOST_SEAT
		opponent_queued = _seat_queued[other]
	var live := mode != Mode.DEDICATED or _queue_match_started
	var phase := "MATCH"
	if not live:
		phase = "MATCHMAKING" if local_queued else "SELECT_CLASS"
	return {
		"phase": phase,
		"local_class_id": local_class,
		"local_queued": local_queued,
		"opponent_queued": opponent_queued,
		"match_live": live,
	}


func _note_client_match(snap: Dictionary) -> void:
	if mode != Mode.CLIENT or snap.is_empty():
		return
	var pre := _as_dict(snap.get("prematch", {}))
	var local_class := str(pre.get("local_class_id", ""))
	if local_class != "":
		confirmed_class_id = local_class
	if bool(pre.get("local_queued", false)) and queue_status != "matched":
		queue_status = "waiting"
	if bool(pre.get("match_live", false)) or str(snap.get("server_mode", "")) == "host":
		_client_match_live = true


func _emit_class_reject(seat: int, reason: String, class_id: String) -> void:
	class_rejected.emit(reason, class_id)
	if not _can_rpc(peer_for_seat(seat)):
		return
	rpc_class_rejected.rpc_id(peer_for_seat(seat), reason, class_id)


func _send_class_selected(seat: int, class_id: String) -> void:
	if not _can_rpc(peer_for_seat(seat)):
		return
	rpc_class_selected.rpc_id(peer_for_seat(seat), class_id)


func _send_status(seat: int, status: String) -> void:
	if not _can_rpc(peer_for_seat(seat)):
		return
	rpc_matchmaking_status.rpc_id(peer_for_seat(seat), status)


func _send_match_found(seat: int) -> void:
	if not _can_rpc(peer_for_seat(seat)):
		return
	rpc_match_found.rpc_id(peer_for_seat(seat))


func _clear_roster() -> void:
	_queue_match_started = false
	_seat_class = ["", ""]
	_seat_confirmed = [false, false]
	_seat_queued = [false, false]


func _clear_client_prematch() -> void:
	confirmed_class_id = ""
	queue_status = ""
	_client_match_live = false


func _normalize_class_id(class_id: String) -> String:
	return class_id.strip_edges().to_lower()


func _class_fail(reason: String, class_id: String) -> Dictionary:
	return {"ok": false, "pending": false, "reason": reason, "class_id": class_id}


func _client_class_label() -> String:
	var class_id := confirmed_class_id
	if class_id == "":
		class_id = _class_on_seat(local_seat)
	return SpellKits.class_label(class_id)


func _class_on_seat(seat: int) -> String:
	var units: Array = last_snapshot.get("units", [])
	for unit in units:
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) == seat:
			return str(unit.get("class_id", ""))
	return ""


func _rpc_ready() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null


func _can_rpc(peer_id: int) -> bool:
	return peer_id > 1 and _rpc_ready()


func _as_dict(raw: Variant) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	return {}


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


func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": [],
		"snapshot": last_snapshot,
	}
