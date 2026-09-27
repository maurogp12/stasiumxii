# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven ground and cliffs are slices of the earth punch (`crosshaven_ground_punch.png`, `crosshaven_elevation_punch.png`, `crosshaven_props_punch.png`). Brinewake is the coast punch in `pending/brinewake/`. Windmere is sliced from the ice punch sheets in `pending/ice/punch/`. Stormspire is sliced from the algo-así punch sheets in `pending/electric/`. Slagcrown is sliced from the lava punch sheets in `pending/lava/`.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | earth | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Dirt and stone, lighter mud, water, bare earth cliffs. Moss is only on the ruin walls. No lawn. |
| Brinewake | coast | `brine_*` | Wet sand, pier wood, tide scorch, deep water. Foam sits on the diamond seams. Tide crust is a few dark marks, not a grass carpet. Source `pending/brinewake/brine_ground_punch.png` |
| Slagcrown | lava | `slag_*` | Lava and scorched dirt floors, dark ash pools, volcanic cliffs, volcanic props. Source `pending/lava/` punch sheets. No grass, moss, or bushes |
| Windmere | ice | `wind_*` | Snow and bare ice, meltwater, ice cliffs, sparse crystals. Live source `pending/ice/punch/wind_ground_punch.png`, `wind_elevation_punch.png`, `wind_props_punch.png`. The scenario sheet `pending/ice/stasium_tileset_ice.png` stays in the folder. |
| Stormspire | electric | `storm_*` | Dark charcoal stone, cyan and violet seams, gold edge. Hard 64×32 diamonds so the border stays readable. Cliffs hang at the real platform step; the high shelf is taller. The board draws six props, each about one diamond tall, and leaves the tagged ring undrawn. Live source `pending/electric/storm_ground_punch.png` (alias `ground_punch.png`), `storm_elevation_punch.png`, `storm_props_punch.png` (the 1280×720 props_small_v2 sheet, alias `props_punch.png`). The 2048 monolith is `pending/electric/archive/storm_props_punch_monolith.png` and is not sliced. `board_mood_punch.png` and `luca_preview_stormspire.png` are the look reference and are not sliced. The earlier contact sheet `stasium_tileset_electric.png` stays in that folder. |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first. Windmere crystals stay narrow accents. Flat ice and water tiles are hard 64×32 diamonds so the freeze/water seam stays readable. Tags and the tmx geometry are unchanged.

Crosshaven’s dirt, stone cliffs, and the props that arena paints (`ruins`, `well`, `hay`, `fence`, `rubble`, `rock_pillar`) come from the earth punch. `slice_crosshaven_punch.py` writes those unprefixed files, then paints moss into the ruin walls only and clears the green cast off the floor seal. Water and the lighter mud stay on `original-tileset-b.jpg` so those tags still read apart from the dirt. The floor seal stays a bare stone mark.

Slagcrown is `slice_lava_punch.py`. Floors are lava diamonds plus dirt and scorch from `pending/lava/ground_punch.png`. Cliffs are the volcanic ledges on `elevation_punch.png`. Every prop Slagcrown paints (`basalt_pillar`, `ash_rock`, `rubble`, `rock_pillar`, `steam_vent`, `floor_seal`) is a `slag_prop_*.png` from the center-tile cluster on `props_punch.png`, except the floor seal, which is a dark ash diamond so a dirt cell does not turn into a lava cell. `board_mood_punch.png` is a preview and is not sliced.

Windmere’s live slices are the ice punch (soft lock: hielo, agua, sparse crystals). `slice_windmere_punch.py` overwrites only `wind_*.png` and `wind_prop_*.png`. Flat ice and water stay hard 64×32 diamonds so the freeze/water seam stays readable.

Stormspire’s live slices are the algo-así punch (soft lock: electric and wind). `slice_storm_punch.py` overwrites only `storm_*.png` and `storm_prop_*.png`. Flat tiles are hard 64×32 diamonds with a gold north rim. Standing props are sliced from the 1280×720 small sheet and scaled to about one diamond (32px on the long side). The archived monolith sheet is not a source. `KoliseoArt.visual_props` draws six of them — a bolt, a spark, rubble, one pillar, one arc, and the center floor seal — and does not draw the tagged conduit ring or the pillar square. The Godot storm dress also shrinks any later sheet whose long side is over 32px. The mood sheet is reference only. Locked geometry, tags, and cell layout stay on the map files. Re-running `slice_ice_electric.py` calls the Windmere punch slicer and does not put the old electric sheet back onto Stormspire.

Brinewake props the coast paints (`driftwood`, `rock_cluster`, `rock_pillar`, `rubble`, `ruins`, `fence`, `waterfall`, `floor_seal`) are `brine_prop_*.png` from the punch sheets. Foam is the seam of the diamond. It is not a haze across the face. Tags and geometry are unchanged.

Tags and combat numbers are unchanged.
