# Northgate theme kit — light snow + crags (Crosshaven outskirts)

A PC-only painted 2D iso kit for the northern outskirts of the Crosshaven open world. It uses the same 2:1 grid, cell size,
file layout and anchors as `art/world/crosshaven/`. Godot root: `res://art/world/outskirts/northgate/`.
The machine-readable spec is in `atlas_meta.json` (tiles / terrace / props / roof_caps / swatches), `props.json`,
`props/props.json` and `kit.json` (134 ids).

## Look (direction update, 2026-10-03)
The palette follows the Crosshaven plate (`ref/look_target/crosshaven_plate.jpg`): hay-gold / yellow-green grass,
warm grey and cliff-white stone, clear blue water, soft gouache painting.

- **Northgate snow is light.** It is a dusting, but it should still read as snowy at a glance.
  - The main ground is **frost_grass**.
  - The common snowy tile is **snow_patch_a..d**: frost grass with 2–4 irregular snow patches.
    Cover is a 27%, b 33%, c 38% and d 30%.
  - **Full snow (snow_a..d, snow_rock_a/b, crag_a..c) is only for crag tops and high ground.** Do not use it for open fields.
- **Roofs:** the default caps are `roof_snow_patchy_a` and `roof_snow_dust_a`. Each is a broken band in the top third
  of the slope, with no eave lip or icicles. The full caps are a deep-winter option.
- **Drifts** are a light dusting at wall, fence and tree bases. Crest is about 14 px (wall) or 10 px (fence) at 2x, and the far tails fade to about 55% alpha.
- **Crag rock** is graded to warm grey with pale cliff-white faces. Shadows are cool but not blue, and the lip snow is thin (about 5–7 px).
- **Ice** plates are pale lake blue, and their cracks and shadows are blue rather than turquoise.
- **Grass joins** use the repo's `golden_plains_*` pixels unchanged. Frost grass matches its hue (about 0.19–0.20) and is paler and frosted.
- There are no labels on the ground and no chunk-board look (no dark field, no floating slabs).

## Layout (world kit)
```
tiles/<id>.png      1x  (64x32 diamond)        tiles/_2x/<id>.png     2x master (128x64)
props/<id>.png      1x                          props/_2x/<id>.png     2x master
roof/<id>.png       1x                          roof/_2x/<id>.png      2x master
overlays/<id>.png   1x                          overlays/_2x/<id>.png  2x master
```
Why this layout: it drops straight into `crosshaven_art.gd`'s `texture(kind, id)` lookup, and it matches the reference
atlas schema that `tools/check_assets.py --package world` validates. All PNGs use straight alpha, linear filtering and no mipmaps.
Draw 2x masters at scale 0.5; placement is identical.

## Families
| family | ids | use |
|---|---|---|
| frost grass (main ground) | `frost_grass_a..d` | interior of the frost terrain |
| snow patch (common snowy) | `snow_patch_a..d` | same terrain as frost grass. Its border band is plain frost grass, so it mixes freely with frost_grass and uses the frost_grass edges |
| frost→golden edges | `frost_grass_edge_<sides>` (15), `frost_grass_corner_<n,e,s,w>` | where frost grass meets the repo `golden_plains` |
| full snow (high ground only) | `snow_a..d` (a/b common, c/d rare), `snow_rock_a/b` | crag tops / high ground |
| snow→frost edges | `snow_edge_<sides>`, `snow_corner_*` | where full snow meets frost grass |
| crag tops | `crag_a..c` + `crag_edge_*`, `crag_corner_*` | plateau interior; the edge is a wind cornice where it drops |
| ice on water | `water_ice_edge_{nw,ne,se,sw}`, `water_ice_corner_{n,e,s,w}`, `water_ice_a/b` | decals over the repo `water_a..d` |
| frost decals | `frost_overlay_a/b` | diamond rime decals that frost an existing grass tile |
| cliffs | `crag_cliff_{left,right}_h1..h3`, `crag_side_{left,right}_{top,a,b,base_ground}`, `crag_lip_{left,right}`, `crag_lip_corner_{front,left,right}` | terrace drops |
| crag props | `crag_spire_a/b`, `crag_outcrop_a/b` (2x2, 256x384), `crag_outcrop_c/d`, `crag_boulders_a..d`, `crag_split_shrub` (1x1), `crag_cairn_flag` (tree class 128x224) | rocks, with contact AO baked in |
| drifts | `drift_wall_long_a..c` (2x1), `drift_fence_a`, `drift_tree_ring_a/b`, `drift_patch_a/b` | ground overlays |
| roof snow | `roof_snow_patchy_a`, `roof_snow_dust_a` (DEFAULT), `roof_snow_full_a/b`, `roof_snow_{left,right}_{a,b}` (option) | masked onto cottage roofs |
| frost tint | `overlays/frost_tint_swatch` (512 at 2x, tileable) | screen/world-space rime |

## Autotile grammar
- **Chain:** `golden_plains → frost_grass_edge_* → frost_grass / snow_patch → snow_edge_* → snow` (crag tops / high ground only).
- **Edges:** `<family>_edge_<sides>` lists the sides in the order nw, ne, se, sw. It is a floor tile used *instead of* the interior when those side neighbours are the outer terrain.
- **Corners:** `<family>_corner_<n|e|s|w>` is a decal drawn over the floor when only that diagonal neighbour is the outer terrain.
- **Joins** (a neighbour that does not need an edge):
  - frost_grass / snow_patch join frost, snow, crag and water.
  - snow joins snow, crag and water.
  - crag joins only crag.
- **Interior mix (suggested picker weights):**
  - Frost field: frost_grass_a..d with a few snow_patch tiles.
  - Snowy field ("frost_snowy"; same edges as frost_grass): about 70% snow_patch_a..d and 30% frost_grass_a/b.
  - Snow (high ground): snow_a/b common, snow_c/d about 1 in 10, plus snow_rock occasionally.
  - Crag top: crag_a..c mixed with snow_a/b and snow_rock_b.
- **Water:** keep the repo `water_a..d` floor.
  - Add `water_ice_edge_<side>` for each land side.
  - Add `water_ice_corner_<c>` for each diagonal that is land while both of its side neighbours are water.
  - Add `water_ice_a/b` on about 1 in 3 open cells.
  - The decals are masked to the repo water alpha, so no hairline shows.

## Cliffs / terraces (step = 10 px at 1x, 20 px at 2x)
- **Faces** are drawn *before* the lifted cell's top tile.
  - Offsets are from the lifted cell centre at 2x: left/SW face `(-64,0)`, right/SE face `(0,0)`.
  - `crag_cliff_<side>_hN` is a one-piece face for an N-step drop.
- **Loader strips** (`crosshaven_art.gd` side-strip slot `<terrain>_side_<face>_<top|a|b|base_ground>`):
  - Strip k is drawn at `offset_2x + k*(0,20)`.
  - Use `top` for k=0, alternate `a`/`b`, and use `base_ground` for the last strip (it has snow banked at the foot).
  - The foot noise is periodic along the face, so chained faces match.
- **Lips** are drawn *after* the top tile.
  - `crag_lip_left` goes at `(-64,-8)`, `crag_lip_right` at `(0,-8)`. Both are 64x52 with the cell edge at canvas y 8..40.
  - `crag_lip_corner_front/left/right` are 40x40 with pivot `(20,12)` on the matching vertex of the lifted cell.
- **Lighting:** the key light is top-left. The SW face is lit and the SE face is in cool (not blue) shade.

## Drifts and props
- **Draw order:** ground (floors, edges, decals, faces) → drifts (`layer: ground_overlay`) → y-sorted props.
- **Prop anchor:** the image bottom-centre sits on the south tip of the footprint's south-most cell.
- **2x1 wall drifts:**
  - Anchored on the FRONT cell; the footprint runs back to `(x-1,y)`.
  - Painted along +x. Use `flip_h` for a run along +y.
  - Draw them before the wall or fence they hug.
- **Ring drifts:** the tree trunk base sits in the hole. `hole_px_2x` is given in the json.
- **Crag rocks:** the snow skirt fades out inside the footprint, and the contact AO is baked in (alpha ≤ 0.3).

## Roof snow recipe (any cottage sprite)
1. Get the roof alpha (for the repo slate cottages, this is the blue slate pixels; see `previews/.../roof_masks/`).
2. Choose the slope. The left slope faces SW (ridge descending to the right) and uses shear **+0.5**.
   The right slope uses shear **−0.5**. You can shear the flat 640-wide periodic cap or use the pre-sheared
   `roof_snow_{left,right}_*`. Fit the eave line at a fixed 2:1 slope.
3. Place the cap:
   - **DEFAULT (`patchy_a` / `dust_a`):** map the cap's top rows into the band 0.03–0.36 of the ridge→eave depth,
     then fade it out with a noisy edge. There is no lip and no icicles.
   - **OPTION (`full_*`):** the cap top sits about 5% below the ridge and the cap eave on the roof eave.
     Extend the roof alpha downward by `lip_px_2x` (16/16/14/9), but **only below the eave line**, so the lip and icicles can hang.
4. Output = roof alpha × cap alpha, composited over the sprite. Optionally borrow the roof's high-pass luminance as soft bumps,
   and give any visible back slope plain cap body at about 0.86 brightness.

## Frost tint swatch
`overlays/_2x/frost_tint_swatch.png` is 512x512, tileable, straight alpha, mean alpha 0.37.
To use it, sample at `world_px / 512` (2x) in a grass shader or modulate pass to frost any grass, including repo
golden_plains, without diamond edges.

## Previews
These are in `previews/outskirts_themes/northgate/`:
- `mock_northgate.png` / `_1x` / `_layout.json`: frost and snow-patch fields, full snow on and around the crag, light roof caps, light drifts.
- `contact_sheet.png`: every piece.
- `roof_snow_demo.png`: DEFAULT rows first, then the full option.
