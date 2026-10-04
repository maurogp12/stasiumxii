"""Gloam actions v1 - read-only access to the LOCKED Gloam walk (gloam/v1_claude on claude/gloam-legs, locked at 8119c9e,
lock note bdf0ff37). The walk is not on this branch, so its scripts and parts are extracted with `git archive` into
$GWALK (default /tmp/gloam_walk_v1) and imported from there; nothing of the walk is changed. The walk's own blockouts
(S v3.1 42d8d7cc, E v3 ffbfe3a9) are extracted the same way into $GBLOCK_S / $GBLOCK_E before grig is imported."""
import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
WALK_COMMIT = 'bdf0ff3753f6e045133d3105135a7687c3232511'      # "Lock Gloam walk v1 (S/E/W/N) at 8119c9e."
ROOT = os.environ.get('GWALK', '/tmp/gloam_walk_v1')
SUB = 'docs/pc/art_help/class_walk_looks/gloam/v1_claude'
WDIR = os.path.join(ROOT, SUB)
BLOCKS = {'GBLOCK_S': ('42d8d7cca9b29f3202c10a61602f0a80161b1220', '/tmp/gloam_blockout_v31'),
          'GBLOCK_E': ('ffbfe3a9e0d219ac3b5ef8898b9f6979b7fececf', '/tmp/gloam_blockout_v3')}

def _x(commit, path, root):
    os.makedirs(root, exist_ok=True)
    subprocess.run(f'git -C "{REPO}" archive {commit} {path} | tar -x -C "{root}"', shell=True, check=True)

if not os.path.exists(os.path.join(WDIR, 'scripts/grig.py')):
    _x(WALK_COMMIT, SUB, ROOT)
for env, (commit, default) in BLOCKS.items():
    root = os.environ.setdefault(env, default)
    if not os.path.exists(os.path.join(root, 'docs/pc/art_help/class_walk_blockouts/gloam/joints_512.json')):
        _x(commit, 'docs/pc/art_help/class_walk_blockouts/gloam', root)
os.environ.setdefault('G1PARTS', os.path.join(WDIR, 'parts'))
sys.path.insert(0, os.path.join(WDIR, 'scripts'))
import grig            # noqa: E402  (the LOCKED walk rig, read-only)
PARTS = os.environ['G1PARTS']
