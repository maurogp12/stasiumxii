# STASIUM XII

Phase A local hot-seat duel. Godot 4.7+. Combat lives in `CombatSim`; the board is a thin client.

## How to play

1. Open `project.godot` in Godot 4.7 or later and run the main scene.
2. **Kestrel** (green, seat 0) always acts first, then **Ironjaw** (red).
3. Each turn starts with **6 AP** and **3 MP**. Spend them in any order, then **End Turn**. A **30s TIME** countdown is visible on the HUD; at 0 the seat auto End Turns (same as the button). The clock keeps ticking during walk hop animations. Advance is an instant snap (no hops). Change `TurnClock.DURATION_SEC` to retune.
4. Click a highlighted empty tile to **walk**. Dest-click only: `CombatSim` expands an orthogonal path (horizontal E/W first, then N/S). MP cost is Manhattan `|dx|+|dy|` from a pool of 3. The pawn animates one ortho tile at a time along the returned path and **faces each hop** (final facing = last hop). Manual **Face** still turns in place (0 AP). The client never sends `intent.path`. Walk is the default mode. After selecting a spell, press **Walk** or **Esc** to cancel back to walk chrome (right-click still faces; it does not cancel).
5. The action bar shows only the active kit (from `class_id` / `legal_intents`). Select a spell, then click a legal tile. **Strike / Mark Shot / Detonate / Shoulder / Crush range stays Chebyshev**. **Advance range is Manhattan 1–2** (diamond):
   - **Advance** (Ironjaw only) — dest-click teleport, **3 AP / 0 MP**. Range gate Manhattan 1–2. Instant snap (no hop animation). `CombatSim` ignores a client `intent.path`. Works at 0 MP. Does not zero leftover MP; after Advance, leftover MP still walks (`legal_intents` offers moves whenever MP > 0, even at 0 AP). No roll. +1 Impact if you land Chebyshev-adjacent to an enemy. After the snap, spell selection clears and walk chrome returns from `legal_intents` (remaining MP is still spendable). **Facing is unchanged** on Advance (no auto-face). Kestrel never sees Advance chrome and never gains Impact.
   - **Mark Shot** (Kestrel) — 2 AP, range 2–5 Chebyshev, 8 Air. Selecting it paints the Chebyshev 2–5 ring (walk chrome stays off). +1 Mark on the **target** if it connects.
   - **Detonate** (Kestrel) — 3 AP / 0 MP, range 1–6 Chebyshev. Needs 1+ Marks on that target. On connect: 6+6×M Air and **consumes** those Marks. On miss: Marks stay (AP/MP stay spent).
   - **Strike** (Ironjaw) — 3 AP, range 1, 16 Earth. +1 Impact on Ironjaw if it connects.
   - **Shoulder** (Ironjaw) — 2 AP / 0 MP, range 1. On connect: 6 Earth, +1 Impact, push the target 1 Chebyshev cell away along the line. **Locked Push (1):** if the dest is occupied or off-board, the target does not move; damage/Impact still apply; CombatSim emits `push_blocked`. Client toasts **PushBlocked** and does not hop; hit/Impact feedback still plays.
   - **Crush** (Ironjaw) — 4 AP / 0 MP, range 1. Needs/spends 2 Impact (spend on connect; miss retains Impact). 24 Earth on connect. **Stun 1** if Impact was **4 before** the spend. **Locked Stun (A):** Stun 1 blocks move + cast + face (`stunned_cannot_act`); End Turn is allowed. HUD greys Walk/Face/spells, shows a STUN badge, and keeps End Turn enabled.
6. **Face** with the N/E/S/W buttons, or right-click a tile to face that direction (0 AP). Walks set facing from each hop (final = last hop). Advance teleport leaves facing unchanged. In-place Face is still available. Back hits deal ×1.20; front/side are ×1.00.
7. A **miss** still spends AP/MP and deals nothing. An **illegal** cast is rejected and refunded. The coach line under the board tells them apart.
8. While aiming **Mark Shot / Strike / Detonate / Shoulder / Crush**, the HUD shows the Locked **HIT %** for the current Chebyshev band before you click. Advance (no roll) and walks never show hit %. Bands are Locked: 1→90%, 2–3→80%, 4–5→75%, 6–8→70%.
9. **End Turn** (button or clock expiry) shows a ~1.0s client-only turn banner, then hands the seat to the other player (Proposed presentation; not a CombatSim rule).
10. First combatant to 0 HP loses. **New Match** resets from `CombatSim.reset_match()`.

## Architecture

| Piece | Role |
| --- | --- |
| `backend/combat_sim.gd` (autoload `CombatSim`) | Sole authority. `reset_match(config)`, `submit(intent)`, `legal_intents(seat)`, `snapshot()`, `aim_hit_preview(seat, spell, dest?)`, `preview_cast(spell, from, to, target_seat=-1)` (read-only; also accepts an intent Dictionary). Rolls and HP live here. Walk paths are expanded here. Advance is a dest-click teleport. `preview_cast` does not mutate match state, RNG, or the intent log. |
| `backend/event_bus.gd` (autoload `EventBus`) | Forwards events to listeners. Does not mutate combat. |
| `data/kits.gd` | Locked Phase A kit data only. |
| `ui/turn_clock.gd` | Proposed 30s seat clock. Client-only; expiry submits `end_turn`. |
| `board_view.gd`, `ui/hud.gd`, `units/pawn.gd` | Input and presentation. They submit dest-clicks, animate walk hops, snap Advance teleports, paint enemy-spell range rings, show Locked hit %, grey Locked Stun (A) chrome, toast PushBlocked, show Proposed hover/long-press attack cards, and run the Proposed timers. |
| `data/spell_tooltip.gd` | Proposed attack-card copy. Reads Locked kit + CombatSim constants. Does not retune kits or roll. |

Intents: `end_turn` | `face` | `move` | `cast`.

## Locked in this slice (GDD v0.2)

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
- **Locked Stun (A):** Stun 1 blocks move + cast + face; End Turn allowed. `stun_remaining` on the unit; decrement at start of that unit's turn after setting stunned-this-turn. HUD greys Walk/Face/spells, shows a STUN badge, End Turn stays enabled.
- **Locked Push (1):** Shoulder into occupied/OOB = no-move + `push_blocked`; damage/Impact still apply. Client toasts **PushBlocked**, does not hop, still plays hit/Impact feedback.

## Proposed (not Locked)

- ~1.0s client-only seat handoff pause + turn banner on End Turn. CombatSim still advances the seat immediately. The next seat's 30s is held during that banner so it does not drain before they can act.
- 30s visible seat clock (`TurnClock.DURATION_SEC`). At 0, auto End Turn (same as the button). CombatSim does not own the clock. Walk hop animations do **not** pause the clock. Advance does not hop.
- Pre-cast **HIT %** HUD/aim chrome for Mark Shot / Strike / Detonate / Shoulder / Crush (the bands themselves are Locked). Marks/Impact pips read from the snapshot.
- Hover / long-press **attack cards** on spell buttons. Copy is Locked-accurate (AP/MP, Chebyshev vs Manhattan, on-connect / on-miss, worked `damage = Base × CritMult(1.0) × Passive(1) × Facing` with front/side ×1.00 and back ×1.20). Rolling spells list Locked hit bands; Advance (no roll) has no HIT %. Stun (A) / PushBlocked (1) wording is Locked. CombatSim does not own the card.

## Omitted (not silent defaults)

- Networking / MultiplayerSynchronizer
- Step-shot, Rain, Longbow, Avalanche
- Other classes (Mender, Gloam, Bastion)
- Crit roll, Longshot, Momentum, Residue, Blends, Gust / WindMod
- Weapon fumbles, dual loadouts, WP/PW

## A03–A07 (provisional Open, not Locked)

These are playable stubs so the duel runs. They are **not** approved defaults. **A01 Marks-on-target is Locked** (Marks live on the target, cap 5; Detonate reads/consumes that stack) and is no longer listed as Open. **A02 walk is Locked** (Manhattan dest-click, H-first ortho path, facing follows each hop). **Advance is Locked** (Manhattan 1–2 diamond dest-click teleport, 3 AP / 0 MP; facing unchanged). **Locked Stun (A)** (blocks move + cast + face; End Turn allowed) and **Locked Push (1)** (occupied/OOB = no-move + `push_blocked`) are no longer Open. A06 still notes the adjacent-Impact stub. **Ask before inventing** further defaults. Do not invent Step-shot, Gust, Mark Shot +5, or other Opens.

| ID | Stub used here |
| --- | --- |
| A03 | Gust omitted. WindMod omitted (not invented as 1.0). Weather = Calm. |
| A04 | No crit roll. No elemental riders. |
| A05 | Resist 0, damage `roundi` to nearest int. WindMod omitted from the formula. **Locked Stun (A):** Stun 1 blocks move + cast + face (`stunned_cannot_act`); End Turn allowed; decrement at start of that unit's turn after setting stunned-this-turn. **Locked Push (1):** occupied/OOB = no-move + `push_blocked`; damage/Impact still apply. |
| A06 | Advance dest-click teleport, Manhattan range 1–2 (diamond), 3 AP / 0 MP, instant snap. `submit` does not zero leftover MP; leftover MP still walks (`legal_intents` is mp>0, not AP). Adjacency = Chebyshev 1 after landing. Facing unchanged (Advance does not auto-face). |
| A07 | Back = 90° rear cone (facing axis opposite and dominant), not exact-rear-tile-only. |

## Tests

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
```

## How to test aim chrome

1. Run the main scene. Select **Mark Shot**: Chebyshev 2–5 ring + **HIT 75%** vs default Ironjaw (range 5). Walk chrome stays off. Advance / Walk never show HIT %.
2. After a Mark connects, select **Detonate**: 1–6 ring + HIT %.
3. Kit buttons stay class-gated (Kestrel: Mark Shot / Detonate; Ironjaw: Advance / Strike / Shoulder / Crush). Crush stays disabled below 2 Impact.

## How to test attack hover cards

1. Hover (or long-press) **Mark Shot**: card shows 2 AP / 0 MP, range 2–5 Chebyshev, +1 Mark on connect, no Mark on miss, HIT **2–3→80%, 4–5→75%** (no +5), and the worked example 8 front / 10 back.
2. After a Mark connects, hover **Detonate**: 6+6×M, Marks consumed on connect and retained on miss, HIT bands including 1→90% and 6–8→70%. Example M=1 is 12 / 14.
3. End Turn. Hover **Advance**: Manhattan 1–2 teleport, no HIT %, no damage formula. **Strike** melee example 16 / 19. **Shoulder** names **Locked Push (1)** / **PushBlocked**. **Crush** (even if grey at 0 Impact) names **Stun 1 (Locked A)**.

## How to test walk-after-Advance and last-hop facing

1. End Turn so **Ironjaw** acts (6 AP / 3 MP).
2. **Cancel checklist:** Select **Advance** (purple diamond, walk chrome off). Press **Walk** or **Esc** — selection returns to Walk, cyan Manhattan tiles come back. Right-click a tile still faces (does not cancel).
3. Select **Advance** again and dest-click a Manhattan 1–2 tile. The pawn snaps (no hops). Advance deselects; walk tiles highlight from remaining MP. With e.g. 3 AP / 3 MP (or a second Advance to 0 AP / 3 MP), click a Manhattan walk dest — it must be selectable and highlight.
4. Walk a multi-hop dest (e.g. two east then one south). The pointer faces **each** hop; after landing it faces the last hop. HUD Face matches. In-place Face N/E/S/W still works without moving.
5. Advance onto a diagonal dest: position snaps, **facing is unchanged**. Walk last-hop facing still applies after. No HIT % on Advance or walks.

## How to test Stun suppress and PushBlocked

1. Get Ironjaw to **4 Impact** (Strike/Shoulder connects), then **Crush** Kestrel. On Kestrel's next turn: **Walk / Face / spells are grey**, a **STUN** badge shows, **End Turn stays enabled**. Move, Face, and spells do not submit (`stunned_cannot_act`). End Turn hands the seat off; after serving Stun 1, Walk/Face/spells return.
2. Shoulder Kestrel into the west edge (Ironjaw at (1,0), Kestrel at (0,0) facing E): toast **PushBlocked**, Kestrel does not hop, HP still drops and Ironjaw Impact still ticks.

