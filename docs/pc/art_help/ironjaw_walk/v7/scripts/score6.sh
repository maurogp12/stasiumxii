#!/bin/bash
# score6.sh <cand_dir> <tag> <outdir> [E_target]   (E_target default = old rp_E_f00_t1.jpg; S always rp_S_f00_t1.jpg)
# official numbers: match_metric.py unchanged (it already takes --target); extras_v6.py adds motion_bootsole / leg_ratio_true / secondary.
OUT=$3; mkdir -p $OUT; ET=${4:-/workspace/scratch/ij_walk/repaint/rp_E_f00_t1.jpg}; ST=${5:-/workspace/scratch/ij_walk/repaint/rp_S_f00_t1.jpg}
PY=/workspace/scratch/npc_sprites/.venv/bin/python; CS=/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts
FACS=${FACS:-S E}
for F in $FACS; do
 if [ $F = E ]; then T=$ET; else T=$ST; fi
 RPP=""; if [[ $T == *stride* ]]; then RPP="--rp_pelvis 415"; fi; if [[ $T == *turn* ]]; then RPP="--rp_pelvis 360"; fi
 $PY $CS/match_metric.py --facing $F --cand $1 --v2 /workspace/art/ironjaw_full/v4_hd/walk --target $T \
  --idle /workspace/handoff/ironjaw_walk_claude/hd_set_idle/ironjaw_idle_${F}_f00.png \
  --joints /workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json --out $OUT/mm_${2}_$F.json --png $OUT/mm_${2}_$F.png > /dev/null 2>&1 || echo fail $F
 $PY /workspace/scratch/ij_walk/v7/extras_v6.py --facing $F --cand $1 --official $OUT/mm_${2}_$F.json --out $OUT/mm_${2}_extras_$F.json --target $T $RPP > /dev/null
 $PY - $OUT/mm_${2}_$F.json $OUT/mm_${2}_extras_$F.json $2 $F <<'PY'
import json,sys; r=json.load(open(sys.argv[1])); x=json.load(open(sys.argv[2]))
print(sys.argv[3], sys.argv[4], 'look', r['look_score'], 'up', r['ssim_upper'], 'low', r['ssim_lower'], 'iou', r['iou'], 'pal', r['palette'], 'h', r['height_vs_idle'], 'legr', r['leg_ratio_vs_repaint'], 'lrt', x['leg_ratio_true'], 'motion', r['motion_score'], 'mb', x['motion_bootsole'], r['PASS'])
PY
done
