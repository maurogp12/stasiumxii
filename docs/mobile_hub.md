# STASIUM XII Mobile — Hub shell

Mobile track only. This hub lives on the `mobile` branch. It stays off PC `main`.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

`export_presets.cfg` is unchanged (Android preset from ticket 1). This shell is not an APK and is not ready to install.

Combat rules, kits, hit bands, and the five Koliseo arenas are unchanged. Stasis on this branch is a mobile-only dungeon (Luca Garza, overnight 2026-09-25). It does not add loot or keys. It is not for PC `main`. See [`docs/mobile_stasis.md`](mobile_stasis.md).

## Related

- [`docs/things_to_review.md`](things_to_review.md) — pending design questions for Mauro and Luca. Items there are not Locked. Current Locked Ambush still requires a live Shade unless the caster is Invisible.

## F5

Press **F5 / Play**. `run/main_scene` is `scenes/mobile_hub.tscn` (`MobileHub.MOBILE_HUB`).

The hub is a vertical stack of fat buttons (minimum height 72px). They fill the 960×720 window and grow when the expanded viewport is taller than 720, which is the portrait case. Each target is above a 48px floor.

| Button | Opens |
| --- | --- |
| Koliseo | `scenes/class_select.tscn` |
| Crosshaven Stasis | `scenes/stasis_run.tscn` for `crosshaven` (Threshgate) |
| Brinewake Stasis | same run for `brinewake` (Tidehold) |
| Slagcrown Stasis | same run for `slagcrown` (Ashmarch) |
| Windmere Stasis | same run for `windmere` (Galevault) |
| Stormspire Stasis | same run for `stormspire` (Coilgate) |

The five ids are exactly `crosshaven`, `brinewake`, `slagcrown`, `windmere`, and `stormspire`. Boards are the existing files `art/maps/arena_colosseum_v2/tiled/{id}_15x15.*`. Door labels are Title Case of those ids (`Crosshaven Stasis`). No other spelling is accepted.

## Koliseo

Koliseo is PvP into those five boards. The door opens the existing class-select screen. Hot-seat is still P1, then P2, then `main.tscn` on a **random** arena among the same five ids (`ClassSelect.roll_hotseat_map`). There is no map picker. Online queue still stays on Crosshaven. **Back to hub** on that screen returns to the hub.

`--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip the hub. The hub forwards any non-picker route straight into class select, which already sends those flags to the dedicated host view or to `main.tscn`.

## Stasis

Luca Garza (overnight, 2026-09-25) unparked these doors for the phone APK. Each door stores `MobileHub.pending_biome_id` and opens `scenes/stasis_run.tscn`. The run shows the Proposed door name, that biome's trash and boss, a class pick, and **Back to hub**. It does not say “Stasis coming soon”.

Picking a class opens `scenes/stasis_fight.tscn` on that door’s Stasis schematic (`art/maps/stasis_v1/{id}_room_a_15x15_tags.json`, then room B). Room A is one fight with the trash pack, then Room B is the boss. Koliseo still uses `art/maps/arena_colosseum_v2/tiled/{id}_15x15`. Foe HP and attack base are provisional Open playtest numbers, not Locked kit law. Details and the playtest steps are in [`docs/mobile_stasis.md`](mobile_stasis.md).

`scenes/stasis_stub.tscn` is only an old path. If something still loads it, it forwards to the run. Do not add these scenes to PC `main`.

## Headless check

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . -s res://tests/run_stasis_tests.gd
godot --headless --path . --quit-after 2
```
