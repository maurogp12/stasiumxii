# STASIUM XII

Phase A local hot-seat duel. Godot 4.7+. Combat lives in `CombatSim`; the board is a thin client.

## How to play

1. Open `project.godot` in Godot 4.7 or later and run the main scene.
2. **Kestrel** (green, seat 0) always acts first, then **Ironjaw** (red).
3. Each turn starts with **6 AP** and **3 MP**. Spend them in any order, then **End Turn**.
4. Click a highlighted empty tile to **walk** (Chebyshev / king-move; each tile of distance costs 1 MP).
5. Select a spell, then click a legal tile:
   - **Advance** (both) — 1 AP + 1 MP, dash 1–2 tiles, no roll. +1 Impact if you land Chebyshev-adjacent to an enemy.
   - **Mark Shot** (Kestrel) — 2 AP, range 2–5, 8 Air. +1 Mark on the target if it connects.
   - **Strike** (Ironjaw) — 3 AP, range 1, 16 Earth. +1 Impact on Ironjaw if it connects.
6. **Face** with the N/E/S/W buttons, or right-click a tile to face that direction (0 AP). Back hits deal ×1.20; front/side are ×1.00.
7. A **miss** still spends AP/MP and deals nothing. An **illegal** cast is rejected and refunded. The coach line under the board tells them apart.
8. First combatant to 0 HP loses. **New Match** resets from `CombatSim.reset_match()`.

## Architecture

| Piece | Role |
| --- | --- |
| `backend/combat_sim.gd` (autoload `CombatSim`) | Sole authority. `reset_match(config)`, `submit(intent)`, `legal_intents(seat)`, `snapshot()`. Rolls and HP live here. |
| `backend/event_bus.gd` (autoload `EventBus`) | Forwards events to listeners. Does not mutate combat. |
| `data/kits.gd` | Locked Phase A kit data only. |
| `board_view.gd`, `ui/hud.gd`, `units/pawn.gd` | Input and presentation. They submit intents and render snapshots. |

Intents: `end_turn` | `face` | `move` | `cast`.

## Locked in this slice (GDD v0.2)

- 8×8 flat board, no walls, no LOS
- 80 HP, 6 AP / 3 MP refilled at turn start
- Chebyshev range and movement
- Hit bands 1=90%, 2–3=80%, 4–5=75%, 6–8=70%
- Damage pipeline with Mastery 0, CritMult held at **1.0** (crit *roll* off)
- Facing front/side ×1.00, back ×1.20
- Miss keeps AP/MP, refunds engine, no engine gain
- Illegal cast reject + refund
- Advance / Strike / Mark Shot values above
- Kestrel then Ironjaw

## Omitted (not silent defaults)

- Networking / MultiplayerSynchronizer
- Detonate, Step-shot, Shoulder, Crush, Rain, Longbow, Avalanche
- Other classes (Mender, Gloam, Bastion)
- Crit roll, Longshot, Momentum, Residue, Blends, Gust / WindMod
- Weapon fumbles, dual loadouts, WP/PW

## A01–A07 (provisional Open, not Locked)

These are playable stubs so the duel runs. They are **not** approved defaults.

| ID | Stub used here |
| --- | --- |
| A01 | Marks live on the target (cap 5). Impact lives on the caster (cap 4). |
| A02 | Walk spends Chebyshev distance to an empty destination. Occupied tiles cannot be entered. No wall pathing. Spawn: Kestrel `(1,1)` facing E, Ironjaw `(6,6)` facing W. |
| A03 | Gust omitted. WindMod = 1.0, weather = Calm. |
| A04 | No crit roll. No elemental riders. |
| A05 | Resist 0, WindMod 1.0, damage `roundi` to nearest int. |
| A06 | Advance dashes to any empty Chebyshev 1–2 tile. Adjacency = Chebyshev 1 after landing. Facing unchanged. |
| A07 | Back = 90° rear cone (facing axis opposite and dominant), not exact-rear-tile-only. |

## Tests

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
```
