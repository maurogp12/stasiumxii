# Crosshaven terrain v2 — file layout & blend-mask notes (CONCEPTO)

- **albedo**: ter_<name>_albedo.webp — RGB sRGB, no alpha (v1 ter_<name>_albedo_height.webp is retired)
- **height**: ter_<name>_height.png — lossless 8-bit grayscale PNG, linear 0..1, 1024x1024 (same UV tile as the 2048 maps; bilinear upsample is fine for height-blend). Fine relief detail lives in the 2048 normal map.
- **normal**: ter_<name>_normal.webp — tangent space, OpenGL +Y (Godot default), baked from height with real relief
- **orm**: ter_<name>_orm.webp — R=AO, G=roughness, B=metallic(0), linear

weight_i = max(0, height_i + splat_i - max_j(height_j + splat_j) + 0.15); contrast 0.1-0.2. Mud lowest, cobble domes / slabs / grass tops highest.

| material | tile (m) | use | blend mask note |
|---|---|---|---|
| grass_short | 2.0 | mown/trampled grass inside plots, verges | height-blend over dirt_path: bare soil patches (low alpha) give way first; v2: low-frequency macro patches (yellow-green / dark-green, ~1 per tile) |
| grass_lush | 2.0 | meadows, outside the walls, riverbanks top | tallest material: wins height-blends against short grass/dirt; pair with grass card scatter; v2: low-frequency macro patches (yellow-green / dark-green, ~1 per tile) |
| dirt_path | 3.0 | packed dirt roads and paths | low/medium height; grass edges bleed in by height+noise mask; mud fills its low areas |
| mud | 3.0 | wet low ground, near millrace, gate approach, livestock pens | lowest height: always sits under others; puddles = low roughness where height<0.3; v2: roughness 0.08-0.40 (wet), AO smoothed (no speckles) |
| cobblestone | 2.0 | city streets inside the wall | domed cobbles ~12-18 cm (13 per 2 m tile), deep dark joints with mud in places; dirt/mud height-blend into the joints first |
| plaza_flagstones | 4.0 | central plaza, around fountain/gazebo, castle forecourt | irregular worn slabs of mixed size (recursive split + noise warp, no grid), chipped edges, moss in some joints; dirt blends into joints |
| riverbank_pebbles | 2.0 | river edges, under the bridge, millrace banks | rounded pebbles high; sand low; wet darkening zones lower roughness - bias wet zone toward water side |
| wall_base_gravel | 2.0 | 1-2 m strip at the foot of the city wall, towers, gatehouse | loose angular gravel in 3 overlapping layers on dirt (not a mosaic); dirt shows between; weeds at wall line |
| cobblestone_b | 2.0 | variant b of cobblestone (different seed/joint pattern); noise-mix with variant a to break the repeat | domed cobbles ~12-18 cm (13 per 2 m tile), deep dark joints with mud in places; dirt/mud height-blend into the joints first |

**Cobble a/b mix:** Mix ter_cobblestone (a) and ter_cobblestone_b with low-frequency world-space noise n (period ~6-10 m) through a sharp height-blend so whole cobbles switch (no ghosting): d=(h_a+1.6*(1-n))-(h_b+1.6*n); w_a=clamp(d/0.08+0.5). Same 2 m tile and scale. Preview: ter_cobblestone_ab_mix_preview_CONCEPTO_.jpg (8x8 m).
