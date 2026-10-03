# STASIUM XII PC: Crosshaven jungle backdrop (L2), ship PNGs

v1 built Fri 2 Oct 2026, ~21:50 ET; v2 update ~22:30 ET; **v3 update ~23:55 ET** (front_leaves_top v3 + back_mid v3, see below), on the box with Python 3 + Pillow 12.3 / numpy 2.2 / OpenCV 5.0 / SciPy 1.18.
Sources: `raw/crosshaven_jungle/*_raw.png` (Scenario, Seedream 4.5 High 4K; IDs from raw README.txt).
Spec: `SPEC_v1.md` (with the "Code answers" section from 21:39). Build scripts: `/workspace/scratch/build/` (box only, not in the repo).

**Naming (per code update):** each 2x master is `<name>@2x.png` (the spec size). Plain `<name>.png` is the half-size fallback (Lanczos, same mode, straight alpha). Sway masks are `<layer>_sway.png` at half the master size and have no @2x version.
Straight (non-premultiplied) alpha throughout. RGB under alpha=0 is filled with the neighbouring foliage colour (not black), so linear filtering can't pull in magenta or dark fringes.

## v3 update (Oct 2, ~23:55 ET)

| Layer | Shipped | Source asset | Previous version archived in |
|---|---|---|---|
| front_leaves_top | **v3** | asset_6q9bBdY9xwGxvog8UgkiinHJ (`front_leaves_top_raw_v3.png`) | `ship_archive/crosshaven_jungle_v1/` (v1 top; byte-identical copies checked) |
| back_mid | **v3** | asset_VboyPVLNJsJjxvbojQThy4rW (`back_mid_raw_v3.png`) | `ship_archive/crosshaven_jungle_v2/` (v2 back_mid@2x, back_mid, back_mid_sway) |
| front_leaves_left / right | v2 (unchanged) | see v2 table | |
| back_far, leaf_shadow, front_leaves_bottom | v1 (unchanged) | | |

Build scripts (box only): `/workspace/scratch/build/top_v3.py`, `back_mid_v3.py`, `export_v3.py`, `export_bm3.py`, `preview_v3.py`. Intermediates: `/workspace/scratch/v3/`.

### front_leaves_top v3: judged better than v1, shipped
- **Crop, no stretch:** 21:9 raw 6048x2592. The 16:3 band is the top 1134 rows (0..1134, full width), scaled uniformly x0.4233 to 2560x480. Processed at 2x supersampling (5120x960), then area-downsampled.
- **Key:** same as the v2 sides: exact #FF00FF plus near-magenta (hue 280-352, s>0.28), plus thick pure-black backing (opening r=7 of RGB max<0.06). Thin black outlines are split off, and the ones between kept leaves are restored.
- **Leaf segments:** only whole leaves are kept, and only if they are attached to the top edge. A leaf is dropped if it crosses the band's bottom rows (it would be cut straight) or overlaps the board keep-out. The keep-out is the board diamond at the default camera plus a 24 screen-px margin. 538 of 583 segments were dropped, mostly sub-150 px specks and the big banana/fern fronds that reach down to the board. The dark navy painted canopy is kept as whole segments above a smoothed lower envelope of the kept leaves (floor 45% of the band depth). Pure-black gaps enclosed by foliage (closing r=40, top edge padded) become a deep blue-green shadow (#081A1A-ish with noise).
- **Canopy notches:** where dropped leaves left wide gaps at the top edge, a dark canopy fill was added (closing r=110 from the top, limited to the upper half and kept out of the keep-out zone). It keeps the painted navy texture and gets a dark tint over dropped bright leaves. Its lower boundary gets a fine leafy jitter. Real magenta leaf holes stay see-through.
- **Edges:** the leaf silhouettes are smoothed at the stair-step scale (sigma 6 px at 2x, inward bias), giving a crisp 1-2 px AA edge. Master: 0 texels with alpha 1-63, 0 pink edge texels, bottom row fully transparent (nothing reaches the band's bottom edge). The top row is 90% opaque; the open 10% is the centre-right canopy opening and the monstera holes.
- **Density/darkness vs the v2 sides:** opaque (a>=0.5) 50.3% of the band (v2 left 36.4%, right 43.5%, v1 top 73.4%). Mean luminance of opaque texels 0.31 (v2 right 0.34, left 0.42, v1 top 0.46). The darker navy canopy now matches the v2 right side.
- **Why v3 beats v1:** v1's lower edge was the soft wavy fake fade (31k faint texels with alpha 1-63). v3 has crisp leaves and no haze, and it matches the v2 sides in style. Board clearance at the default camera stays 0%, and pan clearance improves (see coverage).
- **Fallback:** `front_leaves_top.png` 1280x240 is an alpha-weighted Lanczos downscale with straight alpha. Isolated Lanczos ringing specks (<64 alpha, not next to solid) were zeroed.
- **Sway** `front_leaves_top_sway.png` 1280x240 L: 0 at the top edge (top row max 3), smoothstep ramp to 255 at each column's leaf tip (tip depth max-filtered and smoothed), 0 a few px outside the leaves.

### back_mid v3: judged better than v2, shipped
- **Raw:** 5376x3024 16:9. The magenta oval is only 2835x734 raw px (53% of the width x 24% of the height, flatter than the prompt's 55% height) and sits at y 913..1647.
- **Crop, no stretch:** a 3200x2000 window (x 1142..4342, y 426..2426) centred on the oval horizontally. The window is shifted 146 raw px down so the hole sits ~90 screen px above canvas centre, where the board sits in the composite (board centre y 450 vs canvas 540). Uniform x1.28 Lanczos upscale to 4096x2560 (allowed by spec, needed to reach the 60% centre rule). This crop drops the raw's bottom-left round bush (only a sliver remains at the bottom-left corner, under front_leaves_bottom) and the lowest cliff faces.
- **Hole:** largest flat-magenta component, with interior islands filled. The stair-stepped oval edge is Gaussian-smoothed (sigma 42 px at 2x) with a light leafy waviness, then given a ~1 px AA edge along the smoothed contour. Rim colour is push-pull from texels at least 4 px from any magenta, then despilled (0 pink edge texels).
- **Checker centre box:** 68.4% alpha<32. Fully transparent: 25.1% of the canvas. All four edges are 100% opaque. Solid painting runs at least 228 px (left) / 234 px (right) at 2x on every row. That's less than v2's ~516 because the v3 oval is wide. No structures or gates.
- **Sway** `back_mid_sway.png` 2048x1280 L: leaf masses (hue/texture) sway. Pinned at 0: coherent smooth bark/rock/roots (opening r=8), the sky, and the whole terrace/root/cliff block below the hole. Ramp over ~40 px from the pins. 0 in the hole.
- **Ground under the board (composite, 30 px band under the board's two lower edges, % painted ground):** default camera v3 9% vs v2 0%; pan y -220: v3 69% vs v2 19%. At the default camera the terrace meets the board's bottom tip, and the board no longer floats over an open sky/valley. Clearing ground runs from the bottom tip down to the bottom leaves. Because the oval is ~1.9x wider than the board, the board's lower-left/right edges still look over back_far through the hole (see concerns).

## v2 update (Oct 2, 22:30 ET)
Scenario v2 repaints were processed for four layers; each was judged against its v1.

| Layer | Shipped | Source asset |
|---|---|---|
| back_mid | **v2** | asset_9VhMvWtzAgiaB4WVe27DwuxK (`back_mid_raw_v2.png`) |
| front_leaves_left | **v2** | asset_QJUivbS1ywVBVZPJzfLeE3XH (`front_leaves_left_raw_v2.png`) |
| front_leaves_right | **v2** | asset_5h9Hew1YyKdYzj4qLGfV4129 (`front_leaves_right_raw_v2.png`) |
| front_leaves_top | **v1 kept** | v2 asset_on9FunLZqXA2ZUFFxqEcKRdk rejected (see below) |
| back_far, leaf_shadow, front_leaves_bottom | v1 (as instructed) | unchanged |

The v1 ship files (all 20 files as they were at 22:15) are backed up in `/workspace/stasium-pc-look/ship_archive/crosshaven_jungle_v1/`.
The locally normalised v2 PNGs were the input (exact #FF00FF field). The `.scenario_v2_originals/` were used only for comparison. They show that the stair-stepped silhouettes and black outlines come from Scenario itself, not from the normalisation.

**Why front_leaves_top stayed v1:** the v2 top is not foliage on magenta. Its top ~55% is an opaque painted sunset sky with distant trees and a tree on the left. The big leaves sit in the middle of that scene and are not attached to the top edge. The band's lower edge is a stair-stepped cut, and there is stray foliage in the magenta field (a round bush at bottom left, a fern at bottom right). Run through the pipeline, a 2560x480 cover-fit crop comes out **99.9% opaque** (a sky banner). Removing the sky would leave floating leaf islands. Unusable.

### v2 processing (shared, `build/front_v2.py`, `build/back_mid_v2.py`)
- Key: exact #FF00FF plus near-magenta (hue 280-352, s>0.28). On the fronts, thick flat black **backing** (morphological opening r=7 of RGB max<0.06) is also keyed. Thin black "sticker" outlines are separated out. Outlines between two kept leaves are restored (closing, >6 px from the key). The stepped **outer** outline is dropped.
- Junk removal: only foliage connected to the attachment edge is kept (drops isolated islands and the separate scenes Scenario painted in the open field). Segments under 150 px are dropped, and pinholes are filled. The alpha is binary at 2x supersampling, then area-downsampled, so there is **no low-alpha haze** (0 texels with alpha 1-63 in either front layer, vs 25k/8k in v1).
- **Stair-step repair:** Scenario painted the silhouettes as ~16 raw px stair steps. The silhouette is Gaussian-smoothed at the step scale (sigma 6 px at 2x) and re-thresholded with a slight inward bias, so the edge stays on real paint. The result is a crisp 1-2 px anti-aliased edge. There are no fades.
- Colour: only pixels at least 3 px inside the silhouette, away from key and outline, are trusted. The rim and the transparent texels get neighbouring foliage colour (push-pull) plus a magenta despill. Dark edge specks are replaced with the local median. Pink in visible texels: 0.0000%.
- Sway masks: same scheme as v1 (front: 0 at the attachment edge to 255 at the tips, per column; back_mid: trunks, cool bark and sky pinned, leaf masses sway, rooted at the bleed edges).

### Per-file notes (v2)
- `front_leaves_left@2x.png`: cover-fit at zoom 0.8 (raw crop x 0..2662, y 624..4368, x0.385), so the cluster is about 40% of the width deep and matches the right side's weight. The separate tree/palm scene Scenario painted on the right half of the raw is removed (it isn't attached to the left edge). The flat black backing behind the leaves had a straight vertical edge, so it is removed **except** where leaves enclose it. There it stays as a dark blue-green shadow mass (#081A1A-ish with subtle noise), and bubbles inside it are filled. Opaque area: 36.4%.
- `front_leaves_right@2x.png`: cover-fit x0.308, crop y 156..4836. Removed: the bush/tree cluster plus ferns in the lower-left of the raw, which touched the inner edge (it would have been a straight cut on screen), and flat indigo "ghost" leaf silhouettes painted into the open field. Opaque area: 43.5% (v1 right was 7.7%, so left/right are now balanced).
- `back_mid@2x.png`: crop x 660..4772, y 119..2689 raw (zoom 0.85, centred on the oval), x0.996, so no upscale. The oval is keyed. Any islands inside it are removed. The stepped oval edge is smoothed with a light leafy waviness and a 1 px AA edge. Centre box: 70.6% transparent (checker). At 1.0 zoom the hole only covered 57%, which would fail the 60% rule. Every row is fully opaque at both sides, with at least 516 px left / 522 px right of solid painting. All four edges are fully opaque (it's a full painting). There are no structures or gates (v1 had the yellow gate posts at the top centre). Fully transparent: 22.3% of the canvas. Semi-transparent texels only on the hole edge (3.5k).

## Files

| File | Size | Mode | Source asset | Notes |
|---|---|---|---|---|
| `back_far@2x.png` | 2048x1280 | RGB (opaque) | asset_dtbE3duKhryB5GEu4nSG9DHR (job_kTr9rY3887D1RVWeUt5nzD5C) | Cover-fit from 6048x2592: scaled to 1280 tall (x0.494), centre crop x=950..5097 raw. Area downsample, then a gentle 0.8 px Gaussian blur so it reads as the far plane. No letterbox. |
| `back_far.png` | 1024x640 | RGB | same | Half-size Lanczos fallback. |
| `back_mid@2x.png` | 4096x2560 | RGBA | **v3: asset_VboyPVLNJsJjxvbojQThy4rW** (see v3 notes). v2 (archived in ship_archive/crosshaven_jungle_v2): asset_9VhMvWtzAgiaB4WVe27DwuxK. v1 (archived in ship_archive/crosshaven_jungle_v1): asset_oL3WsfvcfFnykBzPMEymPgF9 | v3: crop x 1142..4342, y 426..2426 raw, uniform x1.28. Oval keyed and edge smoothed. Centre box 68.4% transparent. All edges opaque. Older v1/v2 processing notes are in the v2 section and the archived README. |
| `back_mid.png` | 2048x1280 | RGBA | same | Half-size fallback. |
| `back_mid_sway.png` | 2048x1280 | L | derived (v3) | v3: leaf masses sway. Bark/rock/roots, sky and the terrace/cliff block below the hole are pinned at 0. 0 in the hole. |
| `front_leaves_left@2x.png` | 1024x1440 | RGBA | **v2: asset_QJUivbS1ywVBVZPJzfLeE3XH** (see v2 notes above). v1 (archived): asset_ZG4xdJjAYeci9sXtEYwJ7Kpx (job_hKtmFcjEnfMUvbx7u1bWUvaN), v1 notes follow: | Cover-fit width (x0.339), top-anchored crop (drops the round topiary bush at the raw's bottom). Leaves attached to the left edge, about 300 px deep. Mauve backdrop pockets keyed. The raw's hard vertical paste cut was replaced by a soft, noise-wavy fade inside the painted band. The dark backing dissolves before lit leaves near the free edge. |
| `front_leaves_left.png` | 512x720 | RGBA | same | Half-size fallback. |
| `front_leaves_right@2x.png` | 1024x1440 | RGBA | **v2: asset_5h9Hew1YyKdYzj4qLGfV4129** (see v2 notes above). v1 (archived): asset_bBjApU7mSi1ggKqqHv5FGC93 (job_rc7vxbxjQZ886MvFpJPZBUrq), v1 notes follow: | Cover-fit width, bottom-anchored. Vines on a mauve backdrop: mauve and its cast shadows hue-keyed. Frond tips clipped by the raw's paste cut were removed as floating bits. Attached to the right edge. |
| `front_leaves_right.png` | 512x720 | RGBA | same | Half-size fallback. |
| `front_leaves_top@2x.png` | 2560x480 | RGBA | **v3: asset_6q9bBdY9xwGxvog8UgkiinHJ** (see v3 notes). v1 (archived): asset_pCwvxEtkQ3T3KdHLZz2AhNRM (job_rxc35HduQJGocUgRGcSsZPpD) | v3: top 1134-row band of the 21:9 raw, uniform x0.4233. Whole top-attached leaves plus dark navy canopy, crisp 1-2 px edges, no haze. Nothing touches the bottom edge, and nothing sits in the board keep-out. |
| `front_leaves_top.png` | 1280x240 | RGBA | same | Half-size fallback. |
| `front_leaves_bottom@2x.png` | 2560x480 | RGBA | asset_PNzHoosrz3AiLHqNURoaxY1Z (job_D9u5BpGdyi3SrCAvzxCV19Yf) | Width-fit, bottom-anchored (the raw's paste cut falls outside the crop). Valley-shaped soft upper edge (~45% depth at the centre) to keep the action-bar area lighter. Attached to the bottom edge. |
| `front_leaves_bottom.png` | 1280x240 | RGBA | same | Half-size fallback. |
| `front_leaves_*_sway.png` | 512x720 (L/R), 1280x240 (T/B) | L | derived | Half size. 0 at the attachment edge, smooth ramp to 255 at the free leaf tips (normalised per row/column to the local tip distance, smoothed). Extends a few px past the silhouette, then 0. |
| `leaf_shadow@2x.png` | 1024x1024 | L | asset_c9pPjGgkms5w2GYbywZGETCK (job_dYwk4R4xrhWdkMY5MR6mArmq) | Luminance, area-downsampled from 4096, 5 px Gaussian blur for soft dapples. Made seamless with two separable, variance-preserving offset blends that use rotated copies (no half-period repeat and no contrast loss in the blend zones). Local density normalised with wrap-mode filters. Tone: white = lit, darkest ~71, mean 196. Edge diffs (L/R 1.6, T/B 1.3) are below the average neighbour-pixel diff. |
| `leaf_shadow.png` | 512x512 | L | same | Half-size fallback, downscaled wrap-aware (3x3 tile, Lanczos, centre crop), still seamless. |
| `../../previews/crosshaven_jungle/_preview_composite.png` | 1920x1080 | RGB | preview | Current package (top v3, back_mid v3, sides v2) at the default camera (same setup as v1: 16:9 canvas at 1.5x, back_far x1.06 @0.12, back_mid half size @0.40, 15x15 board at zoom 0.64, leaf_shadow x50%, screen-locked fronts). Coverage numbers are printed on the image. |
| `../../previews/crosshaven_jungle/_preview_pan220.png` | 1920x1080 | RGB | preview | 2x2 grid: pan x -220 / +220 / y -220 / +220 world px, with coverage. |
| `../../previews/crosshaven_jungle/_preview_back_mid_v2_vs_v3.png` | 3860x1080 | RGB | preview | Default-camera composite with back_mid v2 (left, archived) vs v3 (right). Everything else is the current ship. |
| `../../previews/crosshaven_jungle/_preview_v1_vs_v2.png` | 3856x1080 | RGB | preview | v1 (archived files) and v2 composites side by side at the default camera. |
| `../../previews/crosshaven_jungle/_preview_tiles.png` | 2632x3118 | RGB | preview | leaf_shadow tiled 2x2, and each leaf layer next to its sway mask. **Not rebuilt for v3** (it still shows v1 top / v2 back_mid). |
| `../../previews/crosshaven_jungle/v1/` | | | preview | The v1 composite/tiles previews as they were before the update. |

## Checker (`tools/check_assets.py --package jungle`)
- v3 run (Oct 2, ~23:53 ET, after both v3 layers were exported): all 12 expected entries **PASS** (7 @2x masters + 5 sway masks). INFO only: non-black RGB under alpha=0 (intentional), and back_mid centre transparency 68.4%. 1x fallbacks ignored. Overall: **PASS**.
- v2 run (Oct 2, 22:28 ET): all 12 expected entries **PASS** (7 @2x masters + 5 sway masks). INFO only: transparent RGB is non-black (intentional colour bleed), and back_mid centre transparency is 70.6%. The 1x fallbacks are recognised and ignored. Overall: **PASS**. No previews in this folder.

## Front-leaf clearance (v3, measured in the composite; % of board diamond covered by any front-leaf alpha)

| Camera | Total (any alpha) | alpha>0.5 | top | bottom | left | right | (v2 package, v1 top) |
|---|---|---|---|---|---|---|---|
| default | **0.00%** | 0.00% | 0 | 0 | 0 | 0 | 0.00% |
| pan x +220 | 0.27% | 0.23% | 0.27 | 0 | 0 | 0 | 2.71% |
| pan x -220 | 1.36% | 1.29% | 0 | 0 | 0 | 1.36 | 4.61% |
| pan y -220 (camera up, board moves down) | 0.00% | 0.00% | 0 | 0 | 0 | 0 | 0.00% |
| pan y +220 (camera down, board moves up under the top margin) | 20.35% | 19.46% | 20.35 | 0 | 0 | 0 | 52.2% |

## Art concerns / regenerate candidates (current state, v3)
1. **back_mid v3 painted stair-steps:** the moss ring around the oval is painted as blocky ~40-60 px (2x) stair ledges with dark outlines, against the sky above and the terrace below. The keyed hole edge is smoothed, but these painted ledges are inside the painting and can't be fixed without repainting. They're visible at game scale on the ring's left and right shoulders. This is the main reason to regenerate back_mid.
2. **back_mid v3 oval is too flat:** 53% x 24% of the frame instead of the prompt's ~60% x 55%. To meet the 60% centre rule it had to be zoomed (x1.28 upscale, mildly softer). The hole is also ~1.9x wider than the board, so back_far still shows beside the board's lower-left/right edges. For a regen, ask for a taller oval (~50-55% width x 45-50% height) with no stepped rim, so the ground can hug the board on all sides.
3. **front_leaves_top v3 centre-right opening:** the big banana/fern fronds over the centre-right reached down into the board keep-out and the band bottom, so they were dropped whole rather than cut. That leaves a canopy opening at about 50-75% of the width, open to the top edge, where back_mid/back_far show through. The canopy-notch fill is synthetic dark foliage with a jittered, somewhat scalloped lower boundary. It reads as deep canopy at game scale but is flatter than painted leaves up close.
4. **front_leaves_top v3 hanging shrub:** the round moss/broccoli shrub (top-left, ~x 330-560) has a visible trunk at its bottom. It reads a bit like a bush on a ledge rather than hanging foliage. It's acceptable, but a regen could drop it.
5. **front_leaves_left v2** dark shadow mass is a synthetic flat tint (unchanged from v2 notes).
6. **front_leaves_bottom (v1)** still has the soft v1 fade. It's now the only layer with the fake-fade look.
7. Ultrawide headroom note from v1 still applies.
