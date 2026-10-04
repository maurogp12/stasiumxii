# Mender walk v1 (Claude): STOPPED at the S foot-track gate

> **Status, 4 Oct 2026: not built.** The S foot-track check comes before the full rig. No Mender S track passes both gates (no shin X, far boot ≥ 60% on every S frame) without sideways splay worse than Gloam's approved 88° / 6°. As instructed, I stopped here and did not hack the feet. There are no walk frames, GIFs or scores yet. No blockout v-next was committed. Mauro's call is needed (options at the end).

## What was used

- **Approved look.** `targets/mender_rp_S_f00.jpg` and `targets/mender_rp_E_f00.jpg` with their `_alpha.png` masks: the design-B repaint at `3250c2ba` on `art/ironjaw-walk-help`, which Mauro approved. The same bytes are on this branch. The rejected first pair in `targets/_orig/` was not used.
- **Blockout.** Mender v3 (`ffbfe3a9` on `claude/class-walk-blockouts`), whose current S track is `foot_w` 0.9 (the default). The sweep re-rendered S only, with `scripts/blockout.py` and `foot_w` overridden. At 0.9 that render is pixel-identical to the committed v3 clay and ID, and its joints are identical.
- **Pipeline.** The Gloam v1 scripts (`gloam/v1_claude/scripts/`), copied and adapted here. Gloam and Kestrel are unchanged.

## The cut (`scripts/mcut.py`)

Mender's robe hangs to the boot tops, so the cut differs from Gloam:

- **Legs.** Only the S forward leg shows above the hem, through the robe's front slit. It is cut as one leg, from the slit trouser to the wrapped boot and sole. That is blockout L, screen-right.
  - E uses the screen-right planted boot, which is blockout R. The staff in front of its toe is painted out.
  - Above the visible part, the leg is grown from itself, as in Gloam, and the robe hides it.
- **Body.** The whole robe, the staff and the lantern sit in front of the legs on both S and E.
  - The S slit, where the leg was, is filled with the robe's dark inside, with a ragged lower edge.
  - The removed boots leave a ragged robe hem, never a straight cut.
- **Hood top.** The figure top is the hood, not the staff crook. The crook rises above the hood in E, and in a few E clay frames it also reached the column range Gloam used for the clay head row. `clay_top` now looks only within 15 px of the `head_top` joint.

A first rig pass on v3 already holds the proportions in S: belt −0.9 to +1.2 pts, knee −1.7 to +0.3 pts, thigh and boot within ±1.5%, skate 0.56 px. E needs `dy` tuning: its belt is −0.4 to −3.9 pts at the auto `dy`.

## S foot track (`s_track_options.png`, `s_track_sweep.json`)

I rendered Mender S at `foot_w` 0.0 to 1.8 and rigged the painted legs on each with the same settings (`hip_w` 1.0, auto `dy`). For each one I measured:

- **(a) Shins cross.** The two knee→ankle segments intersect on screen.
- **(b) Far boot.** `boot_vis.measure`, with the near leg and the robe as occluders, the same as Gloam.
- **(c) Contact angle.** Front heel minus back heel at f00 / f06, against the 27° diagonal. The formula reproduces Kestrel v3.2 (41 / 27), Kestrel v3.1 (78 / 9) and Gloam v3.1 (88 / 6) from their joints.

| foot_w | shins cross | far boot min | frames < 60% | angle f00 / f06 | far boot % f00 … f11 |
|---|---|---|---|---|---|
| 0.0 | f03 | 30% (f03) | f01, f02, f03, f09, f10 | 34 / 34 | 74 55 59 30 69 89 91 74 76 56 37 80 |
| 0.15 | f03 | 23% (f03) | f01, f02, f03, f10 | 39 / 30 | 73 55 58 23 83 88 87 73 77 70 26 78 |
| 0.3 (Kestrel's) | f03 | 9% (f10) | f01, f02, f03, f10 | 44 / 27 | 70 54 55 20 91 86 82 71 73 79 9 71 |
| 0.5 | none | 14% (f10) | f01, f02, f03, f10, f11 | 50 / 22 | 60 48 46 26 96 84 76 69 71 95 14 57 |
| 0.65 | none | 29% (f10) | f00–f03, f10, f11 | 56 / 19 | 47 38 35 41 93 83 72 68 69 98 29 41 |
| **0.9 (v3 now)** | f02 | 16% (f11) | f00, f01, f02, f10, f11 | 65 / 15 | 22 20 18 65 89 83 70 63 66 100 53 16 |
| 1.2 | none | 10% (f00) | f00, f01, f02, f11 | 76 / 10 | 10 22 20 86 82 82 70 61 67 100 76 12 |
| 1.35 | none | 14% (f00) | f00, f01, f02, f11 | 81 / 8 | 14 29 31 92 78 81 68 62 65 98 84 23 |
| 1.5 (Gloam's) | none | 32% (f00) | f00, f01, f02, f11 | 86 / 7 | 32 40 48 92 74 67 67 77 87 96 90 37 |
| 1.65 | none | 50% (f11) | f00, f01, f11 | 90 / 5 | 53 54 62 90 70 65 69 73 84 93 95 50 |
| 1.7 | none | 55% (f11) | f00, f01, f11 | 92 / 5 | 58 58 65 89 69 65 68 72 83 92 96 55 |
| 1.75 | none | 59% (f11) | f11 | 93 / 4 | 64 61 68 88 68 64 68 71 81 91 98 59 |
| 1.8 | none | 64% (f11) | none | 95 / 4 | 67 64 71 87 66 64 67 71 80 90 98 64 |

**Why no track passes.**

- **f01 is the blocker.** Both feet are planted there, so swing keys can't touch it without skate. Its visible share is about 55% at every narrow track (0.0–0.3). It drops to 20–40% in the middle (0.65–1.5) and reaches 60% only at 1.75 or wider.
  - At 0.3, most of the loss is the robe hem: 26% of the far boot, against 23% for the near shin.
  - At 1.5 it is the near R shin (59%).
- **Narrow tracks fail on the swing frames too.**
  - At f03 the L swing passes behind the R stance leg: 20–30%, and the shins cross at 0.0–0.3.
  - At f10 the R swing passes in front of the planted L: 9–37%.
  - Gloam showed that ≤ 8 px swing keys gain about 10 points, so they cannot close a 30–50 point gap.
- **The robe makes it worse than Gloam.** The robe hem covers the far boot's top on most frames: up to 37% of it by itself on f06–f08.
- **Only 1.8 passes, and 1.75 passes with one f11 swing key.** Their splay is 95° / 4° and 93° / 4°, which is wider than Gloam's 88° / 6° and much wider than the rejected Kestrel v3.1.

**Rig hip width, not used.** Narrowing the painted hips (`hip_w` 0.6, legs about 6 cell px inside the painted hips each side) lifts f00/f01 to 78% / 62% on a 0.3 track. f02, f03 and f10 still fail (47%, 23%, 15%). It also breaks the rule that the legs root at the target's own hips. Kestrel reverted the same kind of hip change, so I did not use it.

## Options for Mauro

1. **Accept a wide track: `foot_w` 1.8**, or 1.75 plus one f11 swing key. This passes no-X and far boot ≥ 60%. The splay is 95° / 4°, wider than Gloam's.
2. **Relax the far-boot gate for Mender only**, because the robe hides the boot tops by design. This means measuring against the near leg alone, without the robe hem. It does not rescue either track by itself:
   - Gloam's 1.5 track (86° / 7°) still fails f00, f01 and f11 (32%, 41%, 37%).
   - Kestrel's 0.3 track (44° / 27°) then passes f00–f02 (79%, 77%, 69%). It still fails the swing frames f03 (20%, shins cross) and f10 (9%).
3. **A new blockout plant pattern.** For example, put the trailing foot's toe-off earlier, so f01 is not double-planted behind the near shin. That is a blockout motion change, not a track change.

## Files

| file | what |
|---|---|
| `s_track_options.png` | Kestrel v3.2 (approved) and v3.1 (rejected) clay, Gloam v1 (approved), then Mender at foot_w 0.3, 0.65, 0.9, 1.5 and 1.8, rigged. Columns are f00, f01, f03, f06, f09 and the option's lowest far-boot frame. |
| `s_track_sweep.json` | Every option's per-frame shin cross and far-boot %, plus the contact angles. |
| `scripts/` | `mcut.py`, `mrig.py`, `mcfg.json`, `boot_vis.py`, `s_checks.py`, `sheets.py`, `run_metric.py` (adapted from Gloam), `s_track.py` (sweep), `s_track_options.py` (sheet). |

## How to re-run the sweep

```
cd docs/pc/art_help/class_walk_looks/mender/v1_claude/scripts
python3 mcut.py                                    # parts/ (M1PARTS to put them elsewhere)
# render S at a foot_w with the blockout script (FOOT_W / FACINGS overrides in a scratch copy), then:
MBLOCK_S_DIR=<render>/ python3 s_track.py <trk>/fw<w>
python3 s_track_options.py <trk> <kestrel clay dir> ../s_track_options.png
```
