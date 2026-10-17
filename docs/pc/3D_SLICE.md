# Stasium XII: 3D slice (Crosshaven first)

Status: work in progress on `claude/pc-3d-slice`. Mauro's gate: **Crosshaven in 3D first**, plus the 5 class heroes. Nothing else moves until he approves it.

## What is built

- **Generic 3D city builder** (`slice3d/city/`): city layout data in, 3D scene out.
  - `city_plan.gd` reads a city file (`data/world/city3d/<city>.json`). Crosshaven reads the approved modular layout (`data/world/crosshaven_city/tilemap.json`, built from `streetplan.json`) through the existing `TileCity` data, so 2D and 3D agree on every cell.
  - `city_builder.gd` builds the terrain (one mesh, splat colours per cell corner, procedural setts and grass), water, the ring wall, towers, gatehouses with opening doors, water tunnels, bridges, every building and prop, lamps, window glow, chimney smoke and the mill wheel.
  - Placeholder geometry is sized in metres from `data/world/city3d/scale_table.json`. A model at `res://art/3d/<kind>.glb` replaces the placeholder of that kind.
  - `nav_grid.gd`: the walk grid from the layout (same `passable` rule as 2D), A* plus line-of-sight smoothing, so walking glides in straight legs.
  - `city_env.gd`: shared sun, sky, fog, tone, and a day/night clock from the city file's keyframes. Lamps and windows light up at night.
  - `city_life3d.gd`: the city's NPCs at their posts, keeping the same day as the 2D city life, with a "!" over mission givers, plus townsfolk strolling the streets by day.
  - `hero3d.gd` + `camera_rig.gd`: click-to-walk hero; high-angle 3/4 camera with orbit, zoom and pan.
- **Scene:** `res://slice3d/city3d.tscn`.
- **Hero model:** `art/3d/characters/hero_male/` (rigged, with walk and run clips; textures re-encoded to 1024 px). Loaded at run time, so the folder has a `.gdignore` and needs no editor import.

## Scale

- Crosshaven cell = 2.0 m. Hero = 1.8 m.
- Heights per kind are in the scale table (Proposed).

## Rules

- The existing combat engine and every rule stay unchanged. 3D is a presentation layer.

## Meshy log

| Job | What | Credits |
|---|---|---|
| multi-image-to-3d 01a14bb3 | hero_male from Grok's turnaround (front, side, back), textured, PBR, 20k tris | 30 |
| rigging 01a14bb8 | hero_male rig (+ free walk and run clips) | 5 |
| animation 01a14bcb | hero_male idle (action 0) | 3 |

Balance before: 2188.
