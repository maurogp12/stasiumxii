# Ship log

Durable record of feel passes on the mobile track. Kit numbers in here are reminders of what stayed Locked. They are not a second source of truth. The legal sentences live in `docs/STASIUM_XII_GDD_handoff.md`.

## 2026-09-26 — Rosebud feel / chrome pass

Compared the current `mobile` tip (Batch-1c feel, Stasis unpark, Ambush teleport, Shade tile, APK 0.1.17) with the Rosebud Gloam combat reference. The hypothesis held: tile spawn and the Ambush teleport destination were already in place. This pass is chrome readability and aim feedback.

### Player-visible

- Selecting a legal **Ambush** draws a dashed red arc from the Shade to the enemy, and a predicted damage float over that enemy (a backstab sample reads `-30`). While Gloam is Invisible the same arc starts on Gloam. A Shade that is not yet a legal origin draws neither.
- The Ambush **back tile** highlight is blue, so the legal landing is distinct from the gold range cells. The range is still measured from the Shade.
- Other armed spells draw the same arc from the caster to the hovered in-range cell. A hovered body shows the predicted connect float (`-8` on a front Mark Shot, `+` heals, `+` shield).
- An Ambush **miss** whiff leaves the Shade (or Gloam, while Invisible) and the float stays `MISS`. The body does not streak across the board.

Already on the tip, and left as they were: Drop Shade's marker lands on the clicked tile with the Shade plate and token; the Shades count follows live tokens; the Ambush button stays soft-grey until `legal_intents` contains the cast; a legal Shade wears the loud Ambush plate; a hit snaps to the back tile, faces the prey, plays the purple slash, and removes that Shade in the same beat.

### Files

- `backend/combat_sim.gd` — `aim_feel` presentation helper
- `backend/net_session.gd` — forwards `aim_feel` while online
- `board/aim_line.gd` — dashed arc and float
- `board_view.gd` — paints the line from the armed spell
- `board/tile.gd` — legal landing blue
- `vfx/vfx_router.gd` — Ambush miss whiff origin
- `tests/run_combat_tests.gd`, `tests/run_vfx_tests.gd`

### Intentionally not changed

- Ambush-without-Shade stays parked in `docs/things_to_review.md`.
- Locked kit numbers and origin rules stay: Drop Shade 1 AP / 0 MP, Chebyshev 1–3, empty tile, LOCK Neutral, +1 Shade (max 2), duration 3, geometry marker. Ambush legal iff origin is the caster while Invisible, otherwise a live Shade that has seen the opponent complete at least one turn; cardinal row/col; Manhattan 1 or 2; empty back tile; AP at least 4. Cost 4 AP / 0 MP. Resolve teleports, then hits 22 FLEX. A Shade is spent only on a Shade-origin hit. A miss does not teleport and keeps Shade and Invisible.
- No Open kit defaults, no Ambush 3 AP retune, no cosmetics.
- Stasis stays mobile-only. It was not ported to `main`.
- No APK version bump and no APK cut. A follow-up ships 0.1.18 after this merges.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Combat | 4509 |
| VFX | 438 |
| Motion | 1828 |
| Event hooks | 329 |
| Net session | 280 |
| Elevation chrome | 189 |
| Touch adapter | 403 |

### Pull request

https://github.com/maurogp12/stasiumxii/pull/135 into `mobile`. Not merged.

### 2026-09-26 follow-up — Rosebud beat check

A second pass against the reference beats. Locked destination stays the enemy back tile. Batch-1c walk cycles stay.

- Drop Shade no longer travels. The token pops on the tapped tile with a floating "Shade" label and a purple outline.
- While Ambush is legal and selected, the Manhattan 1–2 cardinal cells paint blue from the Shade (from Gloam only while Invisible). The back tile stays the landing.
- The action line under the board is larger (`Selected: Ambush · 4 AP / 0 MP · range …`) and still adds "Ambush from Shade" only when the cast is in `legal_intents`.
- A backstab float is the large bouncing number (`BACKSTAB` at 1.55). The coach line stays the smaller clinical log. The button stays soft-grey until AP and Shade geometry are legal. Consume, snap, face, and slash stay on the same beat.

Headless recount after this follow-up, 0 failed: combat 4510, VFX 439, motion 1828, touch adapter 403.
