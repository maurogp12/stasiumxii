"""Check that the shared kit still rebuilds the Drowned Abbey's town, board, fx and manifest exactly
(the committed monster frames are copied in, not re-rendered). See check_kit_repro.py.
  python3 check_abbey_repro.py [--keep]
Exit code 0 = identical.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_kit_repro import run_check  # noqa: E402

if __name__ == "__main__":
    run_check("drowned_abbey", ["build_abbey_town.py", "build_abbey_board.py", "build_abbey_fx.py", "build_abbey_manifest.py"], "Drowned Abbey")
