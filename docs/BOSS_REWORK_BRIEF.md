# STASIUM XII — Boss rework art brief (legs + real animation)

Mauro, 2 Oct 2026: "you need to fix how the dungeon bosses look we need to do a
rework probably because they have no legs or anything." He picked **option 1**
(new art, Claude wires the code) and **keep the designs, add legs**, and asked
"you will still keep the same looks right?" — **yes**: same character, colours,
armour, face and theme. Only the body changes so it has legs that walk, and
it's drawn as frames so it moves instead of sliding.

**Nothing ships until Mauro approves the art.** Do not change any other art.

## What is wrong today

Each boss is one still painting (`art/stasis/foes/<art>.png`, 288×320). When it
moves, the whole picture slides with a bob. Most have nothing to walk on:

| Boss (door) | Art name | Today | Rework (same look) |
|---|---|---|---|
| Sheaf Sovereign (Threshgate, Crosshaven) | `warden_of_the_sheaves` | straw robe down to the floor | robe opens at the front and ends at the knee; two thick legs of bound straw with root feet; straw tufts trail |
| Tide-Lord Brineclaw (Tidehold, Brinewake) | `captain_brineclaw` | torso fading into a ship wreck | same captain torso, coat and barnacles; the wreck becomes a plank / hull skirt over **crab legs** (4–6) that scuttle |
| Slagheart (Ashmarch, Slagcrown) | `slagheart_the_emberbrute` | squat golem, legs barely shown | same lava golem, full figure with clear stumpy legs; heavy stomp, cracks glow brighter on the landing |
| Serra White-Spire Regent (Galevault, Windmere) | `serra_the_gale_sentinel` | long gown, no legs | gown splits at the front; legs in ice greaves step under it; staff and crown unchanged |
| High Coilspire (Coilgate, Stormspire) | `tyrant_coilspire` | coil tower on an orb with painted spider legs | same tower and lightning orb; the **spider legs actually step** (alternate pairs), orb pulses |

Guides with the grid, feet line and today's painting:
`docs/media/boss_rework/<art>_guide.png`.

## Files (drop in, no code change needed)

```
res://art/stasis/bosses/<art>/<art>_<anim>_<dir>.png
```

- **anim**: `idle`, `walk`, `attack`, `hit` (required); `cast` optional (falls
  back to `attack`).
- **dir**: `s`, `e`, `n` required; `w` optional (missing `w` = `e` mirrored).
  Same facing letters as the heroes (`art/characters/<class>/<class>_<dir>.png`).
- One horizontal strip per file. **Cells 288×320 px**, transparent PNG,
  frame count = width ÷ 288.
- **Feet on y = 300** in every cell (the red line), body centred at x = 144
  (the blue line). Same size on screen as today's painting.

| Anim | Frames | Notes |
|---|---|---|
| idle | 4–6 | loops at 6 fps; breathing / weight shift. The code turns its own breathing off when a sheet is present. |
| walk | **8** | one full stride across one tile (0.34 s): 0 contact (right foot forward), 1 down, 2 passing, 3 up, 4 contact (**left** foot forward), 5 down, 6 passing, 7 up. **Legs must alternate** (no same-leg limp). The planted foot does not slide inside the cell. |
| attack | 5–6 | anticipation, wind-up, strike, impact hold, recover. Plays once over the strike. |
| hit | 3–4 | flinch, recover. |

## How it plays (already wired, `units/boss_sheets.gd` + `units/pawn.gd`)

- A boss with a sheet uses it; a missing sheet keeps today's painting, so art
  can land one boss / one animation at a time.
- Walk: the frame follows the stride across each tile; the old stomp and lean
  stay on top at a quarter strength.
- Attack / cast / hit: the frame follows the motion's clock; the lunge stays.
- West without a `w` sheet mirrors `e`; north without `n` uses `s`.

## Check before asking Mauro

1. Each strip: width a multiple of 288, height 320, feet on y = 300.
2. `xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_stasis.gd -- <out_dir> <biome>`
   for a still on the real board.
3. Record the boss walking (all four directions) on the real board and send
   Mauro the clip next to today's painting. Push nothing before his yes.
4. Run all `tests/run_*_tests.gd` suites; log the change in
   `docs/CHANGE_LOG_CLAUDE.md`.
