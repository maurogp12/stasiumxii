# walls v3 — 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO
- Material re-painted to match tower_round (rectangular grey-beige blocks, same outline/shading; colour-matched to tower stats).
- Back parapet recessed: low, darker lip; walkway visible between it and the front merlons.
- wall_h + wall_h_b + wall_h_c: 206 px step, footprint [2,1], shared edges (mix freely).
- gate_h / gate_diag_*: 700 px gatehouse block (635 px wide) with its own square merlons; arch 261x455; 550 px wall flanks. height_px 700.
- Doors: v1 leaves rescaled to 261x455 (diag 261x585 sheared), 8 frames, 12 fps, inward, no portcullis/dust, arch alpha 0 with thin rim.
- Tunnels: gatehouse arch scaled into the wall, procedural iron grate.
- Script: scripts/build_g1_v3_walls.py, scripts/sheets_v3.py. Raws: raw/v3_wall_h_raw.jpg, v3_wall_diag_raw.jpg, v3_gatehouse_raw.jpg. v2 in ../_v2_backup/.
