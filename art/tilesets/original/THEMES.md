# Koliseo board families

Visual source is the original isometric sheets in this folder. Boards paint slices of `original-tileset-b.jpg` (the labeled 64×32 sheet). `original-tileset-a.jpg` is the same set in the other layout. Flat terrain is a full 64×32 diamond. Cliffs keep that top face and hang the rock face below it.

| Arena | Pack | Files | What you see |
| --- | --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, `ground_e1.png`, `ground_e2.png` | Grass, dirt, water, grass cliffs, farm props |
| Brinewake | coast | `brine_*` | Cobble and stone, deep water, stone cliffs, rocks, log |
| Slagcrown | lava | `slag_*` | Cracked earth, lava, dark rock, stone cliffs, campfire |
| Windmere | pale stone | `wind_*` | Pale cobble from the sheet. Not an ice pack |
| Stormspire | dark stone | `storm_*` | Dark rock from the sheet. Not an electric pack |

Cell variety is extra `*_vN.png` siblings of the primary file. The primary name is what `KoliseoArt.terrain_texture` returns.

## Not in this pass

Ice and electric sheets are a separate scenario job. Hooks:

- `pending/ice/` — Windmere should switch to that sheet when it lands. Do not invent snow tiles here.
- `pending/electric/` — Stormspire should switch to that sheet when it lands. Do not invent lightning tiles here.

The one ice crystal on the original sheet is `prop_ice_shard.png` only. It is not a terrain pack. Waterfall, hay, floor seals, conduits, and arcs use the closest sprite on the sheet (rock, bush, stone, pillar, wall). Tags and combat numbers are unchanged.
