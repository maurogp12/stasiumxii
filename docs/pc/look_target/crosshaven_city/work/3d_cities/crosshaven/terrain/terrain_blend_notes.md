# Crosshaven terrain set — blend-mask notes (CONCEPTO)

ter_<name>_albedo_height.webp (RGB albedo sRGB, A = height linear 0..1), ter_<name>_normal.webp (OpenGL +Y, tangent space; Godot default), ter_<name>_orm.webp (R=AO, G=roughness, B=metallic=0, linear)

weight_i = max(0, height_i + splat_i - max_j(height_j + splat_j) + 0.15); suggested contrast 0.1-0.2. Height scale is comparable across materials: lush grass/cobble stones ~0.7-0.9 tops, mud ~0.2-0.4 so mud settles into joints and low ground.

| material | tile (m) | use | blend mask note |
|---|---|---|---|
| grass_short | 2.0 | mown/trampled grass inside plots, verges | height-blend over dirt_path: bare soil patches (low alpha) give way first |
| grass_lush | 2.0 | meadows, outside the walls, riverbanks top | tallest material: wins height-blends against short grass/dirt; pair with grass card scatter |
| dirt_path | 3.0 | packed dirt roads and paths | low/medium height; grass edges bleed in by height+noise mask; mud fills its low areas |
| mud | 3.0 | wet low ground, near millrace, gate approach, livestock pens | lowest height: always sits under others; puddles = low roughness where height<0.3 |
| cobblestone | 3.0 | city streets inside the wall | stones tall, joints low: dirt/mud height-blend into the joints first |
| plaza_flagstones | 4.0 | central plaza, around fountain/gazebo, castle forecourt | slabs flat-high, joints low; grime/dirt blends into joints |
| riverbank_pebbles | 2.0 | river edges, under the bridge, millrace banks | rounded pebbles high; sand low; wet darkening zones lower roughness - bias wet zone toward water side |
| wall_base_gravel | 2.0 | 1-2 m strip at the foot of the city wall, towers, gatehouse | angular gravel mid height; dirt patches low; weeds at wall line |
