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

The hub matches Luca's menu mock. The ground is dark navy. A thin gold frame with corner brackets sits inside the window. **STASIUM XII** is a gold serif title at the top left, with a four-pointed star. Cinzel Semibold is bundled at `art/ui/hub/Cinzel-Semibold.ttf` (SIL Open Font License, `art/ui/hub/OFL-Cinzel.txt`).

Under the title is a wide Koliseo banner: the five roster heroes in the colosseum, left to right Kestrel, Ironjaw, Mender, Gloam, Bastion, with **KOLISEO** across the bottom. The whole banner is the hit target. It opens `scenes/class_select.tscn`, the same route as the old Koliseo button.

Under a **RAID** header (crossed swords) is one row of five portrait tiles. The painted plates read:

| Plate | Button text | Opens |
| --- | --- | --- |
| KOLISEO (on the banner) | Koliseo | `scenes/class_select.tscn` |
| CROSSHAVEN STASIS | Crosshaven Stasis | `scenes/stasis_run.tscn` for `crosshaven` (Threshgate) |
| BRINEWAKE STASIS | Brinewake Stasis | same run for `brinewake` (Tidehold) |
| SLAGCROWN STASIS | Slagcrown Stasis | same run for `slagcrown` (Ashmarch) |
| WINDMERE STASIS | Windmere Stasis | same run for `windmere` (Galevault) |
| STORMSPIRE STASIS | Stormspire Stasis | same run for `stormspire` (Coilgate) |

Banner and tile art are crops of that mock, stored in `art/ui/hub/` (`koliseo_banner.png`, `raid_crosshaven.png`, and the other four `raid_*.png`). Each control's `custom_minimum_size.y` is 72. At 960×720 the tiles lay out about 178×250, so the phone target stays fat. `window/handheld/orientation` is sensor landscape, so the phone shows this wide poster (title, banner, RAID, one horizontal row) instead of a tall portrait stack. A wider landscape window keeps that same column and pins the footer star to the bottom of the frame. It does not crop the nameplates.

The five ids are exactly `crosshaven`, `brinewake`, `slagcrown`, `windmere`, and `stormspire`. Boards are the existing files `art/maps/arena_colosseum_v2/tiled/{id}_15x15.*`. `door_text` stays Title Case of those ids (`Crosshaven Stasis`). The painted plate is the mock's uppercase. No other id spelling is accepted. Door names Threshgate, Tidehold, Ashmarch, Galevault, and Coilgate stay on the Stasis run screen.

## Koliseo

Koliseo is PvP into those five boards. The door opens the existing class-select screen. Hot-seat is still P1, then P2, then `main.tscn` on a **random** arena among the same five ids (`ClassSelect.roll_hotseat_map`). There is no map picker. Online queue still stays on Crosshaven. **Back to hub** on that screen returns to the hub.

`--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip the hub. The hub forwards any non-picker route straight into class select, which already sends those flags to the dedicated host view or to `main.tscn`.

## Stasis

Luca Garza (overnight, 2026-09-25) unparked these doors for the phone APK. Each door stores `MobileHub.pending_biome_id` and opens `scenes/stasis_run.tscn`. The run shows the Proposed door name, that biome's trash and boss, a class pick, and **Back to hub**. It does not say “Stasis coming soon”.

Picking a class opens `scenes/stasis_fight.tscn` on that door’s Stasis schematic (`art/maps/stasis_v1/{id}_room_a_15x15_tags.json`, then room B). Room A is one fight with the trash pack, then Room B is the boss. Koliseo still uses `art/maps/arena_colosseum_v2/tiled/{id}_15x15`. Foe HP and attack base are provisional Open playtest numbers, not Locked kit law. Details and the playtest steps are in [`docs/mobile_stasis.md`](mobile_stasis.md).

`scenes/stasis_stub.tscn` is only an old path. If something still loads it, it forwards to the run. Do not add these scenes to PC `main`.

## Actualizar

The title row has a gold **Actualizar** button. It checks GitHub for a newer mobile debug APK and, on Android, hands that APK to the system installer. The Koliseo banner and the five RAID tiles are unchanged. Status text sits on the right of the RAID header. The first-time unknown-apps step is in [`docs/mobile_android_export.md`](mobile_android_export.md).

## Headless check

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . -s res://tests/run_apk_update_tests.gd
godot --headless --path . -s res://tests/run_stasis_tests.gd
godot --headless --path . --quit-after 2
```
