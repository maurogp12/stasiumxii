# TA joints update (2026-10-04, 04:5x ET)

- **walk_S has a 2.0 px pelvis raise baked in.** Thigh and shin are 1.0275x longer, and the feet are IK-pinned (ankle, heel and toe joints are identical to before). Everything from the pelvis up moves exactly (0, -2) px: pelvis, neck, head, chest, cape, shoulders, elbows, wrists, grips and axe heads. Stride, contacts and bob are unchanged.
- **idle_S, idle_E and walk_E are unchanged.** All existing keys are identical to the previous file.
- **2 px is solved on your metric.** Scenario's rig rebuilt on these joints scores height_vs_idle 1.000 (it was 0.992). Their qa_walk.py stays 48/48 PASS with skate 0.
- **Your prototype:** reduce `raise_px` for S by 2.
  - `raise_px = 7` gives height_vs_idle **1.000** in your setup (tested: look 88.4, ssim_upper 0.976).
  - `raise_px = 11` reproduces your old 1.015 (it was 13 on the old joints).
  - Leaving it at 13 would raise S by 15 px in total.
- **New additive keys for rig_fx.** Details are in the TA README ("Additive joints_512.json keys for rig_fx").
  - Per frame: `arm_swing_deg` {R,L} (rig swing, + = forward) and `arm_swing_screen_deg` {R,L} (shoulder->grip screen angle minus idle; use it as the lbs_swing deg in S).
  - Per frame: `cape_points` {collar, hem} in cell px.
  - E only: `reach_vs_idle` {R,L}: `length_scale`, `depth_delta_units` (+ = toward camera) and `toward_away` (toward/away/level).
  - Meta: `meta.fx.cape_lag_frames` {S 2.43, E 2.3}, the hem's sideways swing behind the pelvis sway; `meta.walk_leg_raise`.
- **The S/E y offsets (15 / 31) put each facing's idle lowest sole on row 329.** In the 460 renders the idle soles are at 314 (S) and 298 (E). E's boots project higher on screen, so E needs the bigger offset. x +26 centres the 460 render in the 512 cell.
