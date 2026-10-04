# Kestrel v2 legs-only sheet (gate before the full body)

Rig: kestrel/v2/scripts (kbuild.py with `boot_one`, `hip_mode v2`, no squash). Joints: **blockout v3 legs**, commit ffbfe3a on claude/class-walk-blockouts (kestrel/blockout_v3/). toe_pin is `full` on S and E.

Files
- `kestrel_v2_legs_sheet.png`: the layout from issuecomment-5981171032. Each row is target legs | f00 | f03 | f06 | f09, all at the same figure height (hood to sole).
  - Rows are S, E, and E-ALT. E-ALT allows k ≥ 0.90, which breaks the 1 ≤ k ≤ 1.10 rule. It's there only for Claude to decide on.
  - Solid lines are this tile's belt (blue), knee = boot top (orange) and sole (green). Dashed lines are the target's lines. Grey ticks mark Claude's nominal 43% / 70%.
- `kestrel_v2_legs_cycle.png`: all 12 frames per facing, legs only. Each frame is labelled with the key and knee bend per leg, knee line %, belt-to-sole %, stance straight % and hip offset.
- `thigh_keys_v1_vs_v2.png`: before/after strip of the fwd / down / back thigh keys (R leg), plus the three key outlines pinned at the hip.
- `legs_sheet.json`, `legs_cycle.json`: every number printed on the sheets.

Definitions (the same method on the target and on the walk)
- **height:** hood top to the lowest boot sole.
- **belt:** the target belt centre.
- **knee line:** the top of the boot whose sole is lowest. This matches the target, where the boot is one piece from knee to sole.
- **thigh / boot width:** the run across the bone at mid-thigh / mid-shaft.
- **shoulder:** fixed outer shoulder points on the target.
- **straight %:** hip to heel-sole distance of the stance leg ÷ (target thigh + target boot laid out straight).
