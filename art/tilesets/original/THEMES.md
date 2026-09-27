# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven and Slagcrown are slices of `original-tileset-b.jpg`. Brinewake is the coast punch in `pending/brinewake/`. Windmere is sliced from the ice punch sheets in `pending/ice/punch/`. Stormspire is sliced from the algo-así punch sheets in `pending/electric/`.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grass, dirt, water, grass cliffs, farm props |
| Brinewake | coast | `brine_*` | Wet sand, pier wood, tide scorch, deep water. Foam sits on the diamond seams. Tide crust is a few dark marks, not a grass carpet. Cliffs are wooden stairs that end on a deck. The upper-corner deck is not on the elevation sheet. Props are sparse and about one tile tall. Source `pending/brinewake/brine_ground_punch.png`, `brine_elevation_punch.png`, `brine_props_punch.png` |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, scorched cliffs, volcanic rock props |
| Windmere | ice | `wind_*` | Snow and bare ice, meltwater, ice cliffs, sparse crystals. Live source `pending/ice/punch/wind_ground_punch.png`, `wind_elevation_punch.png`, `wind_props_punch.png`. The scenario sheet `pending/ice/stasium_tileset_ice.png` stays in the folder. |
| Stormspire | electric | `storm_*` | Dark charcoal stone, cyan and violet seams, gold edge, ozone on the cracks. Cliffs and stairs from the elevation punch. Sparse pylons, vanes, banners, and rune rocks. Live source `pending/electric/storm_ground_punch.png`, `storm_elevation_punch.png`, `storm_props_punch.png`. The earlier contact sheet `stasium_tileset_electric.png` stays in that folder. |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first. Windmere crystals stay narrow accents. Flat ice and water tiles are hard 64×32 diamonds so the freeze/water seam stays readable. Tags and the tmx geometry are unchanged.

Slagcrown cliffs are the bare dirt/rock walls on `original-tileset-b.jpg`, not the grass-capped stone block. Mossy forest props (`basalt_pillar`, `ash_rock`, `rubble`) are `slag_prop_*.png` from the bare volcanic rock cells on that same sheet. `rock_pillar`, `floor_seal`, and `steam_vent` stay on the shared sheets because those slices are already bare rock or fire. Crosshaven keeps the original-sheet props, including grass and moss.

Windmere’s live slices are the ice punch (soft lock: hielo, agua, sparse crystals). `slice_windmere_punch.py` overwrites only `wind_*.png` and `wind_prop_*.png`. Flat ice and water stay hard 64×32 diamonds so the freeze/water seam stays readable.

Stormspire’s live slices are the algo-así punch (soft lock: electric and wind). `slice_storm_punch.py` overwrites only `storm_*.png` and `storm_prop_*.png`. Locked geometry, tags, and cell layout stay on the map files. Re-running `slice_ice_electric.py` calls the Windmere punch slicer and does not put the old electric sheet back onto Stormspire.

Brinewake props the coast paints (`driftwood`, `rock_cluster`, `rock_pillar`, `rubble`, `ruins`, `fence`, `waterfall`, `floor_seal`) are `brine_prop_*.png` from `pending/brinewake/brine_props_punch.png`, scaled to about one tile so the dress stays sparse. The floor seal is a small deck mark, not a second floor. Cliffs come from the regenerated `brine_elevation_punch.png`, which does not include the upper-corner wooden deck. The cap is the upper deck. The wooden stair hangs under it and stops on the lower deck in the same sprite. Foam is the seam of the diamond. It is not a haze across the face. Tags and geometry are unchanged.

Tags and combat numbers are unchanged.
