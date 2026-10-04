# Ironjaw full set v3.2 (movement fix of v3.1; v3 = technical fix of the approved v2)
v3.2 built Oct 3 2026, 20:57–21:08 ET from a fresh copy of v3 (= v3.1). v2 and v3 are untouched (md5 trees checked).
**Look unchanged: no pixel was painted, recoloured or resampled, and no frame was moved inside its cell.** The only art change is
the walk N/E frame order. All other frames are byte-identical to v3.1. Cells, pivots, fps, frame counts and file names are the same.

## v3.2 (Oct 3 2026): movement
### 1. N/E idle -> walk (feet)
**Problem (v3.1):** idle E/N stands with both boots down. attack/hit/death E/N f00 share that stance: the boots are the same pixels,
and attack f05 / hit f03 are exact copies of idle f0. walk E f00 is late stance: the support boot is 16 px left and 5 px below the
idle boot, and the other boot is in the air. check_chars: idle -> walk lowest row 1 px, feet centre 31 px.
**Why not the S/W method here:** in S/W the action starts share the walk f00 legs, so idle got those legs. In N/E they share the
*idle* legs. Giving idle E the walk E f00 legs would fix idle -> walk but break every action: idle -> attack/hit/death f00 =
lowest row 1, feet centre 31, support boot (16,-6/-7) px, and attack f05 / hit f03 -> idle the same 31 px. Repainting the action frames
is out of scope. No walk frame matches both boots of the stand, so with these frames the 6-row feet-centre metric cannot be <= 2 for
idle -> walk in N/E (checked for every phase).
**Fix:** re-phase the walk E cycle so it starts on the frame whose support boot sits on the idle boot:
v3.2 `walk_E_fNN` = v3.1 `walk_E_f(NN+3 mod 12)` (byte copy). walk N = exact file flip of the new E (equals v3.1 walk N rotated the
same way, checked). The loop itself is unchanged: same 12 frames in the same cyclic order. Strips rebuilt. Idle N/E, attack, hit and
death are unchanged. idle N is still the exact flip of idle E.
* Side effect (good): contacts in E/N now land on f05/f11, one frame from S/W (f00/f06). In v3.1 they were two frames off (f02/f08),
  so a facing turn mid-path now pops the leg phase by one frame instead of two.

### Jumps, pivot-aligned, idle f0 -> first frame (before v3.1 -> after v3.2)
lowest row / feet centre (check_chars 6-row band) / support boot (RGB-tracked boot blob dx,dy) / head (template match dx,dy)
| facing | walk f00 | attack f00 | hit f00 | death f00 |
|---|---|---|---|---|
| S (unchanged) | 0 / 0 / (0,0) / (0,0) | 0 / 0.5 / (0,0) / (-5,4) | 0 / 0 / (0,0) / (-9,5) | 0 / 0.5 / (0,0) / (-9,6) |
| W (unchanged, flip of S) | 0 / 0 / (0,0) / (0,0) | 0 / 0.5 / (0,0) / (5,3) | 0 / 0 / (0,0) / (9,5) | 0 / 0.5 / (0,0) / (10,5) |
| N | **1 / 31 / (16,5) -> 0 / 17 / (1,0)**, head (-3,4) -> (-3,1) | 0 / 0 / (0,0) / (2,2) | 0 / 0 / (0,0) / (7,2) | 0 / 0 / (0,0) / (8,2) |
| E | **1 / 31 / (-16,5) -> 0 / 17 / (-1,0)**, head (3,4) -> (3,1) | 0 / 0 / (0,0) / (-2,2) | 0 / 0 / (0,0) / (-7,2) | 0 / 0 / (0,0) / (-8,2) |
* N/E idle -> walk after the fix: the support boot stays put (<= 1 px, lowest row 0) and the trailing boot lifts for the first step.
  The 6-row feet-centre metric reads 17 only because the lifted boot leaves the band. check_chars whole-body shift is (0,0), IoU
  0.78 (was (+-1,-2), 0.64).
* Last frame -> idle: attack f05 and hit f03 -> idle are 0 / 0 / (0,0) / (0,0) in all facings (in N/E they are copies of idle f0).
  walk f11 -> idle: S/W = the normal cycle step f11 -> f00 (idle legs = walk f00). N/E v3.1: lowest row 2, feet centre 29.5, boot
  (12,-6), which is not a walk step. N/E v3.2: exactly one walk step (same boot pixels moved (-6,+3) in E, match error 0.2).
  In game the walk stops wherever the path ends (about 8.3 frames per cell), so walk -> idle is always one walk step or less.
  death has no return to idle.

### 2. Pose pops between states (torso/feet offsets, all facings)
Only offsets from *placement* would be moved. A placement error shifts boots and torso together. Here, every idle <-> attack/hit/death
transition keeps the boots identical (0 px), so all torso offsets are painted leans. **No frame was moved.** Painted leans
over 3 px, left as is:
* hit f00: S/W 9 px left/right + 5 down (the flinch), N/E 7 px sideways + 2 down.
* death f00 (same lean as hit f00): S/W 9–10 px + 5–6 down, N/E 8 px + 2 down.
* attack f00: S/W 5 px + 3–4 down (wind-up). N/E (2,2) is under 3 px.
* walk: S/W f00 = idle (0,0). N/E first frame (3,1): the walk E torso sits 2–4 px right of idle in every walk frame while the support
  boot matches idle, so this is painted, and at 3 px it is within the limit.
(Head offsets are a template match of the idle helmet, accurate to about 1 px. The tilted hit/death heads match with error ~23.)

### 3. Walk foot planting and bob (travel 89.2 cell px per cycle = 7.43 px/frame on the 2:1 diagonal)
slide = per-frame move of the planted boot + travel (0 = stuck). Placement test: a frame is offset if its boot and torso residuals
(vs the two neighbour frames) agree. **None found in any facing, so no frame was re-registered.**
* S/W: stance slide 0.5–1.5 px/frame, 3.7 px on the lift-off frame (f05->f06 / f11->f00). Contact on f00/f06. Bob = head
  0,4,8,6,2,0 (x2 per cycle), range 8, max step 4: smooth.
* N/E (v3.2 numbering): early stance 0.5–1.5 px/frame. Late stance (2 frames per step: f02->f04 and f08->f10) the boot rises
  3.7–4.6 px/frame against the travel = heel-off/toe roll. The boot shape changes there (match error 25–29), and the pattern is the
  same in both half-cycles. That makes it painted, not placement: moving those frames to pin the boot would push the head 9–16 px
  lower. About 8 cell px (~4.8 board px at 0.578) of vertical skate per step. Bob = head 0,1,3,4,6 then a 5 px pop up at contact
  (f04->f05, f10->f11), range 6. The sole rows confirm the contact frames are placed correctly (landing -> +3 px/frame, as the travel
  predicts). So the sawtooth is painted. Fixing it would need repainting the walk (out of scope).

### 4. Glide: recommended walk timing (in json/ironjaw.json `walk`)
One move = one 64x32 tile along the diagonal = 35.78 board px. One walk frame = 89.2/12 x 0.578 = 4.296 board px, so 8.33 frames per cell.
* **Feet stick at the authored 17.144 fps with `recommended_tile_sec` 0.486 s per cell** (73.6 board px/s).
* At the repo's WALK_TILE_SEC 0.22 s the legs would need `walk_fps_if_tile_sec_0_22` = 37.9 fps (2.2x the authored cadence) to
  stick. With distance-driven frames that is what they run at, which is why he looks like he churns/glides.
* Added json fields (all other fields unchanged except `status`, `source`, frame paths -> v3.2): `walk.walk_fps` 17.144,
  `walk.recommended_tile_sec` 0.486, `walk.walk_fps_if_tile_sec_0_22` 37.9, `walk.frames_per_cell` 8.33,
  `walk.cell_step_board_px` 35.78, `walk.timing_note`.

### Check / QA / files (v3.2)
* `check_chars.py --chars ironjaw` (VERSIONS ironjaw v3.2, now the CLAIM default): **0 issues**, 128 frames, 0 edge touches, min
  margin 4 px, all W/N flips exact, strips match frames. Report: /workspace/scratch/ij_v32/check_ironjaw_v3_2.json (+ the ironjaw entry
  of ship/characters_pc/check_chars_report.json).
* qa.json: same totals {"semi": 0, "near_white": 0, "cyan": 0, "isolated_light": 82, "light_fixed": 0}, alpha 0/255 only, RGB under alpha
  0 = (0,0,0). Per-frame values follow each frame's source file.
* Contact sheets: `ironjaw_full_v3.2_contact_sheet_1x.png`, `ironjaw_full_v3.2_contact_sheet_game0.578x.png` (now at the per-class
  draw_scale; the v3 sheets were 0.5x).
* Build/measure code: /workspace/scratch/ij_v32/ (`build_v32.py`, `qa_v32.py`, `sheet_v32.py`, `m32.py`, `trans.py`, `walkana.py`,
  `track.py`, `pics_states_v32.py`, `pics_walk_v32.py`; numbers in `trans_v31.json`, `trans_v32.json`, `walk_v32.json`,
  `literal_option.txt`). Backup of the previous json: /workspace/scratch/ij_v32/ironjaw_v3.1.json (+ backup/ for all jsons and tools).
* Pictures: /workspace/luca_pics/chars/ironjaw_v32_states.jpg, ironjaw_v32_walk.gif.

---
*(v3.1 / v3.0 notes below are kept as written. Where they say "v3", the v3.2 folder carries the same pixels except the walk N/E order.)*

## (v3.1 title) Ironjaw full set v3 (technical fix of the approved v2) — v3.1
v3.0 built Oct 3 2026, 20:34–20:50 ET. v2 is untouched (read-only source). In v3.0 **no pixel of the art changed**: every v3 frame
is the v2 frame moved by a whole-pixel offset into a larger transparent cell. No repaint, recolour, restyle or resampling.
Same folder structure, file names, frame counts, fps and facings as v2. **v3.1 replaces idle S/W only** (stance fix, below).

## v3.1 (Oct 3 2026, 20:47–21:00 ET): idle S/W stance fix (folder/version name stays v3)
**Why:** idle S/W was a neutral stand (feet together, soles on the pivot, feet centre 27 px left of it) while walk/attack/hit/death
S/W f00 start in the walk stride (front toe +12 px below the pivot, feet centre +3.5 px). idle -> any action in S/W moved the
lowest foot 12 px down and the feet 30–31 px sideways. N/E were already fine and are unchanged.

**What:** new `idle/ironjaw_idle_S_f00–f03.png` (4 frames, 4 fps, unchanged) built as a pixel composite, and idle W = exact file
flip of the new S (pixel-identical, checked). Strips rebuilt. Nothing else in the set changed (walk/attack/hit/death, N/E, cells,
pivots, fps all as v3.0).
* Leg source = **walk S f00**. walk/attack/hit/death S f00 share the same leg pose (feet rows 130+: mask IoU 0.86–0.97, sole row 152
  in all, feet centre 85.5–86 px), so one leg set gives <= 0.5 px at the feet for all four; walk f00 is the one whose torso already
  lines up with idle at (0,0) (attack/hit/death carry their authored lean), so its hips sit right under the idle torso.
  The idle and walk S f00 torso/head/cape are the same painting (identical or within 12 RGB levels), only arms/axes and legs differ.
* Composite per frame, offset (0,0), no resampling, no new colours, alpha 0/255 only: rows above a hand-placed seam curve =
  the v3.0 idle frame (head, torso, arms, both axes, cape, breathing); rows at/below it = walk S f00 (hips/legs, tabard, cape hem).
  The seam follows the idle axe blade's lower edge (x 62–104, rows 112–120), the dark hip plate / tabard edge (x 44–61, row 109)
  and the cape where idle and walk are the same pixels (x <= 43, row 104). Inside the hip box, walk pixels also fill the idle's
  transparent notch under the blade (the walk thigh shows behind the axe), and 19 idle pixels (the axe's lower horn tip and its
  underside shade, x 69–77, rows 114–120) are kept over the leg. The idle's old down-left leg/boot is gone; behind it walk's
  identical cape/tabard pixels show. f0: 7590 px from the v3.0 idle, 1007 px from walk S f00, 0 other/new px.
* No seam pixels needed repainting: every idle|walk neighbour pair along the seam is dark-on-dark or lies on a painted object edge
  (only outliers = the light axe-horn edge over the dark thigh, which reads as the blade in front of the leg).
* Breathing kept exactly as v3.0: f1 = f2 = f0 with rows 0–72 moved down 1 px, f3 = f0. Legs (rows 73+) identical in all 4 frames.
* Result (check_chars.py, pivot-aligned, f0): S/W idle -> walk / attack / hit / death: lowest-foot jump **0 px** (was 12), feet
  centre 0 / 0.5 / 0 / 0.5 px (was 30.5–31); whole-body best shift walk (0,0), attack (0,-3), hit/death (±1,1)
  (was (0,0), (±2,-4), (∓2,5), (∓2,4)). Torso-only band (rows 4–60) unchanged from v3.0: walk (0,0); attack/hit/death 4–5 px = their
  authored lean. N/E unchanged (sole 0–1 px).
* Side effects: idle S/W lowest row is now +12 (as all S/W action starts); idle facing switch S<->N/E lowest row 13 px
  (was 1; same as the walk/action sets between S and N/E). Idle S/W bbox height 147 (was 135): the class size in
  `ship/characters_pc/json/ironjaw.json` is now measured head-top to the feet line (min(sole, pivot)) so `draw_scale` stays
  0.578 / world 0.532 / head_hp_y -87 (only the status string changed). Bottom margin of idle S/W now 4 px (was 16).
* Backup of the v3.0 idle S/W frames + strips, README, qa.json, contact sheets, ironjaw.json:
  /workspace/scratch/ij_v3/idle_prev/. Build: /workspace/scratch/ij_v3/build_idle_v31.py (+ idle_fix_comp.py seam/mask),
  qa_v31.py, sheet_v31.py, pics_idle_v31.py; check report /workspace/scratch/ij_v3/check_ironjaw_v3_1.json
  (`check_chars.py --chars ironjaw`; v3.0 run: idlefix/check_before.json). Pictures: /workspace/luca_pics/chars/ironjaw_idle_fix.jpg, ironjaw_idle_to_walk.gif.


## What changed vs v2 (v3.0)
1. **Cells grown so every frame has >= 4 px of clear margin on all sides** (v2: 51 of 128 frames had < 4 px, 10 within 2 px,
   walk W f11 and attack W f02 touching the left edge, 4 and 8 px).
2. **Pivot y moved onto the feet**: v2 pivot y 133 sat 4–5 px above the soles. v3 pivot = v2 row **138** (the idle S/W sole row)
   + the 2 px top pad = **140**. Same foot point in every state, so state switches move nothing (same as v2).
3. **Centred pivot x** (82 of 165, 104 of 209): W = plain left/right flip of S and N = plain flip of E (file flip, no offset).
   v2 needed "flip about x = 78" (a 4 px offset). Regenerated as exact flips and checked pixel-identical to the padded v2 W/N.
4. qa.json recomputed, contact sheets at 1x and at the real combat draw scale **0.5x** (v2 sheets said 0.6x), strips rebuilt.

## Cells and pivots (centered = false, offset = -pivot)
| state | frames | v2 cell / pivot | **v3 cell / pivot** | shift applied (x, y) |
|---|---|---|---|---|
| walk / idle / attack / hit (one shared cell) | 12 / 4 / 6 / 4 | 161x155 / (78,133) | **165x157 / (82,140)** | +4, +2 |
| death | 6 | 205x178 / (102,133) | **209x183 / (104,140)** | +2, +2 (+3 rows at the bottom) |

All four facings use the same cell and pivot. Content bbox over all frames (v2 coords): x 0–156, y 2–150 (death x 2–202, y 2–176),
i.e. exactly ±78 (±100) around the pivot x, so the centred cell is the tightest one with 4 px margins.

## Clipping: no pixels were lost, none reconstructed
* walk W f11 and attack W f02 are exact flips of walk S f11 / attack S f02 about x = 78. The S frames end at column 156 (4 px
  inside their right edge), which maps to column 0 in W. The flip itself dropped 0 pixels (checked for every W/N frame).
* Searched for un-clipped sources (pixel-exact template search of both axe tips over ~14k PNGs in /workspace, /home/box, /tmp,
  incl. ironjaw_uploads, stasium-ref/chars, stasium-repo art/characters/ironjaw, scratch/l9_src, wakfu-ship*): the tips exist
  only in v2 itself (frames, strips, contact sheet), all ending at the same column. No v1/v7/work folder is on disk.
* Shape check says the tips are complete, not cut: walk S f11's blade tip is the same 4-px blunt end as walk S f00 and attack
  S f05 / hit S f03 (mask match, shifted 1 px), which end at column 155 with nothing cut. The attack S f02 blade edge follows a
  circle fitted to its un-clipped lower edge (r ~ 11–17 px), which peaks at column 155.7–156.5, i.e. the painted edge (col 156).
* So **0 pixels were reconstructed**; v3 only gives these tips room. If Mauro reads the blunt tips as cut, that is the painted shape.

## Feet / pivot (measured, lowest opaque row vs pivot, v3.0; for idle S/W see v3.1 above: now +12 = the stride, jumps 0)
* idle (v3.0): S/W **0**, N/E **-1** (sole row 139 = bottom edge exactly on the pivot line). attack/hit/death f0 N/E -1.
* S/W attack, hit, death f0–f3 and walk use the v1 stride: the front boot's toe reaches +12 (v2 +17) and the back foot is ~5–13 px
  above the pivot, so the stride straddles the pivot; the torso lines up with idle (best shift walk 0,0; attack 2,-4; hit/death
  ±2,+4/5 = the authored lean/flinch, as in v2). A per-state pivot cannot "fix" this without making the body jump 12 px, so the
  shared pivot is kept. State-switch jumps are therefore identical to v2: N/E sole 0–1 px; S/W lowest-row 12 px from pose (idle S
  is a neutral stand, the actions start in a stride), body as above.
* S/W death f04–f05 lie 36–38 px toward the camera of the pivot (v2 41–43; accepted).

## QA (`qa.json`, same schema as v2)
{"semi": 0, "near_white": 0, "cyan": 0, "isolated_light": 82, "light_fixed": 0}; edge touches: **none** (min margin 4 px, all 128 frames).
v3.1: recomputed with the new idle S/W: same totals (idle S/W isolated_light recomputed with an explicit 3x3 test = 0, as before).
RGB under alpha 0 is (0,0,0) everywhere; alpha only 0/255. isolated_light carried per frame from v2 (pixels identical; painted
metal highlights, none near-white). light_fixed 0 = no pixel edits in v3 (v2's 666 were v2 fixes).

## Files
* `<state>/ironjaw_<state>_<F>_fNN.png` (128 frames) + `<state>/ironjaw_<state>_<F>_strip.png` (20 strips, = frames)
* `ironjaw_full_v3.2_contact_sheet_1x.png`, `ironjaw_full_v3.2_contact_sheet_game0.578x.png` (v3.2), `qa.json`, `_cells_pivots.json`
* Build/QA code: /workspace/scratch/ij_v3/ (`build_v3.py`, `qa_v3.py`, `sheet_v3.py`, `pics_v3.py`, `scan.py`)
* Wiring values: /workspace/stasium-pc-look/ship/characters_pc/json/ironjaw.json (v2 json kept as `ironjaw_v2.json`)
* Draw scale: per class (size tier "big", target 78 board px): `draw_scale` 0.578, `world_draw_scale` 0.532, `head_hp_y` -87.
