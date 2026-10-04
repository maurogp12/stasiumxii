# STASIUM XII: Technical Artist hand-off (for Claude)

Written Sun 4 Oct 2026, ~11:10 ET. All times are ET (UTC-4).

> **Repo copy.** On `art/ironjaw-walk-help` the copies are `docs/pc/art_help/handoff_wip/technical_artist/`. This repo copy excludes `l9_v1_decor_check/cap` (verification screenshots, about 101 MB). That folder stays box-only at `/workspace/handoff/wip_extra/technical_artist/04_l9_v1_decor_import_check/l9_v1_decor_check/cap`. Also excluded, and still box-only, are the Ironjaw venv (`/workspace/art_src/blockout/ironjaw_walk/.venv`), the `/workspace/tmp_ij/` backups, and the L9 scratch copies listed in this file (`wt/`, `proj_*`, and `/workspace/scratch/l9_v14/`). Godot for the L9 check was `/tmp/godot/Godot_v4.7-stable_linux.x86_64` under `xvfb-run`. It may not survive a reset.
>
> `docs/pc/art_help/handoff_wip/technical_artist/MANIFEST.txt` hashes are for the box layout. `cap/` entries in that manifest will not be found in this repo.
>
> A path written below as a repo path is on this branch. Any path still written as `/workspace/...` is **box-only**.

## Flags

For Claude:

1. `ship/l9_outdoor_board` was rewritten to a "v1.4" (sand fringe, new gate report from `/workspace/scratch/l9_v14/`) after the Technical Artist's v1.3 acceptance. The Technical Artist has not checked it. The kit copy on this branch is `docs/pc/art_help/handoff_wip/technical_artist/05_l9_outdoor_board_v1.3_npc_gates/ship_l9_outdoor_board/`. `/workspace/scratch/l9_v14/` was not copied.
2. `PC_IMPORT_WIRING_NOTE.md` still says Ironjaw v3, but the json is v3.2. Copy: `docs/pc/art_help/handoff_wip/technical_artist/03_char_check_wiring_tools/ship_characters_pc/PC_IMPORT_WIRING_NOTE.md`.
3. The Ironjaw underlay folder's own `SHA256SUMS` is stale for `README.md` and `src/pad512.py`. Copy: `docs/pc/art_help/handoff_wip/technical_artist/01_ironjaw_walk_underlay/ironjaw_walk/`.
4. Mauro's leg fix has no written spec on disk. The knee cop and the tassets are not separate parts in the joints yet.
5. Most scripts use hard-coded paths and write in place, even when run from the copy.

Rules for this hand-off: copy and document only. No art, rig or code was changed. Nothing was committed, pushed or merged by the Technical Artist; Stasium Bot commits.
Copies: `docs/pc/art_help/handoff_wip/technical_artist/` (one subfolder per item). SHA-256 for the box layout, including `cap/` files that are not here: `docs/pc/art_help/handoff_wip/technical_artist/MANIFEST.txt`.
The copies that are in this repo are byte-identical to the sources as of this hand-off. The originals are still the working locations. Most scripts below have **hardcoded absolute paths**, so running a copied script still reads and writes the original locations.

---

## 1. Ironjaw walk 3D underlay (Blender blockout)

**Item:** a 3D mannequin walk underlay for the Ironjaw HD repaint. It is a paint-over and rig guide only: it never ships and never goes into Godot. Blender 5.2.2 (pip `bpy`, headless Workbench).

**State:** current, and approved by Luca (the hold). The last change was the walk_S leg raise plus the additive rig_fx keys (2026-10-04 04:43–04:53 ET). Claude's copy of the joints matches the current file byte for byte (joints_512.json sha256 `e9edbe3c…2b`, manifest_512.json `9c75214c…27`).

**Where (box path):**
- Source: `/workspace/art_src/blockout/ironjaw_walk/`
  - `src/` holds `model.py`, `rig.py`, `render.py`, `post.py` and `pad512.py`, plus `geo.py`, `look.py` and `look2.py`.
  - `ironjaw_blockout.blend` (129 KB) and `ironjaw_blockout.blend1` (Blender backup).
  - `camera.json`, `manifest.json`, `SHA256SUMS`, `qa.json`, `README.md`.
  - `renders/{clay,sides,sil,grid}/`: 460x360 cells, pivot (230,329), per-frame PNGs plus `walk_{S,E}_strip.png`.
  - `renders_512/{clay,sides,sil,grid}/`: 512x360 per-frame PNGs (there are no strips at 512), plus `joints_512.json`, `manifest_512.json` and `joints_check.png`.
  - `qa/` (`hold_check.json`, `model_meta.json`, `idpass/`, `look/`) and `ref/luca_hold_reference.png`.
- venv (not copied, 1.1 GB): `/workspace/art_src/blockout/ironjaw_walk/.venv`. It runs Python 3.13.5 with bpy 5.2.2, numpy 2.5.3 and pillow 12.3.0.
- Copy (no venv, no `__pycache__`): `docs/pc/art_help/handoff_wip/technical_artist/01_ironjaw_walk_underlay/ironjaw_walk/`
- Claude's copy of the joints: `docs/pc/art_help/ironjaw_walk/ta_joints/` (`NOTE.md`, `joints_512.json`, `manifest_512.json`, `joints_check.png`).
- Preview GIF and contact sheet (written by `post.py`): `/workspace/luca_pics/chars/ironjaw_walk_underlay.gif` and `.jpg`.
- Backups (not copied, noted only), all in `/workspace/tmp_ij/`:
  - `backup_before_arms/`, `backup_approved_hold/` and `backup_v3_scenario/`: full folder snapshots, ~1.1 GB each because each includes its own `.venv`.
  - `backup_pre_step1/`: 12 MB, `ironjaw_walk/` plus `luca_pics_chars/`, taken before the walk_S raise.
  - `s1/`: 584 MB. It holds the walk_S raise study: `metric/` (match_metric before/after jsons), `scen/` (575 MB of Scenario rig rebuilds: before, after, final_2px, hybrid_blk, walkonly), `proto_sb/`, and `ta_joints_prev/` (the joints before the raise).

**Where you stopped:**
- walk_S raised 2.0 px with longer IK legs, and the additive rig_fx keys exported (joints_512.json 04:53 ET).
- `ta_joints/NOTE.md` was delivered to Claude at 04:53 ET.
- Nothing has been started on Mauro's leg fix (see Open problems).

**How to run:**
```
cd /workspace/art_src/blockout/ironjaw_walk
.venv/bin/python src/render.py   # model, rig, pose, renders/, camera.json, .blend
.venv/bin/python src/post.py     # grid pass, strips, qa.json, preview GIF + contact sheet (to /workspace/luca_pics/chars), manifest.json, SHA256SUMS
.venv/bin/python src/pad512.py   # renders_512/ (512x360), joints_512.json, joints_check.png, manifest_512.json, qa/hold_check.json
```
- All three scripts write **in place** under `BASE=/workspace/art_src/blockout/ironjaw_walk`. `render.py` can be redirected with the env var `OUT=<dir>` (renders and QA only). `post.py` and `pad512.py` cannot. Snapshot the folder before you re-run.
- Tunables live in `src/rig.py`:
  - `LEG_RAISE_PX` = {S: 2.0, E: 0.0} and `LEG_SCALE` = {S: 1.0275, E: 1.0}. Scale with the raise: 1.5 px → 1.0206, 2 px → 1.0275, 2.5 px → 1.0344.
  - `CHEAT` = {S: -20, E: 35} deg of body yaw.
  - The `ARM[(facing, side)]` hold table.
- Scenario's rig reads the joints from the env var `IJ_JOINTS`, defaulting to `/workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json`. See `/workspace/scratch/ij_walk/rig/rig_core.py` line 6, `/workspace/scratch/ij_walk/v4c/claude_proto.py` and `/workspace/scratch/ij_walk/v4c/score.sh`. Set `IJ_JOINTS` explicitly so the rig reads the current joints and not a stale copy.

**Inputs:**
- Luca's hold reference `ref/luca_hold_reference.png`.
- The v3.2 and v4_hd paintings as view references (`post.py` `REF=/workspace/art/ironjaw_full`).
- Scenario's walk QA (make_walk.py / qa_walk.py) and Claude's `match_metric.py` (`/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts/match_metric.py`), used to choose the 2 px raise.

**Open problems:**
1. **Mauro's leg fix.** As Luca relayed it (Claude's proposal): knee cop pivots at the knee joint, shorter thighs and longer greaves, tasset ±3° swing. I found no written spec of it on disk. Today:
   - the knee cop is part of the shin mesh (`model.py` `shin_*`, which starts at the knee);
   - the tassets are part of the rigid pelvis mesh (`model.py` `P['pelvis']`);
   - joints_512.json has no separate knee-cop or tasset part or hook. Its parts are torso, cape, R/L thigh, shin, boot, upperarm, forearm and axe.
   So the fix may need a knee-pivot export (knee-cop part and angle) and a tasset hook (hinge point plus swing angle) from the underlay. **Ankle, heel and toe joints must stay exactly as they are** (they are IK-pinned today: 0.000 px change from the raise).
2. `SHA256SUMS` in the source folder is stale for `README.md` and `src/pad512.py`. Both were edited at 04:53, after SHA256SUMS was written at 04:50. renders_512 is not listed in SHA256SUMS; `renders_512/manifest_512.json` covers it, and all 106 of its hashes match.
3. In idle E and 8 of the 12 walk E frames, the far (L) forearm and fist touch the pelvis block. It is hidden behind the torso and no leg is involved.
4. The S/E paintings are not geometrically consistent (pauldrons, near-level shoulders), so the painter has to cheat the pauldron sizes.

**Decisions:**
- Camera: orthographic, 30° down, azimuth 45°. Blender rotation (60, 0, 45), ortho_scale 494.62.
- Cell 512x360, pivot (256,329). Offsets from the 460 render: x +26, y +15 (S) / +31 (E). These put each facing's idle lowest sole on row 329 (the 460-render idle soles are at 314 S and 298 E). Walk contact soles land up to ~15 px (S) / ~20 px (E) below 329. That is correct for a true 2:1 view; keep it.
- Walk: 12 frames at 17.144 fps. Contacts S f00/f06 and E f05/f11. Travel 161 cell px per cycle.
- Hold (approved by Luca): arms bent ~100°, fists on the handles at belt height, axes forward and down, near (R) axe raised level with the far one (baked in, so Scenario's +24.9° R-forearm correction can be dropped). Per-facing cheats:
  - S near-arm fist ~32 px out by the right hip, elbow ~124°;
  - E elbows hang by the ribs.
- walk_S only: legs 1.0275× longer, everything above the pelvis raised 2.0 px, feet IK-pinned. Scenario's rig scores height_vs_idle 1.000 (was 0.992), and qa_walk stays 48/48 with skate 0. idle_S, idle_E and walk_E are unchanged.
- Claude's prototype should use `raise_px = 7` for S (gives 1.000). 11 reproduces the old 1.015, and leaving 13 would raise S by 15 px in total. Source: `ta_joints/NOTE.md`.
- Additive rig_fx keys in joints_512.json (existing keys unchanged):
  - per frame: `arm_swing_deg` {R,L}, `arm_swing_screen_deg` {R,L} and `cape_points` {collar, hem};
  - E only: `reach_vs_idle` {R,L};
  - meta: `meta.fx.cape_lag_frames` {S 2.43, E 2.3} and `meta.walk_leg_raise`.

---

## 2. Ironjaw sprite fixes v3, v3.1 and v3.2

**Item:** technical fixes to the approved Ironjaw v2 sprite set (128 frames, 4 facings), with no repainting.
- v3.0: padded cells, pivot on the soles, exact W/N flips.
- v3.1: idle S/W stance composite.
- v3.2: walk N/E re-phase.

**State:** done. These are superseded by Scenario's v4_hd repaint (`/workspace/art/ironjaw_full/v4_hd/`) but remain **the fallback**. v3.2 is what `ship/characters_pc/json/ironjaw.json` points at today (`source: /workspace/art/ironjaw_full/v3.2`). check_chars on v3.2 gives 0 issues.

**Where (box path):**
- `/workspace/art/ironjaw_full/v3/`: v3.0, plus the v3.1 idle S/W. README.md, qa.json, `_cells_pivots.json`, contact sheets at 1x and 0.5x.
- `/workspace/art/ironjaw_full/v3.2/`: README.md (covers v3.2, v3.1 and v3.0), qa.json, contact sheets at 1x and 0.578x.
- Scripts: `/workspace/scratch/ij_v3/`:
  - `build_v3.py`, `qa_v3.py`, `sheet_v3.py`, `pics_v3.py`, `scan.py`;
  - v3.1: `build_idle_v31.py`, `idle_fix_comp.py`, `qa_v31.py`, `sheet_v31.py`, `pics_idle_v31.py`;
  - backups in `idle_prev/` and `idlefix/`.
- Scripts: `/workspace/scratch/ij_v32/`: `build_v32.py`, `qa_v32.py`, `sheet_v32.py`, `m32.py`, `trans.py`, `walkana.py`, `track.py`, `pics_*_v32.py`, and `backup/`.
- Wiring json: `/workspace/stasium-pc-look/ship/characters_pc/json/ironjaw.json` (v2 kept as `ironjaw_v2.json`).
- Copy: `docs/pc/art_help/handoff_wip/technical_artist/02_ironjaw_sprite_v3_v3.1_v3.2/` (`art_ironjaw_full_v3/`, `art_ironjaw_full_v3.2/`, `scratch_ij_v3/`, `scratch_ij_v32/`, `ship_json/`).

**Where you stopped:** v3.2 was built 2026-10-03 20:57–21:08 ET, and the json and check report were regenerated at 21:02 ET. No later work.

**How to run:**
- Build scripts in the scratch folders, e.g. `python3 /workspace/scratch/ij_v32/build_v32.py`. They read v3 and write v3.2 in place.
- Check: `cd /workspace/stasium-pc-look && python3 tools/check_chars.py --chars ironjaw` (see item 3 for the default output path).

**Inputs:** v2 as the read-only source (`/workspace/art/ironjaw_full/v2/`).

**Open problems:**
- N/E walk late-stance vertical skate (~8 cell px per step) and the 5 px bob pop at contact are painted. Fixing them needs a repaint (out of scope).
- Painted leans on hit/death f00 (7–10 px) were left as they are.
- WALK_TILE_SEC 0.22 in the repo makes the legs cycle at ~37.9 fps (see item 3).

**Decisions:**
- v3.2 is all native pixels: no painting, recolouring, resampling or moving inside the cell. The only art change is the walk N/E frame order (`v3.2 walk_E_fNN = v3.1 walk_E_f(NN+3 mod 12)`, with N an exact flip of E). After the re-phase, E/N contacts land on f05/f11.
- Cells: 165x157, pivot (82,140); death 209x183, pivot (104,140). Every frame has ≥ 4 px margin.
- Walk timing recommendation (in `ironjaw.json` `walk`): 17.144 fps, `recommended_tile_sec` 0.486 s per cell, 8.33 frames per cell. If WALK_TILE_SEC stays at 0.22, `walk_fps_if_tile_sec_0_22` is 37.9.
- draw_scale 0.578, world_draw_scale 0.532, head_hp_y -87.

---

## 3. Character check and wiring tools (PC characters)

**Item:** `check_chars.py` (read-only measurement of the five class sprite sets), `make_char_json.py` (per-class wiring json), `chars_pics.py` (the pictures for Luca), the wiring note and the report.

**State:** current as of 2026-10-03 21:02 ET.
- Ironjaw v3.2: 0 issues, wire it.
- Kestrel v3: approved, wire it, with notes.
- Gloam v4: needs a pivot-data fix and is awaiting Mauro.
- Bastion v4 and Mender v3: need art fixes.
- The `PC_IMPORT_WIRING_NOTE.md` header still says "Ironjaw v3" (written ~20:50 ET). The json and report point at v3.2.

**Where (box path):**
- `/workspace/stasium-pc-look/tools/check_chars.py`, `/workspace/stasium-pc-look/tools/make_char_json.py`, `/workspace/stasium-pc-look/tools/chars_pics.py`
- `/workspace/stasium-pc-look/ship/characters_pc/`: `PC_IMPORT_WIRING_NOTE.md`, `check_chars_report.json`, and `json/{ironjaw,ironjaw_v2,kestrel,gloam,bastion,mender}.json`.
- Pictures: `/workspace/luca_pics/chars/`: lineup, lineup_tiers, `<char>_sheet`, `issue_*.jpg`, the Ironjaw v3/v3.2 pictures and the underlay GIF/JPG.
- Copy: `docs/pc/art_help/handoff_wip/technical_artist/03_char_check_wiring_tools/` (`tools/`, `ship_characters_pc/`, `luca_pics_chars/`).

**Where you stopped:** the report and jsons were regenerated for Ironjaw v3.2 at 21:02 ET on Oct 3. Since then nothing has been rerun for Bastion v4, Mender v3, Gloam v4 or Kestrel v3.

**How to run:**
```
cd /workspace/stasium-pc-look
python3 tools/check_chars.py [--chars ironjaw kestrel ...] [--ver ironjaw=v2] [--out <json>]
python3 tools/make_char_json.py
python3 tools/chars_pics.py [issues]
```
- `check_chars.py` defaults to `--out ship/characters_pc/check_chars_report.json`. Pass a scratch `--out` to avoid overwriting the shipped report.
- `make_char_json.py` writes straight into `ship/characters_pc/json/`.
- `chars_pics.py` writes into `/workspace/luca_pics/chars/`.

**Inputs:** `/workspace/art/<char>_full/<ver>/` (the versions are set in `VERSIONS`/`CLAIM` in check_chars.py) and `/workspace/stasium-pc-look/refs/ironjaw_tall/ironjaw_tall_idle_s.png` (for chars_pics).

**Open problems:**
- **Walk speed (Mauro's call):** the repo's `WALK_TILE_SEC 0.22` is too fast. ~0.45–0.52 s per cell is recommended; Ironjaw v3.2 needs 0.486, and the v4_hd underlay math gives 0.519.
- `check_chars_report.json` has **no explicit FAIL lists**: `issues` is `[]` for all five characters. The blocking lists are in `PC_IMPORT_WIRING_NOTE.md` §7. The report's measurements support them as follows:
  - **Bastion v4** (`/workspace/art/bastion_full/v4`):
    - idle f0 sole vs pivot: S +1, W +12, N +15, E +10 (interim pivot y S166 / W177 / N180 / E175);
    - idle height S 138 / W 148 / N 152 / E 143 (W/N/E taller, with lower, dangling feet);
    - strips `attack_S` and `hit_S` DIFFER from their frames (stale);
    - walk S torso vs idle worst +9 px;
    - no mirrored facings (4 painted); 0 edge touches, min margin 5.
    - From the note only: death W/N/E f03 jumps up 12–18 px; death S f03 sits 6 px under the floor; the great-helm plate knight and steel/navy/gold palette are off-guide.
  - **Mender v3** (`/workspace/art/mender_full/v3`):
    - idle/hit/cast/death S/W sole -7 (floats; use pivot y 168 / cast 189), N/E -1;
    - 348 edge-touch px (walk N/E bottom 2 rows, death N/E bottom 3), min margin 0, 26 frames within 2 px;
    - idle height S/W 143 vs N/E 159 (11% taller);
    - walk N/E torso bob worst -12 px; S idle→walk sole jump 7, feet-x 38.5;
    - W = flip S and N = flip E, which bakes in the staff hand swap.
    - From the note: death S/W f05 reads as a lump, the cast f0→f1 pose pops, and the mustard palette is off.
  - **Gloam v4 pivot fix:**
    - idle f0 sole vs pivot S/W +9, N/E +1;
    - use pivot y 151 for S/W and 143 for N/E (x unchanged; the death x values stay S90 / W149 / N150 / E89);
    - idle height S 146 vs N 140, a minor turn pop;
    - all mirrors are exact flips; min margin 1.
  - **Kestrel v3 (approved, notes only):**
    - 1396 edge-touch px, min margin 0 (hood on the top edge, cape and bow on the right; 137 frames within 2 px);
    - walk W/N/E painted horizontal-only (foot angle 5.6–8.9°), so they skate ~4.8 cell px/frame vertically on diagonal moves;
    - walk S soles +5..+15 (optional pivot (68,145)); S idle→walk sole jump 15;
    - brown/olive palette.

**Decisions:**
- Per-class draw_scale tiers (Luca, 2026-10-03). The world walker scale is `world_draw_scale = draw_scale × 0.92` (0.46/0.5). `head_hp_y` is per class: -(tallest idle f0 head top above the feet × draw_scale + 8).

  | Class | draw_scale | world_draw_scale | head_hp_y |
  |---|---|---|---|
  | Ironjaw v3/v3.2 | 0.578 | 0.532 | -87 |
  | Bastion | 0.565 | 0.520 | -94 |
  | Kestrel | 0.465 | 0.428 | -74 |
  | Gloam | 0.452 | 0.416 | -74 |
  | Mender | 0.462 | 0.425 | -82 |

  The Ironjaw v4_hd cells (512x360) need about 0.30 for ~78 board px; the underlay grid uses 0.30.
- Facing remap at load (do not rename files): code e ← art S, code s ← art W, code n ← art E, code w ← art N (`combat_code_letter_from_art` in each json).
- Import: Linear, no mipmaps, straight alpha, Fix Alpha Border ON. Pack from per-frame PNGs, not strips. Pivots: centered=false, offset = -pivot. Walk frames advance by distance.

---

## 4. L9 v1 decor import check (Scenario's mock-v1 decor kit)

**Item:** a TA gate check of Scenario Art's L9 Crosshaven v1 decor kit against branch `cursor/l9b-v1-decor-ae16` @ `af040d7` (commit 2026-10-04 06:39 ET; the local `origin/cursor/l9b-v1-decor-ae16` ref is also af040d7). The kit was installed only in scratch project copies.

**State:** check done, report written 2026-10-04 07:40 ET. Nothing was committed or pushed. The report and the fixed `.import` files were also copied into the kit folder; they are byte-identical.

**Where (box path):**
- `/workspace/scratch/l9_v1_decor_check/`:
  - report: `TA_CHECK_l9_v1_decor.md`;
  - fixes and logs: `import_fix/` (BC7 `.import` for sky, sky@2x, clearing, clearing@2x), `import_default_generated/`, `import_*.log`;
  - evidence: `cap/` (captures plus `parallax_result.json`, `halo_result.json`, `halo_alpha_bins.json`, `overlay_verify.json`), `alpha/`, `views/`;
  - `tests/` (`run_all.sh`, `summary.txt`, per-project logs);
  - `tools/` (`ta_check_l9.gd`, `ta_modulate.gd`, `ta_clearing_halo.gd`, `ta_bench_v1ready.gd`, `parallax_measure.py`, `halo_*.py`, `overlay_verify.py`, `make_sheet.py`);
  - `checker/` (check_assets run on the mapped jungle and props), `branch_diff.patch`.
- Worktree (not copied): `/workspace/scratch/l9_v1_decor_check/wt/`, a read-only, detached worktree of `/workspace/stasium-repo` at af040d7.
- Scratch Godot projects (not copied, 1.4 GB): `/workspace/scratch/l9_v1_decor_check/proj_base/`, `proj_base_patch/`, `proj_patch/`, `proj_props/`, `proj_wired/`. Each has `tests/pc/ta_check_l9.gd` installed.
- Kit: `/workspace/stasium-pc-look/ship/l9_v1_decor/` (Scenario's, 24 MB; not copied).
- Copy: `docs/pc/art_help/handoff_wip/technical_artist/04_l9_v1_decor_import_check/l9_v1_decor_check/`. The box copy had everything except `wt/` and `proj_*`. This repo copy also excludes `cap/` (box-only). `checker/` is included.

**Where you stopped:** the report and fixes were delivered. Fixes 1–3 below are proposals; none is applied on the branch.

**How to run:**
- Godot 4.7 stable: **`/tmp/godot/Godot_v4.7-stable_linux.x86_64`**. The zip is next to it, `/tmp/godot/g.zip`. `/tmp` may not survive a box reset; if the binary is gone, re-download Godot 4.7-stable for linux x86_64.
- xvfb: `/usr/bin/xvfb-run` and `/usr/bin/Xvfb`, renderer opengl3 (llvmpipe).
- Headless tests: `bash /workspace/scratch/l9_v1_decor_check/tests/run_all.sh`. It runs `--headless --path . -s res://tests/<name>.gd` per proj_* folder and writes `tests/summary.txt`.
- In-game captures:
  ```
  cd <proj_*>
  xvfb-run -a -s "-screen 0 1920x1080x24" /tmp/godot/Godot_v4.7-stable_linux.x86_64 --rendering-driver opengl3 --path . -s res://tests/pc/ta_check_l9.gd -- --out=<dir> --w=1280 --h=720
  ```
  The script reads the user args `--out`, `--w` and `--h`. `--out` defaults to /tmp/ta_l9, which does not exist now. **The exact xvfb command line was not saved**; the line above is reconstructed from the script and from the same pattern in Scenario's `tools/l9_v1_decor_v2/cap_v2.sh`.

**Inputs:** the kit (`ship/l9_v1_decor/`), branch af040d7, and Scenario's `tools/l9_v1_decor/capture_l9_decor.gd` boot sequence.

**Open problems / verdicts:**
1. Import flags: **FIX_REQUIRED**. No `.import` ships for crosshaven_decor, so sky and clearing default to Lossless. Ship the BC7 `.import` files from `import_fix/`.
2. Alpha: **PASS**. Straight alpha, fringe/interior luma ratio 0.97–1.03.
3. Parallax: **FIX_REQUIRED** (branch code). The sky is composited into the clearing plate, so both move at 0.40. The sky should be its own sprite at 0.08, and the parallax test should measure the drawn layer.
4. Leaf modulate with the sway shader: **PASS\***. The shader drops modulate (`COLOR = textureLod(...)`), so `top_fade_alpha` and any non-1.0 tint never render.
5. `leaf_fit_crop.patch`: **PASS**. 0 px over cells and HUD.
- Plus: with props_live on, the rim props on y=15 / x=15 draw over the edge cells. The boulder_cluster at (4,15), (15,7) and (15,13) and the standing_stone at (14,15) cover 16–44% of the edge-cell top diamonds. Keep tall pieces on the back rims.
- Tests with the kit fail as expected (jungle 433/4, board 531/3 with props_live). They need v1 asserts. check_assets shows 6 FAILs for the v4 leaf size pins, which need v1 pins.
- wet_earth (30 mud cells) on the live board is outside the guide's ground set (see item 5).

**Decisions:**
- Check in scratch copies only; the worktree stays read-only.
- Verdicts use PASS / FIX_REQUIRED (team gate vocabulary).

---

## 5. L9 outdoor board v1.3 and NPC sprite gates

**Item:**
- TA gates and the draft wiring note for Scenario's L9 Crosshaven outdoor board kit v1.3.
- The `check_assets.py` checker, including the `--package npc` gate with its foot detector.
- The NPC body sprite gate reports (19 roles).

**State:**
- Board kit v1.3 gates (2026-10-03 ~20:20 ET):
  - `--package world`: Overall PASS (68 checked, 0 WARN, 0 FAIL);
  - `--package props`: Overall WARN (15 accepted anchor WARNs, 0 FAIL).
- **After v1.3 the ship folder changed again, and the README was not updated.**
  - `looks.json` and `atlas_meta.json` were rewritten at 20:55–20:56 ET.
  - New `tiles/grass_fringe_sand_*` files were added.
  - `looks.json` now differs from the v1.3 backup `/workspace/scratch/l9_v13_ship/`.
  - The current `ship/check_report_world_l9_outdoor_board.md` (20:55 ET) is byte-identical to `/workspace/scratch/l9_v14/check_report_world_l9_outdoor_board.md`. It reads PASS with 92 files, 0 WARN, 0 FAIL, and the blocks check covers 61 placements (the v1.3 README says 45).
  - `/workspace/scratch/l9_v14/looks_v14_log.json` lists sand 45, stone_flag 20, wet_earth 30 and decor_added 16.
  - So the shipped kit is a "v1.4" layout iteration. I did not verify who made it or whether Luca approved it.
- The wiring note is **DRAFT, not sent** (dated 20:07 ET). Its header still says kit v1.2.
- NPC gate (reports 2026-10-03 20:40–20:41 ET): 14 roles PASS, 5 roles WARN (forge_master, herald, last_watcher, shard_seer, trader), 0 FAIL.

**Where (box path):**
- Kit: `/workspace/stasium-pc-look/ship/l9_outdoor_board/` (README.md v1.3, `looks.json`, `atlas_meta.json`, `props.json`, `tiles/`, `terrace/`, `props/`).
- Wiring note: `/workspace/stasium-pc-look/ship/l9_outdoor_board_WIRING_NOTE.md`.
- Gate reports:
  - `docs/pc/art_help/handoff_wip/technical_artist/05_l9_outdoor_board_v1.3_npc_gates/check_reports/check_report_world_l9_outdoor_board.md`
  - `docs/pc/art_help/handoff_wip/technical_artist/05_l9_outdoor_board_v1.3_npc_gates/check_reports/check_report_props_l9_outdoor_board.md`
  - `docs/pc/art_help/npc_sprites_wip/check_report_npc_<role>.md` (19 files)
- Checker: `/workspace/stasium-pc-look/tools/check_assets.py`. The npc package starts at ~line 1373; foot detector constants `NPC_FEET_BAND`, `NPC_TOOL_MAX_W`, etc.
- NPC sprites: `docs/pc/art_help/npc_sprites_wip/npc_sprites/<role>/` (28 MB). NPC build pipeline: `/workspace/stasium-pc-look/tools/npc/` (see its README.md). Contact sheets: `/workspace/stasium-pc-look/previews/npc/`.
- Copy: `docs/pc/art_help/handoff_wip/technical_artist/05_l9_outdoor_board_v1.3_npc_gates/`:
  - `ship_l9_outdoor_board/`, `l9_outdoor_board_WIRING_NOTE.md`, `tools/check_assets.py`, `check_reports/`;
  - `npc_sprites_json/` (the 19 role jsons only);
  - `npc_sprites_forge_master/` (the full role folder).

**Where you stopped:** the gates ran on v1.3 and on the 19 NPC roles. The wiring note is waiting for Luca's rulings and has not been updated to v1.3.

**How to run:**
```
cd /workspace/stasium-pc-look
python3 tools/check_assets.py ship/l9_outdoor_board --package world --map-tags art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json
python3 tools/check_assets.py ship/l9_outdoor_board/props --package props
python3 tools/check_assets.py ship/npc_sprites/<role> --package npc [--report <md>] [--previews <dir>] [--no-contact]
```
- The reports go to `ship/check_report_*.md` by default and the NPC contact sheets to `previews/npc/`. Pass `--report` and `--previews` to keep the shipped reports untouched.
- `--map-tags art/maps/...` is relative, and `/workspace/stasium-pc-look/art/maps` **does not exist**. The file is in this repo at `art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json`. The box copy is `/workspace/stasium-repo/art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json` (and in the item 4 worktree). I did not verify which copy the gate actually used.

**Inputs:** ZONES_BUILD_SPEC 4.5a and WP10 NPC bodies (as quoted in check_assets.py), and the Crosshaven map tags json.

**Open problems:**
1. **Luca's mud ruling.** `wet_earth` (30 cells = CombatSim "mud", 2 MP) is not in the Art Bot Guide ground set (grass/stone/water/ash/dock). It needs an explicit guide exception or a change; the kit holds wet_earth unchanged pending the ruling.
2. Further open points from the wiring note §5:
   - board-edge skirt: the kit's or the jungle's;
   - tall standing stones and the 2c walls overdraw fighters;
   - grading is Mauro's.
   (The water-foot faces were addressed in v1.3.)
3. **The NPC gate should ignore props.** Today only role action anims (`work`) skip gating on stance centre ("a tool head in the ground can read as a foot; not gated"). In idle/walk/talk, a prop run wider than 6 px@2x near the feet can still count as a foot. I did not verify whether the forge_master idle_s / walk_n / talk_s stance-centre WARNs (-12.5 to -12.7 px) are caused by a prop.
4. **forge_master work animation is pending.** `work_s`/`work_n` exist (12 f @ 8 fps, an extra anim not in the spec). work_s WARNs that art reaches below pivot row 240 in f06 (+6) and f07 (+5).
5. Other WARN roles are body-centre offsets of 10–19 px: herald, last_watcher, shard_seer, trader.

**Decisions:**
- `blocks` is informational only (all `none`) because CombatSim has no cover or LOS. It must agree with the map data.
- The 2c props keep the 192x160 canvas with anchor (96,160).
- Water-foot faces use the `_water` variants by loader rule.
- NPC frames are 256x256@2x with pivot [128,240], W = flip S and E = flip N, and contact AO ~70x24 with peak ≤ 0.3.

---

## 6. Art law and standards (reference only)

**Item:** the rules all of the above follow.

**State:** reference only; nothing copied, nothing changed.

**Where (box path):**
- Art Bot Guide copy: `/workspace/stasium-pc-look/refs/STASIUM_ART_BOT_GUIDE_2026-10-03.md` (file mode 600).
- Team brief: `/workspace/team_learning/SKILL_REPOS_BRIEF.md`.
- Pointer file: `docs/pc/art_help/handoff_wip/technical_artist/06_art_law_standards/REFERENCE.txt`.

**Where you stopped:** n/a.

**How to run:** n/a.

**Inputs:** n/a.

**Open problems:** wet_earth vs the guide's five ground materials (items 4 and 5).

**Decisions:**
- Gates use PASS / FIX_REQUIRED / BLOCKED.
- Binary deliverables get SHA-256 manifests.
- 3D is used only as a 2D aid (an internal underlay). A 3D file or raw render never enters the Godot project or ships.
- PC, 2D painted, dark fantasy. No neon, circuits or guns.

---

## 7. Class walk blockouts (Bastion, Kestrel, Gloam)

**Item:** walk guides in the Ironjaw underlay format, made by Claude from Mauro's new designs.

**State:** the **Technical Artist has done no work on these yet.** The TA is only listed as backing Scenario on joints, alpha clips and qa_walk (`PAINT_BRIEF.md`: "Scenario Art paints; Technical Artist rigs; Claude scores and reviews").

**Where (box path):**
- Box-only tree: `/workspace/handoff/class_walk_blockouts/` (`README.md`, `PAINT_BRIEF.md`, `bastion/`, `kestrel/`, `gloam/`, `mender/`, `mender_concepts/`, `refs/`, `repo_targets/`, `scripts/`, `targets/`).
- On this branch: `docs/pc/art_help/class_walk_looks/wip_shared/` (`PAINT_BRIEF.md`, `README.md`, `scripts/`) and the painted packages under `docs/pc/art_help/class_walk_looks/`. Blockout v3 is on `claude/class-walk-blockouts` at `ffbfe3a`, not here.
- Pointer: `docs/pc/art_help/handoff_wip/technical_artist/07_class_walk_blockouts/STATE.txt`.

**Where you stopped:** not started.

**How to run:** see that README (`scripts/blockout.py`, `preview.py`, `actions.py`, `video.py`; it installs `bpy==4.2.0` on Python 3.11, a different Blender from item 1's 5.2.2).

**Inputs:** `refs/` (Mauro's designs) and the Ironjaw `joints_512.json` schema.

**Open problems:** n/a for the TA until Scenario asks for joints, alpha clips or qa_walk support.

**Decisions:** same cell, pivot, camera and walk timing as Ironjaw (512x360, (256,329), ortho 30°/45°, 12 f @ 17.144 fps).

---

## 8. Other recent TA work found (last 3 days, not listed above)

The owner of a scratch folder is inferred from its contents. Paths were verified, but who made each one was not.

- `/workspace/scratch/ij_v4hd_check/` (box-only): `attack_board_read.png` (21:12 ET) and `hold_now.png` (21:48 ET, Oct 3). A TA board-read/hold check of the v4_hd set. Copied to `docs/pc/art_help/handoff_wip/technical_artist/08_other_recent_ta_work/scratch_ij_v4hd_check/`.
- `/workspace/scratch/ta_fix/` (Oct 3, 20:09–20:56 ET): the NPC "TA fix" round. It contains:
  - gate before/after summaries (`gate_before.json`, `gate_ta3.json`, `gate_after.json`);
  - the foot-detector prototype `find_feet_proto.py`;
  - `build_all.sh` (it rebuilds the NPC roles via `tools/npc/build_npc.py`), `fix_readmes.py`;
  - `legs/`, `noprop/`, `pk/`, `ta1/`, `ta3/` images and logs.
  Copied to `docs/pc/art_help/handoff_wip/technical_artist/08_other_recent_ta_work/scratch_ta_fix/`. The matching pre-fix backups are `/workspace/scratch/npc_ship_pre_ta_fix/`, `/workspace/scratch/npc_tools_pre_ta_fix/` and `/workspace/scratch/npc_readme_pre_ta_fix/` (box-only, not copied).
- `/workspace/tmp_ij/` loose experiments (Oct 3, 21:49–22:54 ET), from the hold and arm iterations:
  - `export_joints.py`, `pad_ironjaw.py`, `rig_keep.py`, `model_keep.py`, `cmp.py`, `coll*.py`, `compare.py`, `meas.py`, `strip.py`, `render.log`, `post.log`;
  - `r2/`: the per-facing hold optimisation search (`opt*.py`, `scan*.py`, `best*.json`, logs);
  - test render folders (`f1..f3`, `g_*`, `h*`, `q_*`, `t1`, `t2`, `v_*`, `w_*`, `x_*`, `y_*`, `z_*`) and PNGs.
  Scripts, json and logs are copied to `docs/pc/art_help/handoff_wip/technical_artist/08_other_recent_ta_work/tmp_ij_loose_scripts/`. The images and test renders are not copied (box-only, under `/workspace/tmp_ij/`).
- `/workspace/scratch/l9_v14/` (Oct 3, ~20:55 ET): gate runs (`gate_world.txt`, `gate_props.txt`, `check_report_world_l9_outdoor_board.md`), colour metrics and `looks_v14_log.json` for the v1.4 iteration of the outdoor board that is now in the ship folder (see item 5). Not copied; it is unclear whether this was TA or Scenario.
- Related, but Scenario's (not copied): `/workspace/stasium-pc-look/ship/l9_v1_decor_v2/` and `/workspace/stasium-pc-look/tools/l9_v1_decor_v2/` (decor v2 placed where mock v1 puts it, per Luca at 07:42 ET on Oct 4).
