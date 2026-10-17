# tilekit GROUP 1 (ground + walls) — 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO

Style A (approved), original art. Iso 2:1, tile 128x64, hero 156 px, light from upper left. RGBA, keyed from #00FF00.

## Ground (ground/)
- `<terrain>_atlas_CONCEPTO.png`: 512x256 dual-grid corner atlas, 4x4, index = mask (N=1 E=2 S=4 W=8). A set corner means that corner is this terrain; unset corners are transparent. Seamless, no outlines.
- Draw priority: grass < dirt < cobble < plaza < water. In the check renders a corner is set when the vertex terrain is >= this layer, so lower layers fill underneath.
- `<terrain>_full_variants_CONCEPTO.png`: 3 variants of mask 15 (384x64), edge-identical to the atlas tile (grass, dirt, cobble, plaza).
- Water: `water_atlas_CONCEPTO.png` (frame 0) and `water_atlas_anim_CONCEPTO.png` (6 atlases side by side, 8 fps, seamless loop). The stone bank band is built into the edge tiles.
- `bridge_stone_CONCEPTO`, `bridge_wood_CONCEPTO`: walkable pieces that go over water and under props/actors.

## Pieces
| file | size | foot | footprint | height |
|---|---|---|---|---|
| buildings/house_npc_halftimber_blue_2storey_CONCEPTO.png | 613x540 | [306, 480] | [3, 3] | 480 |
| buildings/house_npc_halftimber_blue_a_CONCEPTO.png | 596x520 | [298, 460] | [3, 3] | 460 |
| buildings/house_npc_halftimber_red_L_CONCEPTO.png | 695x500 | [347, 440] | [4, 3] | 440 |
| buildings/house_npc_plaster_blue_2storey_CONCEPTO.png | 576x530 | [288, 470] | [3, 3] | 470 |
| buildings/house_npc_plaster_red_a_CONCEPTO.png | 546x500 | [273, 440] | [3, 3] | 440 |
| buildings/house_npc_plaster_red_pink_CONCEPTO.png | 580x510 | [290, 450] | [3, 3] | 450 |
| buildings/house_npc_stone_blue_round_CONCEPTO.png | 553x490 | [276, 430] | [3, 3] | 430 |
| buildings/house_npc_stone_red_a_CONCEPTO.png | 598x510 | [299, 450] | [3, 3] | 450 |
| buildings/house_npc_workshop_red_CONCEPTO.png | 652x520 | [326, 460] | [4, 3] | 460 |
| buildings/house_player_legendary_CONCEPTO.png | 984x820 | [492, 760] | [7, 6] | 760 |
| buildings/house_player_normal_CONCEPTO.png | 775x530 | [387, 460] | [4, 3] | 460 |
| buildings/house_player_rare_CONCEPTO.png | 753x640 | [376, 580] | [4, 4] | 580 |
| buildings/landmark_bank_CONCEPTO.png | 844x720 | [422, 650] | [5, 5] | 650 |
| buildings/landmark_castle_CONCEPTO.png | 1389x1220 | [694, 1150] | [10, 10] | 1150 |
| buildings/landmark_cathedral_CONCEPTO.png | 1095x1070 | [547, 1000] | [9, 5] | 1000 |
| buildings/landmark_townhall_CONCEPTO.png | 990x920 | [495, 850] | [7, 7] | 850 |
| ground/bridge_stone_CONCEPTO.png | 740x393 | [370, 343] | [2, 5] | 343 |
| ground/bridge_wood_CONCEPTO.png | 740x449 | [370, 399] | [2, 5] | 399 |
| walls/gate_diag_ne_CONCEPTO.png | 1323x1212 | [661, 856] | [16, 1] | 550 |
| walls/gate_diag_se_CONCEPTO.png | 1323x1212 | [661, 856] | [16, 1] | 550 |
| walls/gate_door_diag_ne_CONCEPTO.png | 1952x474 | [122, 474] | [0, 0] | 474 |
| walls/gate_door_diag_se_CONCEPTO.png | 1952x474 | [122, 474] | [0, 0] | 474 |
| walls/gate_door_h_CONCEPTO.png | 1952x352 | [122, 352] | [0, 0] | 352 |
| walls/gate_h_CONCEPTO.png | 1323x600 | [661, 550] | [8, 1] | 550 |
| walls/tower_round_CONCEPTO.png | 608x1050 | [304, 989] | [3, 3] | 990 |
| walls/wall_diag_ne_CONCEPTO.png | 306x703 | [153, 601] | [3, 1] | 550 |
| walls/wall_diag_se_CONCEPTO.png | 306x703 | [153, 601] | [3, 1] | 550 |
| walls/wall_h_CONCEPTO.png | 306x600 | [153, 550] | [2, 1] | 550 |
| walls/water_tunnel_diag_ne_CONCEPTO.png | 718x909 | [359, 704] | [8, 1] | 550 |
| walls/water_tunnel_diag_se_CONCEPTO.png | 718x909 | [359, 704] | [8, 1] | 550 |
| walls/water_tunnel_h_CONCEPTO.png | 718x600 | [359, 550] | [6, 1] | 550 |

## Notes
- foot = the sprite pixel at the footprint's south corner (bottom centre of the art), not counting the soft contact-shadow margin.
- The wall segment is cut from the gate curtain itself, so wall and gate share one colour, merlon height and foot line. The tower plinth covers the wall ends; place the tower foot about 50 px below the wall foot line.
- Diagonal walls, gates and tunnels are sheared 2:1 versions; ne and se mirror each other.
- Doors: 8-frame horizontal strips at 12 fps. f00 is closed and f07 is open, swinging inward. Layer order: ground < door < gate curtain < actors. The arch has alpha 0 with a stone rim; no portcullis, no dust.
- wall_h is now a seamless 206 px repeat with 2 merlons; the cut is chosen where both edges match, with no crossfade.
- Buildings (GROUP 2): 9 NPC houses, 430-480 px tall (all below the 550 px wall), with red and blue roofs in plaster, half-timber and stone; no thatch. Player houses: normal 460 px (unique stone-and-green-timber cottage with a woodshed, repainted in GROUP 3), rare 580 px (turret, bay window, planters), legendary 760 px (mansion with potted plants and topiary only; no gate or walls; below the 850 px townhall). Check sheet: check_buildings_CONCEPTO.jpg.
- Water tunnel: curtain with an iron grate.
- Check sheets: check_ground_CONCEPTO.jpg, check_atlases_CONCEPTO.jpg, check_walls_CONCEPTO.jpg, check_doors_CONCEPTO.jpg, mock_gate_run_CONCEPTO.jpg.
- Scripts: scripts/build_g1.py, build_ground.py, render.py, sheets.py. Raws are in raw/.
- GROUP 3 landmarks (buildings/): landmark_castle 1150 px (10x10, a style-A repaint of big2/castle_native_v2), landmark_cathedral 1000 px (9x5), landmark_townhall 850 px (7x7), landmark_bank 800 px (5x5). All grey-beige stone with red and blue roofs. Check sheet: check_landmarks_CONCEPTO.jpg.
- Note: walls/ and ground/ now belong to the Group 1 v2 worker; the wall/ground rows in this table may be out of date.

- Workshops (buildings/): smithy 470, forge 540, potter 460, weaver 480, carpenter 450, tailor 480 and mill 500 px (wheel on the SE side, static). Check sheet: buildings/check_workshops_CONCEPTO.jpg.
- Props (props/): stall_fruit/cloth/bakery 220, fountain 260, well 290, lamp_post/lamp_hanging 250 (each with a <lamp>_glow_CONCEPTO.png night sprite: additive blend, offset_in_parent in its JSON), bench_iron 110, bench_stone 115, fence_picket 115, fence_rail 125, fence_stone 95 (ne axis; flip for se), crate 80, crate_stack 125, barrel and barrel_b 95, cart_hay 170, signpost 230, notice_board 200. Check sheet: props/check_props_CONCEPTO.jpg.
- Check sheets live in each group's folder (buildings/check_buildings, check_landmarks, check_workshops; props/check_props).


## v2 (Group 1 v2, drop-in; v1 in _v1_backup/, pre-seam-fix v1 in _v1_backup/_pre_seamfix/)
- Ground: organic edges (straight marching-square cuts for 1/3-corner tiles, smooth low-freq wobble, per-mask interior variation), grass tufts and small stones along cobble/dirt/plaza borders, soft inner border shade, no outlines, 1 px diamond overdraw to kill grid lines. Same atlas layout/size.
- Walls: new painted wall with thickness (walkway + back parapet behind the front merlons), square blocky merlons with top faces, 206 px repeat (1 merlon), footprint [2,1]. Diagonals come from a separately painted iso wall (flattened, tiled, re-projected), not a shear of wall_h; ne = mirror of se, 10% darker.
- Gates/tunnels: rebuilt on the new wall, flat-style voussoir arch + jambs + shaded soffit; hole 236x262 (was 244x352) so it sits under the merlons. Doors = v1 leaves rescaled to the new hole, 8 frames 12 fps. Tunnel grate procedural (no light patch).
- Sheets: check_*_CONCEPTO_v2.jpg, mock_gate_run_CONCEPTO_v2.jpg. Scripts: build_g1_v2_walls.py, build_ground_v2.py, sheets_v2.py. Raws: raw/v2_wall_h_raw.jpg, raw/v2_wall_diag_raw.jpg.

| file | size | foot | footprint | height |
|---|---|---|---|---|
| ground/bridge_stone_CONCEPTO.json | 740x393 | [370, 343] | [2, 5] | 343 |
| ground/bridge_wood_CONCEPTO.json | 740x449 | [370, 399] | [2, 5] | 399 |
| walls/gate_diag_ne_CONCEPTO.json | 1323x1229 | [661, 873] | [16, 1] | 550 |
| walls/gate_diag_se_CONCEPTO.json | 1323x1229 | [661, 873] | [16, 1] | 550 |
| walls/gate_door_diag_ne_CONCEPTO.json | 1888x380 | [118, 380] | [0, 0] | 380 |
| walls/gate_door_diag_se_CONCEPTO.json | 1888x380 | [118, 380] | [0, 0] | 380 |
| walls/gate_door_h_CONCEPTO.json | 1888x262 | [118, 262] | [0, 0] | 262 |
| walls/gate_h_CONCEPTO.json | 1323x600 | [661, 550] | [8, 1] | 550 |
| walls/tower_round_CONCEPTO.json | 608x1050 | [304, 989] | [3, 3] | 990 |
| walls/wall_diag_ne_CONCEPTO.json | 306x720 | [152, 619] | [2, 1] | 550 |
| walls/wall_diag_se_CONCEPTO.json | 306x720 | [153, 619] | [2, 1] | 550 |
| walls/wall_h_CONCEPTO.json | 306x600 | [153, 550] | [2, 1] | 550 |
| walls/water_tunnel_diag_ne_CONCEPTO.json | 718x926 | [358, 721] | [8, 1] | 550 |
| walls/water_tunnel_diag_se_CONCEPTO.json | 718x926 | [359, 721] | [8, 1] | 550 |
| walls/water_tunnel_h_CONCEPTO.json | 718x600 | [359, 550] | [6, 1] | 550 |
