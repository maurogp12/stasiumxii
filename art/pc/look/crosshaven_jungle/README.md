# STASIUM XII PC: Crosshaven jungle backdrop (L2), ship PNGs

v1 built Fri 2 Oct 2026, ~21:50 ET; **v2 update ~22:30 ET** (see below), on the box with Python 3 + Pillow 12.3 / numpy 2.2 / OpenCV 5.0 / SciPy 1.18.
Sources: `raw/crosshaven_jungle/*_raw.png` (Scenario, Seedream 4.5 High 4K; IDs from raw README.txt).
Spec: `SPEC_v1.md` (with the "Code answers" section from 21:39). Build scripts: `/workspace/scratch/build/` (box only, not in the repo).

**Naming (per code update):** each 2x master is `<name>@2x.png` (the spec size). Plain `<name>.png` is the half-size fallback (Lanczos, same mode, straight alpha). Sway masks are `<layer>_sway.png` at half the master size and have no @2x version.
Straight (non-premultiplied) alpha throughout. RGB under alpha=0 is filled with the neighbouring foliage colour (not black), so linear filtering can't pull in magenta or dark fringes.

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
| `back_mid@2x.png` | 4096x2560 | RGBA | **v2: asset_9VhMvWtzAgiaB4WVe27DwuxK** (see v2 notes above). v1 (archived): asset_oL3WsfvcfFnykBzPMEymPgF9 (job_pZbxjJCyyX8EGkGrMa8j9o4U), v1 notes follow: | Keyed: the flat #FF00FF paste, the dark-maroon "drop shadow" matte around it and magenta pockets (hue/connectivity key from the paste), plus the white "sticker" outline around the opening. The raw's white paper margin at the outer edge, the four dull-magenta corner tiles and white specks inside the foliage were filled with neighbouring foliage colour (push-pull) so the foliage bleeds off all 4 edges. Thin dark outline strokes hanging into the opening were removed. Despill: colours in the matte rim are replaced with neighbouring interior foliage colour, and min(R,B)>G casts are removed. Cover-fit crop x=365..5011, y=60..2964 raw (trims the paper margin), area downsample x0.88 (no upscale needed). Centre (middle 50%) is 100% transparent. The left/right columns are opaque on every row, with at least ~276 master px (~138 world px) of solid foliage on every row at each side. |
| `back_mid.png` | 2048x1280 | RGBA | same | Half-size fallback. |
| `back_mid_sway.png` | 2048x1280 | L | derived (v2) | v2: 0 on trunks, cool blue-grey bark and the painted sky. v1 scheme otherwise: 0 on trunks (brown masses) and sand/ground, ramping over ~70 px to leaf masses. Lower at the outer canvas edges (rooted beyond the bleed), weighted by leafiness (green/teal hue), Gaussian smoothed. 0 in the empty centre. |
| `front_leaves_left@2x.png` | 1024x1440 | RGBA | **v2: asset_QJUivbS1ywVBVZPJzfLeE3XH** (see v2 notes above). v1 (archived): asset_ZG4xdJjAYeci9sXtEYwJ7Kpx (job_hKtmFcjEnfMUvbx7u1bWUvaN), v1 notes follow: | Cover-fit width (x0.339), top-anchored crop (drops the round topiary bush at the raw's bottom). Leaves attached to the left edge, about 300 px deep. Mauve backdrop pockets keyed. The raw's hard vertical paste cut was replaced by a soft, noise-wavy fade inside the painted band. The dark backing dissolves before lit leaves near the free edge. |
| `front_leaves_left.png` | 512x720 | RGBA | same | Half-size fallback. |
| `front_leaves_right@2x.png` | 1024x1440 | RGBA | **v2: asset_5h9Hew1YyKdYzj4qLGfV4129** (see v2 notes above). v1 (archived): asset_bBjApU7mSi1ggKqqHv5FGC93 (job_rc7vxbxjQZ886MvFpJPZBUrq), v1 notes follow: | Cover-fit width, bottom-anchored. Vines on a mauve backdrop: mauve and its cast shadows hue-keyed. Frond tips clipped by the raw's paste cut were removed as floating bits. Attached to the right edge. |
| `front_leaves_right.png` | 512x720 | RGBA | same | Half-size fallback. |
| `front_leaves_top@2x.png` | 2560x480 | RGBA | asset_pCwvxEtkQ3T3KdHLZz2AhNRM (job_rxc35HduQJGocUgRGcSsZPpD), **v1 kept** | Raw rows 0..109 (white/orange/cream frame strip) cropped off. Width-fit x0.423, top-anchored. Magenta in the monstera holes keyed (the holes are see-through). Valley-shaped soft lower edge: full 480 depth at the sides, ~52% depth over the centre 50%, so the canopy stays above the board's top tip (screen-locked margin). |
| `front_leaves_top.png` | 1280x240 | RGBA | same | Half-size fallback. |
| `front_leaves_bottom@2x.png` | 2560x480 | RGBA | asset_PNzHoosrz3AiLHqNURoaxY1Z (job_D9u5BpGdyi3SrCAvzxCV19Yf) | Width-fit, bottom-anchored (the raw's paste cut falls outside the crop). Valley-shaped soft upper edge (~45% depth at the centre) to keep the action-bar area lighter. Attached to the bottom edge. |
| `front_leaves_bottom.png` | 1280x240 | RGBA | same | Half-size fallback. |
| `front_leaves_*_sway.png` | 512x720 (L/R), 1280x240 (T/B) | L | derived | Half size. 0 at the attachment edge, smooth ramp to 255 at the free leaf tips (normalised per row/column to the local tip distance, smoothed). Extends a few px past the silhouette, then 0. |
| `leaf_shadow@2x.png` | 1024x1024 | L | asset_c9pPjGgkms5w2GYbywZGETCK (job_dYwk4R4xrhWdkMY5MR6mArmq) | Luminance, area-downsampled from 4096, 5 px Gaussian blur for soft dapples. Made seamless with two separable, variance-preserving offset blends that use rotated copies (no half-period repeat and no contrast loss in the blend zones). Local density normalised with wrap-mode filters. Tone: white = lit, darkest ~71, mean 196. Edge diffs (L/R 1.6, T/B 1.3) are below the average neighbour-pixel diff. |
| `leaf_shadow.png` | 512x512 | L | same | Half-size fallback, downscaled wrap-aware (3x3 tile, Lanczos, centre crop), still seamless. |
| `../../previews/crosshaven_jungle/_preview_composite.png` | 1920x1080 | RGB | preview | v2 package at the default camera (same setup as v1: 16:9 canvas at 1.5x, back_far x1.06 @0.12, back_mid half size @0.40, 15x15 board at zoom 0.64, leaf_shadow x50%, screen-locked fronts). Coverage numbers are printed on the image. |
| `../../previews/crosshaven_jungle/_preview_pan220.png` | 1920x1080 | RGB | preview | 2x2 grid: pan x -220 / +220 / y -220 / +220 world px, with coverage. |
| `../../previews/crosshaven_jungle/_preview_v1_vs_v2.png` | 3856x1080 | RGB | preview | v1 (archived files) and v2 composites side by side at the default camera. |
| `../../previews/crosshaven_jungle/_preview_tiles.png` | 2632x3118 | RGB | preview | leaf_shadow tiled 2x2, and each leaf layer next to its sway mask (v2 layers). |
| `../../previews/crosshaven_jungle/v1/` | | | preview | The v1 composite/tiles previews as they were before the update. |

## Checker (`tools/check_assets.py --package jungle`)
- v2 run (Oct 2, 22:28 ET): all 12 expected entries **PASS** (7 @2x masters + 5 sway masks). INFO only: transparent RGB is non-black (intentional colour bleed), and back_mid centre transparency is 70.6%. The 1x fallbacks are recognised and ignored. Overall: **PASS**. No previews in this folder.

## Front-leaf clearance (v2, measured in the composite; % of board diamond covered by any front-leaf alpha)
- Default camera: **0.00%** (alpha>0.1 and >0.5 also 0%). v1 was also 0.00%.
- Pan x +220: 2.71% (all from the v1 top layer). Pan x -220: 4.61% (top 3.03% + v2 right 1.40%; v1 was 3.25%).
- Pan y -220: 0.00%. Pan y +220: 52.2% (top layer only, identical to v1: the board is pushed up under the top margin, so this is a pan-clamp matter). Diagonals: 2.4-4.5% upward, about 55% downward.

## Art concerns / regenerate candidates (current state)
1. **front_leaves_top (still v1):** the soft wavy fade from v1 is still there. It's the one layer left with the "fake fade" look, and next to the crisp v2 sides it now stands out. Regenerate: whole leaves hanging from the top edge on clean magenta, with no sky or scene behind them. The v2 attempt painted a full sunset backdrop.
2. **Scenario stair-stepping in all v2 raws:** silhouettes were generated as ~16 px blocks. The keyed edges are repaired, but stepped shapes **inside** the paintings remain: the black monstera holes in the left top leaf, and especially back_mid's moss ring, whose outer edge against the painted sky has blocky ledges. At in-game scale (0.48x) they're small but visible on the moss ring's top left.
3. **back_mid v2 is a full opaque painting** (its own sky, trees and sun), not a foliage ring over back_far. back_far is now only visible through the oval, and the sky moves at the mid parallax (0.40). It reads well in the composite. The moss "wreath" around the oval is a bit frame-like, but it is organic and has no structures. A regeneration with a softer, less ring-shaped inner edge would be better, but it isn't blocking.
4. **front_leaves_left v2:** the dark shadow mass between the leaves is a synthetic flat tint (from the raw's flat black backing). It reads as deep foliage shadow at game scale, but up close it's flatter than the painted indigo undergrowth on the right.
5. Wider-view/ultrawide headroom note from v1 still applies (back_mid 2048 world px wide; scale or clamp for ultrawide).
