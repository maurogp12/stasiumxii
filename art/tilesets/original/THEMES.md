# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven ground and cliffs are slices of the earth punch (`crosshaven_ground_punch.png`, `crosshaven_elevation_punch.png`, `crosshaven_props_punch.png`). Brinewake and Slagcrown are slices of `original-tileset-b.jpg`. Windmere is sliced from the ice sheet in `pending/ice/`. Stormspire is sliced from the algo-así punch sheets in `pending/electric/`.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | earth | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Dirt and stone, lighter mud, water, bare earth cliffs. Moss is only on the ruin walls. No lawn. |
| Brinewake | coast | `brine_*` | Cobble and stone, deep water, stone cliffs, rocks, log |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, scorched cliffs, volcanic rock props |
| Windmere | ice | `wind_*` | Snow and bare ice, deep water, ice cliffs, ice crystals. Source `pending/ice/stasium_tileset_ice.png` |
| Stormspire | electric | `storm_*` | Dark charcoal stone, cyan and violet seams, gold edge, ozone on the cracks. Cliffs and stairs from the elevation punch. Sparse pylons, vanes, banners, and rune rocks. Live source `pending/electric/storm_ground_punch.png`, `storm_elevation_punch.png`, `storm_props_punch.png`. The earlier contact sheet `stasium_tileset_electric.png` stays in that folder. |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first.

Crosshaven’s dirt, stone cliffs, and the props that arena paints (`ruins`, `well`, `hay`, `fence`, `rubble`, `rock_pillar`) come from the earth punch. `slice_crosshaven_punch.py` writes those unprefixed files, then paints moss into the ruin walls only and clears the green cast off the floor seal. Water and the lighter mud stay on `original-tileset-b.jpg` so those tags still read apart from the dirt. The floor seal stays a bare stone mark.

Slagcrown cliffs are the bare dirt/rock walls on `original-tileset-b.jpg`, not a grass-capped stone block. Mossy forest props (`basalt_pillar`, `ash_rock`, `rubble`) are `slag_prop_*.png` from the bare volcanic rock cells on that same sheet. `floor_seal` and `steam_vent` stay on the shared sheets. `rock_pillar` is the earth-punch column, which Brinewake and Slagcrown also use when they have no dress file of their own. Brinewake’s ruins, fence, and rubble use those same shared files.

Stormspire’s live slices are the algo-así punch (soft lock: electric and wind). `slice_storm_punch.py` overwrites only `storm_*.png` and `storm_prop_*.png`. Locked geometry, tags, and cell layout stay on the map files. Re-running `slice_ice_electric.py` refreshes Windmere and does not put the old electric sheet back onto Stormspire.

Tags and combat numbers are unchanged.
