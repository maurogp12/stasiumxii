"""Run the npc gate on each role (in-process) and summarise FAIL/WARN notes per role.
usage: gate_sum.py SHIP_NPC_DIR [--verbose] [--json out.json]"""
import sys, json
from pathlib import Path
sys.path.insert(0, '/workspace/stasium-pc-look/tools')
import check_assets as ca
orig = ca.Result.add
def add(self, st, text):
    self.__dict__.setdefault('rec', []).append((st, text)); orig(self, st, text)
ca.Result.add = add
root = Path(sys.argv[1]); verbose = '--verbose' in sys.argv
ROLES = ['farmer', 'woodcutter', 'fisher', 'smith', 'hermit', 'coil_engineer', 'warden', 'guide', 'herald', 'banker', 'elder', 'trader', 'door_keeper', 'archivist', 'forge_master', 'ferry_captain', 'fen_guide', 'last_watcher', 'shard_seer']
if len(sys.argv) > 2 and not sys.argv[2].startswith('--'):
    ROLES = sys.argv[2].split(',')
out = {}
tot = [0, 0, 0]
for r in ROLES:
    res, missing, unexpected, _, _ = ca.check_npc_role(root / r, make_sheet=False)
    fails, warns = [], []
    for x in res:
        for st, t in getattr(x, 'rec', []):
            (fails if st == ca.FAIL else warns).append(f'{x.name.split("/")[-1]}: {t}')
    fails += [f'missing {m}' for m in missing] + [f'stray {u}' for u in unexpected]
    hop = sum('support (lowest) foot above' in t for t in fails + warns)
    off = sum(('body centre' in t or 'stance centre' in t) for t in warns + fails)
    out[r] = {'fail': fails, 'warn': warns}
    tot[0] += len(fails); tot[1] += len(warns); tot[2] += hop
    print(f'{r:14} FAIL {len(fails):2d}  WARN {len(warns):2d}  hop {hop:2d}  offc {off:2d}')
    if verbose:
        for t in fails: print('    F', t[:230])
        for t in warns: print('    W', t[:230])
print('TOTAL FAIL', tot[0], 'WARN', tot[1], 'hop', tot[2])
if '--json' in sys.argv:
    json.dump(out, open(sys.argv[sys.argv.index('--json') + 1], 'w'), indent=1)
