# Phase E — online schema (draft)

**Status:** contract only. Networking stays **OFF**. This file names the host/client split so a later transport can sit on top of the live `CombatSim` API. It does **not** invent MultiplayerSynchronizer, RPC, clock sync, fog, or height→hit.

## Goal

Host and client run the **same** combat brain. The Godot view stays a thin presenter. The host is the only place that seeds the match or rolls the d100.

## Unchanged API

Phase E does **not** change these calls. Client and host submit the same Intent dictionary.

| Call | Owner | Notes |
| --- | --- | --- |
| `reset_match(config)` | Host | Host picks `seed` / `elev_seed`. Snapshot stores both for replay. |
| `submit(intent)` | Host | Identical Intent shape as today's local hot-seat. |
| `legal_intents(seat)` | Host | Client paints from this; it does not invent dests. |
| `snapshot()` | Host | Includes `seed`, `elev_seed`, `match_config`, `last_events`. |
| `preview_cast(...)` | Read-only | HUD cards only. Never a submit. Never rolls. |

`CombatSim.submit` remains the authority for combat legality (range, AP/MP, stun, walk gates). `backend/host_validate.gd` is a **shape + ownership** gate in front of that: known Intent types, no client-supplied roll.

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

## Host-validate (minimal)

`HostValidate.validate_intent(intent)` checks envelope shape and the no-client-roll rule.

`HostValidate.validate_match_config(config)` checks that a live (non-fixture) reset does not carry client RNG.

Suggested later order, **not implemented here**:

1. Host constructs / owns `CombatSim`.
2. Client sends the same Intent it would `submit` locally today.
3. Host `HostValidate.validate_intent` → `CombatSim.submit`.
4. Host broadcasts `events` + `snapshot` (today's `_accept` / `_reject` payload).

## Out of scope (do not invent)

- Transport, lobbies, relay, MultiplayerSynchronizer
- Seat clock sync (the 30s TIME clock is still client-only)
- Fog / hidden enemy
- Height → hit / facing / LoS
- New Advance costs
- Changing Locked kit numbers

## Local still works

Hot-seat `main.tscn` keeps calling `CombatSim.submit` directly. Phase E is a contract so that path and a future host path stay identical.
