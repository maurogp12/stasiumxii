# STASIUM XII

Phase A local hot-seat duel. Godot 4.7+. Combat lives in `CombatSim`; the board is a thin client.

## How to play

1. Open `project.godot` in Godot 4.7 or later and run the main scene.
2. **Locked deploy flow** on `main.tscn` before Turn 1, with **Proposed random blobs** shipped live: each seat gets a seed-sampled ~6-cell zone (2×3 rectangle or organic blob; interior cells allowed). Click a highlighted zone cell to `place_unit` (reposition until Ready). **Ready P1** / **Ready P2** enable from `can_ready` after that seat’s fighter is placed. Both Ready → lock → Turn 1 combat. Walk / kit casts / Face / End Turn and the 30s TIME clock stay hidden during DEPLOYMENT. Outside-zone clicks name the other blob or an unclaimed cell. No fog, no deploy timer, no networking.
3. After deploy, **Kestrel** (green, seat 0) always acts first, then **Ironjaw** (red).
4. Each combat turn starts with **6 AP** and **3 MP**. Spend them in any order, then **End Turn**. After deploy, a **30s TIME** countdown is visible on the HUD; at 0 the seat auto End Turns (same as the button). The clock keeps ticking during walk hop animations. Advance is an instant snap (no hops). Change `TurnClock.DURATION_SEC` to retune. The clock is hidden during DEPLOYMENT (no deploy timer).
5. Click a highlighted empty tile to **walk**. Dest-click only: `CombatSim` expands an orthogonal path (horizontal E/W first, then N/S). MP cost is Manhattan `|dx|+|dy|` from a pool of 3. The pawn animates one ortho tile at a time along the returned path and **faces each hop** (final facing = last hop). Manual **Face** still turns in place (0 AP). The client never sends `intent.path`. Walk is the default mode. After selecting a spell, press **Walk** or **Esc** to cancel back to walk chrome (right-click still faces; it does not cancel).
6. The action bar shows only the active kit (from `class_id` / `legal_intents`). Select a spell, then click a legal tile. At **960×720** the bar **wraps** (FlowContainer) so Walk / kit buttons / End Turn / New Match stay readable. **Face N/E/S/W** sit on a cardinal pad (N top, W left, E right, S bottom). **Strike / Mark Shot / Detonate / Shoulder / Crush range stays Chebyshev**. **Advance range is Manhattan 1–2** (diamond):
   - **Advance** (Ironjaw only) — dest-click teleport, **3 AP / 0 MP**. Range gate Manhattan 1–2. Instant snap (no hop animation). `CombatSim` ignores a client `intent.path`. Works at 0 MP. Does not zero leftover MP; after Advance, leftover MP still walks (`legal_intents` offers moves whenever MP > 0, even at 0 AP). No roll. +1 Impact if you land Chebyshev-adjacent to an enemy. After the snap, spell selection clears and walk chrome returns from `legal_intents` (remaining MP is still spendable). **Facing is unchanged** on Advance (no auto-face). Kestrel never sees Advance chrome and never gains Impact.
   - **Mark Shot** (Kestrel) — 2 AP, range 2–5 Chebyshev, 8 Air. Selecting it paints the Chebyshev 2–5 ring (walk chrome stays off). +1 Mark on the **target** if it hits.
   - **Detonate** (Kestrel) — 3 AP / 0 MP, range 1–6 Chebyshev. Needs 1+ Marks on that target. On hit: 6+6×M Air and **consumes** those Marks. On miss: Marks stay (AP/MP stay spent).
   - **Strike** (Ironjaw) — 3 AP, range 1, 16 Earth. +1 Impact on Ironjaw if it hits.
   - **Shoulder** (Ironjaw) — 2 AP / 0 MP, range 1. On hit: 6 Earth, +1 Impact, push the target 1 Chebyshev cell away along the line. **Locked Push (1):** if the dest is occupied or off-board, the target does not move; damage/Impact still apply; CombatSim emits `push_blocked`. Client toasts **PushBlocked** and does not hop; hit/Impact feedback still plays.
   - **Crush** (Ironjaw) — 4 AP / 0 MP, range 1. Needs/spends 2 Impact (spend on hit; miss retains Impact). 24 Earth on hit. **Stun 1** if Impact was **4 before** the spend. **Locked Stun (A′):** Stun 1 blocks move + cast + face (`stunned_cannot_act`). When that seat's turn starts, CombatSim **auto-resolves `end_turn`** — the player never presses End Turn. `legal_intents` is empty of move/cast/face (auto path only). HUD greys Walk/Face/spells, shows a STUN badge, and presents a **skip banner** from that auto `end_turn` event (the coach line is the log).
7. **Face** with the N/E/S/W buttons, or right-click a tile to face that direction (0 AP). Walks set facing from each hop (final = last hop). Advance teleport leaves facing unchanged. In-place Face is still available. Back hits deal ×1.20; front/side are ×1.00.
8. A **miss** still spends AP/MP and deals nothing. An **illegal** cast is rejected and refunded. The coach line under the board tells them apart.
9. While aiming **Mark Shot / Strike / Detonate / Shoulder / Crush**, the HUD shows the Locked **HIT %** for the current Chebyshev band before you click. Advance (no roll) and walks never show hit %. Bands are Locked: 1→90%, 2–3→80%, 4–5→75%, 6–8→70%.
10. **End Turn** (button or clock expiry) shows a ~1.0s client-only turn banner, then hands the seat to the other player (Proposed presentation; not a CombatSim rule).
11. First combatant to 0 HP loses. **New Match** resets from `CombatSim.reset_match()` (live path starts in DEPLOYMENT again).

## Architecture

| Piece | Role |
| --- | --- |
| `backend/combat_sim.gd` (autoload `CombatSim`) | Sole authority. `reset_match(config)` starts **DEPLOYMENT** (live). `place_unit(seat, cell)`, `ready_seat(seat)`, `can_place`, `can_ready`, `legal_deploy_cells(seat)`, `deploy_zone_cells(seat)`. `submit(intent)`, `legal_intents(seat)`, `snapshot()`, `aim_hit_preview(seat, spell, dest?)`, `preview_cast(...)`. Both Ready → lock → Turn 1 with spawn cells from confirmed positions. `skip_deploy` / `kestrel_pos` / `ironjaw_pos` skip to combat (tests/setup). Rolls and HP live here. |
| `backend/match_flow.gd` (`MatchFlow`, owned by CombatSim) | Locked phase + simultaneous ready. Proposed (shipped live) seed-based ~6-cell blob sampler; `legal_deploy_cells` / `deploy_zone_cells` come from those blobs. #31 border halves stay the previous Locked baseline. Proto stays reference. |
| `backend/event_bus.gd` (autoload `EventBus`) | Forwards events to listeners. Does not mutate combat. |
| `data/kits.gd` | Locked Phase A kit data only. |
| `ui/turn_clock.gd` | Proposed 30s seat clock. Client-only; expiry submits `end_turn`. |
| `board_view.gd`, `ui/hud.gd`, `units/pawn.gd` | Input and presentation. Live deploy chrome binds `place_unit` / `ready_seat` / `legal_deploy_cells` / `deploy_zone_cells` / `can_ready` / `snapshot().phase`. They also submit dest-clicks, animate walk hops, snap Advance teleports, paint enemy-spell range rings, show Locked hit %, grey Locked Stun (A′) chrome, toast PushBlocked, show Proposed hover/long-press attack cards, and run the Proposed combat timers. |
| `data/spell_tooltip.gd` | Proposed attack-card formatter. Reads `CombatSim.preview_cast` only. Does not invent kit numbers. |

Intents: `end_turn` | `face` | `move` | `cast` | `place` / `reposition` | `ready` / `confirm`. During DEPLOYMENT only `place` / `reposition` / `ready` are legal.

## Locked in this slice (GDD v0.2)

- **Locked deploy flow:** MatchPhase DEPLOYMENT before Turn 1. Simultaneous place/reposition (local both-ready; networking OFF). One fighter each. Ready gated on unit placed. Both Ready → lock positions → Turn 1 / combat on, spawning from the confirmed cells. During deploy: reject move/cast/face/end_turn. Fixed seats `(1,1)` / `(6,6)` are superseded on the live duel path (`skip_deploy` test fixture only). #31 1-deep S+W / N+E border halves are the previous Locked zone baseline and are no longer the live legal cells.
- 8×8 flat board, no walls, no LOS
- 80 HP, 6 AP / 3 MP refilled at turn start
- Walk: dest-click only, Manhattan `|dx|+|dy|` MP, pool 3, CombatSim expands ortho path, horizontal-first (E/W before N/S) tie-break. Facing follows each ortho hop; **final facing = last hop direction**. Manual face intent stays for standing turns. `legal_intents` enumerates walks whenever leftover **MP > 0**, regardless of remaining AP.
- Advance: dest-click teleport, **3 AP / 0 MP**, instant snap. Range gate **Manhattan 1–2** (diamond). Ironjaw-only. No MP spend (`submit` does not zero leftover MP). After Advance, leftover MP still walks. **Facing unchanged** (does not auto-face). Client path ignored. After resolve, client clears Advance so walk chrome returns while MP>0. Walk / Esc cancel Advance aim (right-click still faces).
- Spell range stays Chebyshev for Strike / Mark Shot / Detonate / Shoulder / Crush. Advance range is Manhattan.
- Hit bands 1=90%, 2–3=80%, 4–5=75%, 6–8=70%
- Damage pipeline: Base × CritMult × Passive × (1+Mastery/100) × (1−Resist/100) × Facing. Mastery 0, CritMult held at **1.0** (crit *roll* off). WindMod omitted (not invented as 1.0).
- Facing front/side ×1.00, back ×1.20
- Miss keeps AP/MP, refunds engine, no engine gain. Detonate miss retains Marks. Crush miss retains Impact.
- Illegal cast reject + refund
- **A01 Locked:** Marks live on the target (cap 5). Mark Shot +1 on connect. Detonate reads/consumes that stack.
- Detonate / Shoulder / Crush / Advance / Strike / Mark Shot values above
- Advance / Shoulder / Crush are Ironjaw-only. Detonate / Mark Shot are Kestrel-only.
- Kestrel then Ironjaw
- **Locked Stun (A′):** Stun 1 blocks move + cast + face. When that seat's turn starts, CombatSim auto-resolves `end_turn` (player never presses End Turn). `legal_intents` has no move/cast/face (auto path only). `stun_remaining` on the unit; decrement at start of that unit's turn after setting stunned-this-turn so the stunned seat's turn is the one that is skipped. HUD greys Walk/Face/spells and shows a STUN badge. Client shows a skip banner/log from that event and does not re-implement the skip.
- **Locked Push (1):** Shoulder into occupied/OOB = no-move + `push_blocked`; damage/Impact still apply. Client toasts **PushBlocked**, does not hop, still plays hit/Impact feedback.

## Open (not Locked) — deploy leftovers

- Fog / hidden enemy during deploy
- Deploy timer
- Multi-unit rosters

Do **not** invent those. Main (`main.tscn` / `board_view.gd` / `ui/hud.gd`) binds `place_unit` / `ready_seat` / `legal_deploy_cells` / `deploy_zone_cells` / `can_ready` / `snapshot().phase`. `scenes/proto_deployment_board.tscn` stays reference only.

## Proposed (not Locked)

- **Proposed random deploy blobs (shipped live):** per match, each seat gets a seed-sampled ~6-cell blob (2×3 rectangle or organic contiguous blob). Interior cells are allowed. Opening Chebyshev between the two zones is at least **3** (sampler prefers 4–6). Overlapping blobs and same-edge camping (both zones hugging the same map edge) are rejected. `legal_deploy_cells` / `deploy_zone_cells` expose the sampled cells. This replaces the #31 fixed border-half zones on the live Phase A path.
- ~1.0s client-only seat handoff pause + turn banner on End Turn. CombatSim still advances the seat immediately. The next seat's 30s is held during that banner so it does not drain before they can act.
- 30s visible seat clock (`TurnClock.DURATION_SEC`). At 0, auto End Turn (same as the button). CombatSim does not own the clock. Walk hop animations do **not** pause the clock. Advance does not hop.
- Pre-cast **HIT %** HUD/aim chrome for Mark Shot / Strike / Detonate / Shoulder / Crush (the bands themselves are Locked). Marks/Impact pips read from the snapshot.
- Hover / long-press **attack cards** on spell buttons (including **Mark Shot** and **Advance**), formatted from read-only `CombatSim.preview_cast` (costs, range, on-hit / on-miss, `sample_damage` with CritMult 1.0 × live Facing, Locked `hit_chance`). Detonate samples **current Marks** when M≥1. At M=0, `legal=false`, `reason=needs_marks`, and `sample_damage` is null; the card **leads with “needs Marks”** and does not lead with sample 6; notes/`on_connect_text` still explain 6+6×M. Crush shows **Stun 1 (Locked A′)** when `would_stun`. Advance has no HIT % / sample. Resist 0 is labeled provisional/Open if the preview notes it. CombatSim does not own the card.
- Action bar **wraps** at 960×720 so kit labels do not overlap.
- **Locked Stun (A′) skip banner** when CombatSim auto `end_turn`s a stunned seat (presentation of the sim event; client does not auto-submit).

## Omitted (not silent defaults)

- Networking / MultiplayerSynchronizer
- Step-shot, Rain, Longbow, Avalanche
- Other classes (Mender, Gloam, Bastion)
- Crit roll, Longshot, Momentum, Residue, Blends, Gust / WindMod
- Weapon fumbles, dual loadouts, WP/PW

## A03–A07 (provisional Open, not Locked)

These are playable stubs so the duel runs. They are **not** approved defaults. **A01 Marks-on-target is Locked** (Marks live on the target, cap 5; Detonate reads/consumes that stack) and is no longer listed as Open. **A02 walk is Locked** (Manhattan dest-click, H-first ortho path, facing follows each hop). **Advance is Locked** (Manhattan 1–2 diamond dest-click teleport, 3 AP / 0 MP; facing unchanged). **Locked Stun (A′)** (blocks move + cast + face; auto `end_turn` on turn start) and **Locked Push (1)** (occupied/OOB = no-move + `push_blocked`) are no longer Open. A06 still notes the adjacent-Impact stub. **Ask before inventing** further defaults. Do not invent Step-shot, Gust, Mark Shot +5, or other Opens.

| ID | Stub used here |
| --- | --- |
| A03 | Gust omitted. WindMod omitted (not invented as 1.0). Weather = Calm. |
| A04 | No crit roll. No elemental riders. |
| A05 | Resist 0, damage `roundi` to nearest int. WindMod omitted from the formula. **Locked Stun (A′):** Stun 1 blocks move + cast + face (`stunned_cannot_act`); auto `end_turn` on that seat's turn start (player never presses End Turn); decrement at start of that unit's turn after setting stunned-this-turn so the stunned seat's turn is skipped. **Locked Push (1):** occupied/OOB = no-move + `push_blocked`; damage/Impact still apply. |
| A06 | Advance dest-click teleport, Manhattan range 1–2 (diamond), 3 AP / 0 MP, instant snap. `submit` does not zero leftover MP; leftover MP still walks (`legal_intents` is mp>0, not AP). Adjacency = Chebyshev 1 after landing. Facing unchanged (Advance does not auto-face). |
| A07 | Back = 90° rear cone (facing axis opposite and dominant), not exact-rear-tile-only. |

## Tests

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
godot --headless --path . -s res://tests/run_elevation_proto_tests.gd
godot --headless --path . -s res://tests/run_deployment_proto_tests.gd
```

## Phase B+ elevation prototype

**Prototype only. Proposed — not Locked.** Does not change the Phase A hot-seat duel (`main.tscn` / `CombatSim` still uses flat Manhattan dest-click). No Backend tile-schema branch existed, so this PR keeps a local `ProtoMoveSim` instead of rewriting Phase A `CombatSim`.

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

Modules (all under `proto/elevation/`, unused by the Phase A combat path):

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

1. Run the main scene. Select **Mark Shot**: Chebyshev 2–5 ring + **HIT 75%** vs default Ironjaw (range 5). Walk chrome stays off. Advance / Walk never show HIT %.
2. After a Mark hits, select **Detonate**: 1–6 ring + HIT %.
3. Kit buttons stay class-gated (Kestrel: Mark Shot / Detonate; Ironjaw: Advance / Strike / Shoulder / Crush). Crush stays disabled below 2 Impact.

## How to test attack hover cards

1. Hover (or long-press) **Mark Shot**: card is `preview_cast` — 2 AP / 0 MP, range 2–5, hit/miss kit lines, Locked HIT % for the current dest, and `sample_damage` from CritMult 1.0 × live Facing. No +5. Enabled buttons must show the card (same path as Detonate).
2. Hover **Detonate** at **0 Marks**: card **leads with “needs Marks”**. Keep costs / range / HIT %. Do not lead with sample 6. `preview_cast` is `legal=false`, `reason=needs_marks`, `sample_damage` is null; on-hit still explains 6+6×M.
3. After Marks land, hover **Detonate**: sample uses **current Marks** (`6+6*M`). Miss keeps Marks.
4. End Turn. Hover **Advance**: Manhattan teleport, no HIT %, no sample. **Shoulder** passes through Locked Push (1). **Crush** at 4 Impact shows **Stun 1 (Locked A′) this cast**; at 0–2 Impact that flag stays off.
5. At **960×720**, Ironjaw's seven action buttons wrap instead of overlapping. Face N/E/S/W stay usable.

## How to test walk-after-Advance and last-hop facing

1. End Turn so **Ironjaw** acts (6 AP / 3 MP).
2. **Cancel checklist:** Select **Advance** (purple diamond, walk chrome off). Press **Walk** or **Esc** — selection returns to Walk, cyan Manhattan tiles come back. Right-click a tile still faces (does not cancel).
3. Select **Advance** again and dest-click a Manhattan 1–2 tile. The pawn snaps (no hops). Advance deselects; walk tiles highlight from remaining MP. With e.g. 3 AP / 3 MP (or a second Advance to 0 AP / 3 MP), click a Manhattan walk dest — it must be selectable and highlight.
4. Walk a multi-hop dest (e.g. two east then one south). The pointer faces **each** hop; after landing it faces the last hop. HUD Face matches. In-place Face N/E/S/W still works without moving.
5. Advance onto a diagonal dest: position snaps, **facing is unchanged**. Walk last-hop facing still applies after. No HIT % on Advance or walks.

## How to test Stun suppress and PushBlocked

1. Get Ironjaw to **4 Impact** (Strike/Shoulder hits), then **Crush** Kestrel. **End Turn**. Kestrel's turn **auto-ends** (Locked A′ — player never presses End Turn). The HUD shows a **skip banner** (e.g. “Kestrel stunned — turn skipped”) and the coach line logs the event. Ironjaw acts again. Kestrel's card/pawn still show **STUN** while that skipped turn is served. After Ironjaw Ends again, Kestrel acts normally (Walk/Face/spells return). Move/cast/face never become legal on the stunned turn (`stunned_cannot_act`). The client does not press End Turn for the skip.
2. Shoulder Kestrel into the west edge (Ironjaw at (1,0), Kestrel at (0,0) facing E): toast **PushBlocked**, Kestrel does not hop, HP still drops and Ironjaw Impact still ticks.

