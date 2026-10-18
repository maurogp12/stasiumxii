# Crosshaven: Rosebud package (v9 data, no video)

All coordinates are plate pixels on a 5120x2880 plate (= reference coords x5). Origin is top-left and y points down.

## Wiring (same pattern as swamp v15 / Mirebound: plate + walkmask + hand zones)
1. **Background:** draw `ground.jpg` (bare terrain, roads, river) as the lowest layer. `plate.jpg` is the flattened preview with every sprite baked in. Use it only as a static backdrop if you skip the layers.
2. **Sprites:** `layers.json` lists `layers[]` with `file, x, y` (top-left), `sort_y`, `tag` and `fade`.
   - `under_everything: true` (bridges, NW steps): draw these right after the ground, in list order, before any y-sorted sprite.
   - Everything else is y-sorted together with characters by `sort_y` (the character key is foot y).
   - Fade: only `occluding_only` sprites can fade, and only while their pixels overlap the hero's bounding box. Ramp alpha to `fade_min_alpha` (lintel 0.40, others 0.45) over about 0.25 s. Never fade walls, gate_back or trees behind the gate. Characters never disappear.
   - Gate: the gatehouse is split into `gate_back` (drawn behind the hero) and `gate_front_lintel` (tag `lintel`, drawn in front). The hero walks between the two through the arch.
3. **Collision:** `walkmask.png` (white = walkable). Same convention as `swamp_walkmask_v15.png`: blocked by default and full plate resolution. Sample it at the hero's foot point. Keep about 12 px clearance.
4. **Zones (`zones.json`):**
   - `bridges[]`: `entries` are the only ways onto a bridge (the bottom of each staircase, plus an `approach` point about 120 px out along the road axis). `centreline` + `centreline_z`: approach, SE stair bottom, SE top, deck apex, NW top, NW stair bottom, approach. Parapets, side faces and abutments are blocked. Only a 34 px deck-centre corridor is open.
   - `stairs[]` polygons: inside one, lerp z from `z_from` to `z_to` by progress bottom→top. Draw the sprite at `y - z` and keep the collision foot at y.
   - `deck`: z follows the polyline. While z > 0, draw the hero after that bridge's layers, so he shows above the deck and never behind the side wall. `heightmap.png` holds the same z as greyscale (value = px).
   - `water`: never walkable (`river.png`), including under the bridges.
   - `gates[0].passage` is the arch walk polygon. `water_gates` are visual only.
   - `spawn.hero` is at the south map edge, facing N on the gate road.
5. **Routes (`routes.json`):** `hero_tour`, `bridge_crossings` (head-on climb, deck centre, descend, step out onto the road), and `npcs`: `idle` NPCs loop `(anim, seconds)`, `walker_pingpong` NPCs move at `speed` px/s, plus the `patrol` warden. `pets` trot a↔b at 40 px/s with a 1.5 s pause and a 3 px hop.
6. **Hero:** `bastion_v4/` has the walk/idle/attack/hit/death frames (`walk/bastion_walk_{S,N,E,W}_f00..f11.png`, 12 frames at about 8 fps, about 56 px tall in game). See `bastion_v4/README.md`.

## Notes
- The NW ends have 10-step flights with a paved landing joining the deck. The old abutment/parapet stub and its baked grass are cut away. The cobble runs under the bottom step at deck width.
- Elevation values are approximate (SE stairs 0→40, apex 62, NW top 55). Tune them in zones.json.


## Bridges (v4, Oct 15)
All 3 crossings use `meshy_bridge_v2` (a Meshy model, made exactly symmetric in Blender, with a paint-over pass). Each end has the same 6-step stairs, under 30 deg so you can see the treads from the camera, with a 68 px inner width that matches the road. Each bridge sits centred over the water along the deck axis: the arch spans the whole river and both stair bottoms land on the bank, about 125 px from the water. Stairs and centreline come from projected 3D points. Elevation: stairs 0 -> 45 px, deck crown 60 px (`centreline_z`). Inside each deck corridor, `heightmap.png` comes from the render's height pass (`bridge_h_<i>.png`, capped at the deck crown). Walk mask: you can only get on at the bottom step of either stair, and parapets and side walls are solid. The water mill moved to ref (735,330), and the convent moved to (660,188) so it is clear of the river and bridge 1.
