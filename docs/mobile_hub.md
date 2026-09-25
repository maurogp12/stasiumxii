# STASIUM XII Mobile — Hub shell

Mobile track only. This hub lives on the `mobile` branch. It stays off PC `main`.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

`export_presets.cfg` is unchanged (Android preset from ticket 1). This shell is not an APK and is not ready to install.

Combat rules, kits, hit bands, and the five Koliseo arenas are unchanged. Stasis does not add dungeon rooms, loot, keys, trash, or bosses.

## F5

Press **F5 / Play**. `run/main_scene` is `scenes/mobile_hub.tscn` (`MobileHub.MOBILE_HUB`).

The hub is a vertical stack of fat buttons (minimum height 72px). They fill the 960×720 window and grow when the expanded viewport is taller than 720, which is the portrait case. Each target is above a 48px floor.

| Button | Opens |
| --- | --- |
| Koliseo | `scenes/class_select.tscn` |
| Crosshaven Stasis | `scenes/stasis_stub.tscn` for `crosshaven` |
| Brinewake Stasis | same stub for `brinewake` |
| Slagcrown Stasis | same stub for `slagcrown` |
| Windmere Stasis | same stub for `windmere` |
| Stormspire Stasis | same stub for `stormspire` |

The five ids are exactly `crosshaven`, `brinewake`, `slagcrown`, `windmere`, and `stormspire`. Boards are the existing files `art/maps/arena_colosseum_v2/tiled/{id}_15x15.*`. Door labels are Title Case of those ids (`Crosshaven Stasis`). No other spelling is accepted.

## Koliseo

Koliseo is PvP into those five boards. The door opens the existing class-select screen. Hot-seat is still P1, then P2, then `main.tscn` on a **random** arena among the same five ids (`ClassSelect.roll_hotseat_map`). There is no map picker. Online queue still stays on Crosshaven. **Back to hub** on that screen returns to the hub.

`--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip the hub. The hub forwards any non-picker route straight into class select, which already sends those flags to the dedicated host view or to `main.tscn`.

## Stasis stubs

Each door stores `MobileHub.pending_biome_id` and opens one stub scene. The stub shows the biome name, that biome's catalog blurb, the line **Stasis coming soon**, and **Back to hub**.

When `art/maps/arena_colosseum_v2/tiled/{id}_15x15_tags.json` loads as 15×15, the stub draws those cells as flat color squares (`BoardTile.fill_color` only). That grid is a non-combat preview so a later room can reuse the same tags file. It does not start `CombatSim`, place units, or invent a dungeon.

## Headless check

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . --quit-after 2
```
