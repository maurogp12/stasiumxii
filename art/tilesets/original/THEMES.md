# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it.

Crosshaven, Brinewake, and Slagcrown are slices of `original-tileset-b.jpg`. Windmere is sliced from the ice punch sheets in `pending/ice/punch/`. Stormspire is sliced from the electric sheet `pending/electric/stasium_tileset_electric.png`.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grass, dirt, water, grass cliffs, farm props |
| Brinewake | coast | `brine_*` | Cobble and stone, deep water, stone cliffs, rocks, log |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, scorched cliffs, volcanic rock props |
| Windmere | ice | `wind_*` | Snow and bare ice, meltwater, ice cliffs, sparse crystals. Live source `pending/ice/punch/wind_ground_punch.png`, `wind_elevation_punch.png`, `wind_props_punch.png`. The scenario sheet `pending/ice/stasium_tileset_ice.png` stays in the folder. |
| Stormspire | electric | `storm_*` | Dark stone, purple energy tiles, electric cliffs, energy crystals. Source `pending/electric/stasium_tileset_electric.png` |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first. Windmere crystals stay narrow accents. Flat ice and water tiles are hard 64×32 diamonds so the freeze/water seam stays readable. Tags and the tmx geometry are unchanged.

Slagcrown cliffs are the bare dirt/rock walls on `original-tileset-b.jpg`, not the grass-capped stone block. Mossy forest props (`basalt_pillar`, `ash_rock`, `rubble`) are `slag_prop_*.png` from the bare volcanic rock cells on that same sheet. `rock_pillar`, `floor_seal`, and `steam_vent` stay on the shared sheets because those slices are already bare rock or fire. Crosshaven and Brinewake keep the original-sheet props, including grass and moss.

Windmere’s live slices are the ice punch (soft lock: hielo, agua, sparse crystals). `slice_windmere_punch.py` overwrites only `wind_*.png` and `wind_prop_*.png`. Flat ice and water stay hard 64×32 diamonds so the freeze/water seam stays readable.

Stormspire’s live slices are the electric contact sheet. Re-running the ice slicer refreshes Windmere only and does not put a punch sheet onto Stormspire.

Brinewake ground, water, and cliffs are the cobble and stone cells on `original-tileset-b.jpg`. Props the coast paints stay on the shared original-sheet files. Tags and geometry are unchanged.

Tags and combat numbers are unchanged.
