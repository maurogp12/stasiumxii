# STASIUM XII — Hub shell

On PC `main` the hub is **Koliseo only**. Stasis doors, dungeon scenes, and provisional foe numbers stay on the `mobile` branch (PR #132). They are not in this tree.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

Combat rules, kits, hit bands, and the five Koliseo arenas are the shared ones. This shell does not add a map picker.

## Related

- [`docs/things_to_review.md`](things_to_review.md) — pending design questions for Mauro and Luca. Items there are not Locked. Current Locked Ambush still requires a live Shade unless the caster is Invisible.

## F5

Press **F5 / Play**. `run/main_scene` is `scenes/mobile_hub.tscn` (`MobileHub.MOBILE_HUB`).

The hub is a vertical stack of fat buttons (minimum height 72px). They fill the 960×720 window and grow when the expanded viewport is taller than 720, which is the portrait case. Each target is above a 48px floor.

| Button | Opens |
| --- | --- |
| Koliseo | `scenes/class_select.tscn` |

The five Koliseo ids are exactly `crosshaven`, `brinewake`, `slagcrown`, `windmere`, and `stormspire`. Boards are the existing files `art/maps/arena_colosseum_v2/tiled/{id}_15x15.*`. There is no Stasis door for those ids on this branch.

## Koliseo

Koliseo is PvP into those five boards. The door opens the existing class-select screen. Hot-seat is still P1, then P2, then `main.tscn` on a **random** arena among the same five ids (`ClassSelect.roll_hotseat_map`). There is no map picker. Online queue still stays on Crosshaven. **Back to hub** on that screen returns to the hub.

`--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip the hub. The hub forwards any non-picker route straight into class select, which already sends those flags to the dedicated host view or to `main.tscn`.

## Excluded from this branch

Left on `mobile` only:

- `scenes/stasis_run.tscn`, `scenes/stasis_fight.tscn`, `scenes/stasis_stub.tscn` and their scripts
- `backend/stasis_catalog.gd`, `backend/stasis_ai.gd`
- `tests/run_stasis_tests.gd`
- `docs/mobile_stasis.md`
- CombatSim `stasis_roster` / provisional attack overrides
- Hub buttons that opened those scenes

## Headless check

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . --quit-after 2
```
