extends Node

## Listen-host proto. Host owns CombatSim + seed/RNG. Clients submit Intent.
## Transport: Godot 4 MultiplayerAPI + ENet (direct IP). RPC only; no scene sync.
## Local hot-seat stays the default (mode HOTSEAT → CombatSim.submit directly).
## Listen-host only — no dedicated process.

enum Mode { HOTSEAT, HOST, CLIENT }

const DEFAULT_PORT := 7777
const HOST_SEAT := 0
const GUEST_SEAT := 1
const TRANSPORT := "enet"

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
var _signals_wired: bool = false


func _ready() -> void:
	_parse_user_args()
	if _cli_host:
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
	return mode == Mode.HOST or mode == Mode.CLIENT


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func is_hotseat() -> bool:
	return mode == Mode.HOTSEAT


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


func reset_match(config: Dictionary = {}) -> Dictionary:
	if mode == Mode.CLIENT:
		return last_view_result()
	if mode == Mode.HOTSEAT:
		var local_sim := sim()
		if local_sim == null:
			return _fail("no_sim")
		return local_sim.reset_match(config)
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
	out["local_seat"] = local_seat
	out["net_active"] = is_online()
	out["net"] = {
		"transport": TRANSPORT,
		"mode": mode_name(),
		"listen_host": true,
		"local_seat": local_seat,
		"guest_connected": guest_peer_id != 0,
		"port": listen_port,
	}
	return out


func mode_name() -> String:
	match mode:
		Mode.HOST:
			return "host"
		Mode.CLIENT:
			return "client"
		_:
			return "hotseat"


func pack_result(result: Dictionary) -> Dictionary:
	var host_sim := sim()
	var snap: Dictionary = result.get("snapshot", {})
	if snap.is_empty() and host_sim != null:
		snap = host_sim.snapshot()
	var legal0: Array = []
	var legal1: Array = []
	var deploy0: Array[Vector2i] = []
	var deploy1: Array[Vector2i] = []
	if host_sim != null:
		legal0 = host_sim.legal_intents(0)
		legal1 = host_sim.legal_intents(1)
		deploy0 = host_sim.legal_deploy_cells(0)
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
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	var seat := _seat_for_peer(sender)
	var intent := IntentCodec.decode_intent(encoded)
	_authoritative_submit(intent, seat)


@rpc("authority", "reliable")
func rpc_push_state(packed: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	apply_packed_state(packed)


func _authoritative_submit(intent: Dictionary, seat: int) -> Dictionary:
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
		rpc_push_state.rpc_id(guest_peer_id, packed)
	return last_view_result()


func _seat_for_peer(peer_id: int) -> int:
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
	if not last_packed.is_empty():
		rpc_push_state.rpc_id(id, last_packed)


func _on_peer_disconnected(id: int) -> void:
	if mode == Mode.HOST and id == guest_peer_id:
		guest_peer_id = 0
		connection_changed.emit("guest_left")


func _on_connected_to_server() -> void:
	if mode == Mode.CLIENT:
		connection_changed.emit("joined")
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
		elif arg == "--hotseat":
			_cli_host = false
			_cli_join = false
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
			win.title = "STASIUM XII — GUEST (Ironjaw / seat 1)"
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


func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": [],
		"snapshot": last_snapshot,
	}
