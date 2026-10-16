# Blightwood v3 wiring notes (for #378, on top of 5ec33984)
Reference: mock_ingame_1280.png, before_after_zone.png. Hero measured at **58 px tall** in the 1280x720 v2 capture.

## 1. Prop scales (Sprite2D.scale, 1x art; full table in MANIFEST.md)
| sprite | target | scale |
|---|---|---|
| bones_skull | skull 0.3x hero (~17 px skull, 29 px pile) | 0.18 |
| crow_perched / crow_walking | 0.4x hero (23 px) | 0.15 |
| gravestone_cross / cracked / split | ~0.9x hero (49-55 px) | 0.21 |
| fence_a / fence_broken | 0.75x (44 px) | 0.20 / 0.21 |
| hanging_cage | 0.85x (49 px) | 0.21 |
| lantern | 0.55x (32 px) | 0.18 |
| wisp | 0.45x (26 px) | 0.17 |
| cobweb | 0.9x (52 px) | 0.28 |
| thorn_bush_a/b | 0.8x (46 px) | 0.22 |
| dead_tree_mid_a/b | 3x (174 px) | 0.69 / 0.65 |
| dead_tree_tall_a/b/c | 5x (290 px) | 0.76 / 0.79 / 0.79 |
Use the _2x files at half of these scales. If the camera zoom isn't 1:1 with the 1280 capture, keep the hero ratio.

## 2. Trees: fewer, edges only
- In v2, about 20+ trees in the zone.png view cover the hero and both paths. **Remove every tree whose base isn't on the outer 2-tile ring of the zone.**
- Keep **6 framing trees per screen-sized area (about 8-10 for the whole zone)**:
  - 2 on the far (north) border, drawn behind the fog;
  - 1-2 on each side edge;
  - 2 in the south corners. They draw in front of the hero, so keep them at least 4 tiles south of any path tile.
- Spacing: at least 6 tiles between trees, and at least 3 tiles from any path tile, NPC or spawn point.
- Mock positions (screen px in the zone.png view, bottom-centre):
  - tall_a (250,140) h290 and tall_c (930,150) h290, behind the fog;
  - tall_b (30,340) h320, mid_a (1210,330) h260, tall_b (1240,790) h330 and tall_a (40,800) h330, in front.
- Remove the interior thorn bushes or thin them by 70%. Keep about 3 per screen.
- Remove the oversized skulls, crows and gravestones next to the paths, or rescale them per section 1.
- Remove the yellow diamond pips scattered on the ground (about 30 in view). They read as pickups.

## 3. Ground tint
- The v3 ground textures and iso tiles are already baked cool and dark (grey-green-brown). Swap them in and set **modulate = Color(1,1,1)**.
- If you keep the v2 textures, use **modulate = Color(0.55, 0.62, 0.58)** on leaf, root and moss, and **Color(0.72, 0.78, 0.74)** on trodden_path, so the path stays about 30% lighter than the ground around it.
- Darken the path edges (0.55 multiply on a 1-tile soft border) so the X of paths reads.

## 4. Fog (normal blend, painted teal, no glow)
| layer | sprite | modulate alpha | placement | parallax |
|---|---|---|---|---|
| far | fx/fog_layer_far.png (v3, denser) | **0.95** | top band, full width, 360 px tall | 0.2 |
| far, 2nd copy | fx/fog_layer_far.png | **0.50** | shifted 100 px down, 260 px tall | 0.3 |
| mid | fx/fog_layer_mid.png | **0.55** | 90-390 px | 0.5 |
| near | fx/fog_layer_near.png | **0.18** | 330-710 px | 0.9 |
| height wash | solid **#3E6062** | **0.55 at the top, falling to 0 at 60% screen height** (curve ^1.3) | screen-space | - |

The drift speeds stay the same as v2. No additive blend on the fog. Additive is for the moon, shafts, glows and eyes only.

## 5. Unchanged
The eyes blink, glows, moon pools and shafts are the same as v2 (scales in the MANIFEST). The in-game wisps came out saturated blue. Use the wisp sprite as-is plus wisp_glow with modulate (0.8, 1, 0.95) so it stays a soft teal.
