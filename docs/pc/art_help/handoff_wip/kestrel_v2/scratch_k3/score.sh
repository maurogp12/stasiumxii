#!/bin/bash
# usage: score.sh F DIR [out.json]
cd /workspace/handoff/class_walk_blockouts
O=${3:-/tmp/kmetric_$1.json}
/workspace/.venv/bin/python kestrel/v2/scripts/kestrel_metric.py --facing $1 --cand $2 --v2 kestrel/blockout_v3/clay --target targets/kestrel_rp_$1_f00.jpg --target_alpha targets/kestrel_rp_$1_f00_alpha.png --idle kestrel/blockout_v3/clay/kestrel_idle_$1_f00.png --joints kestrel/blockout_v3/joints_512.json --out $O >/dev/null 2>/tmp/kmerr_$1.txt || { tail -5 /tmp/kmerr_$1.txt; exit 1; }
python3 -c "
import json;r=json.load(open('$O'));print({k:r[k] for k in ['fit','ssim_upper','ssim_lower','iou','palette','height_vs_idle','look_score','bob_err','motion_score']});print('pal',r['palette_detail']);print('sole',r['sole_err']); print('hold',r['look_hold_upper'])"
