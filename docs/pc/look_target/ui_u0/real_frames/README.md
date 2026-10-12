# U0 real frames

Real 1920×1080 captures of the PC build for the U0 HUD mockups. Scenario Art composites the HUD on these plates. Nothing here is painted.

Captured 12 Oct 2026 on Godot 4.7.2 (official `ed1daf0bf`) with `xvfb` and `--rendering-driver opengl3` (Mesa llvmpipe). The window keeps the project stretch: base 960×720, `canvas_items`, aspect `expand`. A 1920×1080 window therefore shows a 1280×720 viewport, scaled by 1.5 onto the framebuffer. That is the game on a 1080p screen, not a 1:1 world-pixel blow-up and not a resize of a 1280×720 shot.

Shared settings for every frame:

| Setting | Value |
|---|---|
| Visuals | Full (`VisualSettings.apply_preset("Full")`, performance mode off) |
| World zoom | 1.6, the default in `crosshaven_world.gd` (`ZOOM_MIN` 1.0, `ZOOM_MAX` 2.5). Set on the camera directly, not tweened. |
| Weather | clear, time of day 12.0, clock stopped |
| Hero | Ironjaw (`--class ironjaw`), idle |
| Window | 1920×1080. PNGs are the viewport texture at that size. They were not resized. |

The world plates hide the debug readout, the mission tracker, and the zone banner, the same way the other still captures do (`_hide_debug_readout`). Name plates stay. The stamina bar stays hidden because the hero is standing with a full bar, which is what the game does. Frame 2 keeps the combat HUD.

## Reproduce

From the repo root, with Godot 4.7.2 on `PATH` as `godot`:

```
XDG_DATA_HOME=/tmp/ui-u0-data xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --rendering-driver opengl3 --audio-driver Dummy --path . \
  --resolution 1920x1080 \
  -s res://tools/pc/capture_ui_u0_frames.gd -- \
  --out=docs/pc/look_target/ui_u0/real_frames --class ironjaw
```

`XDG_DATA_HOME` points at an empty directory so a saved Performance preset cannot turn the look off. A fresh store loads Full. `--preview` also writes coast and farm candidates next to the three frames (Eastmarch beach, Eastmarch north shore, Stoneford fields, Stoneford mill).

The clean Granary plate (phone combat HUD hidden) is the same command with `--only=granary-clean`. It writes only `frame2_granary_fight_clean.png`.

## Frame 1 — Crossroads plaza

[frame1_crossroads_plaza.png](frame1_crossroads_plaza.png)

| | |
|---|---|
| Scene | `res://scenes/world/crosshaven/crosshaven_world.tscn` |
| Zone | `crosshaven_crossroads` |
| Hero | Ironjaw, cell (23, 19), facing e (toward the Guide), idle |
| Guide | `crossroads_guide` at (24, 18), one cell north-east, name plate on |
| Landmark | `crossroads_centerpiece` (the obelisk) at (20, 15), cobbles underfoot, red-roof cottages around the square |
| Zoom | 1.6 |
| Visuals | Full, performance off |
| Weather | clear, 12.0 |
| Date | 12 Oct 2026 |

Opaque Ironjaw idle height in this frame: 65.9 world px, 105.4 viewport px at zoom 1.6, **158.2 px in the 1920×1080 PNG**.

## Frame 2 — Granary fight

[frame2_granary_fight.png](frame2_granary_fight.png)

| | |
|---|---|
| Scene | `res://scenes/world/dungeon/dungeon_run.tscn` |
| Dungeon | `old_granary_cellar`, room A (the pack), ★1, level 1 |
| Hero | Ironjaw, seat 0, his turn. The painted attack bar is the combat HUD (`ui/hud.gd`). Monsters are on the board (Granary Rats and a Scarecrow Drudge). |
| Camera | the room fit inside `dungeon_board_view.gd`, zoom 1.021. This is not the world zoom. |
| Visuals | Full. The dungeon reads `VisualSettings.still()`, which is false when performance mode is off. |
| Window | 1920×1080, same project stretch (visible rect 1280×720) |
| Date | 12 Oct 2026 |

The grab is the opening of room A, after the fade, before the hero's first action, so the board and the combat HUD are both still. The isometric floor does not cover every corner of the 16:9 frame; those corners are the scene clear color.

## Frame 2 clean — Granary fight, phone HUD hidden

[frame2_granary_fight_clean.png](frame2_granary_fight_clean.png)

Same fight as frame 2: Old Granary Cellar, room A, ★1, level 1, Ironjaw's turn, before his first action. Move-range tiles, name plates, and HP bars stay. The phone combat HUD is hidden only in this capture (`--only=granary-clean` in `tools/pc/capture_ui_u0_frames.gd`). A normal launch does not hide it.

Hidden for the grab, after the room has faded in:

- the combat HUD layer (`ui/hud.gd`): the red hero card, the AP/MP/TIME box, the N/S/E/W face pad, the action buttons, and the Selected line and log
- the dungeon's right-hand column: the room title, the star line, and the round list

The board then runs its own keep-out fit, so with those panels gone the room zoom is **1.417** (frame 2, with the HUD up, was 1.021). Window, stretch, Full visuals, class, star, and level are the same.

```
XDG_DATA_HOME=/tmp/ui-u0-data xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --rendering-driver opengl3 --audio-driver Dummy --path . \
  --resolution 1920x1080 \
  -s res://tools/pc/capture_ui_u0_frames.gd -- \
  --out=docs/pc/look_target/ui_u0/real_frames --class ironjaw --only=granary-clean
```

| | |
|---|---|
| Scene | `res://scenes/world/dungeon/dungeon_run.tscn` |
| Dungeon | `old_granary_cellar`, room A, ★1, level 1, Ironjaw |
| Camera | room fit after the phone HUD is hidden, zoom 1.417 |
| Visuals | Full, performance off |
| Window | 1920×1080, project stretch (visible rect 1280×720) |
| Date | 12 Oct 2026 |

## Frame 3 — Crosshaven coast

[frame3_crosshaven.png](frame3_crosshaven.png)

| | |
|---|---|
| Scene | `res://scenes/world/crosshaven/crosshaven_world.tscn` |
| Zone | `crosshaven_eastmarch_coves`, cell (22, 6), Ironjaw facing s |
| What is in frame | the cove: cliffs, water, sand, red-roof houses, fields, a dirt path. This is the coast shot in the same family as `real_crosshaven_frame_1920x1080.jpg` on `pc/ui-style`. |
| Zoom | 1.6 |
| Visuals | Full, performance off |
| Weather | clear, 12.0 |
| Date | 12 Oct 2026 |

Opaque Ironjaw idle height in this frame: 65.0 world px, **156.0 px in the PNG**.

A Stoneford fields frame (cell (36, 17) of `crosshaven_stoneford_fields`) was rendered with `--preview` and is a real farm. The cove was kept because it matches the existing Crosshaven reference (water, shore, cliffs, and red roofs together).

## Hero size

Claude's U0 note (12 Oct 2026, on `claude/pc-zones-spec`) says the in-game hero is about 110–120 px tall at 1080p. Measured on these plates, Ironjaw's opaque idle sprite is about **156–158 px** in the 1920×1080 PNG.

The sprite is 65–66 world px tall. Default zoom 1.6 makes that about 105 viewport px. The 1080p window then scales the 720-tall viewport by 1.5, which is why the PNG count is about 157. The frames were not rescaled to force 110–120. Scale the mockup HUD to the sprite in the PNG.
