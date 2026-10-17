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
| ground/bridge_stone_CONCEPTO.png | 740x393 | [370, 343] | [2, 5] | 343 |
| ground/bridge_wood_CONCEPTO.png | 740x449 | [370, 399] | [2, 5] | 399 |
| walls/gate_diag_ne_CONCEPTO.png | 1323x1212 | [661, 856] | [16, 1] | 550 |
| walls/gate_diag_se_CONCEPTO.png | 1323x1212 | [661, 856] | [16, 1] | 550 |
| walls/gate_door_diag_ne_CONCEPTO.png | 1952x474 | [122, 474] | [0, 0] | 474 |
| walls/gate_door_diag_se_CONCEPTO.png | 1952x474 | [122, 474] | [0, 0] | 474 |
| walls/gate_door_h_CONCEPTO.png | 1952x352 | [122, 352] | [0, 0] | 352 |
| walls/gate_h_CONCEPTO.png | 1323x600 | [661, 550] | [8, 1] | 550 |
| walls/tower_round_CONCEPTO.png | 608x1050 | [304, 989] | [3, 3] | 990 |
| walls/wall_diag_ne_CONCEPTO.png | 409x754 | [204, 627] | [4, 1] | 550 |
| walls/wall_diag_se_CONCEPTO.png | 409x754 | [204, 627] | [4, 1] | 550 |
| walls/wall_h_CONCEPTO.png | 409x600 | [204, 550] | [3, 1] | 550 |
| walls/water_tunnel_diag_ne_CONCEPTO.png | 1027x1064 | [513, 782] | [8, 1] | 550 |
| walls/water_tunnel_diag_se_CONCEPTO.png | 1027x1064 | [513, 782] | [8, 1] | 550 |
| walls/water_tunnel_h_CONCEPTO.png | 1027x600 | [513, 550] | [6, 1] | 550 |

## Notes
- foot = the sprite pixel at the footprint's south corner (bottom centre of the art), not counting the soft contact-shadow margin.
- The wall segment is cut from the gate curtain itself, so wall and gate share one colour, merlon height and foot line. The tower plinth covers the wall ends; place the tower foot about 50 px below the wall foot line.
- Diagonal walls, gates and tunnels are sheared 2:1 versions; ne and se mirror each other.
- Doors: 8-frame horizontal strips at 12 fps. f00 is closed and f07 is open, swinging inward. Layer order: ground < door < gate curtain < actors. The arch has alpha 0 with a stone rim; no portcullis, no dust.
- Water tunnel: curtain with an iron grate.
- Check sheets: check_ground_CONCEPTO.jpg, check_atlases_CONCEPTO.jpg, check_walls_CONCEPTO.jpg, check_doors_CONCEPTO.jpg, mock_gate_run_CONCEPTO.jpg.
- Scripts: scripts/build_g1.py, build_ground.py, render.py, sheets.py. Raws are in raw/.