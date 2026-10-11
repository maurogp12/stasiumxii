"""Shared body of the per-dungeon repro checks for the later dungeons (Saltmaw, Abbey): rebuild a dungeon's town,
board, fx and manifest into a scratch folder (GKIT_OUT_ROOT) with the current scripts and compare with the committed
art. The monster rigs are not re-rendered (that takes long): the committed monster frames and metas are copied in, so
the manifest (which reads them) can be rebuilt. Every PNG outside monsters/ and _mock/, and manifest.json, must be
byte-identical. The Granary and Frostspire keep their own full checks (check_granary_repro.py, check_frostspire_repro.py).
"""
import filecmp
import glob
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def run_check(dungeon, scripts, label):
    ref = os.path.join(REPO, "art", "pc", "dungeons", dungeon)
    tmp = tempfile.mkdtemp(prefix=dungeon + "_repro_")
    env = dict(os.environ, GKIT_OUT_ROOT=tmp)
    out = os.path.join(tmp, dungeon)
    mon_dirs = [d for d in ("monsters", "star5/monsters") if os.path.isdir(os.path.join(ref, d))]
    for d in mon_dirs:
        shutil.copytree(os.path.join(ref, d), os.path.join(out, d))
    for s in scripts:
        print("run", s, flush=True)
        subprocess.run([sys.executable, os.path.join(HERE, s)], env=env, check=True, stdout=subprocess.DEVNULL)

    def pngs(root):
        return {os.path.relpath(p, root) for p in glob.glob(os.path.join(root, "**", "*.png"), recursive=True)
                if "/_mock/" not in p and "/monsters/" not in "/" + os.path.relpath(p, root)}
    bad = []
    ref_p, new_p = pngs(ref), pngs(out)
    if ref_p != new_p:
        bad.append("file sets differ: only committed %s, only rebuilt %s" % (sorted(ref_p - new_p)[:5], sorted(new_p - ref_p)[:5]))
    for r in sorted(ref_p & new_p):
        if not filecmp.cmp(os.path.join(ref, r), os.path.join(out, r), shallow=False):
            bad.append("png differs: " + r)
    if not filecmp.cmp(os.path.join(ref, "manifest.json"), os.path.join(out, "manifest.json"), shallow=False):
        bad.append("manifest.json differs")
    print("checked %d PNGs (town, board, fx) and manifest.json" % len(ref_p))
    if "--keep" not in sys.argv:
        shutil.rmtree(tmp)
    else:
        print("kept", tmp)
    if bad:
        print("NOT IDENTICAL:\n  " + "\n  ".join(bad[:30]))
        sys.exit(1)
    print("%s rebuild (town, board, fx, manifest) is byte-identical" % label)
