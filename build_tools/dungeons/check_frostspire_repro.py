"""Check that the shared kit still rebuilds the Frostspire Archive exactly (the Granary check, for dungeon 2).

Rebuilds the whole Frostspire kit into a scratch folder (GKIT_OUT_ROOT) with the current
scripts and compares it with the committed art/pc/dungeons/frostspire_archive/:
  * every PNG and manifest.json must be byte-identical;
  * every monsters/**/meta.json must match on the keys the committed file has.
The monster rebuild is slow (about 20 min); --skip-monsters copies the committed frames in.
  python3 check_frostspire_repro.py [--skip-monsters] [--keep]
Exit code 0 = identical.
"""
import filecmp
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
REF = os.path.join(REPO, "art", "pc", "dungeons", "frostspire_archive")


def run(script, env):
    args = list(script) if isinstance(script, tuple) else [script]
    subprocess.run([sys.executable, os.path.join(HERE, args[0])] + args[1:], env=env, check=True, stdout=subprocess.DEVNULL)


def main():
    skip_mon = "--skip-monsters" in sys.argv
    tmp = tempfile.mkdtemp(prefix="frostspire_repro_")
    env = dict(os.environ, GKIT_OUT_ROOT=tmp)
    out = os.path.join(tmp, "frostspire_archive")
    if skip_mon:
        # The manifest reads the monster metas: copy the committed ones in.
        for p in glob.glob(os.path.join(REF, "**", "meta.json"), recursive=True):
            d = os.path.join(out, os.path.relpath(p, REF))
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy(p, d)
            for png in glob.glob(os.path.join(os.path.dirname(p), "**", "*.png"), recursive=True):
                q = os.path.join(out, os.path.relpath(png, REF))
                os.makedirs(os.path.dirname(q), exist_ok=True)
                shutil.copy(png, q)
    mons = [] if skip_mon else ["frostspire_monsters.py", ("frostspire_monsters.py", "the_frozen_archivist", "frozen_ice_construct", "frozen_book_wraith")]
    for s in ["build_frostspire_town.py", "build_frostspire_board.py", "build_frostspire_fx.py"] + mons + ["build_frostspire_manifest.py"]:
        print("run", s, flush=True)
        run(s, env)
    bad = []
    ref_pngs = {os.path.relpath(p, REF) for p in glob.glob(os.path.join(REF, "**", "*.png"), recursive=True) if "/_mock/" not in p}
    new_pngs = {os.path.relpath(p, out) for p in glob.glob(os.path.join(out, "**", "*.png"), recursive=True) if "/_mock/" not in p}
    if ref_pngs != new_pngs:
        bad.append("file sets differ: only committed %s, only rebuilt %s" % (sorted(ref_pngs - new_pngs)[:5], sorted(new_pngs - ref_pngs)[:5]))
    for r in sorted(ref_pngs & new_pngs):
        if not filecmp.cmp(os.path.join(REF, r), os.path.join(out, r), shallow=False):
            bad.append("png differs: " + r)
    if not filecmp.cmp(os.path.join(REF, "manifest.json"), os.path.join(out, "manifest.json"), shallow=False):
        bad.append("manifest.json differs")
    for p in glob.glob(os.path.join(REF, "**", "meta.json"), recursive=True):
        r = os.path.relpath(p, REF)
        a = json.load(open(p))
        b = json.load(open(os.path.join(out, r)))
        if any(a[k] != b.get(k) for k in a):
            bad.append("meta differs: " + r)
    print("checked %d PNGs, manifest.json and the monster metas" % len(ref_pngs))
    if "--keep" not in sys.argv:
        shutil.rmtree(tmp)
    else:
        print("kept", tmp)
    if bad:
        print("NOT IDENTICAL:\n  " + "\n  ".join(bad[:30]))
        sys.exit(1)
    print("Frostspire rebuild is byte-identical")


if __name__ == "__main__":
    main()
