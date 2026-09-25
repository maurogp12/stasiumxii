# STASIUM XII

Phase A local hot-seat duel, an optional **listen-host** window, and a **dedicated** headless host. Godot 4.7+. Combat lives in `CombatSim`; the board is a thin client. Clients submit Intent; only the authority rolls.

## How to play

Press **F5 / Play**. `run/main_scene` is `scenes/class_select.tscn`.

- **Hot-seat:** choose Hot-seat, then P1 picks a class and P2 picks a class. The local duel on `main.tscn` starts with those two kits on a uniform random arena: Crosshaven, Brinewake, Slagcrown, Windmere, or Stormspire. Players do not choose the map. Kestrel vs Ironjaw is still that pair if you pick those two. **New Match** rolls a new arena. Dev shortcuts that skip the screen start on Crosshaven (`map_id` empty). Online stays on Crosshaven.
- **Online:** choose Online, keep `127.0.0.1` / `7777` or enter a host, pick a class (that calls `select_class`), then **Queue**. A dedicated host is `godot --path . -- --dedicated 7777` and does not show the picker.
- **Dev shortcuts** skip the screen: `--class`, `--queue`, `--join`, and `--host`. `--dedicated` never shows the picker.

1. Open `project.godot` in Godot 4.7 or later and run the main scene.
2. **Locked deploy flow** on `main.tscn` before Turn 1, with **Proposed random blobs** shipped live: each seat gets a seed-sampled ~6-cell zone (2×3 rectangle or organic blob; interior cells allowed). Click a highlighted zone cell to `place_unit` (reposition until Ready). **Ready P1** / **Ready P2** enable from `can_ready` after that seat’s fighter is placed. Both Ready → lock → Turn 1 combat. Walk / kit casts / Face / End Turn and the 30s TIME clock stay hidden during DEPLOYMENT. Outside-zone clicks name the other blob or an unclaimed cell. No fog, no deploy timer, no networking.
3. After deploy, seat 0 acts first, then seat 1. Hot-seat **Kestrel** (green) vs **Ironjaw** (red) is still that order when those two are picked.
4. Each combat turn starts with **6 AP** and **3 MP**. Spend them in any order, then **End Turn**. After deploy, a **30s TIME** countdown is visible on **both** windows (including the watching seat); at 0 the **host** auto End Turns (same as the button). The clock is host-owned: paint `turn_time_seconds` (ceil of `turn_time_remaining`), `turn_time_limit` 30, `turn_time_running`, `turn_timer: "host"`. Guests hydrate; they do not tick. The clock keeps ticking during walk hop animations. Advance is an instant snap (no hops). Change `CombatSim.TURN_TIME_LIMIT` (and `TurnClock.DURATION_SEC`) to retune. The clock is hidden during DEPLOYMENT (no deploy timer).
5. Click a highlighted empty tile to **walk**. Dest-click only: `CombatSim` expands the cheapest orthogonal path (weighted pathfinder). Walk cost is dest **terrain MP + uphill integer z**; downhill is free. Legal tiles come from remaining MP. Live `reset_match` seeds the Koliseo **15×15** tags JSON when that file’s size is `[15,15]` (default **Crosshaven**; `map_id` selects Brinewake, Slagcrown, Windmere, or Stormspire). Terrain + elevation only; the loader does not invent a layout. `paint_only` / Tiled `props_paint` are paint only. The board paints the matching region isometric PNGs on the 64×32 diamonds (`cell_to_local` ≈ `((x-y)*32, (x+y)*16)`). Proto `board_size` 8 still uses the 8×8 crop (origin row 2, col 2 — see below) plus seeded noise. Proto `board_size` 12 seeds Mauro’s token grid and does not load a Crosshaven pack. The camera zooms the 15×15 diamond into 960×720 and middle-mouse pans. The pawn animates one ortho tile at a time along the returned path and **faces each hop** (final facing = last hop). Manual **Face** still turns in place (0 AP). The client never sends `intent.path`. Walk is the default mode. After selecting a spell, press **Walk** or **Esc** to cancel back to walk chrome (right-click still faces; it does not cancel). Hit % / facing cones / spell LoS ignore height.
6. The action bar shows the **local** kit online (`snapshot.local_seat`) and the active kit in hot-seat (`local_seat < 0` → `active_seat`). Snapshot does not encode “show active kit”. Select a spell, then click a legal tile. At **960×720** the bar **wraps** (FlowContainer) so Walk / kit buttons / End Turn / New Match stay readable. **Face N/E/S/W** sit on a cardinal pad (N top, W left, E right, S bottom). **Strike / Mark Shot / Detonate / Shoulder / Crush range stays Chebyshev**. **Advance range is the 4 orthogonal neighbors** (N/S/E/W only):
   - **Advance** (Ironjaw only) — dest-click teleport, **3 AP / 0 MP**. Legal dests are **exactly the 4 ortho neighbors** (N/S/E/W): Chebyshev 1 and Manhattan 1, cardinal only. Manhattan 2 and any diagonal / (1,1) are rejected. Dest must pass the **same stand-on gates as walk** (walkable, not occupied, not lava, climb≤1 / drop≤2). Gate only — no terrain+elev MP spend. Board highlights, the hover sample, and click-accept read those `legal_intents` cells only (hot-seat and NetSession). A click off that set is rejected with the existing refund coach. Instant snap (no hop animation). `CombatSim` ignores a client `intent.path`. Works at 0 MP. Does not zero leftover MP; after Advance, leftover MP still walks (`legal_intents` offers moves whenever MP > 0, even at 0 AP). No roll. +1 Impact if you land Chebyshev-adjacent to an enemy. After the snap, spell selection clears and walk chrome returns from `legal_intents` (remaining MP is still spendable). **Facing is unchanged** on Advance (no auto-face). Kestrel never sees Advance chrome and never gains Impact.
   - **Mark Shot** (Kestrel) — 2 AP, range 2–7 Chebyshev, 8 Air. Selecting it paints the Chebyshev 2–7 ring (walk chrome stays off). +1 Mark on the **target** if it hits.
   - **Detonate** (Kestrel) — 3 AP / 0 MP, range 1–4 Chebyshev. Needs 1+ Marks on that target. On hit: 6+6×M Air and **consumes** those Marks. On miss: Marks stay (AP/MP stay spent).
   - **Strike** (Ironjaw) — 3 AP, range 1, 16 Earth. +1 Impact on Ironjaw if it hits.
   - **Shoulder** (Ironjaw) — 2 AP / 0 MP, range 1. On hit: 6 Earth, push the target 1 Chebyshev cell away along the line. **Director Locked Shoulder Impact:** a clean push onto walkable empty ground is **+1 Impact**. **OOB / truly blocked** (not lava) bounces and **staggers** (**4 HP**, plus **1 MP** if current MP ≥ 1) for **+2 Impact only** (that +2 does not stack with the +1). **Occupied dest** stays `push_blocked` (hard body-block, no bounce, no stagger, no Impact beyond the hit +1). **Lava** is hazardous, not a wall: the forced push **lands on lava** and applies **Burn** (no bounce, no stagger). Voluntary walk onto lava stays impassable. Client toasts **PushBlocked**, **Bounce** plus a single **+2 Impact** (never also +1), a clean Shoulder **+1 Impact**, or **Lava - Burn** when the push lands on lava (not Bounce). It does not hop on block or bounce. Hit/Impact feedback still plays. Burn icons and remaining turns paint from the host snapshot.
   - **Burn** — applied when a forced Shoulder lands on lava. **4 HP** at the **start of the victim’s turn**, duration **2** (two ticks). Re-apply **refreshes** duration and does not stack. Burn continues after the unit leaves lava. Death is checked after each tick. `burn_remaining` is on the unit snapshot; apply emits `status`/`burn` and each tick emits `burn`, so Godot chrome and a host replica paint the same state.
   - **Crush** (Ironjaw) — 4 AP / 0 MP, range 1. Needs/spends 2 Impact (spend on hit; miss retains Impact). 24 Earth on hit. **Stun 1** if Impact was **4 before** the spend. **Locked Stun (A′):** Stun 1 blocks move + cast + face (`stunned_cannot_act`). When that seat's turn starts, CombatSim **auto-resolves `end_turn`** — the player never presses End Turn. `legal_intents` is empty of move/cast/face (auto path only). HUD greys Walk/Face/spells, shows a STUN badge, and presents a **skip banner** from that auto `end_turn` event (the coach line is the log).
7. **Face** with the N/E/S/W buttons, or right-click a tile to face that direction (0 AP). Walks set facing from each hop (final = last hop). Advance teleport leaves facing unchanged. In-place Face is still available. Back hits deal ×1.20; front/side are ×1.00.
8. A **miss** still spends AP/MP and deals nothing. An **illegal** cast is rejected and refunded. The coach line under the board tells them apart.
9. While aiming **Mark Shot / Strike / Detonate / Shoulder / Crush**, the HUD shows the Locked **HIT %** for the current Chebyshev distance before you click (hover updates the cell). Advance (no roll) and walks never show hit %. Bands are Locked through Chebyshev 14: 1→90%, 2–3→80%, 4–5→75%, 6–8→70%, 9→65%, 10→60%, 11→55%, 12→50%, 13→45%, 14→40%. The 9–14 soft-block is lifted. Dist past 14, or outside the spell’s max range, stays illegal and gets no invented percent. Kit damage and ranges are unchanged.
10. **End Turn** (button or clock expiry) shows a ~1.0s client-only turn banner, then hands the seat to the other player (Proposed presentation; not a CombatSim rule).
11. First combatant to 0 HP loses. **New Match** resets from `CombatSim.reset_match()` (live path starts in DEPLOYMENT again) with a **new seed**. Hot-seat also rolls a new arena from the five ship maps. Online, and an empty `map_id`, stay on Crosshaven. Ship elevation stays that map’s tags. Proto `board_size` 8 still regenerates seeded noise on the same crop terrain.

## Architecture

| Piece | Role |
| --- | --- |
| `backend/combat_sim.gd` (autoload `CombatSim`) | Sole authority (including the 30s turn clock). `BOARD_SIZE` is **15**. `reset_match(config)` starts **DEPLOYMENT** (live) and seeds the Koliseo **15×15 tags** (default Crosshaven; terrain + elevation) onto `WalkBoard` when the tags file size matches. `paint_only` is stored beside the walk tile. `MatchConfig.board_size` 8 is the proto crop + seeded noise. `MatchConfig.board_size` 12 is the proto Mauro token grid. `MatchConfig.seed` / `elev_seed` override for fixtures/replay (`snapshot.seed`, `snapshot.elev_seed`). `place_unit(seat, cell)`, `ready_seat(seat)`, `can_place`, `can_ready`, `legal_deploy_cells(seat)`, `deploy_zone_cells(seat)`. `submit(intent)`, `legal_intents(seat)`, `snapshot()`, `aim_hit_preview(seat, spell, dest?)`, `preview_cast(...)`. `hit_chance` reads `backend/hit_bands.gd` (Locked through Chebyshev 14: 1=90, 2–3=80, 4–5=75, 6–8=70, 9=65, 10=60, 11=55, 12=50, 13=45, 14=40; past 14 has no percent). Walk is dest-click weighted pathfinder (`backend/walk_board.gd`); Advance reuses `stand_on_gate`. `snapshot().tiles` exposes per-tile **integer** elevation / terrain_type for Godot. Both Ready → lock → Turn 1 with spawn cells from confirmed positions. `skip_deploy` / `kestrel_pos` / `ironjaw_pos` skip to combat (tests/setup; same Crosshaven tags unless `flat_board` or an explicit proto size). Rolls and HP live here. |
| `backend/match_flow.gd` (`MatchFlow`, owned by CombatSim) | Locked phase + simultaneous ready. Proposed (shipped live) seed-based ~6-cell blob sampler on the **15×15** ship board; `legal_deploy_cells` / `deploy_zone_cells` come from those blobs. Owns `PHASE_A_DEMO_TILES` / `phase_a_demo_tiles()` — proto-only 8×8 **terrain** crop of Mauro’s 12×12 at origin (row 2, col 2) — and `generate_noise_elevations(seed)` for z 0–3. Ship matches load `art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json` when its size is `[15,15]`. Explicit `board_size` 12 seeds Mauro’s tokens (`mauro_12`) and is proto only. #31 border halves stay the previous Locked baseline. Proto stays reference. |
| `backend/event_bus.gd` (autoload `EventBus`) | Forwards events to listeners. Does not mutate combat. |
| `backend/host_validate.gd` + `backend/intent_codec.gd` + `MIGRATION_PHASE_E.md` | Phase E: Intent/`submit` identical; seed/RNG host-owned. Shape gate + JSON/RPC encode. |
| `backend/net_session.gd` (autoload `NetSession`) | Shared host core. ENet / MultiplayerAPI RPC. **Dedicated** (`--dedicated`) owns CombatSim and has no seat. It does not spawn a default pair: players `SELECT_CLASS` (`kestrel`, `ironjaw`, `mender`, `gloam`, `bastion`) then queue. A pair starts a match whose seats use those class ids. **Listen-host** (`--host`) is the same core with seat 0 fixed as Kestrel and the guest as Ironjaw. HOTSEAT still calls `CombatSim.submit` directly. RPC only (no scene sync). |
| `backend/matchmaking.gd` (`MatchQueue`) | Server-side `SELECT_CLASS` + queue. Stores the confirmed class on the session. Rejects any other `class_id`. Pairs the next two confirmed sessions. |
| `scenes/online_lobby.tscn` | Five-class pick, dedicated host, join queue. Listen-host host / direct-IP join / local hot-seat stay on the same scene. |
| `scenes/class_select.tscn` | Main scene. Hot-seat is P1 then P2 (the arena is a random ship map), or Online class pick plus Queue (Find Match / `start_queue_client`). Online matches stay on Crosshaven. `match_assigned()` opens `main.tscn`. `--dedicated` shows host status and no picker. |
| `data/kits.gd` | Locked Phase A kit data only. |
| `ui/turn_clock.gd` | Display helper for the host 30s clock. Remaining comes from the snapshot. |
| `board_view.gd`, `ui/hud.gd`, `units/pawn.gd` | Input and presentation. Live deploy chrome binds `place_unit` / `ready_seat` / `legal_deploy_cells` / `deploy_zone_cells` / `can_ready` / `snapshot().phase`. They also submit dest-clicks, animate walk hops, snap Advance teleports, paint enemy-spell range rings, show Locked hit %, grey Locked Stun (A′) chrome, toast PushBlocked, Bounce +2 Impact, clean Shoulder +1 Impact, and Lava - Burn, show Proposed hover/long-press attack cards, and run the Proposed combat timers. Live tiles paint snapshot `elevation` + `terrain_type` (Ground/Mud/Water/Lava) via `board/snapshot_tiles.gd`. Walk highlights and Advance dest highlights are `legal_intents` dests only (`cast_dests`). Z-sort is VIEW-only (`board/visual_sort.gd`). Hit bands / facing / spell LoS stay flat. |
| `data/spell_tooltip.gd` | Proposed attack-card formatter. Reads `CombatSim.preview_cast` only. Does not invent kit numbers. |

Intents: `end_turn` | `face` | `move` | `cast` | `place` / `reposition` | `ready` / `confirm`. During DEPLOYMENT only `place` / `reposition` / `ready` are legal.

## Locked in this slice (GDD v0.2)

- **Locked deploy flow:** MatchPhase DEPLOYMENT before Turn 1. Simultaneous place/reposition (local both-ready, or one seat per listen-host window). One fighter each. Ready gated on unit placed. Both Ready → lock positions → Turn 1 / combat on, spawning from the confirmed cells. During deploy: reject move/cast/face/end_turn. Fixed seats `(1,1)` / `(6,6)` are superseded on the live duel path (`skip_deploy` test fixture only). #31 1-deep S+W / N+E border halves are the previous Locked zone baseline and are no longer the live legal cells.
- **15×15** ship board (`BOARD_SIZE`), per-tile **integer elevation** + **terrain_type** from the Koliseo tags (`size: [15,15]`, default Crosshaven). `paint_only` never affects pathing, LoS, or MP. Proto `board_size` 8 keeps the 8×8 crop of Mauro’s 12×12 (origin row 2, col 2; all 64 cells) plus **seeded noise** z 0–3. Proto `board_size` 12 is that full token grid (not a Crosshaven map). No invented walls. Spell LoS stays unused (no height mods).
- 80 HP, 6 AP / 3 MP refilled at turn start
- Walk: dest-click only. Cost = dest terrain MP + uphill integer z. Terrain MP: Ground 1, Mud 2, Water 2, Lava impassable. Uphill +1 per z step (units of 1; no 0.5 half-steps); downhill 0. Max climb 1 / drop 2 (no z1→z3 hop); ortho-only. CombatSim runs a weighted pathfinder; legal cells = reachable with remaining MP (pool 3). Facing follows each ortho hop of that path; **final facing = last hop direction**. Manual face intent stays for standing turns. `legal_intents` enumerates walks whenever leftover **MP > 0**, regardless of remaining AP. Phase A flat Manhattan / H-first expansion is superseded. Snapshot `tiles` exposes terrain + elevation **ints** for Godot; board chrome stays Godot-side.
- Advance: dest-click teleport, **3 AP / 0 MP**, instant snap. Range gate is **exactly the 4 ortho neighbors** (N/S/E/W): Chebyshev 1 and Manhattan 1, cardinal only. Manhattan 2 and any diagonal / (1,1) are rejected. Dest must pass the **same stand-on gates as walk** (walkable, not occupied, not lava, climb≤1 / drop≤2 via the shared `WalkBoard.stand_on_gate` helper). Gate only — no terrain+elev MP spend. Illegal dest refunds; `legal_intents` / `preview_cast` reflect the gates. Ironjaw-only. No MP spend (`submit` does not zero leftover MP). After Advance, leftover MP still walks. **Facing unchanged** (does not auto-face). Client path ignored. After resolve, client clears Advance so walk chrome returns while MP>0. Walk / Esc cancel Advance aim (right-click still faces).
- Spell range stays Chebyshev for Strike / Mark Shot / Detonate / Shoulder / Crush. Advance range is cardinal (the 4 ortho neighbors).
- Hit bands (Locked, `backend/hit_bands.gd`): 1=90%, 2–3=80%, 4–5=75%, 6–8=70%, 9=65%, 10=60%, 11=55%, 12=50%, 13=45%, 14=40%. The Chebyshev 9–14 soft-block is lifted. Dist past 14 has no invented percent. Out of spell max range stays illegal. Kit damage and ranges are unchanged.
- Damage pipeline: Base × CritMult × Passive × (1+Mastery/100) × (1−Resist/100) × Facing. Mastery 0, CritMult held at **1.0** (crit *roll* off). WindMod omitted (not invented as 1.0).
- Facing front/side ×1.00, back ×1.20
- Miss keeps AP/MP, refunds engine, no engine gain. Detonate miss retains Marks. Crush miss retains Impact.
- Illegal cast reject + refund
- **A01 Locked:** Marks live on the target (cap 5). Mark Shot +1 on connect. Detonate reads/consumes that stack.
- Detonate / Shoulder / Crush / Advance / Strike / Mark Shot values above
- Advance / Shoulder / Crush are Ironjaw-only. Detonate / Mark Shot are Kestrel-only.
- Kestrel then Ironjaw
- **Locked Stun (A′):** Stun 1 blocks move + cast + face. When that seat's turn starts, CombatSim auto-resolves `end_turn` (player never presses End Turn). `legal_intents` has no move/cast/face (auto path only). `stun_remaining` on the unit; decrement at start of that unit's turn after setting stunned-this-turn so the stunned seat's turn is the one that is skipped. HUD greys Walk/Face/spells and shows a STUN badge. Client shows a skip banner/log from that event and does not re-implement the skip.
- **Director Locked Shoulder:** occupied dest = no-move + `push_blocked` (hard body-block, no stagger; Impact stays the hit +1). Walkable empty dest pushes for **+1 Impact**. OOB / truly blocked (not lava) = bounce + stagger **4 HP** (+ **1 MP** if current MP ≥ 1) for **+2 Impact only** (no stack with +1). Lava is hazardous for the forced push: the unit lands and gains **Burn**. Voluntary walk onto lava stays impassable. Client toasts **PushBlocked**, **Bounce +2 Impact** (not also +1), clean Shoulder **+1 Impact**, or **Lava - Burn** (not Bounce). It does not hop on block or bounce, and still plays hit/Impact feedback. Burn icons paint from `burn_remaining` on the host snapshot (no client tick).
- **Director Locked Burn:** 4 HP at the start of the victim’s turn, duration 2. Re-apply refreshes duration and does not stack. Continues after leaving lava. Death check after each tick. Snapshot `burn_remaining` plus `status`/`burn` events feed Godot chrome. The dedicated host process owns that CombatSim state; clients only hydrate it.

## Open (not Locked) — deploy leftovers

- Fog / hidden enemy during deploy
- Deploy timer
- Multi-unit rosters

Do **not** invent those. Main (`main.tscn` / `board_view.gd` / `ui/hud.gd`) binds `place_unit` / `ready_seat` / `legal_deploy_cells` / `deploy_zone_cells` / `can_ready` / `snapshot().phase`. `scenes/proto_deployment_board.tscn` stays reference only.

## Proposed (not Locked)

- **Proposed random deploy blobs (shipped live):** per match, each seat gets a seed-sampled ~6-cell blob (2×3 rectangle or organic contiguous blob). Interior cells are allowed. Opening Chebyshev between the two zones is at least **3** (sampler prefers 4–6). Overlapping blobs and same-edge camping (both zones hugging the same map edge) are rejected. `legal_deploy_cells` / `deploy_zone_cells` expose the sampled cells. This replaces the #31 fixed border-half zones on the live Phase A path.
- ~1.0s client-only seat handoff pause + turn banner on End Turn. CombatSim still advances the seat immediately. The host 30s clock keeps ticking during that banner (both peers see the same remaining).
- 30s visible seat clock, host-owned (`CombatSim.TURN_TIME_LIMIT`, packed as `turn_time_remaining` / `turn_time_limit` on every snapshot). At 0, host auto End Turn (same as the button). Guest hydrates; no client-authoritative clock. Walk hop animations do **not** pause the clock. Advance does not hop. Online HUD shows **Your Turn** / **Opponent's Turn** from `local_seat` vs `active_seat`.
- Pre-cast **HIT %** HUD/aim chrome for Mark Shot / Strike / Detonate / Shoulder / Crush (the bands themselves are Locked). Marks/Impact pips read from the snapshot.
- Hover / long-press **attack cards** on spell buttons (including **Mark Shot** and **Advance**), formatted from read-only `CombatSim.preview_cast` (costs, range, on-hit / on-miss, `sample_damage` with CritMult 1.0 × live Facing, Locked `hit_chance`). Detonate samples **current Marks** when M≥1. At M=0, `legal=false`, `reason=needs_marks`, and `sample_damage` is null; the card **leads with “needs Marks”** and does not lead with sample 6; notes/`on_connect_text` still explain 6+6×M. Crush shows **Stun 1 (Locked A′)** when `would_stun`. Advance has no HIT % / sample. Resist 0 is labeled provisional/Open if the preview notes it. CombatSim does not own the card.
- Action bar **wraps** at 960×720 so kit labels do not overlap.
- **Locked Stun (A′) skip banner** when CombatSim auto `end_turn`s a stunned seat (presentation of the sim event; client does not auto-submit).

## Omitted (not silent defaults)

- Login / MultiplayerSynchronizer (listen-host ENet, the dedicated process, and the Locked-roster queue are in; see below)
- Pulse, reconnect, relay
- Step-shot, Rain, Longbow, Avalanche
- `open_can_wait` kit edges (Nightfold miss refund, Intercept multi-guard, Neutral primary scope, AoE vs Invisible, Heartstop immunity/heal-overflow/shield stack, Water Ward 24 rider, cone/ward masks). The workbook v0.6 numbers for Mender / Gloam / Bastion are in. Card spells resolve in CombatSim. Chrome does not stub them as `backend_pending`.
- Crit roll, Longshot, Momentum, Residue, Blends, Gust / WindMod
- Weapon fumbles, dual loadouts, WP/PW

## A03–A07 (provisional Open, not Locked)

These are playable stubs so the duel runs. They are **not** approved defaults. **A01 Marks-on-target is Locked** (Marks live on the target, cap 5; Detonate reads/consumes that stack) and is no longer listed as Open. **A02 walk is Locked** (dest-click weighted pathfinder; cost = dest terrain MP + uphill elevation; facing follows each hop). Phase A flat Manhattan / H-first is superseded. **Advance is Locked** (4 orthogonal neighbors only — Chebyshev/Manhattan 1 cardinal dest-click teleport, 3 AP / 0 MP; facing unchanged; same stand-on gates as walk). **Locked Stun (A′)** (blocks move + cast + face; auto `end_turn` on turn start) and **Director Locked Shoulder** (occupied = `push_blocked`; OOB / truly blocked = bounce + stagger and +2 Impact; lava land applies Burn) are no longer Open. A06 still notes the adjacent-Impact stub. **Ask before inventing** further defaults. Do not invent Step-shot, Gust, Mark Shot +5, height→hit/facing/LoS, stairs/ramps/flying, or other Opens.

| ID | Stub used here |
| --- | --- |
| A03 | Gust omitted. WindMod omitted (not invented as 1.0). Weather = Calm. |
| A04 | No crit roll. No elemental riders. |
| A05 | Resist 0, damage `roundi` to nearest int. WindMod omitted from the formula. **Locked Stun (A′):** Stun 1 blocks move + cast + face (`stunned_cannot_act`); auto `end_turn` on that seat's turn start (player never presses End Turn); decrement at start of that unit's turn after setting stunned-this-turn so the stunned seat's turn is skipped. **Director Locked Shoulder:** occupied dest = `push_blocked` (no bounce/stagger; Impact stays +1). Walkable empty dest pushes for +1 Impact. OOB / truly blocked (not lava) = bounce + stagger 4 HP (+1 MP if current MP ≥ 1) for +2 Impact only. Lava forced-push lands and applies **Burn** (4 HP at the victim’s turn start, duration 2, refresh no stack). Voluntary walk onto lava stays impassable. |
| A06 | Advance dest-click teleport, exactly the 4 ortho neighbors (N/S/E/W; Chebyshev 1 and Manhattan 1, cardinal only). Manhattan 2 and any diagonal / (1,1) are rejected. 3 AP / 0 MP, instant snap. Dest uses the same stand-on gates as walk (walkable / occupied / lava / climb≤1 / drop≤2). Gate only — no MP spend. `submit` does not zero leftover MP; leftover MP still walks (`legal_intents` is mp>0, not AP). Adjacency = Chebyshev 1 after landing. Facing unchanged (Advance does not auto-face). |
| A07 | Back = 90° rear cone (facing axis opposite and dominant), not exact-rear-tile-only. |

## Tests

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
godot --headless --path . -s res://tests/run_elevation_chrome_tests.gd
godot --headless --path . -s res://tests/run_elevation_proto_tests.gd
godot --headless --path . -s res://tests/run_deployment_proto_tests.gd
godot --headless --path . -s res://tests/run_host_validate_tests.gd
godot --headless --path . -s res://tests/run_net_session_tests.gd
godot --headless --path . -s res://tests/run_class_select_tests.gd
godot --headless --path . -s res://tests/run_class_picker_tests.gd
godot --headless --path . -s res://tests/run_koliseo_maps_tests.gd
godot --headless --path . -s res://tests/run_matchmaking_tests.gd
godot --headless --path . -s res://tests/run_event_hooks_tests.gd
```

## How to playtest SELECT_CLASS → dedicated match

**Transport:** Godot 4 **ENet** (`ENetMultiplayerPeer` + MultiplayerAPI RPC). Same choice as listen-host: desktop / LAN, not HTML5. WebSocket stays the later HTML5 option; the Intent RPC surface does not change. Moving the server to another machine is the join address, not a new protocol. No login. Listen-host stays a fixed Kestrel / Ironjaw duel.

The dedicated process is not a fighter. Each player confirms a class, then joins the queue. The first two confirmed players become a match. Seat 0 is whoever queued first; seat 1 is whoever queued second. Allowlist: **kestrel**, **ironjaw**, **mender**, **gloam**, **bastion**. HUD paints Pulse / Umbral / Shades / Aegis from the snapshot (`unit.resources` mirrors those fields). Snap Wall paints `blocked_tiles` entries `{x, y, pos, turns}` and `snap_wall` events (`to`, `cells`). There is no `walls` key. Card spells resolve in CombatSim. Chrome does not stub them as `backend_pending`. Nightfold stays gated (`open_can_wait`).

RPC bind:

- `NetSession.select_class(class_id)` → `rpc_select_class` → `rpc_class_result` `{ok, class_id, reason}`
- `rpc_enqueue` → `rpc_queue_result` `{status, reason}` where status is `waiting`, `matched`, or `rejected`
- `rpc_match_assigned` `{type: "match_assigned", seat, class_id, classes, match_id}` then the board hydrates from the snapshot. `NetSession.match_assigned()` is true when the match is live
- Statuses on `connection_changed`: `class_selected`, `class_rejected`, `waiting`, `queue_rejected`, `matched`

**Three processes** (lobby scene). The dedicated host is not a fighter. `--class` accepts any allowlist id.

```bash
# Machine B — dedicated host (no seat). Leave it open.
godot --path . --position 40,40 res://scenes/online_lobby.tscn -- --dedicated 7777

# Machine A — first client
godot --path . --position 40,420 res://scenes/online_lobby.tscn -- --queue 127.0.0.1:7777 --class kestrel

# Machine C — second client. Board opens when the pair matches.
godot --path . --position 1000,40 res://scenes/online_lobby.tscn -- --queue 127.0.0.1:7777 --class ironjaw
```

Other pairs use the same two client lines with `--class mender`, `--class gloam`, or `--class bastion`. Machine B should read `Match m1 — seat 0 <first class>, seat 1 <second class>`. After deploy, the kit bar is that seat's Locked card ids (Mend / Cut / Bash, and so on). Nightfold is not on the bar.

**Editor F5** opens the class select screen. Hot-seat: P1 picks, P2 picks, `main.tscn` starts with those class ids on a random 15×15 arena. Online without flags: run the dedicated host, then two clients with no `--class` or `--queue` and use the screen (Online, `127.0.0.1:7777`, a class, Queue). Online stays on Crosshaven.

```bash
# Dedicated host. No picker.
godot --path . --position 40,40 -- --dedicated 7777

# Two clients. Class select is the main scene.
godot --path . --position 40,420
godot --path . --position 1000,40
```

The `--queue` / `--class` lines above stay the dev shortcut and skip the screen.

Buttons: Machine B presses **Host dedicated**. Machine A and Machine C press a class, then **Join queue** (`127.0.0.1` / `7777`). **Host match** / **Join match** are the old listen-host duel and ignore the class pick.

Same computer: `127.0.0.1`. On a LAN, use Machine B’s IP. UDP **7777** must be reachable. Seat 0’s **New Match** asks the server to reset with those same class ids. A dropped client is a stub: that seat stays reserved. No reconnect.

Verify:

```bash
godot --headless --path . -s res://tests/run_class_select_tests.gd
godot --headless --path . -s res://tests/run_net_session_tests.gd
godot --headless --path . -s res://tests/run_matchmaking_tests.gd
```

## How to playtest online (listen-host, optional)

**Listen-host** — one window is Kestrel (seat 0) **and** the CombatSim authority. One guest is Ironjaw. Same ENet host core as `--dedicated`.

**Two instances, one duel:**

```bash
# Window A — host (Kestrel / seat 0). Owns seed + RNG.
godot --path . --position 40,40 -- --host 7777

# Window B — guest (Ironjaw / seat 1). Submits Intent only.
godot --path . --position 1000,40 -- --join 127.0.0.1:7777
```

Or open `scenes/online_lobby.tscn`, **Host match** on one window and **Join match** (`127.0.0.1` / `7777`) on the other. **Local hot-seat** on that lobby returns to the unchanged single-window path.

Play (dedicated or listen-host): each seat places in its deploy blob and presses its Ready. After both Ready, only the active seat can walk / cast / End Turn. **Kit chrome stays on your fighter** (the class on `local_seat`; listen-host is still Kestrel then Ironjaw) even while watching. Both windows show the host 30s TIME clock from `turn_time_seconds` (ceil of `turn_time_remaining`, limit 30, `turn_timer: "host"`) and **Your Turn** / **Opponent's Turn** (`local_seat` vs `active_seat`, also `net.local_seat` / `net.active_seat`). Clients never roll and never tick the clock. Authority expiry auto End Turns — chrome only paints. On listen-host, New Match is the host window. On a dedicated server, New Match is seat 0’s request.

Listen-host LAN: replace `127.0.0.1` with the host machine’s IP. UDP **7777** must be reachable. Anonymous — anyone who can reach the port joins as Ironjaw (one guest).

Headless contracts: `run_host_validate_tests.gd` + `run_net_session_tests.gd`.

## How to playtest SELECT_CLASS → dedicated match

Allowlist: `kestrel` | `ironjaw` | `mender` | `gloam` | `bastion`. The dedicated host is not a fighter and does not boot the default pair. Each player confirms a class, then joins the queue. Any two Locked classes pair. Seat 0 is the first queued session unless that session is bound to the other transport seat. Kits follow the chosen `class_id` (two of the same class is legal). Advance stays **3 AP / 0 MP**, four orthogonal neighbors. Hot-seat and the listen-host buttons still start Kestrel vs Ironjaw.

Mender, Gloam, and Bastion use workbook v0.6 (`data/select_class_lock_kits_v0.6.json`). Proto is **80 HP / Mastery 0 / Resist 0** with the Locked combat refill (**6 AP / 3 MP**). Umbral is 0–4. Shades max 2. Ambush miss does not teleport, keeps Shade and Invisible, and spends 4 AP. Aegis Break hit clears all Aegis; a miss spends 0. Snap Wall is one blocked tile for 2 turns (walk, and a future Gust) only while a Bastion is in the match. Nightfold and the other `open_can_wait` edges reject instead of guessing.

**Three windows** (lobby scene):

```bash
# Window A — dedicated host. No class. Leave this window open.
godot --path . --position 40,40 res://scenes/online_lobby.tscn -- --dedicated 7777

# Window B — pick a class, then queue.
godot --path . --position 40,420 res://scenes/online_lobby.tscn -- --queue 127.0.0.1:7777 --class gloam

# Window C — any other Locked class. The board opens when the pair matches.
godot --path . --position 1000,40 res://scenes/online_lobby.tscn -- --queue 127.0.0.1:7777 --class bastion
```

Window A should read `Match m1 — seat 0 Gloam, seat 1 Bastion`. Windows B and C open `main.tscn` on those seats. Swap the `--class` flags and the seats follow the new ids.

Buttons, no CLI: window A presses **Host dedicated**. Windows B and C press one of **Kestrel**, **Ironjaw**, **Mender**, **Gloam**, **Bastion**, then **Join queue** (`127.0.0.1` / `7777`). **Host match** / **Join match** are the listen-host duel and ignore the class pick.

### Godot chrome — RPC and snapshot fields

Client → dedicated authority:

| Field | RPC | Args |
| --- | --- | --- |
| `select_class` | `rpc_select_class` | `class_id: String` |
| `queue` | `rpc_enqueue` | none |

Authority → client:

| Field | RPC | Args |
| --- | --- | --- |
|  | `rpc_class_result` | `{ok, class_id, reason}` |
|  | `rpc_queue_result` | `{status, reason}` — `status` is `waiting`, `matched`, or `rejected` |
| `match_assigned` | `rpc_match_assigned` | `{type: "match_assigned", seat, class_id, classes, match_id}` after the state push |
|  | `rpc_push_state` | packed snapshot (existing) |

Reject reasons: `invalid_class`, `class_required`, `already_queued`, `already_matched`, `not_dedicated`, `no_seat`.

`reset_match` config (authority): `classes: ["gloam", "bastion"]` or `seat_classes: {0: "gloam", 1: "bastion"}`. Unknown ids fall back to Kestrel then Ironjaw. Snapshot copies them on `match_config.classes` and `match_config.seat_classes`.

`snapshot.prematch`: `phase` is `SELECT_CLASS`, `MATCHMAKING`, or `MATCH`; `local_class_id`, `local_queued`, `opponent_queued`, `match_live`. `snapshot.server_mode` is `dedicated` or `host`. `snapshot.net.dedicated` stays true on a dedicated client's hydrated view.

Unit fields and `unit.resources`: `pulse` (Mender, 0–6), `umbral` (Gloam, 0–4), `shades` (max 2), `aegis` (Bastion, 0–4), plus `mastery` and `resist` at 0. Snap Wall cells are `snapshot.blocked_tiles` (`x`, `y`, `pos`, `turns`) while a Bastion is in the match, else `[]`. The cast event type is `snap_wall` (`to` and `cells`). There is no `walls` event.

`open_can_wait` (submit reason, not resolved): Nightfold; Intercept when more than one Bastion could guard; Neutral primary scope; AoE versus Invisible; Heartstop immunity refresh, heal overflow, and shield stacking; the Water Ward 24 rider (Ward base stays 20); cone/ward masks.

Headless: `godot --headless --path . -s res://tests/run_matchmaking_tests.gd`.

## Live elevation chrome (Phase A cutover)

Godot chrome on `main.tscn` paints snapshot terrain + elevation. **CombatSim owns walk costs** ([#36](https://github.com/maurogp12/stasiumxii/pull/36) weighted pathfinder). `snapshot().tiles` is the live payload — `reset_match` seeds the Koliseo **15×15 tags** (default Crosshaven; see below). The view paints the Tiled PNGs on those diamonds. A `Camera2D` zooms the 15×15 diamond into the 960×720 play band; middle-mouse pans. Walk dests are whatever `legal_intents` returns. Do **not** invent height→hit / facing / LoS.

| Chrome | Source |
| --- | --- |
| Tile fill + `G/M/W/L` + elevation label | `board/snapshot_tiles.gd` reads `tiles` / `terrain_type` / `elevation` / mud-water-lava cell lists |
| Walk highlights | `CombatSim.legal_intents` move dests only (`SnapshotTiles.walk_dests`) |
| Z-sort / iso lift | `board/visual_sort.gd` — VIEW only |
| HUD legend | Ground 1 / Mud 2 / Water 2 / Lava under the turn line |
| Hit bands / Face / deploy chrome | Unchanged (no height mods) |

**How to test live elevation chrome:** An empty `map_id` (dev shortcuts, and the first board before a hot-seat roll) shows the Crosshaven isometric tiles (not all Ground 0). Hot-seat **New Match** rolls another arena, so a second press can change terrain; the same `map_id` keeps that map’s tag z. After both Ready, cyan walk tiles are only sim-legal dests. The board fits 960×720 by camera zoom; middle-mouse pans. Face N/E/S/W and deploy chrome stay as they are. Headless: `godot --headless --path . -s res://tests/run_elevation_chrome_tests.gd`.

## Phase A demo map (proto `board_size` 8 — Director-stamped Locked 8×8 crop + seeded noise elev)

**Ship board is 15×15.** The default ship map is Crosshaven. Hot-seat rolls Crosshaven, Brinewake, Slagcrown, Windmere, or Stormspire uniformly (`map_id`) from the same tags schema. Empty `map_id` stays Crosshaven. Online does not share a map pick. This crop is proto-only (`MatchConfig.board_size` 8). Terrain is fixed in `MatchFlow.phase_a_demo_tiles()` (`PHASE_A_DEMO_TILES`) and applied when `board_size` is 8 (same terrain on `skip_deploy` unless `flat_board`). **Elevation is not the crop z.** Each proto reset generates z from `seed` (override with `MatchConfig.seed` / `elev_seed` for fixtures and replay). Smooth value noise → integer z 0–3 (z1–z4), preferring contiguous neighbors and avoiding checkerboard 0/3. `snapshot().tiles` exposes terrain + elevation **ints** on all 64 cells; `snapshot.elev_seed` stores the seed. Deploy still rejects lava (`not_walkable`); no elevation MP on place. No height→hit / facing / LoS. Ship matches ignore this crop and load `art/maps/arena_colosseum_v2/tiled/{arena}_15x15_tags.json` when its size is `[15,15]` (default `crosshaven`; sibling `.tmx` is isometric art, not a blocker source). A replacement tags file with the same schema is picked up by that hook; the sim does not invent cells if the file is missing or the size does not match. Explicit `board_size` 12 seeds Mauro’s token grid (`mauro_12`) and is proto only, the same class as the 8×8 crop.

**Crop origin:** row **2**, col **2** on Mauro’s 12×12 (row-major tokens like `0z1`).

**Locked mapping:** terrain digit 0 Ground / 1 Mud / 2 Water / 3 Lava (costs unchanged: G1 / M2 / W2 / Lava impassable). Crop z ladder (source tokens only): z1→0, z2→1, z3→2, z4→3. Live z is **seeded noise**. Max climb 1 / drop 2 (no z1→z3 hop).

Window contains Mud, Water, Lava. Crop-source letters + integer z (z is **not** applied live — noise replaces it):

```
     0  1  2  3  4  5  6  7
   0 G3 G3 M3 W2 L2 W1 W1 M1
   1 M3 G3 M2 W2 L2 L1 L1 M0
   2 W3 M3 M2 W2 L2 L1 W1 M0
   3 W3 W2 W2 W2 W2 W2 M1 G1
   4 W1 W1 W2 W2 W2 M2 M2 G2
   5 M1 M1 M1 M1 M2 M2 G3 G3
   6 G0 G0 G1 M1 G1 G2 G3 G3
   7 G0 G0 G0 G0 G1 G1 G2 G3
```

Tokens (same window, Mauro `NzK` form):

```
0z4 0z4 1z4 2z3 3z3 2z2 2z2 1z2
1z4 0z4 1z3 2z3 3z3 3z2 3z2 1z1
2z4 1z4 1z3 2z3 3z3 3z2 2z2 1z1
2z4 2z3 2z3 2z3 2z3 2z3 1z2 0z2
2z2 2z2 2z3 2z3 2z3 1z3 1z3 0z3
1z2 1z2 1z2 1z2 1z3 1z3 0z4 0z4
0z1 0z1 0z2 1z2 0z2 0z3 0z4 0z4
0z1 0z1 0z1 0z1 0z2 0z2 0z3 0z4
```

## Phase B+ elevation prototype

**Reference only.** Live CombatSim walk is the Locked cutover (per-tile integer elevation + terrain, weighted pathfinder). Keep `proto/elevation` and `scenes/proto_elevation_board.tscn` as the chrome sandbox. Do not import `proto/elevation` from CombatSim. Live paint is the Director crop above; Godot reads `snapshot().tiles` and paints it. Proto cost math may still mention Proposed half-steps — live Locked z is integer only.

Open (do **not** invent): height→hit/facing/LoS, stairs/ramps/flying. Hit bands / facing / spell LoS stay unchanged — no height mods.

Open `scenes/proto_elevation_board.tscn` (or `godot --path . res://scenes/proto_elevation_board.tscn`). Click a cyan reachable tile to spend MP along the cheapest ortho path. **Refill MP** / **Reset board** are prototype chrome.

| Rule | Proposed starter |
| --- | --- |
| Terrain MP | Ground 1, Mud 2, Water 2, Lava impassable |
| Uphill | +1 MP per full elevation level; a half-level climb (0.5) counts as +1 |
| Downhill | +0 MP |
| Max climb | 1.0 |
| Max drop | 2.0 |
| Edges | Ortho-only (no diagonal) |
| Proto MP pool | 6 (Proposed play pool so mud+climb is reachable; not a Locked replacement for Phase A’s 3) |
| Z-sort | VIEW function of iso world Y + elevation offset (`ProtoVisualSort`). **Not** the gameplay elevation source — that is `BoardTileData.elevation` / `ElevationCost`. |

Modules (all under `proto/elevation/`; live CombatSim uses copies under `backend/`, not these files):

1. `TerrainDef` — id, display name, base_mp, walkable
2. `BoardTileData` — grid_pos, elevation, terrain_type, optional walkable override
3. `ElevationCost` — Δelev → climb/drop MP + legality vs max climb/drop
4. `ProtoMoveSim.step_cost` — dest terrain MP + climb MP; rejects non-ortho
5. `ProtoMoveSim.validate_move` — in-bounds, walkable, not occupied, climb/drop ok, MP remaining
6. `ProtoMoveSim.reachable` — Dijkstra / uniform-cost on ortho edges
7. `ProtoMoveSim.reconstruct_path` — cheapest MP path
8. `scenes/proto_elevation_board.tscn` — terrain paint, elevation labels, reachable highlight, click-to-move
9. `ProtoVisualSort` — `z_index` / draw offset from iso Y + elevation (visual-only)

## Phase B+ deployment prototype

**Prototype only. Reference — live Phase A deploy is Locked on CombatSim / MatchFlow.** Keep this scene as the chrome sandbox. Do not import `proto/deployment` from CombatSim. Live `reset_match()` starts in DEPLOYMENT; `(1,1)` / `(6,6)` are skip_deploy fixtures only. Proto still has no networking, no hidden fog, no deploy timer.

Open `scenes/proto_deployment_board.tscn` (or `godot --path . res://scenes/proto_deployment_board.tscn`). **Simultaneous** deploy: both seats may place / reposition at once on their opposite half of the **1-deep map border ring**. Each side has its own **Ready** control. When **both** are ready, positions lock and the scene shows **Turn 1** chrome (stub — CombatSim is not wired).

This stamp **supersedes** sequential hot-seat and the opposite 2×3 boxes.

### Proposed rules

| Rule | Proposed starter |
| --- | --- |
| Seats | Simultaneous: both players place / reposition at once (hot-seat clicks; no netcode) |
| Roster | One fighter per side (Kestrel / Ironjaw stand-ins) |
| Board | 8×8 |
| Legal cells | **1-deep border ring** only (any cell with `x=0`, `y=0`, `x=7`, or `y=7`). Interior cells reject `outside_zone` |
| 1v1 split | Opposite halves of that ring. **Seat 0 (P1): south + west. Seat 1 (P2): north + east.** Corners belong to the north/south edge: NW+NE → P2, SW+SE → P1. Halves never share an edge, so same-edge camp is impossible |
| Actions | Place / reposition on a legal zone cell; Ready locks that side |
| Ready gate | Ready disabled until that side’s required unit is placed |
| Start | Both ready → lock positions → `start_match` → `MatchPhase.TURN_1` |
| Combat chrome | Walk / combat / end-turn disabled until both ready |
| Walkable | Reuses occupancy + optional `ProtoMoveSim.is_walkable` (lava / override). **No elevation MP / climb cost on deploy** |

Modules (all under `proto/deployment/`, unused by the Phase A combat path):

1. `MatchPhase` — proto-local `DEPLOYMENT` / `TURN_1`
2. `DeploymentZone` — `player_id` + `Array[Vector2i]` cells; `border_ring()` + `opposite_half_ring()` (S+W vs N+E)
3. `DeploymentManager` — simultaneous ready flags, selected unit, place/reposition, both-ready → `start_match`
4. `can_deploy_unit(unit, cell)` — phase, zone membership, in-bounds, walkable, not occupied (no turn-order gate)
5. `scenes/proto_deployment_board.tscn` — both half-rings highlighted; click a green S+W cell to place Kestrel or a red N+E cell to place Ironjaw
6. Ready P1 / Ready P2 — each disabled until that side’s required fighter is placed
7. After both ready: lock positions, emit start, show Turn 1 label (CombatSim not wired)

## How to test Locked deploy (CombatSim)

Headless: `godot --headless --path . -s res://tests/run_combat_tests.gd`. Live `reset_match()` starts DEPLOYMENT (no `(1,1)` / `(6,6)`). Zones are seed-sampled ~6-cell blobs. `place_unit` / `ready_seat` reject OOB, unclaimed / other-blob (`outside_zone`), and occupied. Interior cells inside a blob are legal. Both Ready locks the confirmed cells and starts Turn 1; kit tests still pass after that. `skip_deploy` or an explicit `kestrel_pos` / `ironjaw_pos` skips to combat for fixtures. Main chrome binds `legal_deploy_cells`, `deploy_zone_cells`, `can_ready`, Ready P1 / Ready P2, and `snapshot().phase`.

## How to test live deploy chrome (main.tscn)

1. Open `main.tscn` (or run the main scene). Phase is **DEPLOYMENT**. Two seed-sampled ~6-cell blobs are lit (green seat 0, red seat 1). Walk / kit casts / Face / End Turn / TIME are hidden. Ready P1 / Ready P2 start disabled.
2. Click a **green zone** tile — Kestrel places. Click another green zone tile to reposition. Ready P1 enables.
3. Click a **red zone** tile — Ironjaw places at the same time. Ready P2 enables.
4. Click an **unclaimed** tile — coach: outside this side’s deployment zone. Click the other seat’s blob with that fighter selected — coach: other side’s deploy zone. An interior cell inside your blob is legal.
5. **Ready P1** then **Ready P2**. Phase leaves DEPLOYMENT. Deploy chrome hides. Walk / kits / Face / End Turn / TIME return. Turn 1 banner, Kestrel acts first with Locked kits from the confirmed cells.
6. **New Match** returns to DEPLOYMENT with a new seed’s blobs. `scenes/proto_deployment_board.tscn` stays the #31 border-ring reference sandbox.

## How to test the deployment prototype

1. Open `scenes/proto_deployment_board.tscn`. Walk / Combat / End Turn start disabled. Both Ready buttons start disabled.
2. Click a **green south/west ring** tile — Kestrel places. Click another S+W ring tile to reposition. Ready P1 enables. P2’s red N+E ring stays lit.
3. Click a **red north/east ring** tile — Ironjaw places (no need to wait for P1 Ready). Ready P2 enables.
4. Click an interior tile or the other seat’s half — coach shows **outside_zone**. The last legal cell stays.
5. **Ready P1** — P1’s half locks. Ironjaw can still move until Ready P2.
6. **Ready P2** — phase flips to **TURN 1**. Positions lock. Walk / Combat / End Turn enable as stubs (they do not call `CombatSim`).

## How to test aim chrome

1. Run the main scene. Select **Mark Shot**: Chebyshev 2–7 ring + **HIT 75%** vs default Ironjaw (range 5). Hover another in-range cell to see that cell’s Locked % (through 40% at dist 14). Walk chrome stays off. Advance / Walk never show HIT %. Dist past 14 shows no percent. A cast outside the spell’s max range stays illegal.
2. After a Mark hits, select **Detonate**: 1–4 ring + HIT %.
3. Kit buttons stay class-gated (Kestrel: Mark Shot / Detonate; Ironjaw: Advance / Strike / Shoulder / Crush). Crush stays disabled below 2 Impact.

## How to test attack hover cards

1. Hover (or long-press) **Mark Shot**: card is `preview_cast` — 2 AP / 0 MP, range 2–7, hit/miss kit lines, Locked HIT % for the current dest, and `sample_damage` from CritMult 1.0 × live Facing. No +5. Enabled buttons must show the card (same path as Detonate).
2. Hover **Detonate** at **0 Marks**: card **leads with “needs Marks”**. Keep costs / range / HIT %. Do not lead with sample 6. `preview_cast` is `legal=false`, `reason=needs_marks`, `sample_damage` is null; on-hit still explains 6+6×M.
3. After Marks land, hover **Detonate**: sample uses **current Marks** (`6+6*M`). Miss keeps Marks.
4. End Turn. Hover **Advance**: orthogonal-neighbor teleport, no HIT %, no sample. **Shoulder** passes through Director Locked Shoulder (occupied `push_blocked`; OOB / truly blocked bounce + stagger for +2 Impact; lava land applies Burn). **Crush** at 4 Impact shows **Stun 1 (Locked A′) this cast**; at 0–2 Impact that flag stays off.
5. At **960×720**, Ironjaw's seven action buttons wrap instead of overlapping. Face N/E/S/W stay usable.

## How to test walk-after-Advance and last-hop facing

1. End Turn so **Ironjaw** acts (6 AP / 3 MP).
2. **Cancel checklist:** Select **Advance** (purple tiles on the four neighbors, walk chrome off). Press **Walk** or **Esc** — selection returns to Walk, cyan walk tiles come back. Right-click a tile still faces (does not cancel).
3. Select **Advance** again and dest-click an orthogonal neighbor (N/S/E/W). The pawn snaps (no hops). Manhattan 2 and diagonal clicks are rejected. Advance deselects; walk tiles highlight from remaining MP. With e.g. 3 AP / 3 MP (or a second Advance to 0 AP / 3 MP), click a walk dest — it must be selectable and highlight.
4. Walk a multi-hop dest (e.g. two east then one south). The pointer faces **each** hop; after landing it faces the last hop. HUD Face matches. In-place Face N/E/S/W still works without moving.
5. Advance onto an orthogonal neighbor: position snaps, **facing is unchanged**. A diagonal dest does not move the pawn. Walk last-hop facing still applies after. No HIT % on Advance or walks.

## How to test Stun suppress and Shoulder bounce / PushBlocked

1. Get Ironjaw to **4 Impact** (Strike/Shoulder hits), then **Crush** Kestrel. **End Turn**. Kestrel's turn **auto-ends** (Locked A′ — player never presses End Turn). The HUD shows a **skip banner** (e.g. “Kestrel stunned — turn skipped”) and the coach line logs the event. Ironjaw acts again. Kestrel's card/pawn still show **STUN** while that skipped turn is served. After Ironjaw Ends again, Kestrel acts normally (Walk/Face/spells return). Move/cast/face never become legal on the stunned turn (`stunned_cannot_act`). The client does not press End Turn for the skip.
2. Shoulder Kestrel into the west edge (Ironjaw at (1,0), Kestrel at (0,0) facing E): toast **Bounce** plus **+2 Impact** (not also +1), Kestrel does not hop, 6 Earth + stagger **4 HP** (+ **1 MP** if they had MP) apply. Shoulder into an occupied dest still toasts **PushBlocked** with no stagger. A forced push onto lava toasts **Lava - Burn** (not Bounce) and paints a **BURN** badge with the snapshot duration. Walking onto lava is still rejected.

