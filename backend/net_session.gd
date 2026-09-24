extends Node

## Listen-host proto. Host owns CombatSim + seed/RNG + the 30s turn clock.
## Clients submit Intent. Clients never roll, never tick the clock, never mutate sim.
## Transport: Godot 4 MultiplayerAPI + ENet (direct IP). RPC only; no scene sync.
## Local hot-seat stays the default (mode HOTSEAT → CombatSim.submit directly).
## Listen-host still pins seat 0 = Kestrel and seat 1 = Ironjaw.
## DEDICATED is the queue host: it is not a fighter. Players SELECT_CLASS
## (Locked roster only) before ENQUEUE. A pair becomes a match whose seats
## keep those class_ids in queue order.

const _MatchQueueScript := preload("res://backend/matchmaking.gd")

enum Mode { HOTSEAT, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 7777
const HOST_SEAT := 0
const GUEST_SEAT := 1
const TRANSPORT := "enet"
const DEDICATED_SLOTS := 8

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
var selected_class_id: String = ""
var matched: bool = false
var match_id: String = ""
var lobby_text: String = ""

var _sim: Node = null
var _cli_host: bool = false
var _cli_join: bool = false
var _cli_dedicated: bool = false
var _cli_queue: bool = false
var _cli_class: String = ""
var _signals_wired: bool = false
var _queue_client: bool = false
var _class_queue = null
var _peer_seats: Dictionary = {}
var _match_class_ids: Array = []


func _ready() -> void:
	_parse_user_args()
	if _cli_dedicated:
		start_dedicated(listen_port)
	elif _cli_queue:
		var picked: Dictionary = select_class(_cli_class)
		if not bool(picked.get("ok", false)):
			print("SELECT_CLASS rejected (%s)." % str(picked.get("reason", "invalid_class")))
			connection_changed.emit("class_rejected")
		else:
			start_queue_client(join_address, listen_port)
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


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func is_hotseat() -> bool:
	return mode == Mode.HOTSEAT


func is_dedicated() -> bool:
	return mode == Mode.DEDICATED


func is_queue_client() -> bool:
	return mode == Mode.CLIENT and _queue_client


func is_connecting() -> bool:
	return mode == Mode.CLIENT and last_snapshot.is_empty()


func has_view_state() -> bool:
	return not last_snapshot.is_empty() or (mode == Mode.HOST and sim() != null)


func owns_seat(seat: int) -> bool:
	if mode == Mode.HOTSEAT:
		return true
	return seat == local_seat


func can_reset_match() -> bool:
	return mode != Mode.CLIENT


func enter_host_offline() -> void:
	mode = Mode.HOST
	local_seat = HOST_SEAT
	guest_peer_id = 0


func enter_client_offline() -> void:
	mode = Mode.CLIENT
	local_seat = GUEST_SEAT
	guest_peer_id = 0


func enter_dedicated_offline() -> void:
	mode = Mode.DEDICATED
	local_seat = -1
	guest_peer_id = 0
	_queue_client = false
	selected_class_id = ""
	matched = false
	match_id = ""
	_class_queue = _MatchQueueScript.new()
	_peer_seats = {}
	_match_class_ids = []


func return_to_hotseat() -> void:
	_close_peer()
	mode = Mode.HOTSEAT
	local_seat = -1
	guest_peer_id = 0
	last_snapshot = {}
	last_events = []
	last_result = {}
	_clear_queue_state()
	connection_changed.emit("hotseat")
	_update_window_title()


func start_host(port: int = DEFAULT_PORT) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		connection_changed.emit("host_bind_failed")
		return {"ok": false, "reason": "bind_failed", "port": port}
	_close_peer()
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	local_seat = HOST_SEAT
	listen_port = port
	guest_peer_id = 0
	_wire_peer_signals()
	connection_changed.emit("host_listening")
	_update_window_title()
	return {"ok": true, "reason": "", "port": port, "transport": TRANSPORT}


func start_dedicated(port: int = DEFAULT_PORT) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, DEDICATED_SLOTS)
	if err != OK:
		connection_changed.emit("host_bind_failed")
		return {"ok": false, "reason": "bind_failed", "port": port}
	_close_peer()
	multiplayer.multiplayer_peer = peer
	mode = Mode.DEDICATED
	local_seat = -1
	listen_port = port
	guest_peer_id = 0
	_queue_client = false
	selected_class_id = ""
	matched = false
	match_id = ""
	_class_queue = _MatchQueueScript.new()
	_peer_seats = {}
	_match_class_ids = []
	_wire_peer_signals()
	lobby_text = "Dedicated host on %d. Each player picks Kestrel or Ironjaw, then joins the queue." % port
	connection_changed.emit("dedicated_listening")
	_update_window_title()
	return {"ok": true, "reason": "", "port": port, "transport": TRANSPORT, "role": "dedicated"}


func start_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		connection_changed.emit("join_failed")
		return {"ok": false, "reason": "connect_failed", "address": address, "port": port}
	_close_peer()
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	local_seat = GUEST_SEAT
	join_address = address
	listen_port = port
	_wire_peer_signals()
	connection_changed.emit("connecting")
	_update_window_title()
	return {"ok": true, "reason": "", "address": address, "port": port, "transport": TRANSPORT}


## Class must already be confirmed. Connects as a queue client with no seat
## until the host pairs this session.
func start_queue_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	if not SpellKits.is_roster_class(selected_class_id):
		_queue_client = false
		return {
			"ok": false,
			"illegal": true,
			"reason": "class_required",
			"address": address,
			"port": port,
		}
	_queue_client = true
	var result: Dictionary = start_client(address, port)
	if not bool(result.get("ok", false)):
		_queue_client = false
		return result
	local_seat = -1
	_update_window_title()
	return result


## Local confirm before join/queue. The dedicated host validates again.
func select_class(class_id: String) -> Dictionary:
	if mode == Mode.DEDICATED:
		return _fail("server_has_no_class")
	var id := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(id):
		return {
			"ok": false,
			"illegal": true,
			"reason": "invalid_class",
			"class_id": "",
		}
	selected_class_id = id
	if mode == Mode.CLIENT and _client_link_up():
		rpc_select_class.rpc_id(1, id)
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
		"class_id": id,
	}


func server_select_class(session_id: String, class_id: String) -> Dictionary:
	if mode != Mode.DEDICATED or _class_queue == null:
		return _fail("not_dedicated")
	return _class_queue.select_class(session_id, class_id)


func server_enqueue(session_id: String) -> Dictionary:
	if mode != Mode.DEDICATED or _class_queue == null:
		return _fail("not_dedicated")
	var result: Dictionary = _class_queue.enqueue(session_id)
	if bool(result.get("matched", false)):
		var opened: Dictionary = _open_dedicated_match(result.get("match", {}))
		result["match"] = opened
		result["snapshot"] = snapshot()
	else:
		var waiting := int(_class_queue.queued_count())
		lobby_text = "Dedicated queue: %d confirmed fighter%s waiting." % [waiting, "" if waiting == 1 else "s"]
		connection_changed.emit("player_queued")
	return result


func server_session(session_id: String) -> Dictionary:
	if _class_queue == null:
		return {}
	return _class_queue.session(session_id)


func reset_match(config: Dictionary = {}) -> Dictionary:
	if mode == Mode.CLIENT:
		return last_view_result()
	if mode == Mode.HOTSEAT:
		var local_sim := sim()
		if local_sim == null:
			return _fail("no_sim")
		return local_sim.reset_match(config)
	if mode == Mode.DEDICATED:
		config = _with_match_classes(config)
	var fixture := bool(config.get("fixture", false)) or bool(config.get("skip_deploy", false)) or config.has("rolls")
	var gate: Dictionary = HostValidate.validate_match_config(config, fixture)
	if not bool(gate.get("ok", false)):
		return _gate_reject(str(gate.get("reason", "client_must_not_roll")))
	var host_sim := sim()
	if host_sim == null:
		return _fail("no_sim")
	var snap: Dictionary = host_sim.reset_match(config)
	if mode == Mode.DEDICATED:
		var spawned: Variant = snap.get("match_config", {}).get("classes", [])
		if spawned is Array:
			_match_class_ids = (spawned as Array).duplicate()
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
	if mode == Mode.DEDICATED:
		return _fail("not_a_player")
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
	# local_seat = this window. active_seat = whose turn it is (CombatSim).
	# Godot kit chrome reads local_seat. Do not encode "show active kit".
	out["local_seat"] = local_seat
	out["active_seat"] = active_seat
	out["net_active"] = is_online()
	out["net"] = {
		"transport": TRANSPORT,
		"mode": mode_name(),
		"listen_host": mode == Mode.HOST,
		"local_seat": local_seat,
		"class_id": selected_class_id,
		"active_seat": active_seat,
		"guest_connected": guest_peer_id != 0,
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
	if mode != Mode.HOST and mode != Mode.DEDICATED:
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
	return IntentCodec.encode({
		"ok": bool(result.get("ok", false)),
		"illegal": bool(result.get("illegal", false)),
		"reason": str(result.get("reason", "")),
		"events": result.get("events", []),
		"snapshot": decorate_snapshot(snap),
		"legal_intents": {0: legal0, 1: legal1},
		"legal_deploy_cells": {0: deploy0, 1: deploy1},
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
	if mode != Mode.HOST and mode != Mode.DEDICATED:
		return
	var sender := multiplayer.get_remote_sender_id()
	var seat := _seat_for_peer(sender)
	var intent := IntentCodec.decode_intent(encoded)
	_authoritative_submit(intent, seat)


@rpc("any_peer", "reliable")
func rpc_select_class(class_id: String) -> void:
	if mode != Mode.DEDICATED:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = server_select_class(str(peer), class_id)
	if _rpc_live():
		rpc_class_result.rpc_id(peer, result)


@rpc("authority", "reliable")
func rpc_class_result(result: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	if bool(result.get("ok", false)):
		selected_class_id = str(result.get("class_id", selected_class_id))
		lobby_text = "Class confirmed: %s." % SpellKits.display_name(selected_class_id)
		connection_changed.emit("class_selected")
	else:
		lobby_text = "Class rejected (%s)." % str(result.get("reason", "invalid_class"))
		connection_changed.emit("class_rejected")


@rpc("any_peer", "reliable")
func rpc_enqueue() -> void:
	if mode != Mode.DEDICATED:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = server_enqueue(str(peer))
	if bool(result.get("matched", false)):
		return
	if _rpc_live():
		rpc_queue_result.rpc_id(peer, {
			"ok": bool(result.get("ok", false)),
			"reason": str(result.get("reason", "")),
			"queued": bool(result.get("queued", false)),
		})


@rpc("authority", "reliable")
func rpc_queue_result(result: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	if bool(result.get("ok", false)) and bool(result.get("queued", false)):
		lobby_text = "In queue as %s. Waiting for an opponent." % SpellKits.display_name(selected_class_id)
		connection_changed.emit("queued")
	else:
		lobby_text = "Queue rejected (%s)." % str(result.get("reason", "class_required"))
		connection_changed.emit("queue_rejected")


@rpc("authority", "reliable")
func rpc_match_assigned(payload: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	local_seat = int(payload.get("seat", -1))
	selected_class_id = str(payload.get("class_id", selected_class_id))
	match_id = str(payload.get("match_id", ""))
	matched = true
	var packed: Variant = payload.get("packed", {})
	if typeof(packed) == TYPE_DICTIONARY and not (packed as Dictionary).is_empty():
		apply_packed_state(packed)
	lobby_text = "Matched as %s (seat %d)." % [SpellKits.display_name(selected_class_id), local_seat]
	connection_changed.emit("matched")
	_update_window_title()


@rpc("authority", "reliable")
func rpc_push_state(packed: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	apply_packed_state(packed)


func _authoritative_submit(intent: Dictionary, seat: int) -> Dictionary:
	if seat not in [0, 1]:
		return _cache_and_broadcast(_gate_reject("not_in_match"))
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
	if mode == Mode.HOST and guest_peer_id != 0 and multiplayer.multiplayer_peer != null:
		rpc_push_state.rpc_id(guest_peer_id, pack_result(result, GUEST_SEAT))
	elif mode == Mode.DEDICATED and is_inside_tree() and multiplayer.multiplayer_peer != null:
		for session_id in _peer_seats.keys():
			if not str(session_id).is_valid_int():
				continue
			var peer_id := int(session_id)
			if peer_id <= 0:
				continue
			var seat := int(_peer_seats[session_id])
			rpc_push_state.rpc_id(peer_id, pack_result(result, seat))
	return last_view_result()


func _seat_for_peer(peer_id: int) -> int:
	if mode == Mode.DEDICATED:
		return int(_peer_seats.get(str(peer_id), -1))
	if peer_id == 1 or peer_id == 0:
		return HOST_SEAT
	return GUEST_SEAT


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
	if mode == Mode.DEDICATED:
		lobby_text = "Player %d connected. Waiting for SELECT_CLASS, then the queue." % id
		connection_changed.emit("player_connected")
		return
	if mode != Mode.HOST:
		return
	if guest_peer_id != 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	guest_peer_id = id
	connection_changed.emit("guest_joined")
	if last_packed.is_empty() and sim() != null:
		last_packed = pack_result({
			"ok": true,
			"illegal": false,
			"reason": "",
			"events": sim().snapshot().get("last_events", []),
			"snapshot": sim().snapshot(),
		})
	if sim() != null:
		rpc_push_state.rpc_id(id, pack_result({
			"ok": true,
			"illegal": false,
			"reason": "",
			"events": last_events if not last_events.is_empty() else sim().snapshot().get("last_events", []),
			"snapshot": sim().snapshot(),
		}, GUEST_SEAT))
	elif not last_packed.is_empty():
		rpc_push_state.rpc_id(id, last_packed)


func _on_peer_disconnected(id: int) -> void:
	if mode == Mode.DEDICATED:
		if _class_queue != null:
			_class_queue.drop(str(id))
		_peer_seats.erase(str(id))
		connection_changed.emit("player_left")
		return
	if mode == Mode.HOST and id == guest_peer_id:
		guest_peer_id = 0
		connection_changed.emit("guest_left")


func _on_connected_to_server() -> void:
	if mode == Mode.CLIENT:
		connection_changed.emit("joined")
		if _queue_client and SpellKits.is_roster_class(selected_class_id):
			rpc_select_class.rpc_id(1, selected_class_id)
			rpc_enqueue.rpc_id(1)
		_update_window_title()


func _on_connection_failed() -> void:
	connection_changed.emit("join_failed")


func _on_server_disconnected() -> void:
	connection_changed.emit("host_left")


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func _parse_user_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg == "--host":
			_cli_host = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				listen_port = int(args[i])
		elif arg == "--join":
			_cli_join = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				var spec := str(args[i])
				if spec.contains(":"):
					var parts := spec.split(":")
					join_address = parts[0]
					listen_port = int(parts[1])
				else:
					join_address = spec
		elif arg == "--dedicated":
			_cli_dedicated = true
			_cli_host = false
			_cli_join = false
			_cli_queue = false
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				listen_port = int(args[i])
		elif arg == "--queue":
			_cli_queue = true
			_cli_host = false
			_cli_join = false
			_cli_dedicated = false
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				var spec := str(args[i])
				if spec.contains(":"):
					var parts := spec.split(":")
					join_address = parts[0]
					listen_port = int(parts[1])
				else:
					join_address = spec
		elif arg == "--class":
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				_cli_class = str(args[i])
		elif arg == "--hotseat":
			_cli_host = false
			_cli_join = false
			_cli_dedicated = false
			_cli_queue = false
		i += 1


func _update_window_title() -> void:
	if not is_inside_tree():
		return
	var win := get_window()
	if win == null:
		return
	match mode:
		Mode.HOST:
			win.title = "STASIUM XII — HOST (Kestrel / seat 0)"
		Mode.CLIENT:
			if _queue_client and not matched:
				win.title = "STASIUM XII — QUEUE (%s)" % SpellKits.display_name(selected_class_id)
			elif matched:
				win.title = "STASIUM XII — SEAT %d (%s)" % [local_seat, SpellKits.display_name(selected_class_id)]
			else:
				win.title = "STASIUM XII — GUEST (Ironjaw / seat 1)"
		Mode.DEDICATED:
			win.title = "STASIUM XII — DEDICATED"
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


func _open_dedicated_match(match: Dictionary) -> Dictionary:
	var class_ids: Array = match.get("class_ids", [])
	_match_class_ids = class_ids.duplicate()
	match_id = str(match.get("id", ""))
	matched = true
	_peer_seats = {}
	for seat_info in match.get("seats", []):
		if typeof(seat_info) != TYPE_DICTIONARY:
			continue
		var session_id := str(seat_info.get("session_id", ""))
		_peer_seats[session_id] = int(seat_info.get("seat", -1))
	# Snapshot first, then tell each player their seat with that state packed in.
	var opened: Dictionary = reset_match({"classes": _match_class_ids.duplicate()})
	_notify_match_seats(match)
	var name_0 := ""
	var name_1 := ""
	if _match_class_ids.size() > 0:
		name_0 = SpellKits.display_name(str(_match_class_ids[0]))
	if _match_class_ids.size() > 1:
		name_1 = SpellKits.display_name(str(_match_class_ids[1]))
	lobby_text = "Match %s — seat 0 %s, seat 1 %s." % [match_id, name_0, name_1]
	connection_changed.emit("match_started")
	var out: Dictionary = match.duplicate(true)
	out["ok"] = bool(opened.get("ok", false))
	return out


func _notify_match_seats(match: Dictionary) -> void:
	if not _rpc_live():
		return
	for seat_info in match.get("seats", []):
		if typeof(seat_info) != TYPE_DICTIONARY:
			continue
		var session_id := str(seat_info.get("session_id", ""))
		if not session_id.is_valid_int():
			continue
		var peer_id := int(session_id)
		if peer_id <= 0:
			continue
		var seat := int(seat_info.get("seat", -1))
		rpc_match_assigned.rpc_id(peer_id, {
			"seat": seat,
			"class_id": str(seat_info.get("class_id", "")),
			"match_id": str(match.get("id", "")),
			"packed": pack_result(last_result, seat),
		})


func _with_match_classes(config: Dictionary) -> Dictionary:
	var out: Dictionary = config.duplicate(true)
	if not out.has("classes") and not out.has("seat_classes") and not _match_class_ids.is_empty():
		out["classes"] = _match_class_ids.duplicate()
	return out


func _clear_queue_state() -> void:
	_queue_client = false
	selected_class_id = ""
	matched = false
	match_id = ""
	lobby_text = ""
	_class_queue = null
	_peer_seats = {}
	_match_class_ids = []


func _client_link_up() -> bool:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _rpc_live() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null


func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": [],
		"snapshot": last_snapshot,
	}
