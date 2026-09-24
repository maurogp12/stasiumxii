# Phase E — host core (listen-host and dedicated)

**Status:** Director milestone A. The **dedicated server process** owns CombatSim and has no seat. The optional **listen-host** window is the same host core with seat 0 on that process. Transport is **ENet** via Godot 4 `MultiplayerAPI` (`ENetMultiplayerPeer` + RPC). This is **not** MultiplayerSynchronizer and not login. Dedicated clients pick a Locked class before the duel (see SELECT_CLASS).

Local hot-seat on `main.tscn` is unchanged: it still calls `CombatSim.submit` directly when `NetSession` is HOTSEAT.

## Why ENet (not WebSocket)

- Desktop Godot 4 already ships high-level MultiplayerAPI + ENet. The playtest is Godot windows on localhost or LAN, including a headless dedicated process.
- Direct IP + port matches the proto (anonymous, no lobby service).
- Reliable RPC is enough to send an Intent and broadcast `events` + `snapshot`.
- Moving the dedicated process to another machine is `--join <ip>:<port>` on this same host core. It is not a new protocol.
- WebSocket (`WebSocketMultiplayerPeer`) stays the later HTML5 option. Same RPC surface later; do not invent it here.

## Dedicated process and listen-host

The dedicated server process owns the match, the turn, the 30s timer, HP/MP, Marks, Impact, Burn, terrain, elevation, pushes, and death. Clients send Intent and apply snapshot/events. They never roll.

```
godot --headless --path . -- --dedicated 7777
```

First joiner is seat 0. Second joiner is seat 1. Class is not the seat: each client confirms `kestrel` or `ironjaw`, then queues. Seat 0 may ask the server for a fresh `reset_match`. The server ignores any seed, rolls, or positions on that request and keeps the confirmed classes.

A disconnect is a stub: that seat stays reserved and is not given to a new joiner. There is no reconnect policy.

**Listen-host** remains behind `--host`. That window is seat 0 and the authority. One guest is seat 1. After a guest disconnect, the listen-host slot can be taken again. The dedicated stub does not do that.

Hot-seat is the default. `--hotseat` forces it.

The Intent/`submit` envelope is the same on every path.

## Unchanged API

Phase E does **not** change these calls. Client and host submit the same Intent dictionary.

| Call | Owner | Notes |
| --- | --- | --- |
| `reset_match(config)` | Host | Host picks `seed` / `elev_seed`. Snapshot stores both for replay. |
| `submit(intent)` | Host | Identical Intent shape as today's local hot-seat. |
| `legal_intents(seat)` | Host | Client paints from this; it does not invent dests. |
| `snapshot()` | Host | Includes `seed`, `elev_seed`, `match_config`, `last_events`. |
| `preview_cast(...)` | Read-only | HUD cards only. Never a submit. Never rolls. |

`CombatSim.submit` remains the authority for combat legality (range, AP/MP, stun, walk gates). `backend/host_validate.gd` is a **shape + ownership** gate in front of that: known Intent types, no client-supplied roll. `CombatSim.snapshot().networking` stays `false` — the brain is not a net peer. Transport metadata lives on `NetSession` (`net_active`, `net.transport`).

## Intent envelope (identical)

Normalized by `CombatSim._normalize_intent`: `type` lowercased, `spell` lowercased, `dir` uppercased, `to` as `Vector2i`.

| `type` | Required fields | Optional | Phase |
| --- | --- | --- | --- |
| `end_turn` |  | `seat`, `auto` | combat |
| `face` | `dir` (`N`/`E`/`S`/`W`) | `seat` | combat |
| `move` | `to` | `seat` | combat |
| `cast` | `spell`, `to` | `seat`, `target_seat` | combat |
| `place` / `reposition` | `seat`, `to` |  | DEPLOYMENT |
| `ready` / `confirm` | `seat` |  | DEPLOYMENT |

Walk is dest-click only. `intent.path` is **ignored** (not authoritative). Advance ignores client path the same way.

## Seed / RNG — host-owned

- `MatchConfig.seed` and `elev_seed` are authored by the **host** on `reset_match`. Live New Match uses a fresh seed; fixtures may pin one.
- The d100 lives in `CombatSim` (`_rng` seeded from `seed`). Scripted `config.rolls` is a **test/setup** hook, not a client channel.
- The client must **not** send `roll`, `hit_roll`, or `rng` on an Intent. Host-validate rejects those keys (`client_must_not_roll`).
- `snapshot.seed` / `snapshot.elev_seed` / `snapshot.match_config` are the replay handle. The client displays them; it does not re-seed the host.

## Host-validate + listen-host order

`HostValidate.validate_intent(intent)` checks envelope shape and the no-client-roll rule.

`HostValidate.validate_match_config(config)` checks that a live (non-fixture) reset does not carry client RNG.

Implemented order:

1. The authority owns `CombatSim` (`NetSession` mode HOST or DEDICATED). Same submit / tick / broadcast path.
2. Client sends the same Intent it would `submit` locally today (`IntentCodec` over ENet RPC).
3. The authority stamps `intent.seat` from peer ownership, then `HostValidate.validate_intent` → `CombatSim.submit`.
4. The authority broadcasts `events` + `snapshot` + seat-filtered `legal_intents`, plus `viewer_seat`. Each client hydrates a read-only replica via `CombatSim.apply_host_snapshot` for HUD `preview_cast` only.

## Seat ownership

Hot-seat is replaced by seat ownership when online:

- **Dedicated:** the server process owns neither seat. Join order assigns seat 0, then seat 1. Each client learns its seat from `viewer_seat`.
- **Listen-host:** the host window owns seat 0 (Kestrel). The guest owns seat 1 (Ironjaw).
- Deploy: each window only places / readies its seat. Simultaneous still — both can act at once.
- Combat: only the owner of `active_seat` can submit. The other window watches.

## Host-owned turn timer (Godot HUD)

The 30s TIME clock is **host authority**. `CombatSim` starts it on turn begin, ticks only on the host / hot-seat brain, and on expiry submits the same `end_turn` Intent as the HUD button (`auto: true`, `reason: "timer"`). Guests **hydrate** remaining from the snapshot. They do not tick, do not invent a second clock, and do not mutate the sim.

Every host broadcast (after `submit`, and on each timer tick that changes the displayed second) includes `events` + `snapshot` + seat-filtered `legal_intents`.

### Snapshot fields for the HUD

| Field | Owner | Meaning |
| --- | --- | --- |
| `turn_time_remaining` | Host CombatSim | Seconds left on the **active** seat's clock (float). Present on **every** snapshot, including during the opponent's turn. |
| `turn_time_limit` | Host CombatSim | Duration (30). Retune with `CombatSim.TURN_TIME_LIMIT` (keep `TurnClock.DURATION_SEC` in sync). |
| `turn_time_running` | Host CombatSim | `true` while the host clock is ticking (combat, match not over). |
| `turn_time_seconds` | Host CombatSim | `ceil(remaining)` for the TIME readout. |
| `turn_timer` | Host CombatSim | Stamp `"host"` — not a client clock. |
| `active_seat` | Host CombatSim | Whose turn it is. `turn_start` / `end_turn.next_seat` events fire on seat change. |
| `local_seat` | NetSession decorate | This window's seat (`0` listen-host or first dedicated client, `1` guest or second client, `-1` hot-seat or the dedicated process). Also under `net.local_seat`. `viewer_seat` on the packet assigns it. |
| `net.active_seat` | NetSession decorate | Copy of `active_seat` next to `local_seat` so Godot can compare without inventing kit policy. |

Godot HUD:

- TIME bar = `turn_time_seconds` / `turn_time_limit` (or `ceil(turn_time_remaining)`).
- **Your Turn** vs **Opponent's Turn** = `local_seat == active_seat` (hot-seat `local_seat < 0` keeps the active name).
- Kit buttons = the unit at `local_seat`, using that unit's `class_id` (hot-seat falls back to `active_seat`). The snapshot does **not** encode “show active kit”. Seat 0 is not hard-coded to Kestrel when `class_id` is present.
- Guest never starts its own countdown.

## SELECT_CLASS (dedicated clients)

Chrome calls these names. The authority validates. Clients do not write the roster.

| Call / signal | Direction | Meaning |
| --- | --- | --- |
| `select_class(class_id: String)` | Client → `rpc_select_class` | Ask the server to lock this seat's class. |
| `signal class_selected(class_id: String)` | Server → `rpc_class_selected` | Accept. `class_id` is lowercase `kestrel` or `ironjaw`. |
| `signal class_rejected(reason: String, class_id: String)` | Server → `rpc_class_rejected` | Reject. `reason` is `invalid_class`, `no_seat`, `not_connected`, `not_your_seat`, `already_queued`, or `class_not_confirmed`. |
| `enter_matchmaking()` | Client → `rpc_enter_matchmaking` | Queue after a confirmed class. |
| `signal matchmaking_changed(status: String)` | Server → `rpc_matchmaking_status` | `waiting` until the other seat queues, then `matched`. |
| `signal match_found(snapshot: Dictionary)` | Server → `rpc_match_found` | Duel snapshot is ready. Kit bar reads `units[].class_id`. |

Locked roster is only `kestrel` and `ironjaw`. Anything else is `invalid_class`.

`reset_match` config key the authority passes (clients never send this):

```
seat_classes: { 0: "ironjaw", 1: "kestrel" }
```

Int keys or `"0"` / `"1"`. Missing or unknown ids keep the default roster (seat 0 Kestrel, seat 1 Ironjaw) so hot-seat and listen-host stay unchanged.

Per-viewer snapshot block `prematch` (also `server_mode`: `dedicated` or `host`):

| Field | Meaning |
| --- | --- |
| `phase` | `SELECT_CLASS`, `MATCHMAKING`, or `MATCH` |
| `local_class_id` | This viewer's confirmed class, or `""` |
| `local_queued` | This viewer has entered the queue |
| `opponent_queued` | The other seat has entered the queue |
| `match_live` | The duel snapshot is the one to paint |

After `match_live`, `units[].class_id` (and that unit's `spells`) is the kit. `kestrel_pos` / `ironjaw_pos` remain seat-slot fixture keys, not class identity.

## Out of scope (do not invent)

- Login, relay
- Full reconnect (dedicated disconnect is a stub: the seat stays reserved)
- MultiplayerSynchronizer
- WebSocket / HTML5 client
- Fog / hidden enemy
- Height → hit / facing / LoS
- New Advance costs
- Changing Locked kit numbers
- Blends / Residue / Gloam / Pulse

## Local still works

Hot-seat `main.tscn` keeps calling `CombatSim.submit` directly. Open `scenes/online_lobby.tscn` or pass `--host` / `--join` for listen-host. Pass `--dedicated 7777` for the headless authority (clients `--join` that IP).
