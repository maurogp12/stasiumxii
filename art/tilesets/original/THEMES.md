# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven, Brinewake, and Slagcrown are slices of `original-tileset-b.jpg`. Windmere and Stormspire are slices of the scenario sheets that were dropped in `pending/` and promoted.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grass, dirt, water, grass cliffs, farm props |
| Brinewake | coast | `brine_*` | Cobble and stone, deep water, stone cliffs, rocks, log |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, stone cliffs, campfire |
| Windmere | ice | `wind_*` | Snow and bare ice, deep water, ice cliffs, ice crystals. Source `pending/ice/stasium_tileset_ice.png` |
| Stormspire | electric | `storm_*` | Dark stone, purple energy tiles, electric cliffs, energy crystals. Source `pending/electric/stasium_tileset_electric.png` |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first. Crosshaven, Brinewake, and Slagcrown keep the original-sheet props.

Tags and combat numbers are unchanged.
