# STASIUM XII (PC): change log

PC game only. Never merged into `main` or `mobile` by an agent; only Mauro merges.

| Date | What | Why / who asked | Branch | Commit |
|---|---|---|---|---|
| 2 Oct 2026 | **Combat glide walk.** The combat walk flows through corners on one rounded route instead of a slide per cell with an in-place turn at every corner; facing switches as the body rounds the corner; speed eases in from a stand and out into the stop (`ViewMotion.glide_route / glide_point / glide_progress / glide_duration`, `BoardView._sample_glide`). Only the first step may still turn in place. Tile speed stays 0.22 s (`Pawn.WALK_TILE_SEC`). Rules and paths unchanged. `run_motion_tests.gd` pins the glide instead of the per-cell slide and tests the route and speed math. All 16 suites pass. Not merged; waiting for Mauro's review of the before/after clip | Mauro: walking like the Wakfu videos and his tactics reference clip; "work on the combat walk on the PC branch from main"; 3 Oct: push it so it isn't lost | `claude/stasium-xii-pc` (from `main`) | 42e61ab |
