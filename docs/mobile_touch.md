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
| Cast / ability | Tap the spell circle (72px, primary larger) to arm it. The skill card stays hidden; the status line and range chrome update. Hold the circle to open the card. Release, a board tap, or Walk dismisses it. | Hover still shows the card and hides it on exit. |
| Move / Advance | Walk is the default. Tap a highlighted cell. Advance is the spell button, then a tap on a highlighted neighbor. | Same clicks as before. |
| Facing | Face pad, N/E/S/W, each 48×48. | Right-click a cell still faces. |
| End Turn | End Turn button, 72px tall. | Same button. |

Aim hit % is no longer hover-only. Selecting a rolling spell still shows the enemy's Locked percent. A finger drag over the board updates that percent before the finger lifts and the cast commits. The same drag-aim / release-commit works when the finger starts on an ability circle and slides onto the board. Mouse motion still does the same preview.

Board diamonds stay 64×32. The nearest-tile pick radius stays 22px so a fatter pick cannot steal a neighbor. A unit-targeted spell (Mark Shot, Strike, Mend, and the other enemy / ally / any casts) treats a tap on the fighter sprite as that living cell. The sprite is drawn about 72px above the feet, so the 22px diamond test used to hit the empty tile behind the figure and CombatSim refunded with "needs a living unit." Walks and empty-tile spells still use the diamond. The camera still fits the arena in the band above the controls (`PLAY_TOP` 140, `PLAY_BOTTOM` 460).

The kit sits in a bottom-right thumb cluster: a large primary circle (the first rolling enemy cast, otherwise the first spell) and one smaller circle per other spell, arcing up and to the left. Costs stay on the labels. Face stays bottom-left. Walk, End Turn, and New Match stay on the secondary row.

Hub doors stay 72px. Class select still has **Back to hub**.

## Editor check

1. Press **F5 / Play**. The hub opens (`scenes/mobile_hub.tscn`).
2. Tap **Koliseo**.
3. Tap **Hot-seat**, then two class cards. The duel opens on a random arena.
4. With the mouse, or with the Game workspace's touch emulation: tap **Walk** and a highlighted cell, tap the large attack circle (the spell arms, the skill card stays hidden). Hold the circle to open the card; release or tap the board to dismiss it. Drag across the enemy figure and release. The cast spends AP. Tap **Face** N/E/S/W, tap **End Turn**. Tapping the empty diamond behind a fighter still refunds.
5. **Back to hub** on class select returns to the hub. It is still there.

## Combat motion (view chrome)

Mobile track only. This does not change kits, hit bands, AP/MP, marks, or CombatSim.

A legal walk moves one orthogonal tile at a time (`Pawn.WALK_HOP_SEC`, 0.25s). The pawn node tweens along the path. Playback puts the body back on the departure tile first, so a snapshot refresh cannot skip the travel. When that facing has a walk strip, the strip loops at its authored fps for the whole path and the hop arc stays off (the bounce is in the frames). When it does not, the hop (`ViewMotion.hop_offset`, `ViewMotion.HOP_PX`, about one iso tile tall) lifts the sprite and the name together, and the seat ring stays on the tile. The crest stretches and the landing squashes. Drop Shade's token is a board marker (`board/shade_marker.gd`), not a shader pool. Advance stays a teleport snap and does not hop.

On spell commit the caster plays the same short body motion for a hit and a miss: about a 6px lunge for melee (`ViewMotion.ATTACK_LUNGE_PX`) or the cast wind-up otherwise. The target recoils or lifts only when the spell connects. Existing impact VFX still fire on their own timing. One action locks input for at most 0.6s.

Facing art stays `art/characters/<class>/<class>_<n|e|s|w>.png` when a strip is missing. Batch 1 (Kestrel and Ironjaw, SE/NE walk and attack, optional Kestrel cast) loads from `art/grok_project/anims/` — see that README for the exact drop paths, including TA `export_2x` `.tres` files. An `AnimatedSprite2D` plays `walk_se` / `walk_ne`, then `walk_<n|e|s|w>`, then generic `walk` (same order for attack and cast). Walk loops at authored fps (`Pawn.walk_strip_speed_scale` is 1.0; the cycle is 6 frames at 12 fps, not one cycle squeezed into the 0.25s tile). Attack stays a one-shot plus the lunge. A missing file keeps the static sprite and, for walks, the hop. No placeholder strips are shipped.

## Headless check

```text
godot --headless --path . -s res://tests/run_touch_adapter_tests.gd
godot --headless --path . -s res://tests/run_combat_tests.gd
godot --headless --path . -s res://tests/run_class_select_tests.gd
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
```
