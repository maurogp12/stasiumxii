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
| Move / Advance | Walk is the default. Tap a highlighted cell. Advance is the spell button, then a tap on a highlighted tile exactly 2 cardinal spaces away. | Same clicks as before. |
| Facing | Face pad, N/E/S/W, each 48×48. | Right-click a cell still faces. |
| End Turn | End Turn button, 72px tall. | Same button. |

Aim hit % is no longer hover-only. Selecting a rolling spell still shows the enemy's Locked percent. A finger drag over the board updates that percent before the finger lifts and the cast commits. The same drag-aim / release-commit works when the finger starts on an ability circle and slides onto the board. Mouse motion still does the same preview.

Board diamonds stay 64×32. A mouse still uses the 22px nearest-tile radius and a 34px sprite capsule, so a click cannot steal a neighbor. A finger (or an Android / iOS export) uses the painted diamond, including the side tips that 22px circle used to give to the neighbor, and a 52px sprite capsule so a tap beside the chest still selects that fighter. The east-neighbor diamond stays a tile. Walks do not prefer the body. A tap just off the board uses a 36px pad. CombatSim still rejects anything outside the Locked range.

The 960×720 camera fit is unchanged (15×15 stays zoom 0.64 inside `PLAY_TOP` 140, `PLAY_BOTTOM` 460). Phones stay landscape (`sensor landscape`), and stretch stays `canvas_items` / `expand`, so that poster fills the glass instead of sitting in a letterboxed strip inside a portrait activity. The combat camera shows most of the iso diamond: on a 20:9 window (canvas about 1600×720) the zoom is about 1.48, so a diamond is about 47px tall and the width of the board still fits. **Zoom +** and **Zoom −** sit on the left of the combat HUD (72px tall). Zoom out stops at the whole diamond. Zoom in stops at 2.25, under the old cover zoom. The step is kept for the rest of the session, including the next fight. The turn plaque and the thumb cluster overlay the edges. A walk-mode drag pans inside the board. While a unit spell is armed, the selected fighter pulses a ring. That ring is chrome only.

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

A legal walk eases along the segment for about 0.30s (`Pawn.WALK_TILE_SEC`). `grid_position` is the tactical cell and updates when the foot commits. `pawn.position` is the visual foot on the diamond. The body faces each segment, and the matching `walk_n/e/s/w` strip is sampled from that step (press on the contact frame, passing frames through the stride, next contact on arrival) so a paused clock cannot leave the idle pose sliding. Path end shows the idle facing. The sprite root takes a 4–6px gait. The contact shadow is the Foot child and stays on the ground.

On spell commit the caster plays the same short body motion for a hit and a miss: a short squash and pull-back, then about a 12px lunge for melee (`ViewMotion.ATTACK_LUNGE_PX`; Ambush keeps its longer reach) or the cast rise otherwise. The impact pose holds briefly, and that hold never pushes the one-shot past 0.6s. Kestrel's bow is a cast in the kit, and it has an attack strip and no cast strip, so Mark Shot and Detonate play that attack cycle with the same lunge and hold the impact frame. The clip stays at 12 fps (0.5s) when the 0.6s lock has room. Advance stays a teleport snap. The target recoils or lifts only when the spell connects. Existing impact VFX still fire on their own timing. One action locks input for at most 0.6s.

Facing art stays `art/characters/<class>/<class>_<n|e|s|w>.png` when a strip is missing. Batch 1 ships lettered sheets at `art/export_2x/characters/<class>/anims/<class>_<walk|attack>_<n|e|s|w>.png` for Kestrel and Ironjaw. When `<class>_frames.tres` is present, that bank is the playback source and the PNGs only fill letters it left empty. Cells are baked off `CompressedTexture2D` so the strip cycles on device. Facing map: SE→`e`, SW→`s`, NE→`n`, NW→`w`. The pawn tries `walk_e` before a drawn-master name like `walk_se`. The directional bank is those SpriteFrames (`walk_n`, `walk_e`, `walk_s`, `walk_w`). A full cycle is two tiles, not one. Attack is a one-shot; impact frame index is 3. A missing file, or a `play()` that does not start, keeps the static sprite and the same 4–6px gait. Mender and Bastion use that gait. Gloam uses `gloam_walk_*`. There is no 36px hop. `*_gen.png` is never loaded.

## Headless check

```text
godot --headless --path . -s res://tests/run_touch_adapter_tests.gd
godot --headless --path . -s res://tests/run_combat_tests.gd
godot --headless --path . -s res://tests/run_class_select_tests.gd
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
```
