# Stasium art handoff: scenario and state (written 2026-10-04, 11:0x ET, by Grok Bot for Claude)

> **Fallback only.** Written before Luca's override. Scenario Art keeps Kestrel and is still finishing it. Claude does not take Kestrel over. [5981373327](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981373327).

All times are ET. A path written as a repo path below is on `art/ironjaw-walk-help`. Any path still written as `/workspace/...` is **box-only** (Luca's agent box) and is not in this repo.

Class-walk paint that has landed is under `docs/pc/art_help/class_walk_looks/`. It is not under `docs/pc/art_help/class_walk_blockouts/` on this branch. Blockout v3 stays on `claude/class-walk-blockouts` at `ffbfe3a` (`docs/pc/art_help/class_walk_blockouts/` on that branch). The box tree `/workspace/handoff/class_walk_blockouts/` is box-only. Box copies that were brought across sit at `docs/pc/art_help/handoff_wip/` (was `/workspace/handoff/wip_extra/`). `wip_extra/blockout_v3` was not included. The Technical Artist handoff is [`docs/pc/art_help/HANDOFF_TA.md`](HANDOFF_TA.md), with copies under `docs/pc/art_help/handoff_wip/technical_artist/`.

---------------------------------------------------------------------------------------------------------------------------
## Kestrel walk v2 (ACTIVE, legs only, not accepted)

**Item:** Kestrel (archer) 8-dir walk. S and E are built; W and N are mirrors (approved). 12 frames per facing, 512x360 cells. It's a hybrid: the approved target
painting cut into layers and re-posed on Claude's blockout joints.

**State**
- v1 (`docs/pc/art_help/class_walk_looks/kestrel/v1/`, committed at **b522f23**) was **REJECTED by Mauro** ("Bad", "the legs") even though it scored S look 90.1, E 88.7, motion 100 and qa 48/48.
  Since then the gate is **the legs-only sheet + Mauro's eye**, not the scores (Claude, #252 issuecomment-5981174258).
- v2 runs on **blockout v3** (commit **ffbfe3a**, claude/class-walk-blockouts; straight planted legs, toe joint on the sole) with `toe_pin: full` on S and E.
  Bastion is NOT moved to v3.
- **Legs sheet A** (`kestrel/v2/legs_sheet/`) passes the numbers:
  - thigh / shoulder within ±4% of the target
  - boot / shoulder within ±5.6% at the sheet frames (8.3% in one S frame outside them)
  - belt-to-sole −0.1 to +4.7% vs the target
  - knee line within 2.3 points
  - hip offset 0 px
  - S stance legs straight (5°, the painted bend)

  **Luca and Stasium Bot rejected the LOOK:**
  1. Cut-out pieces with hard seams at the knee and boot top.
  2. No pelvis or hip mass; knock-knees at S f00/f06/f09.
  3. Flat, paper-like thighs (no volume shading).
  4. The E boots merge into one blob at f00/f09.
  5. Jagged silhouette at the cut edges.
  6. (Luca, 11:00, TOP PRIORITY) The S legs LEAN sideways: both thighs tilt to screen-right. The hip→ankle axis must stay within about 8° of the target's
     leg axis at contact and mid-stance, with the stride shown as depth (near foot lower and bigger), not a sideways swing. Same check on E.
- **Legs sheet B (requested 10:56): code written, sheet NOT produced.** The render was interrupted when Luca stopped the work at 11:01.
  - `kestrel/v2/legs_sheet_b/` and `kestrel/v2/paint_guides/` do **not exist yet**.
- Cape, arms and brief points 4 / 6 / 7 (cape lag and hem ripple, left-arm swing ±20°, bow swing ±8°) are **not started**.
  - Neither are the full-body frames, GIFs, `mauro_checks.json`, `v2_brief_check.md` or the scores.

**Last commit SHA:** v1 is at b522f23. v2 is not committed by me; Stasium Bot is committing `kestrel/v2` (scripts + legs_sheet). Blockout v3 is at ffbfe3a.

**Where**
- Scripts: `docs/pc/art_help/class_walk_looks/kestrel/wip/v2/scripts/` (box-only original: `/workspace/handoff/class_walk_blockouts/kestrel/v2/scripts/`)
- Legs sheet: `docs/pc/art_help/class_walk_looks/kestrel/v2/legs_sheet/`
  - `kestrel_v2_legs_sheet.png` (target | f00 f03 f06 f09 for S, E and E-ALT)
  - `kestrel_v2_legs_cycle.png` (12 frames)
  - `thigh_keys_v1_vs_v2.png`
  - `legs_sheet.json`, `legs_cycle.json`
  - `README.md` (measurement definitions)
- Blockout v3 for Kestrel / Gloam / Mender is box-only at `/workspace/handoff/class_walk_blockouts/{kestrel,gloam,mender}/blockout_v3/`. Same content as `docs/pc/art_help/class_walk_blockouts/{kestrel,gloam,mender}/` at ffbfe3a on `claude/class-walk-blockouts`. Not on this branch. `wip_extra/blockout_v3` was not included.
- Rig parts (cut layers, generated): `docs/pc/art_help/handoff_wip/kestrel_v2/parts/` (box-only original: `/workspace/scratch/k3/parts/`). Regenerate them with the cut scripts below.

**Where I stopped**
- I had just added the following to `kbuild.py` (all on in `scripts/kcfg.json`):
  - `leg_one`: ONE continuous painted leg per facing, hip to sole, skinned on 3 bones with smoothstep blends at the knee and ankle (`leg_skin`), cut by
    `cut_legs_b.py`. The E leg is now the target's screen-left leg, so E `src: 'L'`.
  - `pelvis` layer: belt, pouches, tunic hem.
  - `shade_leg`: cylindrical volume gradient, far leg 12% darker.
  - Rim gap between overlapping legs.
  - `to_rgba_aa`: anti-aliased alpha with a 1 px dark outline.
  - `RS` render scale, for the hi-res paint guides.
  - `depth_bend` / `lat_max 3`: a bent knee stays on the hip→ankle axis and foreshortens instead of swinging sideways. This is Luca's upright-legs fix.
    **It knowingly breaks Mauro's 1 ≤ k ≤ 1.10 rule** for bent swing / toe-off legs only (k ≈ 0.85–0.97).
- `legs_sheet_b.py` is written (sheet B, `side_by_side_{S,E}.png`, S knee-gap check, leg-axis annotation vs target) but **never ran to completion; its output is untested.**
- Paint guides (Track B: full-figure composites at about 1024 px tall on grey 172, plus a transfer note) are **not written**.
  - Plan: `KB.RS = 4`, render, `to_rgba_aa`, composite on (172,172,172), crop.
- Leg-axis numbers with depth_bend on (geometry only, not yet rendered):
  - **S:** stance legs 11.5° (f00 contact) / 4.2° (f03) / 10.4° (f06) / 1.3° (f09) vs the target's forward leg at 4.2° and back leg at −6.0°. That's within 8°.
    Thighs now follow the axis (no more +13 to +22° right tilt).
  - **E:** forward-leg target +3.0°, back −10.4°; the walk is within about 8° by role.
- **The S f00 knock is geometric.** On the v3 plants the near leg R runs from the left hip to a foot right of the L foot: in 2:1 iso the stride along the
  diagonal is larger in x than the hip spacing. So the legs cross near the knees at f00/f01 and f10/f11 (knee-point distance 16–25 px).
  - Fixing it needs either wider `hip_w` (each leg then leans more) or moving the plants in x (that skates the feet against the ground, so motion drops).
  - Unresolved.

**How to run** (rig venv is box-only: `/workspace/.venv/bin/python`; rembg uses the same venv, model `isnet-general-use`; the NPC sprite venv is
box-only `/workspace/scratch/npc_sprites/.venv/bin/python`, which Kestrel doesn't need)
```
cd docs/pc/art_help/class_walk_looks/kestrel/wip/v2/scripts
# box-only: /workspace/handoff/class_walk_blockouts/kestrel/v2/scripts
export KPARTS=docs/pc/art_help/handoff_wip/kestrel_v2/parts/
# box-only default in kcommon.py: /workspace/scratch/k3/parts/
mkdir -p $KPARTS
PY=/workspace/.venv/bin/python        # box-only
$PY cut_target.py            # body/front/back + thigh/shin/foot/boot layers + target_legs.json
$PY cut_legs_b.py            # sheet B: T{S,E}_leg.png (one continuous leg) + pelvis_{S,E}.png + leg_b.json
# sheet A exactly as delivered: use kcfg_sheetA.json (leg_one / depth_bend off, E src R)
# kcfg_sheetA.json is not in the committed scripts folder
cp kcfg.json kcfg_B.json; cp kcfg_sheetA.json kcfg.json
$PY legs_sheet.py ../legs_sheet --alt --cycle && $PY keys_strip.py ../legs_sheet/thigh_keys_v1_vs_v2.png
cp kcfg_B.json kcfg.json     # back to the sheet-B config
$PY legs_sheet_b.py ../legs_sheet_b        # UNTESTED: sheet B + side_by_side_{S,E}.png + legs_sheet_b.json (about 1 min, RS=4 renders)
$PY kbuild.py --out ../frames              # full frames at 512x360 (binary alpha), with whichever config is in kcfg.json
# scores (the metric is no longer the gate, but the acceptance numbers are still asked for):
# blockout clay / joints below are box-only, or on claude/class-walk-blockouts at ffbfe3a
$PY docs/pc/art_help/class_walk_looks/kestrel/wip/v2/scripts/kestrel_metric.py --facing S --cand kestrel/v2/frames --v2 kestrel/blockout_v3/clay \
    --target docs/pc/art_help/class_walk_looks/targets/kestrel_rp_S_f00.jpg --target_alpha docs/pc/art_help/class_walk_looks/targets/kestrel_rp_S_f00_alpha.png \
    --idle kestrel/blockout_v3/clay/kestrel_idle_S_f00.png --joints kestrel/blockout_v3/joints_512.json --out kestrel/v2/metric_S.json   # same for E
```
- `qa_walk.py`, `mauro_checks.py`, `boot_sep.py`, `legs_check.py` and `previews_walk.py` (v1 layout) still expect `*_shin` / `*_foot` layers.
  **Update them for `*_boot` / `*_leg` before scoring v2.**
- `foot_solve.py` / `swing_solve.py`: re-solve `foot_o` and `swing_drop` on v3. They were reset to 0 when switching to v3, and the sole error hasn't been checked since.
- Helper scripts I used are box-only in `/workspace/scratch/k3/`, copied to `docs/pc/art_help/handoff_wip/kestrel_v2/scratch_k3/`:
  - `score.sh F DIR`
  - `strip.py` (crops with the clay outline)
  - `sheet.py`
  - `poly_ov.py` (polygons over the target)
  - `dropgrid.py` / `axis.py` / `legtab.py` (leg geometry tables)
  - `grid.py`, `rot_grid.py`

**Inputs**
- Targets: `docs/pc/art_help/class_walk_looks/targets/kestrel_rp_{S,E}_f00.jpg` + `_alpha.png`, approved by Mauro.
- Blockout v3: `kestrel/blockout_v3/joints_512.json`, `clay/`, `id/`, and `kestrel_v2_v3_legs.png` (ffbfe3a on `claude/class-walk-blockouts`). Box-only on this branch: `/workspace/handoff/class_walk_blockouts/kestrel/blockout_v3/`.
- Briefs on PR #252 of maurogp12/stasiumxii:
  - 5981085130: Kestrel v2 points 1–7, plus the Bastion v3 rules in `bastion/v3/scores.md`
  - 5981171032: leg priority, legs-only sheet layout, belt-to-sole ±5%, knee line ±3%
  - 5981174258: v1 rejected
  - 5981194458: v3 blockout
- Luca's notes on sheet A: 10:56 (notes 1–5) and 11:00 (upright legs, leg axis within 8°).

**Open problems**
1. **E foreshortening conflict.** The clay E hip→ankle length runs from 110 px at heel strike to 133 px at mid-stance (about ±10%).
   - A fixed target-length leg with 1 ≤ k ≤ 1.10 can't be straight at both. At drop 20, E contact (f05/f11) bends 41–46° and f06 bends 33°.
   - The **E-ALT** row (k ≥ 0.90) straightens them but breaks the rule.
   - Using the forward leg's own foreshortened boot made it worse (mid-stance reach 1.22).
   - **Answered** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): use E-ALT, k ≥ 0.90.
2. **Thigh width.** The target's mid-thigh is 70 px = 0.397 of shoulder width = **2.2× the forearm plus bracer** (31 px). Mauro's "thigh as wide as the forearm"
   would mean about 45% of the target width, which breaks the ±8% thigh/shoulder rule.
   - **Answered** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): keep the target ratio, thigh ÷ shoulder ±8%. The forearm note is withdrawn. Do not slim the thighs to 45%.
3. **Upright legs (Luca) vs no compression (Mauro).** depth_bend uses k < 1 on bent legs.
   - **Answered** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): Luca's upright-legs rule wins. `depth_bend` k from 0.85 to 1.0 is allowed on bent swing and toe-off legs. Stance legs stay at k between 1.0 and 1.10.
4. **S f00 / f10–f11 leg crossing** (see Where I stopped).
   - **Answered** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): Kestrel blockout v3.1, `ec4beff918ad691be293d7f22de3689b1516e67e` on `claude/class-walk-blockouts`. `foot_w` 1.45× the hip half-width (was 0.9). Knee x gap 4.5–20.7 px at f00, f01, f10, and f11. No skate. Kestrel rigs on v3.1. Gloam and Mender stay on v3 (`ffbfe3a9`). Re-solve `foot_o` and `swing_drop` on v3.1.
5. The S back thigh barely trails (thigh angles +22 / +13 / +6° for fwd / down / back; v1 had +19 / +8 / −10° but with squashed, bent legs). Still **open**.
6. E toe-off R f00 and L f06 can't reach after a 25° heel lift, so the boot lifts about 2.7 px off the ground.
   - **Answered** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): the lift of about 2.7 px is fine for now. Pin the toe if possible.
7. Not done: the scores on v3, foot_o / swing_drop re-solve, qa / mauro scripts update, cape, arms, bow swing. Still **open**. The re-solve is now on v3.1, per the same comment.

**Decisions**
- v2 was on blockout v3. `toe_pin: full` on S and E, so the earlier E toe workaround is obsolete. [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472) moves Kestrel onto v3.1 (`ec4beff9`). Gloam and Mender stay on v3.
- Legs are full target length. Hips sit on the target belt centre ± half the blockout hip vector (hip offset 0 px).
- The boot is one piece from knee to sole (sheet A). Sheet B goes further: one continuous painted leg, hip to sole.
- Thigh keys change shape (the thigh bends toward the travel side for fwd, toward the trailing side for back) and are keyed by the rendered thigh angle:
  S `key_deg 3`, E `key_deg 6`.
- Body height: drop S 21, E 20, chosen so the stance legs are straight within the 1.10 stretch.
- **Planned next step (Luca), approved** by [5981423472](https://github.com/maurogp12/stasiumxii/pull/252#issuecomment-5981423472): repaint keys f00/f03/f06/f09 for S and E with an image model, over the paint guides, with the target as the style reference. Keep the leg-axis check within 8°. Send legs sheet B side by side with the target before the full body.
  Then transfer them back:
  - mask the legs
  - align by the hip / knee / ankle joints (the rig meta in `_build_info.json` has hip, knee, ankle per leg per frame)
  - warp the repaint onto the rig pose with the same 3-bone skin (`leg_skin`)
  - generate the in-betweens by skinning the nearest repainted key (or cross-blending the two neighbouring keys) on the rig joints

---------------------------------------------------------------------------------------------------------------------------
## Bastion walk v3 (LOCKED)
- **State:** LOCKED by Luca at 10:22 Oct 4. Built on the v2 joints (it stays on v2; do NOT move it to blockout v3).
  - Scores: S look 87.1, E look 88.7, motion 100/100, qa 48/48. Verified by Claude at **7f65035**.
- **Where:** `docs/pc/art_help/class_walk_looks/bastion/v3/` (scores.md, frames, scripts). Box-only original: `/workspace/handoff/class_walk_blockouts/bastion/v3/`.
  - Blockout: `bastion/blockout_v2/` on `claude/class-walk-blockouts` (box-only here: `/workspace/handoff/class_walk_blockouts/bastion/blockout_v2/`). Older builds: `docs/pc/art_help/class_walk_looks/bastion/v1/` and `bastion/v2/`. Tars `/workspace/bastion_v{1,2,3}.tar.gz` are box-only.
  - Scratch: `/workspace/scratch/bastion`, `/workspace/scratch/b2`, `/workspace/scratch/b21`. These are box-only intermediates, not needed: the v3 scripts rebuild from `bastion/parts_src` (box-only; not in this repo).
- **How to run:** see `docs/pc/art_help/class_walk_looks/bastion/v3/scores.md` (build_hybrid.py → metric → qa). Venv is box-only: `/workspace/.venv/bin/python`.
- **Decisions:** target-scale leg pieces at s_up, with 1 ≤ k ≤ 1.1 along the bone and stretch only when out of reach. These are the "Bastion v3 rules" that Kestrel also follows.

## Ironjaw walk v8 (LOCKED, parked)
- **State:** locked by Luca at 7:56 Oct 4 and parked. No further work.
- **Where:**
  - Working dir: `/workspace/scratch/ij_walk/v8/` (2.1 GB, box-only, too big to copy). The same tree holds v3–v7.
  - Parked package already on this branch: `docs/pc/art_help/ironjaw_walk/v8/`.
  - Packaged deliverable: box-only `/workspace/ironjaw_v8.tar.gz` (4 MB), copied to `docs/pc/art_help/handoff_wip/ironjaw_v8/ironjaw_v8.tar.gz`.
  - Claude handoff pack: `docs/pc/art_help/ironjaw_walk/` (BRIEF.md, CONVERSATION_HISTORY.md, NOTES.txt, rig_scripts/, parts/, ta_joints/, repaint_targets/). Box-only original: `/workspace/handoff/ironjaw_walk_claude/`.
  - Other box-only tars: `/workspace/ironjaw_v7_*.tar.gz`, `/workspace/ironjaw_walk_claude.tar.gz`.

## Gloam walk (STOPPED)
- **State:** walk stopped by Luca at 10:30 Oct 4. **Not started on v3.** No `gloam/v1` exists: nothing was written before the stop.
- **Inputs:**
  - Targets: `docs/pc/art_help/class_walk_looks/targets/gloam_rp_{S,E}_f00.jpg` + `_alpha.png`
  - Parts: `docs/pc/art_help/class_walk_looks/gloam/wip/parts_src/`
  - v3 joints / clay / ID: `gloam/blockout_v3/` from ffbfe3a on `claude/class-walk-blockouts`. Box-only here: `/workspace/handoff/class_walk_blockouts/gloam/blockout_v3/`. `wip_extra/blockout_v3/gloam/` was not included.
- **Next:** the same pipeline as Kestrel v2 (cut_target, cut_legs_b, kbuild) but with Gloam polygons and anchors.

## Mender (targets approved, walk not painted)
- **State:** targets approved by Mauro (**3250c2b**): `docs/pc/art_help/class_walk_looks/targets/mender_rp_{S,E}_f00.jpg` + `_alpha.png` (with `docs/pc/art_help/class_walk_looks/targets/_orig/mender_targets_vs_clay.jpg`). Walk parts not painted yet.
- **Where:** `docs/pc/art_help/class_walk_looks/mender/wip/v2/` and `mender/wip/targets_work/`. `blockout_v3/` is ffbfe3a on `claude/class-walk-blockouts`. Box-only here: `/workspace/handoff/class_walk_blockouts/mender/blockout_v3/`. `wip_extra/blockout_v3/mender/` was not included.
  - Approved concepts: `docs/pc/art_help/class_walk_looks/mender_concepts/`. WIP copies: `docs/pc/art_help/class_walk_looks/mender/wip/mender_concepts/`.

## 19 NPC role sprites
- **Where:** `docs/pc/art_help/npc_sprites_wip/npc_sprites/` (19 role folders: archivist, banker, coil_engineer, door_keeper, elder, farmer, fen_guide,
  ferry_captain, fisher, forge_master, guide, herald, hermit, last_watcher, shard_seer, smith, trader, warden, woodcutter). Box-only original: `/workspace/stasium-pc-look/ship/npc_sprites/`.
  - Gate reports: `docs/pc/art_help/npc_sprites_wip/check_report_npc_*.md`. Raws `raw/npc_sprites/` and concepts `ship/npc_concepts`, `raw/npc_concepts` are box-only (under `/workspace/stasium-pc-look/`).
- **Run:** venv `/workspace/scratch/npc_sprites/.venv/bin/python` (520 MB, box-only, not copied). The pre-TA-fix backup is box-only: `/workspace/scratch/npc_ship_pre_ta_fix`.

## World kits
- **Northgate snow kit** (outskirts, light snow + crags):
  - Box-only: `/workspace/stasium-pc-look/ship/outskirts_themes/northgate/` (README, atlas_meta.json, kit.json with 134 ids, tiles/props/roof/overlays). Gate: `ship/check_report_*_outskirts_northgate.md` (box-only, under that tree).
  - Status table: `ship/outskirts_themes/STATUS.md` (eastmarch, southbridge and westwatch PASS 3 Oct). Box-only, under `/workspace/stasium-pc-look/`.
  - Build scripts: box-only `/workspace/scratch/ng_build/*.py`, copied to `docs/pc/art_help/handoff_wip/scripts_scratch/ng_build/`. The 108 MB intermediates were skipped.
  - Raws: `raw/outskirts_themes/` (box-only, under `/workspace/stasium-pc-look/`).
- **L2 jungle (Crosshaven jungle backdrop):** `ship/crosshaven_jungle/` (README: v4, 3 Oct ~00:27). Box-only, under `/workspace/stasium-pc-look/`. Raws: `raw/crosshaven_jungle/` (box-only).
  - Build scripts: box-only `/workspace/scratch/build/*.py`, copied to `docs/pc/art_help/handoff_wip/scripts_scratch/jungle_build/`.
  - Tars: `/workspace/jungle_v{2,3,4}_*.tar.gz` (box-only).
- **L4 Thunderwell:** floor `ship/thunderwell_floor/` and props `ship/thunderwell_props/` (box-only, under `/workspace/stasium-pc-look/`). Raws: `raw/thunderwell_floor_v{2,3}`, `raw/thunderwell_props_v1` (box-only).
  - **Thunderwell decor went out as PR #228.**
  - Scratch: `/workspace/scratch/l4`, `/workspace/scratch/l4v2` (56 MB, skipped, box-only). Tars: `/workspace/thunderwell_floor_v{1,3}.tar.gz`, `/workspace/thunderwell_props_v2.tgz` (box-only).

## L9 Crosshaven board
- **State:** `ship/l9_v1_decor_v2/` was **APPROVED by Luca at 8:04**. Box-only, under `/workspace/stasium-pc-look/`.
- **RULE:** the decor stays exactly where it is in `mock_l9_1280_v1.png`; only the tiles change. Placement data: `placement_v1_mock.json`, `match_1280.json`, `v1_mock_placement.patch`. Those files are box-only with that ship tree.
- Older boards: `ship/l9_outdoor_board/` (+ WIRING_NOTE), `ship/l9_v1_decor/` (box-only, under `/workspace/stasium-pc-look/`). Tars: `/workspace/l9_outdoor_board_v1{,1,2,3}.tar.gz`, `/workspace/l9_v1_decor_kit.tar.gz` (box-only).
- Scratch, all box-only:
  - `/workspace/scratch/l9_*` (l9_build, l9_src, l9_v14, backups; 25–87 MB each, skipped)
  - `/workspace/scratch/l9_v1_decor_check` (1.7 GB, skipped)
  - L9 layout scripts `l9_layout.py` / `l9_render.py` / `l9_diagram.py`, copied to `docs/pc/art_help/handoff_wip/scripts_scratch/l9/`

## WP10a Rowanvale / Windmere and zone joins
- **Rowanvale / Windmere:** `ship/wp10a_rowanvale/` and `ship/wp10a_windmere/` (tiles, props, animated, atlas_meta.json). Box-only, under `/workspace/stasium-pc-look/`. File list: `ship/wp10a_file_list.txt` (box-only).
  - Gate: `ship/check_report_world_wp10a_*.md` (box-only). Raws: `raw/wp10a*` (box-only).
  - Build scripts: box-only `/workspace/scratch/wp10a/*.py`, copied to `docs/pc/art_help/handoff_wip/scripts_scratch/wp10a/`. The 107 MB intermediates were skipped.
- **Zone joins** (stoneford→rowanvale ford, northgate→windmere cliff steps, level signs): **PARKED on 3 Oct, incomplete.**
  - Box-only original: `/workspace/scratch/wp10a_joins/` (RESUME.md, scripts, `out/` with the blend tiles), copied in full to `docs/pc/art_help/handoff_wip/wp10a_joins/`.
  - Raws: `raw/wp10a_joins/` (README.txt). Box-only, under `/workspace/stasium-pc-look/`.
  - Not visually reviewed yet: ford stitch, steps, signs.

## Art brief and tools
- **Art brief:** the skill `stasium-art-bot-guide` (box: `/home/box/sand-data/workflows/stasium-art-bot-guide/SKILL.md`).
  - Copy: `/workspace/stasium-pc-look/refs/STASIUM_ART_BOT_GUIDE_2026-10-03.md` (box-only). Also in `refs/` (box-only): LOOK_TARGET.md, ZONES_BUILD_SPEC.md, CHANGE_LOG_PC.md.
  - Project specs: `/workspace/stasium-pc-look/{BRIEF.md, SPEC_v1.md, PC_SPEC_GAP_AUDIT.md}` (box-only).
  - Class-walk briefs: `docs/pc/art_help/class_walk_looks/wip_shared/PAINT_BRIEF.md` and `docs/pc/art_help/class_walk_looks/wip_shared/README.md`. Shared scripts: `docs/pc/art_help/class_walk_looks/wip_shared/scripts/`.
- **Paint tool:** repaints and raws were made with an **image model through Luca's agent tools** (GenerateImage / Scenario: Seedream 4.5 and others; IDs are in each raw README).
  **Claude may not have this.** Any repaint (for example the Kestrel key repaint) needs an image model with the approved target images as style references.
  The procedural rigs above only cut and re-pose existing paintings.
- **Venvs** (box-only):
  - `/workspace/.venv/bin/python`: rigs, metrics, rembg with model `isnet-general-use`
  - `/workspace/scratch/npc_sprites/.venv/bin/python`: NPC sprites
- **Repo clone on the box:** `/workspace/stasium-repo` (box-only; origin maurogp12/stasiumxii; the class-walk branch is claude/class-walk-blockouts).

---------------------------------------------------------------------------------------------------------------------------
## wip_extra (copied from box-only `/workspace/handoff/wip_extra/`, 29 MB total)

In this repo that copy is `docs/pc/art_help/handoff_wip/`, except `blockout_v3`, which was not included.

- `docs/pc/art_help/handoff_wip/kestrel_v2/parts/`: generated Kestrel rig layers (cut_target.py + cut_legs_b.py output; the default KPARTS)
- `docs/pc/art_help/handoff_wip/kestrel_v2/scratch_k3/`: my helper scripts: score.sh, strip.py, sheet.py, poly_ov.py, grid.py, rot_grid.py, dropgrid.py, axis.py, legtab.py
- `blockout_v3/{kestrel,gloam,mender}/`: not in this commit. v3 joints, clay, ID are ffbfe3a on `claude/class-walk-blockouts`. Box-only copy: `/workspace/handoff/class_walk_blockouts/{kestrel,gloam,mender}/blockout_v3/`.
- `docs/pc/art_help/handoff_wip/ironjaw_v8/ironjaw_v8.tar.gz`
- `docs/pc/art_help/handoff_wip/wp10a_joins/`: the full zone-join scratch project (scripts + out/ + RESUME.md)
- `docs/pc/art_help/handoff_wip/scripts_scratch/{jungle_build,ng_build,wp10a,l9}/`: build scripts only

**Not produced, so nothing to copy:** `kestrel/v2/legs_sheet_b/`, `kestrel/v2/paint_guides/`, `gloam/v1/`.

**Skipped** (too large, venv, or intermediates):
- `/workspace/scratch/ij_walk/` (16 GB; v8 alone is 2.1 GB; packaged as ironjaw_v8.tar.gz instead)
- `/workspace/scratch/l9_v1_decor_check` (1.7 GB)
- `/workspace/scratch/npc_sprites` (520 MB, contains the venv)
- `outskirts` (174 MB)
- `ng_build` intermediates (108 MB)
- `wp10a` intermediates (107 MB)
- `farm_kit` (94 MB)
- `l9_build*` / `l9_src` (45–87 MB each)
- `l4v2` (56 MB)
- `crosshaven_plate_gap` (53 MB)
- `v3` / `v4` / `b2` / `bastion` / `k2` scratch (22–144 MB; old rig intermediates, reproducible)
- `/workspace/.venv`
