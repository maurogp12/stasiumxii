# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven, Brinewake, and Slagcrown are slices of `original-tileset-b.jpg`. Windmere is sliced from the ice sheet in `pending/ice/`. Stormspire is sliced from the algo-así punch sheets in `pending/electric/`.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grass, dirt, water, grass cliffs, farm props |
| Brinewake | coast | `brine_*` | Cobble and stone, deep water, stone cliffs, rocks, log |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, scorched cliffs, volcanic rock props |
| Windmere | ice | `wind_*` | Snow and bare ice, deep water, ice cliffs, ice crystals. Source `pending/ice/stasium_tileset_ice.png` |
| Stormspire | electric | `storm_*` | Dark charcoal stone, cyan and violet seams, gold edge, ozone on the cracks. Cliffs and stairs from the elevation punch. Sparse pylons, vanes, banners, and rune rocks. Live source `pending/electric/storm_ground_punch.png`, `storm_elevation_punch.png`, `storm_props_punch.png`. The earlier contact sheet `stasium_tileset_electric.png` stays in that folder. |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first.

Slagcrown cliffs are the bare dirt/rock walls on `original-tileset-b.jpg`, not the grass-capped stone block. Mossy forest props (`basalt_pillar`, `ash_rock`, `rubble`) are `slag_prop_*.png` from the bare volcanic rock cells on that same sheet. `rock_pillar`, `floor_seal`, and `steam_vent` stay on the shared sheets because those slices are already bare rock or fire. Crosshaven and Brinewake keep the original-sheet props, including grass and moss.

Stormspire’s live slices are the algo-así punch (soft lock: electric and wind). `slice_storm_punch.py` overwrites only `storm_*.png` and `storm_prop_*.png`. Locked geometry, tags, and cell layout stay on the map files. Re-running `slice_ice_electric.py` refreshes Windmere and does not put the old electric sheet back onto Stormspire.

Tags and combat numbers are unchanged.
