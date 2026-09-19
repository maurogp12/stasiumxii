# Phase E — listen-host proto

**Status:** listen-host playtest. Transport is **ENet** via Godot 4 `MultiplayerAPI` (`ENetMultiplayerPeer` + RPC). This is **not** MultiplayerSynchronizer, not a dedicated server, and not matchmaking/auth.

Local hot-seat on `main.tscn` is unchanged: it still calls `CombatSim.submit` directly when `NetSession` is HOTSEAT.

## Why ENet (not WebSocket)

- Desktop Godot 4 already ships high-level MultiplayerAPI + ENet. Two editor/export windows on localhost or LAN is the Mauro playtest.
- Direct IP + port matches the proto (anonymous, no lobby service).
- Reliable RPC is enough to send an Intent and broadcast `events` + `snapshot`.
- WebSocket (`WebSocketMultiplayerPeer`) is the better pick for an HTML5 client. Same RPC surface later; do not invent it here.

## Why listen-host only

The host window **is** seat 0 (Kestrel) **and** the CombatSim authority. There is no dedicated server process.

If Mauro later wants a headless dedicated host (no player on the server), **stop and Lock that** — do not invent it on top of this proto. The Intent/`submit` envelope would stay the same.

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

1. Host constructs / owns `CombatSim` (`NetSession` mode HOST).
2. Client sends the same Intent it would `submit` locally today (`IntentCodec` over ENet RPC).
3. Host stamps `intent.seat` from peer ownership (host=0, guest=1), then `HostValidate.validate_intent` → `CombatSim.submit`.
4. Host broadcasts `events` + `snapshot` + `legal_intents` (today's `_accept` / `_reject` payload). Guest hydrates a read-only replica via `CombatSim.apply_host_snapshot` for HUD `preview_cast` only.

## Seat ownership

Hot-seat is replaced by seat ownership when online:

- Host owns seat 0 (Kestrel). Guest owns seat 1 (Ironjaw).
- Deploy: each window only places / readies its seat. Simultaneous still — both can act at once.
- Combat: only the owner of `active_seat` can submit. The other window watches.

## Out of scope (do not invent)

- Dedicated server, relay, matchmaking, auth
- MultiplayerSynchronizer
- Seat clock sync (the 30s TIME clock is still client-only, and only ticks on the owning seat)
- Fog / hidden enemy
- Height → hit / facing / LoS
- New Advance costs
- Changing Locked kit numbers
- Blends / Residue / Gloam

## Local still works

Hot-seat `main.tscn` keeps calling `CombatSim.submit` directly. Open `scenes/online_lobby.tscn` or pass `--host` / `--join` for the listen-host path.
