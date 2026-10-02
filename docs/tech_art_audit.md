# Tech art audit — Phase A phone combat

Presentation only. Kit numbers, ranges, damage, AP/MP, legality, map tags, and the roster are unchanged. Camera zoom and board scale are unchanged. No APK version bump.

Look target: a colorful isometric board with a punchy read (Dofus Koliseo / Wakfu). References: https://youtu.be/o5M8JC8xKGc and https://youtu.be/HjDKnEb1eF0. An icy wash or a lifeless violet board is the thing this pass pushes back on.

Open pull requests on `mobile` that this branch stays off of:

| PR | What it owns | This branch |
| --- | --- | --- |
| #190 melee windup v3b | `art/vfx/scenario/melee_windup.png`, `vfx/vfx_stamp.gd`, `tests/run_vfx_tests.gd`, `docs/ship_log.md` | Not edited. Windup timing and crops stay theirs. |
| #105 idle board chrome | `board/tile.gd`, `board_view.gd`, `board/board_ambient.gd`, `board/board_shimmer.gdshader` | Not edited. Tile outlines and overlay breathe stay theirs. |
| #80 ability icons v2 | `art/ui/mobile/abilities/*.png` | Not edited. |
| #108 cosmetics, Parked | `art/export_2x/characters_custom/**` | Not edited. Live combat still uses `art/export_2x/characters/`. |

Character playback stays Batch-1 REDRAW v3 / approved Wakfu walk strips. `art/grok_project/anims/gen_raw/*_gen.png` is not loaded (`StripLibrary.try_load` rejects `_gen`).

## 1. Shaders and VFX

### Current state

Combat chrome is already a real system, not a placeholder:

- `units/figure_read.gdshader` lifts crushed blacks for Ironjaw and Bastion only, with a 1px class rim. Kestrel, Gloam, and Mender were a straight sample (`rim_px` 0, `mid_mix` 0). A warm key light (`edge_light`) already sat on the upper-left edge. Modulate is a vertex varying, so the texel is not multiplied by itself.
- Hit, cast, and death strips play from `art/export_2x/characters/...` when the sheet exists. The white/gold hit flash is a modulate tween in `board_view.gd` (0.28s) plus the scenario `hit_flash` plate. Melee anticipation is the `melee_windup` stamp (#190).
- Impacts are pooled one-shots: sparks (12, cap 24), puffs (8), motes (6). Input lock stays at `VfxBudget.LOCK_MAX` 0.6s.
- Damage numbers are chunky, outlined, and bounce. The aim line is a dashed arc (heal / shield / damage colors). Shade / Ambush chrome is the cloak, the tile decal, and a loud halo only when that Shade is a legal Ambush origin (`board/shade_marker.gd`). Illegal Shades stay the softer rest modulate. No text plate.
- Arena surfaces (`board/arena_surface.gdshader`) run 5-octave value noise on lava, runes, and water. Stormspire mode 3 was a violet step-flicker. Mode 4 pulled slate toward blue-violet and replaced most of the stamp.

### What changed

- Shared warm ink (`board_ink`, 1.15px, umber) on every body. Class `rim_px` / `mid_mix` are unchanged, so Ironjaw and Bastion keep the ochre and stone edge, and Kestrel is still not recolored. The ink only fills fringe the class rim did not claim. Invisible still multiplies alpha to 0.
- Key light `FIGURE_EDGE` 0.30 → 0.48 so a dark cloak separates from a night tile.
- Hit flash modulate is warm (`2.2, 1.42, 0.78`) instead of near-white, so the silhouette does not wash out on snow. The scenario hit plate is untouched.
- Spark core draws a short cross on top of the existing pooled burst. Particle count is unchanged.
- Damage numbers sit on a soft dark plate so the orange reads on sunlit snow.
- Aim arc keeps the same curve. A dark understroke and a small diamond at the target make it readable on both boards. Heal and shield colors are unchanged. Shade legality is unchanged.
- Fallen heroes get a foot-anchored stain and a small cross. `DEATH_FADE_ALPHA` stays 0. Death strips still hold their last cell. The mark does not move the body.
- Active unit: the existing gold ring pulses, with a dark understroke. Only that pawn runs `_process`.
- Team disc and keyline are a step stronger. Colors stay `BoardTile.TEAM_BLUE` / `TEAM_RED`.
- Windmere grade is still snow (`b >= r`, gap under 0.2) but the blue gap is smaller, the key light is warm, and ground sheen is quieter.
- Stormspire grade and key light are warm stone / amber. Rune arcs are gold with a violet core and a sine pulse instead of a hard step. Slate keeps more of the painted stamp.
- Surface noise is 3 octaves. The extra octaves were smaller than a phone tile texel and mostly aliased.

## 2. Art pipeline

### Current state

486 texture imports under `art/` are the same recipe: `compress/mode=0` (lossless), `mipmaps/generate=false`, `process/fix_alpha_border=true`. Tests lock that for `art/characters/` turnarounds, Batch-1c strips, hit flinches, and class-picker portraits.

Combat bodies are the 2× Wakfu strips (`864×160`, six `144×160` cells) drawn at scale `0.5` with `TEXTURE_FILTER_LINEAR`. That half-scale linear sample is the sharp downsample. Nearest would crunch it. Mipmaps would fight the exact `0.5` scale and, on the scenario plates, would bleed neighboring frames.

Walk playback bakes cells off `CompressedTexture2D` into `ImageTexture` (`StripLibrary._bake_compressed_atlases`) and prefers `art/export_2x/walk_src/*.pngbin` so Android does not keep one atlas region for the whole cycle. `*_gen.png` never loads.

Map stamps in `art/maps/arena_look/` are already `64×32`, which is the diamond. They are not a downscale problem.

Scenario VFX plates are `1280×720` (Mark Shot cast is `1280×320`) and draw at about 44–118px. Crops in `vfx/vfx_stamp.gd` are source-pixel rects with padding so linear filtering stays off the next cell. Mipmaps or `size_limit` would move those rects and smear frames. That is why those imports stay full-size and mip-less even though the GPU minification is soft.

`detect_3d/compress_to=1` is on every import. Combat is 2D, so it does not recompress the board. A 3D preview that pulls the same texture can.

`project.godot` now sets `textures/canvas_textures/default_texture_filter=1` (Linear). That matches the filter the pawns already set. It does not turn mipmaps on.

Several arena-look props are 1×1 placeholders (70 bytes), so those decorations are missing, not blurry. See Open below.

The Android preset still excludes `stasium-ref/*` and `art/tilesets/*`. Punch sheets that combat actually samples live under `art/maps/`.

## 3. Mobile performance and art budgets

### Current state

`project.godot` features were Forward+ with no `rendering_method.mobile` override. The September export note recorded `org.godotengine.rendering.method=mobile` on the APK; that is not guaranteed once the project renderer is Forward+. Forward+ is the wrong fill path for a 2D board on a mid-range phone (clustered lighting, desktop Vulkan).

Particle pools are already small (`VfxBudget`). Koliseo weather is 18 motes. The expensive GPU piece is `arena_surface.gdshader`: several fbm calls per fragment on every lava, rune, slate, and water tile, previously at 5 octaves.

Character VRAM is the lossless 2× strips. A walk sheet is `864×160` RGBA (~0.5MB). The roster’s walks, attacks, hits, and deaths are the right memory trade for sharp phone pixels. The scenario plates are the outlier: eight full-HD RGBA images for effects that land under ~120px.

There is no per-frame full-screen post pass. The ground grade is one shader on each diamond (5 taps for a light unsharp). That is cheap next to the surface noise and was left alone.

### What changed

- `renderer/rendering_method` stays `forward_plus` for desktop and headless, so editor shots and tests do not switch pipelines.
- `renderer/rendering_method.mobile="mobile"`. Compatibility (`gl_compatibility`) was not selected. The phone path already targeted the Mobile renderer, canvas shaders in this project stay inside it, and Compatibility would change blend on every 2D material. If a test phone cannot boot Vulkan, switch that one key to `gl_compatibility`. That decision is Open, not taken here.
- Surface fbm dropped from 5 octaves to 3. Roughly two fifths of the hash work on those tiles, and less shimmer alias.
- No new particle systems, no pool growth, no extra full-screen pass. The active-unit pulse is one pawn’s `_process` redrawing its foot mark.
- The new ink is 4 texture taps, and only on fragments that are already transparent (`alpha < 0.2`). Opaque paint does not pay it.

`import_etc2_astc` stays true so the exporter is satisfied. Imports stay lossless, so the flag does not recompress art.

## 4. Unit readability

### Current state

Shared scale: presentation mul is capped, feet sit at offset `(0, -72)`, scale `0.5` on the body, not on the pawn. Ground marks are a `Foot` child and do not hop. Walk is one cycle per facing, face into the segment, about `0.30s` per tile, plant on arrival. Those constants were not touched.

Team color was already a Dofus-style disc in `TEAM_BLUE` / `TEAM_RED`. The active unit had a static gold ring. Target, burn, and stun rings already existed. Ironjaw and Bastion had a class rim; the three lighter classes did not, so they relied on the paint plus a small contact shadow (`alpha` about `0.42`).

On Windmere the grade was `Color(0.96, 1.02, 1.06)` with a cool key and a high ground sheen, so light armor sat in the snow. On Stormspire the grade was violet, mode 4 ate the stamp, and mode 3 strobed. Dark cloaks (Gloam) and the floor were the same family.

### What changed

- Umber ink plus a stronger warm key, on the same foot pivot and the same scale.
- Darker, slightly wider contact shadow. It still shrinks when the body hops, and it stays on `Foot`.
- Team disc alpha `0.38` → `0.52`, team stroke `2.6` → `3.1`, darker keyline outside it, warmer inner glint.
- Active ring pulses gold over a dark understroke.
- Target ring has a dark understroke so the orange aim reads on snow.
- DOWN stain and cross on the foot when `alive` is false.
- Windmere and Stormspire lighting, as in section 1, so the floor is not the same value as the figure.

Camera zoom and `cell_to_local` were not changed.

## Backlog

Rough cost is GPU or art time, not a schedule. “Cheap” means a shader constant or a few draw calls. “Heavy” means new textures or a renderer switch.

| Priority | Upgrade | Why | Rough cost |
| --- | --- | --- | --- |
| 1 | Re-export scenario plates at phone size and retarget `vfx_stamp.gd` crops | Full-HD plates minified to ~50–120px are the soft VFX and the extra VRAM. Do this after #190 lands so the windup crops are not rewritten twice. | Art + one script. Large VRAM win. Do not enable mipmaps on the current sheets. |
| 2 | Death strips for Mender and Bastion | They have no `death_*` sheet, so a downed body fades to alpha 0. The new foot cross is the stand-in. | Art. Cheap at runtime (same strip player). |
| 3 | Replace 1×1 arena-look props | Windmere ice sheet, rubble, floor seal; Stormspire rubble and floor seal; Slagcrown steam vent and rubble; Brinewake rock pillar and waterfall. The tiled sheets under `arena_colosseum_v2` already have real pixels for several of these. | Art wiring. Open which cut is approved. |
| 4 | ASTC for map stamps only, if a device is memory-bound | Stamps are tiny (`64×32`). Character strips should stay lossless. Compressing the 2× walks will look muddy. | Import change. Quality risk on the walks, low risk on stamps. |
| 5 | Per-board ink color | One umber edge is the compromise for snow and night. If playtest still loses Gloam on Stormspire, a light rim on dark maps is the next step. Do not add a cyan halo. | Cheap shader uniform. Open: one rim or two. |
| 6 | Merge #105, then a single pass on tile ink | Idle breathe, water/mud shimmer, and the hard selection rim are in that PR. Stacking another outline here would fight it. | After that PR. Cheap. |
| 7 | `gl_compatibility` on phones that fail Vulkan | Only if Mobile fails to boot. Do not switch the desktop method. | One project key. Look can shift. Open until a device says so. |

## Open (not decided here)

- **Phone renderer fallback.** Mobile is the phone method. Compatibility is not turned on. Needs a device that fails Vulkan before anyone flips `rendering_method.mobile`.
- **Scenario plate resolution.** Source-pixel crops in `vfx_stamp.gd` are correct for the current files. A smaller export is an art drop, and #190 is already on `melee_windup.png`.
- **Missing props.** The 1×1 files are listed above. Which painted cut replaces each one is an art call. This pass does not invent props.
- **Mender and Bastion death poses.** No sheet exists. The foot stain is presentation only.
- **Second rim color for dark arenas.** Shared umber is in. A Stormspire-only light rim is not.
- **Body team tint.** The ring carries team color. Tinting the painted costume would fight the approved Wakfu identity. Not done.
- **Shade copy.** Halo vs soft-grey is unchanged. No new Shade text.

## Files

- `units/figure_read.gdshader`, `units/pawn.gd` — ink, key light, hit flash, foot read, active pulse, DOWN mark
- `board/aim_line.gd` — understroke and target diamond
- `board/koliseo_life.gd` — Windmere and Stormspire grade, key, sheen
- `board/arena_surface.gdshader` — 3-octave noise, warmer Stormspire slate and runes
- `vfx/vfx_number.gd`, `vfx/vfx_spark.gd` — number plate, spark cross
- `project.godot` — Mobile renderer on phones, explicit Linear canvas filter
- `tests/run_sprite_tests.gd` — the shared ink is part of the sprite contract; Kestrel `rim_px` stays 0
