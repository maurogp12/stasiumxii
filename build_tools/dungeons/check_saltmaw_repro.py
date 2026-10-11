"""Check that the shared kit still rebuilds the Saltmaw Grotto's town, board, fx and manifest exactly
(the committed monster frames are copied in, not re-rendered). See check_kit_repro.py.
  python3 check_saltmaw_repro.py [--keep]
Exit code 0 = identical.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_kit_repro import run_check  # noqa: E402

if __name__ == "__main__":
    run_check("saltmaw_grotto", ["build_saltmaw_town.py", "build_saltmaw_board.py", "build_saltmaw_fx.py", "build_saltmaw_manifest.py"], "Saltmaw")
