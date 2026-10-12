# Blightwood Hollow kit (Proposed), art only, not committed
Target root: `res://art/world/blightwood_hollow/{tiles,props,animated}/`. Conventions copied from the WP10a Rowanvale/Windmere ship kits (Crosshaven schema): 64x32 floor diamond at 1x, `_2x/` masters drawn at scale 0.5 with identical placement, linear filter, no mipmaps, straight alpha. Tiles anchor at bottom-centre on the cell's south tip. Props anchor at bottom-centre on the south tip of the footprint's south-most cell. Y-sort uses the footprint's south-most cell. No baked cast shadows. The violet-black dusk grade is a runtime setting (crosshaven_grade.gdshader region params; see animated/grade_ramp_violet_dusk.png). The in-game mock previews the grade at about 55%.
Blend strip: blend_meadow_{side}_s3 is next to the blight and s1 is next to the meadow. The weight runs continuously across the 3 cells, so there's no hard edge. The road runs along grid x: watch_flagstone -> road_gap_wall -> road_gap_s3 -> s2 -> s1 -> map_polish road_dirt.
Mock: mock_ingame_1280.png. Sheet: contact_sheet.png (2x masters).

| file (1x; 2x master in `_2x/`) | 1x size | 2x size | pivot | use | class |
|---|---|---|---|---|---|
| tiles/blight_soil_a.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | Blightwood base turf (grass grammar), random-pick variant | floor 64x32 |
| tiles/blight_soil_b.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | Blightwood base turf (grass grammar), random-pick variant | floor 64x32 |
| tiles/blight_soil_c.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | Blightwood base turf (grass grammar), random-pick variant | floor 64x32 |
| tiles/blight_soil_d.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | Blightwood base turf (grass grammar), random-pick variant | floor 64x32 |
| tiles/root_ground_a.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | walkable root-laced soil (dirt grammar) | floor 64x32 |
| tiles/root_ground_b.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | walkable root-laced soil (dirt grammar) | floor 64x32 |
| tiles/root_ground_c.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | walkable root-laced soil (dirt grammar) | floor 64x32 |
| tiles/watch_flagstone_a.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | sunken watch road (stone grammar), Proposed family | floor 64x32 |
| tiles/watch_flagstone_b.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | sunken watch road (stone grammar), Proposed family | floor 64x32 |
| tiles/watch_flagstone_c.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | sunken watch road (stone grammar), Proposed family | floor 64x32 |
| tiles/blend_meadow_nw_s1.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from nw (stage 1/3) | floor 64x32 |
| tiles/blend_meadow_nw_s2.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from nw (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_nw_s3.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from nw (stage 3/3) | floor 64x32 |
| tiles/blend_meadow_ne_s1.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from ne (stage 1/3) | floor 64x32 |
| tiles/blend_meadow_ne_s2.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from ne (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_ne_s3.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from ne (stage 3/3) | floor 64x32 |
| tiles/blend_meadow_se_s1.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from se (stage 1/3) | floor 64x32 |
| tiles/blend_meadow_se_s2.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from se (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_se_s3.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from se (stage 3/3) | floor 64x32 |
| tiles/blend_meadow_sw_s1.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from sw (stage 1/3) | floor 64x32 |
| tiles/blend_meadow_sw_s2.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from sw (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_sw_s3.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from sw (stage 3/3) | floor 64x32 |
| tiles/blend_meadow_nw_ne.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from nw+ne (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_ne_se.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from ne+se (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_se_sw.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from se+sw (stage 2/3) | floor 64x32 |
| tiles/blend_meadow_sw_nw.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | blend strip blight->meadow, blight entering from sw+nw (stage 2/3) | floor 64x32 |
| tiles/road_gap_s1.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | road gap, blend stage 1 cell: meadow dirt -> pale root-dirt (pairs with blend_meadow_nw_s1; road runs along grid x (NW->SE on screen), blight side = NW edge) | floor 64x32 |
| tiles/road_gap_s2.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | road gap, stage 2: root-dirt starts showing flagstones | floor 64x32 |
| tiles/road_gap_s3.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | road gap, stage 3: mostly watch flagstone (the wall-gap cell side) | floor 64x32 |
| tiles/road_gap_wall.png | 64x32 | 128x64 | bottom-centre = cell south tip (tile) | road through the wall gap itself on blight_soil, full flagstone; next cells use watch_flagstone_* | floor 64x32 |
| props/tw_tree_giant.png | 160x224 | 320x448 | bottom-centre (80,224) 1x = south tip of 1x1 cell | twisted blight tree, leafed with hanging moss; height 224px 1x; sway: canopy top 40% | tree_tall |
| props/tw_tree_large_a.png | 128x192 | 256x384 | bottom-centre (64,192) 1x = south tip of 1x1 cell | twisted blight tree, leafed with hanging moss; height 192px 1x; sway: canopy top 40% | tree_tall |
| props/tw_tree_large_b.png | 128x192 | 256x384 | bottom-centre (64,192) 1x = south tip of 1x1 cell | twisted blight tree, leafed with hanging moss; height 192px 1x; sway: canopy top 40% | tree_tall |
| props/tw_tree_mid.png | 112x160 | 224x320 | bottom-centre (56,160) 1x = south tip of 1x1 cell | twisted blight tree, leafed with hanging moss; height 160px 1x; sway: canopy top 40% | tree_tall |
| props/tw_tree_small.png | 80x112 | 160x224 | bottom-centre (40,112) 1x = south tip of 1x1 cell | twisted blight tree, leafed with hanging moss; height 112px 1x; sway: canopy top 40% | tree_tall |
| props/tw_tree_bare_hanging.png | 112x160 | 224x320 | bottom-centre (56,160) 1x = south tip of 1x1 cell | twisted blight tree, bare with moss strands; height 160px 1x; sway: canopy top 40% | tree_tall |
| props/dead_snag_tall.png | 64x150 | 128x300 | bottom-centre (32,150) 1x | ominous dead snag silhouette, blocking 1x1 | tree_tall |
| props/dead_snag_broken.png | 64x90 | 128x180 | bottom-centre (32,90) 1x | ominous dead snag silhouette, blocking 1x1 | tree_tall |
| props/watch_tower_broken_tall.png | 64x160 | 128x320 | bottom-centre (32,160) 1x | broken watch tower, gate flank (blocking 1x1), tall | tower |
| props/watch_tower_broken_stump.png | 64x112 | 128x224 | bottom-centre (32,112) 1x | broken watch tower, gate flank (blocking 1x1) | tower |
| props/watch_wall_nwse_high.png | 64x80 | 128x160 | bottom-centre (32,80) 1x | ruined watch wall nwse high (fence axis like stone_wall_field), blocking | wall |
| props/watch_wall_nwse_low.png | 64x56 | 128x112 | bottom-centre (32,56) 1x | ruined watch wall nwse low (fence axis like stone_wall_field), blocking | wall |
| props/watch_wall_nesw_high.png | 64x80 | 128x160 | bottom-centre (32,80) 1x | ruined watch wall nesw high (fence axis like stone_wall_field), blocking | wall |
| props/watch_wall_nesw_low.png | 64x56 | 128x112 | bottom-centre (32,56) 1x | ruined watch wall nesw low (fence axis like stone_wall_field), blocking | wall |
| props/roots_decal_a.png | 64x32 | 128x64 | bottom-centre (32,32) 1x = cell south tip; decal, walkable, draw under units | surface roots decal (walkable) | decal 64x32 |
| props/roots_decal_b.png | 64x32 | 128x64 | bottom-centre (32,32) 1x = cell south tip; decal, walkable, draw under units | surface roots decal (walkable) | decal 64x32 |
| props/roots_decal_c.png | 64x32 | 128x64 | bottom-centre (32,32) 1x = cell south tip; decal, walkable, draw under units | surface roots decal (walkable) | decal 64x32 |
| props/roots_decal_d.png | 64x32 | 128x64 | bottom-centre (32,32) 1x = cell south tip; decal, walkable, draw under units | surface roots decal (walkable) | decal 64x32 |
| props/blight_mushrooms_a.png | 32x32 | 64x64 | bottom-centre (32,64) 1x | blight mushroom cluster, walkable decor | small |
| props/blight_mushrooms_b.png | 32x32 | 64x64 | bottom-centre (32,64) 1x | blight mushroom cluster, walkable decor | small |
| props/heart_of_the_blight.png | 192x256 | 384x512 | bottom-centre (96,256) 1x = south tip of the 3x3 footprint south cell (origin+(2,2)) | landmark 3x3: ruined watch obelisk strangled by roots, amber sap frozen mid-fall, spores held mid-burst. Low warm pulse optional (animated/heart_sap_pulse) | landmark_3x3 |
| animated/ground_fog_tile.png | 256x128 | 512x256 | top-left, tileable (wraps on X and Y); _1x = 256x128 | low ground fog overlay; draw above floor, below units at ~60% opacity, multiply-free normal blend | overlay |
| animated/ground_fog_drift_12f.png | 3072x128 | - | 12 frames 256x128 horizontal, loop, 8 fps; each frame tileable | animated drifting ground fog (seamless loop: layers shift integer multiples of the width) | anim |
| animated/spores_drift_12f.png | 1536x128 | - | 12 frames 128x128, loop 10 fps, tileable vertical rise | sparse pale spores (never neon) | anim |
| animated/heart_sap_pulse_8f.png | 1536x192 | - | 8 frames 192x192, centre on heart sap wound = anchor + (0,-181) 1x, add blend, 6 fps | low warm sap glow pulse on the Heart | anim |
| animated/grade_ramp_violet_dusk.png | 256x16 | - | - | suggested luminance->colour ramp for crosshaven_grade.gdshader region params (deeper violet-black dusk); runtime grade, not baked | lut |

Generator: `../kitsrc/paint.py` (deterministic). Mocks: `../kitsrc/mock.py`.
