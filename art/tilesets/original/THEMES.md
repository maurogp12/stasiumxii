# Koliseo board families

Visual source is the isometric sheets in this folder. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the wall below it. A left-half sheet from the early Koliseo pass is scaled onto that diamond at draw time.

Crosshaven ground, cliffs, and the farm props are the grassland slices from `ef474cd` (mobile parent of the earth punch). Brinewake is the coast punch in `pending/brinewake/`. Windmere is sliced from the ice punch sheets in `pending/ice/punch/`. Slagcrown and Stormspire paint the early Koliseo diamonds from `171f5b5` (Raise Koliseo graphics), which is older than the #184 restore parents `79eda27` and `fc2030d`. The earth punch, the lava punch, and the algo-así punch stay in the repo as rejected sources. Their slicers refuse to run.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | earth | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grassland diamonds, grass-capped cliffs, lighter mud, water, and the farm props (hay, fence, ruins, well, rubble, rock pillar). Source commit `ef474cd`. The earth punch `crosshaven_ground_punch.png` is not the live dress. |
| Brinewake | coast | `brine_*` | Wet sand, pier wood, tide scorch, deep water. Foam sits on the diamond seams. Tide crust is a few dark marks, not a grass carpet. Cliffs are wooden stairs that end on a deck. The upper-corner deck is not on the elevation sheet. Props are sparse and about one tile tall. Source `pending/brinewake/brine_ground_punch.png`, `brine_elevation_punch.png`, `brine_props_punch.png` |
| Slagcrown | lava | `slag_*` | Early readable half-diamonds: dark rock, red lava, cyan water, short rock cliffs. Props are the `171f5b5` shared sprites copied onto `slag_prop_*`. Older than `79eda27`. The lava punch `pending/lava/ground_punch.png` is not the live dress. No grass carpet. |
| Windmere | ice | `wind_*` | Snow and bare ice, meltwater, ice cliffs, sparse crystals. Live source `pending/ice/punch/wind_ground_punch.png`, `wind_elevation_punch.png`, `wind_props_punch.png`. The scenario sheet `pending/ice/stasium_tileset_ice.png` stays in the folder. |
| Stormspire | electric | `storm_*` | Early readable half-diamonds: blue-gray stone, bright water, short cliffs. Props are the `171f5b5` shared sprites copied onto `storm_prop_*`. Older than `fc2030d`. The algo-así punch sheets `storm_ground_punch.png`, `storm_elevation_punch.png`, and `storm_props_punch.png` are not the live dress. The contact sheet `stasium_tileset_electric.png` stays in that folder. |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

Windmere and Stormspire props that share a name with another arena (`spark`, `rubble`, `rock_pillar`, `floor_seal`) are `wind_prop_*.png` and `storm_prop_*.png`. The board tries the dress file first. Windmere crystals stay narrow accents. Flat ice and water tiles are hard 64×32 diamonds so the freeze/water seam stays readable. Tags and the tmx geometry are unchanged.

Crosshaven’s grassland, grass-capped cliffs, and the props that arena paints (`ruins`, `well`, `hay`, `fence`, `rubble`, `rock_pillar`) are the `ef474cd` slices of `original-tileset-b.jpg`. `slice_crosshaven_punch.py` refuses to run, so the earth punch cannot paint dirt back over that lawn. Water and the lighter mud stay on `original-tileset-b.jpg`. The floor seal stays a bare stone mark. Hay stays the green farm bundle.

Slagcrown is the `171f5b5` dress, not `slice_lava_punch.py`. Soft Lock: fuego + lava. Floors are the early half-diamonds: dark rock, red lava, and cyan water. `slice_lava_punch.py` refuses to run. Low walls are `slag_ground_e1.png` and `slag_mud_e1.png`. The high wall is `slag_ground_e2.png`, and it is taller. Props the arena already paints (`basalt_pillar`, `rock_pillar`, `ash_rock`, `rubble`, `steam_vent`, `floor_seal`) are `slag_prop_*.png` copied from the shared sprites at `171f5b5`. Punch-only siblings (`slag_ground_v1` and the lava variants) are not on disk, so the variant picker cannot mix them in. `board_mood_punch.png` is a reference plate and is not sliced. No grass carpet.

Windmere’s live slices are the ice punch (soft lock: hielo, agua, sparse crystals). `slice_windmere_punch.py` overwrites only `wind_*.png` and `wind_prop_*.png`. Flat ice and water stay hard 64×32 diamonds so the freeze/water seam stays readable.

Stormspire’s live slices are the `171f5b5` half-diamonds (soft lock: electric and wind). `slice_storm_punch.py` refuses to run, so the algo-así punch cannot overwrite `storm_*.png` or `storm_prop_*`. Locked geometry, tags, and cell layout stay on the map files. Re-running `slice_ice_electric.py` calls the Windmere punch slicer and does not write `storm_*.png`.

Brinewake props the coast paints (`driftwood`, `rock_cluster`, `rock_pillar`, `rubble`, `ruins`, `fence`, `waterfall`, `floor_seal`) are `brine_prop_*.png` from `pending/brinewake/brine_props_punch.png`, scaled to about one tile so the dress stays sparse. The floor seal is a small deck mark, not a second floor. Cliffs come from the regenerated `brine_elevation_punch.png`, which does not include the upper-corner wooden deck. The cap is the upper deck. The wooden stair hangs under it and stops on the lower deck in the same sprite. Foam is the seam of the diamond. It is not a haze across the face. Tags and geometry are unchanged.

Tags and combat numbers are unchanged.
