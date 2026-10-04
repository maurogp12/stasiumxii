# STASIUM XII — Art job handoff (for any artist who picks this up)

Mauro, 2 Oct 2026: "keep a record of all this for other artist in case this one
runs out you will give instructions of what he needs to do". If you are a new
artist (or a new Claude), start here. Claude reviews the art; Mauro decides.

## House rules (from `CLAUDE.md`)

- Nothing is pushed, committed or merged without Mauro's yes. Previews only.
- Only Mauro merges into `mobile` / `main`. Never touch them.
- The game stays 2D (Dofus / Waven / Wakfu look). Never 3D.
- Every change that does land is logged in `docs/CHANGE_LOG_CLAUDE.md`, and
  all `tests/run_*_tests.gd` suites (Godot 4.7.2 headless) pass first.
- Code base / latest work: branch `claude/stasium-xii-development-6ni8g2`.

## The order of work

1. **Hero walk redraw** (in progress, 2 Oct 2026, by the Technical Artist /
   Grok). Share the preview with Claude → Claude reviews → fix → until Claude
   approves.
2. **Then the five dungeon bosses** (Claude hands this over only after step 1
   is approved). Same review loop.
3. **Then stop and wait for Mauro.** When everything is approved, Claude tells
   the artist: "All done and approved by Claude. Stop here and wait for Mauro.
   Don't push, merge or start anything new until he answers." That is how the
   artist knows the job is finished.

## Step 1 — Hero walk redraw (new looks Mauro approved)

Painted redraw of the mobile walk for all five classes. Mauro's rules:

| Class | Must have |
|---|---|
| Ironjaw | his exact double-bladed skull axes, held low and forward (like Gloam's daggers), blades always facing forward, every frame and direction |
| Kestrel | a **woman**, same as her painted turnaround |
| Bastion | shield on his **left** arm, spiked mace in his **right** |
| Mender | staff always **upright** |
| Gloam | hooded assassin, daggers |
| All | every class faces the same way per direction: **E walks down-right, N walks up-right** (S / W follow); each class keeps its own colours |

Sheets: `art/export_2x/walk_src/<class>_walk_<dir>.pngbin` (PNG data,
cells 144×160 each, one horizontal strip; today 6 frames, the game reads the
frame count from the width). Idle turnarounds: `art/characters/<class>/<class>_<dir>.png`.

## Claude's review checklist (both steps)

Claude says "okay" only when all of this holds:

1. **Same character in every frame** — no changing face, cape, buckles or
   weapon shape between frames (AI-painted frames drift and flicker in motion).
2. **Legs alternate** left / right — no limp (same leg leading); the planted
   foot does not slide.
3. **8 frames per walk, all four directions** (W may mirror E, but Ironjaw's
   axes must still face forward and Bastion's shield / mace hands must stay
   right — if mirroring swaps them, paint W).
4. **Transparent background**, feet on one baseline in every frame, centred,
   same size in every direction.
5. **Fits the board** at game size next to the other heroes, monsters and
   bosses.
6. **Feels right on the 0.1.86 glide** (0.34 s per tile, one stride cycle per
   tile, no skating).
7. Recorded **in the real game**: `xvfb-run godot --path . --rendering-driver
   opengl3 --fixed-fps 30 -s res://tests/shot_walk_video.gd -- <out_dir>`, old
   walk next to new. Share the **frame strips too**, not only the video.

## Step 2 — Bosses (after step 1 is approved)

Full brief: `docs/BOSS_REWORK_BRIEF.md`; guides with the grid, feet line and
today's painting: `docs/media/boss_rework/<boss>_guide.png`.

- Same looks, add legs: Sheaf Sovereign (straw legs, robe cut at the knee),
  Brineclaw (crab legs under the ship-plank skirt), Slagheart (rock legs that
  stomp), Serra (legs under a split gown), Coilspire (spider legs that step).
- Each boss: idle, **8-frame walk** (legs alternate), attack, hit; S, E, N
  (W may mirror E).
- Cells 288×320, transparent, feet on y = 300.
  Files: `art/stasis/bosses/<boss>/<boss>_<anim>_<dir>.png`. The game already
  plays them (`units/boss_sheets.gd`); a boss without files keeps its painting.
- Match the new hero style. Start with Sheaf Sovereign; share strips + a video
  of him walking and attacking on the real board.
- A code-built cut-out prototype of Sheaf Sovereign (painting kept above the
  knee + straw legs) was shown to Mauro on 2 Oct 2026 and not adopted; painted
  frames are the goal.

## Status log

| Date | What | State |
|---|---|---|
| 2 Oct 2026 | Hero walk redraw started (Technical Artist) | in progress, preview only |
| 2 Oct 2026 | Boss frame code + brief pushed (`units/boss_sheets.gd`, `docs/BOSS_REWORK_BRIEF.md`) | done |
| 2 Oct 2026 | Hero walk redraw rounds 1–3 (20 strips, 144×176, one step per tile) | approved by Claude; held (not in the game) until Mauro says yes |
| 2 Oct 2026 | Bosses: Crosshaven, Brinewake, Slagcrown pairs (★1–4 + ★5 form each); boss letters s/w/e/n per Mauro's facing rule | shipped in 0.1.87 by Mauro's order; cannon shot / eruption VFX held until Mauro sets the numbers |
| 2 Oct 2026 | Serra, Coilspire | waiting for Mauro |
