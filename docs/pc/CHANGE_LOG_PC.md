# STASIUM XII (PC): change log

PC game only. Never merged into `main` or `mobile` by an agent; only Mauro merges.

| Date | What | Why / who asked | Branch | Commit |
|---|---|---|---|---|
| 3 Oct 2026 | Added `docs/pc/ZONES_BUILD_SPEC.md`: build spec for the PC open world zones (levels 1–50, 11 zones, one dungeon per zone, 51 NPCs), work packages WP0–WP13, team split, data formats, Locked / Proposed / Open, PC-only rule. Docs only, no game change | Mauro: zone plan approved to try; Stormspire / Coilgate south of Gloomfen at 35–40; "you write the instructions, the build team builds"; main goal high graphics, Dofus / Wakfu / Waven combined | `claude/pc-zones-spec` (from PR #214 head) | see commit |
| 3 Oct 2026 | WP0 baseline on `pc/world-zones` (from this spec head). No gameplay change. Ran all 20 `tests/run_*_tests.gd` suites on Godot 4.7.2 headless: 20 passed, 0 failed. Recorded the before world tour at 1920×1080, 30 fps, H.264, under `docs/pc/media/before/`: `--movie v7tour` (all six towns, also split per town) and a 20 s free walk from the Crossroads (`--movie tour`, 600 frames). | Spec WP0. Baseline and before media before any zone package. | `pc/world-zones` | 5692a46 |
| 3 Oct 2026 | WP1: `data/world/level_zones.json` plus schema, `backend/world_levels.gd` (preload, no class_name), and `tests/run_world_levels_tests.gd`. All 11 zones from the plan, Stormspire 35–40 south of Gloomfen in the band table, swamp level_min 30, dark zone level_min 45. Crosshaven chunks only: new regions have empty chunk lists until their indexes exist. Colours are a green-to-purple ramp from the spec example `#3fbf4f`; the map image was not in the repo. No zone file, atlas id, or walker change. | Spec WP1. Mauro: zone plan approved to try. | `pc/world-zones-wp1-level-zones` | 27afe8e |
