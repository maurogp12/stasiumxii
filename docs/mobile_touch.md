# STASIUM XII Mobile — Touch adapters

Mobile track only. This lives on the `mobile` branch. It stays off PC `main`.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

`export_presets.cfg` is unchanged. This is not an APK.

Combat rules, kits, hit bands, AP/MP, and map tags are unchanged. The adapter only changes how a finger reaches the existing intents.

## What changed

`ui/touch_adapter.gd` classifies pointers. The board and the combat HUD call it.

| Action | Tap path | Desktop still works |
| --- | --- | --- |
| Select unit / cell | Finger down highlights the cell. Finger up commits it (walk, Advance, or the armed spell). | Mouse left press still commits immediately. |
| Cast / ability | Tap the spell button (72px tall). The card opens on that press and stays until you tap the board or Walk. Range rings still paint when the spell is selected. | Hover still shows the card and hides it on exit. |
| Move / Advance | Walk is the default. Tap a highlighted cell. Advance is the spell button, then a tap on a highlighted neighbor. | Same clicks as before. |
| Facing | Face pad, N/E/S/W, each 48×48. | Right-click a cell still faces. |
| End Turn | End Turn button, 72px tall. | Same button. |

Aim hit % is no longer hover-only. Selecting a rolling spell still shows the enemy's Locked percent. A finger drag over the board updates that percent before the finger lifts and the cast commits. Mouse motion still does the same preview.

Board diamonds stay 64×32. The nearest-tile pick radius stays 22px so a fatter pick cannot steal a neighbor. The camera still fits the arena in the band above the controls (`PLAY_TOP` 140, `PLAY_BOTTOM` 460).

Hub doors stay 72px. Class select still has **Back to hub**.

## Editor check

1. Press **F5 / Play**. The hub opens (`scenes/mobile_hub.tscn`).
2. Tap **Koliseo**.
3. Tap **Hot-seat**, then two class cards. The duel opens on a random arena.
4. With the mouse, or with the Game workspace's touch emulation: tap **Walk** and a highlighted cell, tap a spell (the card appears without hovering), tap a cell to cast, tap **Face** N/E/S/W, tap **End Turn**.
5. **Back to hub** on class select returns to the hub. It is still there.

## Headless check

```text
godot --headless --path . -s res://tests/run_touch_adapter_tests.gd
godot --headless --path . -s res://tests/run_combat_tests.gd
godot --headless --path . -s res://tests/run_class_select_tests.gd
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
```
