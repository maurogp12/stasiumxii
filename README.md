# STASIUM XII

Phase A local hot-seat duel. Godot 4.7+. Combat lives in `CombatSim`; the board is a thin client.

## How to play

1. Open `project.godot` in Godot 4.7 or later and run the main scene.
2. **Kestrel** (green, seat 0) always acts first, then **Ironjaw** (red).
3. Each turn starts with **6 AP** and **3 MP**. Spend them in any order, then **End Turn**. A **30s TIME** countdown is visible on the HUD; at 0 the seat auto End Turns (same as the button). The clock keeps ticking during walk / Advance hop animations. Change `TurnClock.DURATION_SEC` to retune.
4. Click a highlighted empty tile to **walk**. Dest-click only: `CombatSim` expands an orthogonal path (horizontal E/W first, then N/S). MP cost is Manhattan `|dx|+|dy|` from a pool of 3. The pawn animates one ortho tile at a time along the returned path. The client never sends `intent.path`.
5. The action bar shows only the active kit (from `class_id` / `legal_intents`). Select a spell, then click a legal tile. **Strike / Mark Shot range stays Chebyshev**. **Advance range is Manhattan 1–2** (diamond):
   - **Advance** (Ironjaw only) — dest-click, 1 AP + Manhattan `|dx|+|dy|` MP (ortho 1, diagonal neighbor = 2 MP, not 1). Range gate Manhattan 1–2. `CombatSim` expands an H-first ortho path and ignores a client `intent.path`. No roll. +1 Impact if you land Chebyshev-adjacent to an enemy. Kestrel never sees Advance chrome and never gains Impact.
   - **Mark Shot** (Kestrel) — 2 AP, range 2–5, 8 Air. +1 Mark on the target if it connects.
   - **Strike** (Ironjaw) — 3 AP, range 1, 16 Earth. +1 Impact on Ironjaw if it connects.
6. **Face** with the N/E/S/W buttons, or right-click a tile to face that direction (0 AP). Back hits deal ×1.20; front/side are ×1.00.
7. A **miss** still spends AP/MP and deals nothing. An **illegal** cast is rejected and refunded. The coach line under the board tells them apart.
8. **End Turn** (button or clock expiry) shows a ~1.0s client-only turn banner, then hands the seat to the other player (Proposed presentation; not a CombatSim rule).
9. First combatant to 0 HP loses. **New Match** resets from `CombatSim.reset_match()`.

## Architecture

| Piece | Role |
| --- | --- |
| `backend/combat_sim.gd` (autoload `CombatSim`) | Sole authority. `reset_match(config)`, `submit(intent)`, `legal_intents(seat)`, `snapshot()`. Rolls and HP live here. Walk and Advance paths are expanded here. |
| `backend/event_bus.gd` (autoload `EventBus`) | Forwards events to listeners. Does not mutate combat. |
| `data/kits.gd` | Locked Phase A kit data only. |
| `ui/turn_clock.gd` | Proposed 30s seat clock. Client-only; expiry submits `end_turn`. |
| `board_view.gd`, `ui/hud.gd`, `units/pawn.gd` | Input and presentation. They submit dest-clicks, animate the returned path, render snapshots, and run the Proposed timers. |

Intents: `end_turn` | `face` | `move` | `cast`.

## Locked in this slice (GDD v0.2)

- 8×8 flat board, no walls, no LOS
- 80 HP, 6 AP / 3 MP refilled at turn start
- Walk: dest-click only, Manhattan `|dx|+|dy|` MP, pool 3, CombatSim expands ortho path, horizontal-first (E/W before N/S) tie-break
- Advance: dest-click / H-first ortho path / Manhattan `|dx|+|dy|` MP plus 1 AP. Range gate **Manhattan 1–2** (diamond). Ironjaw-only.
- Spell range stays Chebyshev for Strike / Mark Shot. Advance range is Manhattan.
- Hit bands 1=90%, 2–3=80%, 4–5=75%, 6–8=70%
- Damage pipeline: Base × CritMult × Passive × (1+Mastery/100) × (1−Resist/100) × Facing. Mastery 0, CritMult held at **1.0** (crit *roll* off). WindMod omitted (not invented as 1.0).
- Facing front/side ×1.00, back ×1.20
- Miss keeps AP/MP, refunds engine, no engine gain
- Illegal cast reject + refund
- Advance / Strike / Mark Shot values above
- Advance is Ironjaw-only
- Kestrel then Ironjaw

## Proposed (not Locked)

- ~1.0s client-only seat handoff pause + turn banner on End Turn. CombatSim still advances the seat immediately. The next seat's 30s is held during that banner so it does not drain before they can act.
- 30s visible seat clock (`TurnClock.DURATION_SEC`). At 0, auto End Turn (same as the button). CombatSim does not own the clock. Walk / Advance hop animations do **not** pause the clock.

## Omitted (not silent defaults)

- Networking / MultiplayerSynchronizer
- Detonate, Step-shot, Shoulder, Crush, Rain, Longbow, Avalanche
- Other classes (Mender, Gloam, Bastion)
- Crit roll, Longshot, Momentum, Residue, Blends, Gust / WindMod
- Weapon fumbles, dual loadouts, WP/PW

## A01–A07 (provisional Open, not Locked)

These are playable stubs so the duel runs. They are **not** approved defaults. **A02 walk is Locked** (Manhattan dest-click, H-first ortho path) and is no longer listed as Open. **Advance range + MP are Locked** (Manhattan 1–2 diamond dest-click, H-first ortho path). A06 still notes the adjacent-Impact stub.

| ID | Stub used here |
| --- | --- |
| A01 | Marks live on the target (cap 5). Impact lives on the caster (cap 4). |
| A03 | Gust omitted. WindMod omitted (not invented as 1.0). Weather = Calm. |
| A04 | No crit roll. No elemental riders. |
| A05 | Resist 0, damage `roundi` to nearest int. WindMod omitted from the formula. |
| A06 | Advance dest-click, Manhattan range 1–2 (diamond), H-first ortho path, Manhattan MP + 1 AP. Adjacency = Chebyshev 1 after landing. Facing unchanged. |
| A07 | Back = 90° rear cone (facing axis opposite and dominant), not exact-rear-tile-only. |

## Tests

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
```
