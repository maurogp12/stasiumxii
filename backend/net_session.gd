extends Node

## Host core shared by listen-host (--host) and the dedicated process (--dedicated).
## Authority owns CombatSim: match, turn, 30s timer, HP/MP, Marks, Impact, Burn,
## terrain, elevation, pushes, and death. Clients send Intent and apply
## snapshot/events. Clients never roll, never tick the clock, never mutate sim.
## Transport: Godot 4 MultiplayerAPI + ENet (direct IP). RPC only; no scene sync.
## Another machine is a different --join address on this same host core.
## Hot-seat is the default (mode HOTSEAT → CombatSim.submit directly).
## Dedicated: a seat stays reserved only while that match is being played.
## A drop before the match, or after it ends, frees the seat. No mid-fight reconnect.

enum Mode { HOTSEAT, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 7777
## Public game server. Play Online tries the last working address, then this
## host, then Tailscale, then LAN (ServerDial). CLI --join / --queue stay direct.
const DEFAULT_SERVER := "68.201.184.207"
const HOST_SEAT := 0
const GUEST_SEAT := 1
const LISTEN_HOST_CLIENTS := 1
const DEDICATED_CLIENTS := 2
const TRANSPORT := "enet"
const _MatchQueueScript := preload("res://backend/matchmaking.gd")
const _ServerDial := preload("res://backend/server_dial.gd")

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
var join_address: String = DEFAULT_SERVER

var _sim: Node = null
var _cli_host: bool = false
var _cli_join: bool = false
var _cli_dedicated: bool = false
var _signals_wired: bool = false
## peer id per seat. 0 means no live peer. Server peer id is 1 and is never stored.
var _seat_peer: Array[int] = [0, 0]
## True once a seat has been given out. Dedicated keeps this only while the match is live.
var _seat_held: Array[bool] = [false, false]
## SELECT_CLASS on the dedicated queue. Listen-host ignores this and stays fixed.
var selected_class_id: String = ""
## 1v1 is one class. 3v3 is three different classes on the separate queue.
var queue_format: String = "1v1"
var selected_class_ids: Array[String] = []
var lobby_text: String = ""
var _queue_client: bool = false
## Play Online walks ServerDial.address_order. One probe at a time.
var _dial_order: Array[String] = []
var _dial_index: int = 0
var _dial_active: bool = false
var _dial_attempt: int = 0
var _dial_live_attempt: int = -1
var _dial_port: int = DEFAULT_PORT
## True while a peer is being closed so its failure cannot advance the chain.
var _dial_suppress: bool = false
var _match_queue: MatchQueue
var _match_class_ids: Array[String] = []
var _match_team_size: int = 1
## Fighter seats this connection plays. Empty means "only local_seat" (1v1, listen-host).
var _owned_seats: Array[int] = []
var _cli_class: String = ""
var _cli_classes: Array = []
var _cli_queue: bool = false
var _local_queued: bool = false
var _opponent_queued: bool = false
var _match_live: bool = false
## Set when a dedicated match reaches match_over. The peers stay up for the result.
var _match_finished: bool = false
## Client is leaving after a finished match, so the close is not "server disconnected".
var _quiet_leave: bool = false
var _prematch_phase: String = "MATCH"
## Koliseo payout (Blueprint §9/§15). One payout per finished match.
var _koliseo_result_noted: bool = false
var koliseo_last_payout: Dictionary = {}
## Worn gear per seat on the authority (Mauro 29 Sep 2026: gear counts in
## Koliseo). Each peer sends its own; the host adds its own seat 0.
var _seat_gear: Dictionary = {}
var _gear_sent_seat: int = -1


func _ready() -> void:
	_parse_user_args()
	if _cli_classes.size() == 2 or _cli_classes.size() == 3:
		select_roster(_cli_classes)
	elif _cli_class != "":
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
	if not _owned_seats.is_empty():
		return _owned_seats.has(seat)
	return seat == local_seat


## Seats this phone may place, ready, and act with. 1v1 is just local_seat.
func owned_seats() -> Array[int]:
	if not _owned_seats.is_empty():
		return _owned_seats.duplicate()
	if local_seat >= 0:
		return [local_seat]
	return []


func match_team_size() -> int:
	return _match_team_size


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
	_dial_active = false
	_dial_live_attempt = -1
	_cancel_hub_return()
	_client_in_match = false
	_queue_client = false
	_local_queued = false
	_opponent_queued = false
	_match_live = false
	_close_peer()
	mode = Mode.HOTSEAT
	local_seat = -1
	_owned_seats.clear()
	_gear_sent_seat = -1
	_match_team_size = 1
	guest_peer_id = 0
	last_snapshot = {}
	last_events = []
	last_result = {}
	last_packed = {}
	connection_changed.emit("hotseat")
	_update_window_title()


## The fight already ended. Closing the socket must not surface as a drop.
func note_match_finished() -> void:
	_quiet_leave = true


## Online client: close the socket, then the caller opens the hub.
func leave_after_match() -> void:
	_quiet_leave = true
	return_to_hotseat()


const HUB_SCENE := "res://scenes/mobile_hub.tscn"
## Fallback if the result window never arms its own 4s read. The window restarts this.
const HUB_FALLBACK_SEC := 5.0
var _client_in_match: bool = false
var _hub_return_pending: bool = false
var _hub_return_token: int = 0
var _hub_gone: bool = false


func is_hub_return_pending() -> bool:
	return _hub_return_pending


## True only after rpc_match_assigned for this connection. A later match_over
## from a previous fight (the server used to push that to the next peer) is ignored.
func client_in_match() -> bool:
	return _client_in_match


func _cancel_hub_return() -> void:
	_hub_return_token += 1
	_hub_return_pending = false


func _auto_hub_allowed() -> bool:
	if not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	if scene != null and str(scene.scene_file_path).ends_with("main.tscn"):
		return true
	return OS.get_cmdline_user_args().has("--rematch")


## Start (or restart) the post-match return. The scene change is deferred on
## this autoload so it still runs if the board node is already going away.
func arm_hub_return(after_sec: float = HUB_FALLBACK_SEC) -> void:
	if mode != Mode.CLIENT or not _client_in_match or _hub_gone:
		return
	if not _auto_hub_allowed():
		return
	_hub_return_token += 1
	var token := _hub_return_token
	_hub_return_pending = true
	note_match_finished()
	var timer := get_tree().create_timer(maxf(after_sec, 0.1), true, true)
	timer.timeout.connect(_on_hub_return_timer.bind(token), CONNECT_ONE_SHOT)


func _on_hub_return_timer(token: int) -> void:
	if token != _hub_return_token or not _hub_return_pending:
		return
	return_to_hub_now()


## CLOSE, Back, and Hub. Closes and nulls the peer, then opens the hub.
func return_to_hub_now() -> void:
	if _hub_gone:
		return
	_hub_gone = true
	_hub_return_pending = false
	_hub_return_token += 1
	_client_in_match = false
	if is_inside_tree():
		MobileHub.stay_on_hub = true
		get_tree().call_deferred("change_scene_to_file", HUB_SCENE)
	leave_after_match()


func start_host(port: int = DEFAULT_PORT) -> Dictionary:
	return _open_server(port, LISTEN_HOST_CLIENTS, Mode.HOST, HOST_SEAT, "host_listening")


func start_dedicated(port: int = DEFAULT_PORT) -> Dictionary:
	var opened := _open_server(port, DEDICATED_CLIENTS, Mode.DEDICATED, -1, "dedicated_listening")
	if bool(opened.get("ok", false)):
		_match_live = false
		_match_finished = false
		_match_class_ids = []
		_match_team_size = 1
		_prematch_phase = "SELECT_CLASS"
		lobby_text = "Dedicated queue listening on UDP %d. Pick a Locked class, then join." % port
		print("STASIUM server: listening port=%d" % port)
	else:
		print("STASIUM server: error bind_failed port=%d" % port)
	return opened


func start_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	# Drop the previous socket before opening another. A Queue after a match
	# must not reuse the finished ENet peer.
	_quiet_leave = false
	_hub_gone = false
	_client_in_match = false
	_match_live = false
	_local_queued = false
	_opponent_queued = false
	_owned_seats.clear()
	_gear_sent_seat = -1
	_match_team_size = 1
	_cancel_hub_return()
	_close_peer()
	last_snapshot = {}
	last_events = []
	last_result = {}
	last_packed = {}
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		if not _dial_active:
			connection_changed.emit("join_failed")
		return {"ok": false, "reason": "connect_failed", "address": address, "port": port}
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


func is_auto_dialing() -> bool:
	return _dial_active


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
	selected_class_ids = [normalized]
	queue_format = "1v1"
	if not _match_live:
		_prematch_phase = "SELECT_CLASS"
	if _queue_client and mode == Mode.CLIENT and _rpc_ready():
		rpc_select_class.rpc_id(1, normalized)
	return {"ok": true, "illegal": false, "reason": "", "class_id": normalized}


## Local confirm of two or three different Locked classes before the 2v2 or 3v3 queue.
## A duplicate or a class outside the roster does not clear a stored pick.
func select_roster(class_ids: Array) -> Dictionary:
	var normalized: Array[String] = []
	for raw in class_ids:
		var class_id := SpellKits.normalize_class_id(str(raw))
		if not SpellKits.is_roster_class(class_id):
			return {
				"ok": false,
				"illegal": true,
				"reason": "invalid_class",
				"class_id": selected_class_id,
			}
		if normalized.has(class_id):
			return {
				"ok": false,
				"illegal": true,
				"reason": "duplicate_class",
				"class_id": selected_class_id,
			}
		normalized.append(class_id)
	if normalized.size() != 2 and normalized.size() != 3:
		return {
			"ok": false,
			"illegal": true,
			"reason": "class_required",
			"class_id": selected_class_id,
		}
	queue_format = "2v2" if normalized.size() == 2 else "3v3"
	selected_class_ids = normalized
	selected_class_id = normalized[0]
	if not _match_live:
		_prematch_phase = "SELECT_CLASS"
	if _queue_client and mode == Mode.CLIENT and _rpc_ready():
		rpc_select_roster.rpc_id(1, normalized)
	return {"ok": true, "illegal": false, "reason": "", "class_id": normalized[0], "class_ids": normalized.duplicate()}


## Online menu switches 1v1 / 2v2 / 3v3. Clears the pick so one format cannot enter another queue.
func set_queue_format(format: String) -> void:
	if format == "2v2" or format == "3v3":
		queue_format = format
	else:
		queue_format = "1v1"
	selected_class_id = ""
	selected_class_ids = []


func _queue_roster_ready() -> bool:
	if queue_format == "2v2":
		return selected_class_ids.size() == 2
	if queue_format == "3v3":
		return selected_class_ids.size() == 3
	return SpellKits.is_roster_class(selected_class_id)


func start_queue_client(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	if not _queue_roster_ready():
		return {"ok": false, "illegal": true, "reason": "class_required", "class_id": selected_class_id}
	_queue_client = true
	var opened: Dictionary = start_client(address, port)
	if not bool(opened.get("ok", false)):
		_queue_client = false
		return opened
	return opened


## Play Online. override_address replaces the remembered head when non-empty
## (the hidden Advanced field). Empty uses the saved address, then the chain.
## Does not add an RPC. Each hop is still start_queue_client.
func begin_auto_queue(override_address: String = "", override_port: int = -1) -> Dictionary:
	if not _queue_roster_ready():
		return {"ok": false, "illegal": true, "reason": "class_required", "class_id": selected_class_id}
	var head := override_address.strip_edges()
	if head == "":
		head = _ServerDial.remembered()
	_dial_order = _ServerDial.address_order(head)
	_dial_index = 0
	_dial_port = override_port if override_port > 0 else DEFAULT_PORT
	_dial_active = true
	_dial_live_attempt = -1
	_close_peer()
	return _dial_open_current()


func _dial_open_current() -> Dictionary:
	if _dial_index < 0 or _dial_index >= _dial_order.size():
		_dial_active = false
		_dial_live_attempt = -1
		_queue_client = false
		connection_changed.emit("join_failed")
		return {"ok": false, "reason": "unreachable", "address": "", "port": _dial_port}
	_dial_attempt += 1
	var attempt := _dial_attempt
	_dial_live_attempt = attempt
	var address := _dial_order[_dial_index]
	var opened: Dictionary = start_queue_client(address, _dial_port)
	if not bool(opened.get("ok", false)):
		return _dial_advance()
	if is_inside_tree():
		var timer := get_tree().create_timer(_ServerDial.PROBE_SEC, true, true)
		timer.timeout.connect(_on_dial_timeout.bind(attempt), CONNECT_ONE_SHOT)
	return opened


func _dial_advance() -> Dictionary:
	_dial_live_attempt = -1
	_close_peer()
	_dial_index += 1
	if _dial_index >= _dial_order.size():
		_dial_active = false
		_queue_client = false
		connection_changed.emit("join_failed")
		return {"ok": false, "reason": "unreachable", "address": "", "port": _dial_port}
	connection_changed.emit("connecting")
	return _dial_open_current()


func _dial_fail_attempt(attempt: int) -> void:
	if not _dial_active or attempt != _dial_live_attempt:
		return
	_dial_advance()


func _on_dial_timeout(attempt: int) -> void:
	if not _dial_active or attempt != _dial_live_attempt:
		return
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_dial_advance()


func server_select_class(session_id: String, class_id: String) -> Dictionary:
	return _queue().select_class(session_id, class_id)


func server_select_roster(session_id: String, class_ids: Array) -> Dictionary:
	return _queue().select_roster(session_id, class_ids)


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
	config = _authority_gear_config(config)
	if mode == Mode.DEDICATED:
		var chosen: Array[String] = _class_ids_from_config(config)
		if chosen.size() == 2 or chosen.size() == 4 or chosen.size() == 6:
			_match_class_ids = chosen
			_match_team_size = int(chosen.size() / 2)
			_match_live = true
			_match_finished = false
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


func aim_feel(seat: int, spell_id: String, hover: Variant = null) -> Dictionary:
	var local_sim := sim()
	if local_sim == null or not local_sim.has_method("aim_feel"):
		return {}
	return local_sim.aim_feel(seat, spell_id, hover)


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
## A quiet tick (same displayed second, no expiry) does not build a snapshot.
func tick_turn_timer(delta: float) -> Dictionary:
	if mode == Mode.CLIENT:
		return last_view_result()
	var host_sim := sim()
	if host_sim == null or not host_sim.has_method("tick_turn_timer"):
		return _fail("no_sim")
	var before := _clock_marker(host_sim)
	var result: Dictionary = host_sim.tick_turn_timer(delta)
	if not is_authority():
		return result
	var expired := bool(result.get("expired", false))
	var after := _clock_marker(host_sim)
	if expired or before != after:
		var snap: Dictionary = result.get("snapshot", {})
		if snap.is_empty():
			result["snapshot"] = host_sim.snapshot()
			result["ok"] = true
			result["illegal"] = false
			result["reason"] = ""
			if not result.has("events"):
				result["events"] = []
		var view: Dictionary = _cache_and_broadcast(result)
		view["expired"] = expired
		return view
	result["expired"] = expired
	return result


func _clock_marker(host_sim: Node) -> Dictionary:
	if host_sim != null and host_sim.has_method("clock_marker"):
		return host_sim.clock_marker()
	return _clock_wire(host_sim.snapshot())


## The headless authority never loads the board, so nothing else ticks the
## clocks there. Only that process ticks here, and only while a match is live.
## A listen-host board and a hot-seat already tick, and a phone must not tick
## a second time. Idle (no match) returns before any snapshot work.
func _process(delta: float) -> void:
	if not is_dedicated():
		return
	if not _match_live:
		return
	tick_turn_timer(delta)


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
	var team_size := 1
	if host_sim != null and host_sim.has_method("team_size"):
		team_size = int(host_sim.team_size())
	elif not snap.is_empty():
		team_size = int(snap.get("team_size", 1))
	var fighter_count := 2 if team_size <= 1 else team_size * 2
	var visible := _packed_fighter_seats(viewer_seat, team_size)
	var legal := {}
	var deploy := {}
	for seat in fighter_count:
		legal[seat] = []
		deploy[seat] = []
	if host_sim != null:
		for seat in visible:
			var intents: Array = host_sim.legal_intents(seat)
			if viewer_seat == HOST_SEAT or viewer_seat == GUEST_SEAT:
				intents = _redact_hidden_intent_cells(intents, hidden_cells)
			legal[seat] = intents
			deploy[seat] = host_sim.legal_deploy_cells(seat)
	return IntentCodec.encode({
		"ok": bool(result.get("ok", false)),
		"illegal": bool(result.get("illegal", false)),
		"reason": str(result.get("reason", "")),
		"events": events,
		"snapshot": decorate_snapshot(snap),
		"legal_intents": legal,
		"legal_deploy_cells": deploy,
		"viewer_seat": viewer_seat,
	}) as Dictionary


## Authority cache (viewer < 0) includes every fighter. A phone includes the
## seats that connection plays: 1v1 is that seat, 3v3 is seat, seat+2, seat+4.
func _packed_fighter_seats(viewer_seat: int, team_size: int) -> Array[int]:
	var count := 1 if team_size <= 1 else team_size
	var out: Array[int] = []
	if viewer_seat < 0:
		for seat in count * 2:
			out.append(seat)
		return out
	if viewer_seat != HOST_SEAT and viewer_seat != GUEST_SEAT:
		return out
	for i in count:
		out.append(viewer_seat + i * 2)
	return out


## Per-viewer wire copy. Does not mutate CombatSim.
## viewer_seat < 0 (hot-seat, listen-host local cache) stays full-fidelity.
## For seat 0 or 1, a unit with invisible=true and a different seat loses its tile:
## pos is null, pos_hidden is true, x/y are omitted. Event fields that name that
## unit's tile (current or the cell it just left) become null; path and cone are
## omitted. range and hit_chance become null when the event locates that unit.
## Coach text replaces those coordinates with (?,?). Wall / plant tokens stay,
## including their cells; Shades are the owner's only (_redact_shades_for_viewer). legal_intents omit `to` when it was the hidden tile.
func _redact_invisible_for_viewer(snap: Dictionary, events: Array, viewer_seat: int) -> Dictionary:
	var out_snap: Dictionary = snap.duplicate(true) if not snap.is_empty() else {}
	var out_events: Array = events.duplicate(true)
	var hidden_cells: Array = []
	if viewer_seat != HOST_SEAT and viewer_seat != GUEST_SEAT:
		return {"snapshot": out_snap, "events": out_events, "hidden_cells": hidden_cells}
	_redact_shades_for_viewer(out_snap, out_events, viewer_seat)
	_redact_traps_for_viewer(out_snap, out_events, viewer_seat)
	var hidden_seats := {}
	var secret: Array = []
	for unit in out_snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = unit
		if not bool(rec.get("invisible", false)):
			continue
		var seat := int(rec.get("seat", -1))
		if _viewer_shares_fighter(out_snap, seat, viewer_seat):
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
	var logged: Variant = out_snap.get("battle_log", [])
	if logged is Array:
		_redact_events(logged, hidden_seats, hidden_cells, secret)
	if out_snap.has("coach"):
		out_snap["coach"] = _scrub_coach(str(out_snap.get("coach", "")), secret)
	return {"snapshot": out_snap, "events": out_events, "hidden_cells": hidden_cells}


## Shades are secret to their owner (Mauro 29 Sep 2026): the opponent's
## view loses the other seat's Shade tokens, the Drop Shade target cell and
## the cell of a Shade expiring. An Ambush still reveals where its caster lands.
func _redact_shades_for_viewer(out_snap: Dictionary, out_events: Array, viewer_seat: int) -> void:
	var kept: Array = []
	for token in out_snap.get("shade_tokens", []):
		if typeof(token) == TYPE_DICTIONARY and not _viewer_shares_fighter(out_snap, int(token.get("owner_seat", -1)), viewer_seat):
			continue
		kept.append(token)
	if out_snap.has("shade_tokens"):
		out_snap["shade_tokens"] = kept
	var lists: Array = [out_events]
	if out_snap.get("last_events", null) is Array:
		lists.append(out_snap["last_events"])
	if out_snap.get("battle_log", null) is Array:
		lists.append(out_snap["battle_log"])
	for list in lists:
		for event in list:
			if typeof(event) != TYPE_DICTIONARY:
				continue
			if str(event.get("spell", "")) == SpellKits.DROP_SHADE and not _viewer_shares_fighter(out_snap, int(event.get("seat", -1)), viewer_seat):
				event.erase("to")
			if str(event.get("type", "")) == "expire" and str(event.get("status", "")) == "shade" and not _viewer_shares_fighter(out_snap, int(event.get("owner_seat", -1)), viewer_seat):
				event.erase("pos")


## Snare Traps are secret to the side that set them. The other side loses the
## token and the cast cell. A sprung trap (type "trap") stays, so the fighter
## who walked into it can see where they stopped.
func _redact_traps_for_viewer(out_snap: Dictionary, out_events: Array, viewer_seat: int) -> void:
	var kept: Array = []
	for token in out_snap.get("trap_tiles", []):
		if typeof(token) != TYPE_DICTIONARY:
			continue
		if _trap_hidden_from(out_snap, int(token.get("owner_seat", -1)), viewer_seat):
			continue
		kept.append(token)
	if out_snap.has("trap_tiles"):
		out_snap["trap_tiles"] = kept
	var lists: Array = [out_events]
	if out_snap.get("last_events", null) is Array:
		lists.append(out_snap["last_events"])
	if out_snap.get("battle_log", null) is Array:
		lists.append(out_snap["battle_log"])
	for list in lists:
		for event in list:
			if typeof(event) != TYPE_DICTIONARY:
				continue
			if str(event.get("type", "")) == "trap":
				continue
			if str(event.get("spell", "")) != SpellKits.SNARE_TRAP:
				continue
			if _trap_hidden_from(out_snap, int(event.get("seat", -1)), viewer_seat):
				event.erase("to")


func _trap_hidden_from(snap: Dictionary, owner_seat: int, viewer_seat: int) -> bool:
	if owner_seat < 0:
		return true
	return not _viewer_shares_fighter(snap, owner_seat, viewer_seat)


## 1v1: only the viewer's own seat. 3v3: every fighter on that player's team,
## so the phone that controls all three can see its own hidden fighter and Shades.
func _viewer_shares_fighter(snap: Dictionary, owner_seat: int, viewer_seat: int) -> bool:
	if int(snap.get("team_size", 1)) <= 1:
		return owner_seat == viewer_seat
	return _seat_team(snap, owner_seat) == _seat_team(snap, viewer_seat)


func _seat_team(snap: Dictionary, seat: int) -> int:
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) == seat:
			return int(unit.get("team", seat))
	return seat


## While the fighter is invisible, the opponent's copy loses the step cost,
## facing, and terrain. A reveal puts the stopped tile back on the wire.
func _strip_hidden_motion(event: Dictionary) -> void:
	var kind := str(event.get("type", ""))
	for key in ["dir", "facing", "facing_from", "facing_hops"]:
		event.erase(key)
	if kind in ["move", "advance"]:
		event.erase("mp_spent")
		event.erase("trap_mp")
		event.erase("coach")
	if kind == "face":
		event.erase("from")
		event.erase("coach")
	if kind in ["face", "trap", "push_bounce", "push_blocked", "lava_land"]:
		event.erase("coach")
		event.erase("reason")
	if kind in ["hit", "trap", "lava_land", "blend", "push_bounce", "move", "advance"]:
		event.erase("slow_applied")
		event.erase("burn_applied")
		event.erase("silence_applied")


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
		_strip_hidden_motion(event)
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
		_strip_hidden_motion(event)
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
		# A blind attack (Mauro 30 Sep 2026: punches in the air) is offered on
		# every open tile in reach, so the hidden tile is one of many identical
		# offers and keeps its `to`: stripping it would single the tile out.
		if bool(intent.get("blind", false)):
			out.append(intent)
			continue
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
	if mode == Mode.CLIENT:
		var filtered := _filter_client_snapshot(last_snapshot, last_events)
		last_snapshot = filtered["snapshot"]
		last_events = filtered["events"]
		last_result["snapshot"] = last_snapshot
		last_result["events"] = last_events
		if bool(filtered.get("finished", false)):
			arm_hub_return(HUB_FALLBACK_SEC)
	last_legal = _packed_seat_map(decoded.get("legal_intents", {}))
	last_legal_deploy = _packed_seat_map(decoded.get("legal_deploy_cells", {}))
	if mode == Mode.CLIENT:
		var viewer := int(decoded.get("viewer_seat", -1))
		if viewer >= 0 and viewer != local_seat:
			local_seat = viewer
			_send_local_gear()
			if is_inside_tree():
				print("STASIUM XII client assigned seat %d" % local_seat)
			_update_window_title()
	if hydrate and mode == Mode.CLIENT:
		var view := sim()
		if view != null and view.has_method("apply_host_snapshot"):
			view.apply_host_snapshot(last_snapshot)
	_note_koliseo_result(last_snapshot)
	state_changed.emit(last_events, decorate_snapshot(last_snapshot))
	return last_view_result()


## Only an online match with a live local seat is a human Koliseo fight.
## Hot-seat, dedicated and Stasis pay nothing.
func koliseo_pays() -> bool:
	return (mode == Mode.HOST or mode == Mode.CLIENT) and local_seat >= 0


## A match_over packet counts only for a match this connection was assigned.
## Anything else is the previous fight still sitting on the server.
func _filter_client_snapshot(snap: Dictionary, events: Array) -> Dictionary:
	if typeof(snap) != TYPE_DICTIONARY or not bool(snap.get("match_over", false)):
		return {"snapshot": snap, "events": events, "finished": false}
	if not _client_in_match:
		var clean: Dictionary = snap.duplicate(true)
		clean["match_over"] = false
		clean["winner_seat"] = -1
		var kept: Array = []
		for event in events:
			if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "match_over":
				continue
			kept.append(event)
		return {"snapshot": clean, "events": kept, "finished": false}
	return {"snapshot": snap, "events": events, "finished": true}


func _note_koliseo_result(snap: Dictionary) -> void:
	if not bool(snap.get("match_over", false)):
		_koliseo_result_noted = false
		return
	if _koliseo_result_noted:
		return
	_koliseo_result_noted = true
	koliseo_last_payout = {}
	if not koliseo_pays():
		return
	var won := int(snap.get("winner_seat", -1)) == local_seat
	if won:
		var wallet := KoliseoWallet.load_saved()
		koliseo_last_payout = wallet.record_human_win(KoliseoWallet.now_unix())
		wallet.save()
	# XP (Characteristics sheet): human win 50, human loss 15. The coin cap
	# never cuts XP. It goes to the class this seat played.
	var class_id := ""
	var still_used := ""
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == local_seat:
			class_id = str(unit.get("class_id", ""))
			still_used = str(unit.get("still", ""))
	# The XII Still that fought is destroyed with the fight.
	if still_used != "":
		var vault := StillVault.load_saved()
		var still_class := class_id if StillVault.CLASS_IDS.has(class_id) else vault.focus_class
		if vault.socket_of(still_class) == still_used:
			vault.consume(still_class)
			vault.save()
	var hero := HeroProgress.load_saved()
	var gained := hero.add_xp(class_id, HeroProgress.XP_KOLISEO_WIN if won else HeroProgress.XP_KOLISEO_LOSS)
	hero.save()
	koliseo_last_payout["xp"] = int(gained["xp"])
	koliseo_last_payout["level"] = int(gained["level"])
	koliseo_last_payout["levels_gained"] = int(gained["levels_gained"])


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


## Client → authority: the sender's own worn gear. Stored for its seat only;
## applied now if both sides are still deploying.
@rpc("any_peer", "reliable")
func rpc_submit_gear(payload: Dictionary) -> void:
	if not is_authority():
		return
	accept_seat_gear(seat_for_peer(multiplayer.get_remote_sender_id()), payload)


func accept_seat_gear(seat: int, payload: Variant) -> bool:
	if seat < 0:
		return false
	if typeof(payload) == TYPE_DICTIONARY and (payload as Dictionary).has("by_seat"):
		var applied := false
		var by_seat: Dictionary = (payload as Dictionary).get("by_seat", {})
		for key in by_seat:
			var fighter := int(key)
			if not _connection_owns_fighter(seat, fighter):
				continue
			if _store_seat_gear(fighter, by_seat[key]):
				applied = true
		if applied:
			var host_sim := sim()
			if host_sim != null:
				_cache_and_broadcast({
					"ok": true, "illegal": false, "reason": "", "events": [],
					"snapshot": host_sim.snapshot(),
				})
		return applied
	return _store_seat_gear(seat, payload, true)


func _store_seat_gear(seat: int, payload: Variant, broadcast: bool = false) -> bool:
	if seat < 0:
		return false
	var gear := GearBag.clean_fight_gear(payload)
	_seat_gear[seat] = gear
	var host_sim := sim()
	if host_sim == null or not host_sim.has_method("set_seat_gear"):
		return false
	# The stored kit stays a clean fight payload. Koliseo applies +0 parts
	# on a copy so the live fight matches the match-start flatten.
	var live := gear.duplicate(true)
	live["flatten_plus"] = true
	if not host_sim.set_seat_gear(seat, live):
		return false
	if broadcast:
		_cache_and_broadcast({
			"ok": true, "illegal": false, "reason": "", "events": [],
			"snapshot": host_sim.snapshot(),
		})
	return true


## Gear the host puts into a match: its own seat 0 (listen-host) plus what
## each peer sent. Any seat_gear in the incoming config is dropped, so a
## reset request can never set the other seat's gear.
func _authority_gear_config(config: Dictionary) -> Dictionary:
	var out := config.duplicate(true)
	out.erase("seat_gear")
	var gear := {}
	if mode == Mode.HOST:
		gear[HOST_SEAT] = GearBag.clean_fight_gear(GearBag.load_saved().fight_gear(true, selected_class_id))
	for seat in _seat_gear:
		gear[seat] = _seat_gear[seat]
	# Koliseo arena flatten (Mobile Sets): parts count as +0; set bonuses stay.
	for seat in gear:
		gear[seat] = (gear[seat] as Dictionary).duplicate(true)
		gear[seat]["flatten_plus"] = true
	if not gear.is_empty():
		out["seat_gear"] = gear
	# Live Koliseo: higher Init acts first, tie = coin flip (never "host first").
	# Scripted fixtures (skip_deploy / rolls) keep their authored seat order.
	var fixture := bool(config.get("fixture", false)) or bool(config.get("skip_deploy", false)) or config.has("rolls")
	if not fixture:
		out["first_by_init"] = true
	return out


## Mauro 6 Oct 2026: a pre-fight element change sends this seat's gear again.
func resend_local_gear() -> void:
	_gear_sent_seat = -1
	_send_local_gear()


## Listen-host: this phone's pre-fight set, stance, or Still. The stored kit
## stays clean. The live fight flattens parts, same as a guest's accept.
func push_host_gear(class_id: String = "") -> bool:
	if mode != Mode.HOST:
		return false
	var seat := local_seat if local_seat >= 0 else HOST_SEAT
	var use := class_id if class_id != "" else selected_class_id
	var gear := GearBag.clean_fight_gear(GearBag.load_saved().fight_gear(true, use))
	_seat_gear[seat] = gear
	var host_sim := sim()
	if host_sim == null or not host_sim.has_method("set_seat_gear"):
		return false
	var live := gear.duplicate(true)
	live["flatten_plus"] = true
	if not host_sim.set_seat_gear(seat, live):
		return false
	_cache_and_broadcast({
		"ok": true, "illegal": false, "reason": "", "events": [],
		"snapshot": host_sim.snapshot(),
	})
	return true


func _send_local_gear() -> void:
	if mode != Mode.CLIENT or local_seat < 0 or _gear_sent_seat == local_seat:
		return
	if not _rpc_ready():
		return
	_gear_sent_seat = local_seat
	var fighters := _local_fighter_seats()
	if fighters.size() <= 1:
		var only := selected_class_id
		if fighters.size() == 1 and selected_class_ids.size() == 1:
			only = selected_class_ids[0]
		rpc_submit_gear.rpc_id(1, GearBag.clean_fight_gear(GearBag.load_saved().fight_gear(true, only)))
		return
	var by_seat := {}
	for i in fighters.size():
		var fighter := int(fighters[i])
		var class_id := selected_class_id
		if i < selected_class_ids.size():
			class_id = selected_class_ids[i]
		by_seat[fighter] = GearBag.clean_fight_gear(GearBag.load_saved().fight_gear(true, class_id))
	rpc_submit_gear.rpc_id(1, {"by_seat": by_seat})


func _local_fighter_seats() -> Array[int]:
	if not _owned_seats.is_empty():
		return _owned_seats.duplicate()
	if local_seat >= 0 and ((queue_format == "2v2" and selected_class_ids.size() == 2) or (queue_format == "3v3" and selected_class_ids.size() == 3)):
		var built: Array[int] = []
		for i in selected_class_ids.size():
			built.append(local_seat + i * 2)
		return built
	if local_seat >= 0:
		return [local_seat]
	return []


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
		seat = assign_peer_seat(peer_id)
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


## Client → dedicated authority. Two or three different Locked classes for 2v2 or 3v3.
@rpc("any_peer", "reliable")
func rpc_select_roster(class_ids: Array) -> void:
	if not is_authority():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if mode != Mode.DEDICATED:
		_send_class_result(peer_id, false, "", "not_dedicated")
		return
	var seat := seat_for_peer(peer_id)
	if seat < 0:
		seat = assign_peer_seat(peer_id)
	if seat < 0:
		_send_class_result(peer_id, false, "", "no_seat")
		return
	var session_id := _session_for_peer(peer_id)
	_queue().bind_seat(session_id, seat)
	var result: Dictionary = _queue().select_roster(session_id, class_ids)
	if not bool(result.get("ok", false)):
		_send_class_result(peer_id, false, str(result.get("class_id", "")), str(result.get("reason", "invalid_class")))
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
		seat = assign_peer_seat(peer_id)
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
		lobby_text = "Queued as %s. Waiting for an opponent." % _queue_display_name()
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
	var team_size := clampi(int(payload.get("team_size", 1)), 1, 3)
	_match_team_size = team_size
	_owned_seats.clear()
	var owned_raw: Variant = payload.get("owned_seats", [])
	if owned_raw is Array:
		for item in owned_raw:
			_owned_seats.append(int(item))
	var owned_classes: Variant = payload.get("owned_classes", [])
	if owned_classes is Array and (owned_classes as Array).size() >= team_size and team_size > 1:
		selected_class_ids = []
		for item in owned_classes:
			selected_class_ids.append(str(item))
		queue_format = "2v2" if team_size == 2 else "3v3"
	var seat := int(payload.get("seat", -1))
	if seat >= 0:
		local_seat = seat
		if _owned_seats.is_empty():
			_owned_seats.append(seat)
		_gear_sent_seat = -1
		_send_local_gear()
	var class_id := str(payload.get("class_id", ""))
	if class_id != "":
		selected_class_id = class_id
	_local_queued = true
	_opponent_queued = true
	_match_live = true
	_client_in_match = true
	_prematch_phase = "MATCH"
	connection_changed.emit("matched")
	_update_window_title()


func _authoritative_submit(intent: Dictionary, seat: int) -> Dictionary:
	if seat != HOST_SEAT and seat != GUEST_SEAT:
		return _cache_and_broadcast(_gate_reject("not_your_seat"))
	var stamped: Dictionary = intent.duplicate(true)
	var fighter := seat
	if stamped.has("seat"):
		fighter = int(stamped["seat"])
	if not _connection_owns_fighter(seat, fighter):
		return _cache_and_broadcast(_gate_reject("not_your_seat"))
	stamped["seat"] = fighter
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
	# The phones already have this fight. Clearing the lobby must not replace
	# the result this call returns (the dedicated brain itself is now a lobby).
	var shown := last_view_result()
	if mode == Mode.DEDICATED and _match_live and not _match_finished:
		var snap: Dictionary = packed.get("snapshot", {})
		if typeof(snap) == TYPE_DICTIONARY and bool(snap.get("match_over", false)):
			_finish_dedicated_match(snap)
			return shown
	return last_view_result()


## Both seats are free immediately, even if those phones are still connected
## long enough to read the result. The sim is cleared so the next peer is not
## handed this fight's match_over snapshot.
func _finish_dedicated_match(snap: Dictionary) -> void:
	_match_finished = true
	_match_live = false
	_match_class_ids = []
	_match_team_size = 1
	_prematch_phase = "SELECT_CLASS"
	_seat_gear.clear()
	for seat in [HOST_SEAT, GUEST_SEAT]:
		var peer_id := int(_seat_peer[seat])
		if peer_id > 1:
			_queue().forget(_session_for_peer(peer_id))
		_seat_peer[seat] = 0
		_seat_held[seat] = false
	guest_peer_id = 0
	_reset_lobby_state()
	print("STASIUM server: match end winner=%d" % int(snap.get("winner_seat", -1)))


func _lobby_snapshot() -> Dictionary:
	return {
		"match_over": false,
		"winner_seat": -1,
		"phase": "SELECT_CLASS",
		"units": [],
		"lobby": true,
		"active_seat": -1,
	}


func _reset_lobby_state() -> void:
	last_events = []
	last_result = {}
	last_packed = {}
	last_snapshot = _lobby_snapshot()
	var host_sim := sim()
	if host_sim != null and host_sim.has_method("clear_to_lobby"):
		host_sim.clear_to_lobby()


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
	if mode == Mode.DEDICATED and (_match_class_ids.size() == 2 or _match_class_ids.size() == 4 or _match_class_ids.size() == 6):
		var again: Array[String] = []
		for class_id in _match_class_ids:
			again.append(class_id)
		var again_config := {"classes": again}
		if _match_team_size > 1:
			again_config["team_size"] = _match_team_size
		return reset_match(again_config)
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


## Listen-host frees the guest slot. Dedicated keeps the seat only during a live match.
func release_peer(peer_id: int) -> int:
	for seat in [HOST_SEAT, GUEST_SEAT]:
		if int(_seat_peer[seat]) != peer_id or peer_id == 0:
			continue
		_seat_peer[seat] = 0
		if mode != Mode.DEDICATED or not _match_live or _match_finished:
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
	_seat_gear.clear()
	_gear_sent_seat = -1


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
		print("STASIUM server: player refused peer=%d reason=seats_full" % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		connection_changed.emit("seat_refused")
		return
	connection_changed.emit("seat_%d_joined" % seat)
	print("STASIUM server: player connected seat=%d peer=%d" % [seat, id])
	if mode == Mode.HOST:
		connection_changed.emit("guest_joined")
	if sim() == null and last_packed.is_empty() and _match_live:
		return
	var snap: Dictionary = sim().snapshot() if sim() != null else last_snapshot
	var events: Array = last_events if not last_events.is_empty() else snap.get("last_events", [])
	if mode == Mode.DEDICATED and not _match_live:
		snap = _lobby_snapshot()
		events = []
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
	if mode == Mode.DEDICATED:
		_queue().forget(_session_for_peer(id))
	var seat := release_peer(id)
	if seat < 0:
		return
	connection_changed.emit("seat_%d_left" % seat)
	print("STASIUM server: player disconnected seat=%d peer=%d reason=left" % [seat, id])
	if mode == Mode.HOST:
		connection_changed.emit("guest_left")


func _on_connected_to_server() -> void:
	if mode == Mode.CLIENT:
		if _dial_active:
			_ServerDial.remember(join_address)
			_dial_active = false
			_dial_live_attempt = -1
		connection_changed.emit("joined")
		print("STASIUM XII client connected to %s:%d" % [join_address, listen_port])
		if _queue_client and ((queue_format == "2v2" and selected_class_ids.size() == 2) or (queue_format == "3v3" and selected_class_ids.size() == 3)):
			rpc_select_roster.rpc_id(1, selected_class_ids)
			rpc_enqueue.rpc_id(1)
		elif _queue_client and queue_format != "2v2" and queue_format != "3v3" and SpellKits.is_roster_class(selected_class_id):
			rpc_select_class.rpc_id(1, selected_class_id)
			rpc_enqueue.rpc_id(1)
		_update_window_title()


func _on_connection_failed() -> void:
	if _dial_suppress:
		return
	print("STASIUM XII client join failed for %s:%d" % [join_address, listen_port])
	if _dial_active:
		if _dial_live_attempt >= 0:
			call_deferred("_dial_fail_attempt", _dial_live_attempt)
		return
	if mode != Mode.CLIENT:
		return
	connection_changed.emit("join_failed")


func _on_server_disconnected() -> void:
	if _quiet_leave or bool(last_snapshot.get("match_over", false)):
		_quiet_leave = true
		connection_changed.emit("match_finished")
		return
	connection_changed.emit("host_left")


func _close_peer() -> void:
	var restore := not _dial_suppress
	_dial_suppress = true
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if restore:
		_dial_suppress = false


static func plan_from_args(args: PackedStringArray) -> Dictionary:
	var planned := "hotseat"
	var port := DEFAULT_PORT
	var address := "127.0.0.1"
	var class_id := ""
	var class_ids: Array = []
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
		elif arg == "--classes":
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("-"):
				i += 1
				var picked: Array = str(args[i]).split(",")
				class_ids = picked
		elif arg == "--hotseat":
			planned = "hotseat"
		i += 1
	return {"mode": planned, "port": port, "address": address, "class_id": class_id, "class_ids": class_ids}


func _parse_user_args() -> void:
	var plan := plan_from_args(OS.get_cmdline_user_args())
	listen_port = int(plan["port"])
	join_address = str(plan["address"])
	_cli_class = str(plan.get("class_id", ""))
	_cli_classes = plan.get("class_ids", [])
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
	var match_left := float(snap.get("match_time_left", -1.0))
	var match_sec := -1
	if match_left >= 0.0:
		match_sec = int(floor(match_left))
	return {
		"seconds": _clock_display_seconds(snap),
		"running": bool(snap.get("turn_time_running", false)),
		"active_seat": int(snap.get("active_seat", -1)),
		"match_sec": match_sec,
		"sudden_death": bool(snap.get("sudden_death", false)),
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
	var team_size := clampi(int(config.get("team_size", 1)), 1, 3)
	var want := team_size * 2
	if incoming.size() < want:
		return []
	var out: Array[String] = []
	for i in want:
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
	var team_size := clampi(int(match.get("team_size", 1)), 1, 3)
	var need := team_size * 2
	if raw.size() < need:
		return
	var ids: Array[String] = []
	for i in need:
		ids.append(str(raw[i]))
	var match_id := str(match.get("id", ""))
	lobby_text = "Match %s — seat 0 %s, seat 1 %s" % [match_id, SpellKits.display_name(ids[0]), SpellKits.display_name(ids[1])]
	print("STASIUM server: match start id=%s seat0=%s seat1=%s team=%d" % [match_id, ids[0], ids[1], team_size])
	var boot := {"classes": ids}
	if team_size > 1:
		boot["team_size"] = team_size
	reset_match(boot)
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
			"team_size": team_size,
			"owned_seats": _owned_for_connection(seat, team_size),
			"owned_classes": _classes_for_connection(ids, seat, team_size),
		}
		rpc_match_assigned.rpc_id(peer_id, payload)
	connection_changed.emit("matched")


func _owned_for_connection(connection_seat: int, team_size: int) -> Array:
	var count := 1 if team_size <= 1 else team_size
	var out: Array = []
	for i in count:
		out.append(connection_seat + i * 2)
	return out


func _classes_for_connection(ids: Array, connection_seat: int, team_size: int) -> Array:
	var out: Array = []
	var count := 1 if team_size <= 1 else team_size
	for i in count:
		var index := connection_seat + i * 2
		if index >= 0 and index < ids.size():
			out.append(str(ids[index]))
	return out


func _connection_owns_fighter(connection_seat: int, fighter: int) -> bool:
	if _match_team_size > 1:
		if fighter < 0 or fighter >= _match_team_size * 2:
			return false
		return fighter % 2 == connection_seat
	return fighter == connection_seat


func _queue_display_name() -> String:
	if (queue_format == "2v2" and selected_class_ids.size() == 2) or (queue_format == "3v3" and selected_class_ids.size() == 3):
		var names: Array[String] = []
		for class_id in selected_class_ids:
			names.append(SpellKits.display_name(class_id))
		return ", ".join(names)
	return SpellKits.display_name(selected_class_id)


func _packed_seat_map(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return {0: [], 1: []}
	for key in raw:
		var seat_key: Variant = key
		if typeof(key) == TYPE_STRING and str(key).is_valid_int():
			seat_key = int(str(key))
		if typeof(seat_key) != TYPE_INT:
			continue
		out[int(seat_key)] = raw[key]
	if out.is_empty():
		return {0: [], 1: []}
	return out


func _prematch_block() -> Dictionary:
	var phase := _prematch_phase
	var live := _match_live
	if mode == Mode.HOTSEAT or mode == Mode.HOST:
		phase = "MATCH"
		live = true
	elif mode == Mode.DEDICATED and (_match_class_ids.size() == 2 or _match_class_ids.size() == 4 or _match_class_ids.size() == 6):
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
