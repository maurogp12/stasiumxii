#!/usr/bin/env python3
"""Build the Northgate snow kit procedurally, in the Crosshaven painted style.

Writes 2x masters and 1x copies into art/world/crosshaven/{tiles,props}/.
Ground textures are drawn from noise. Snowy props are repaints of the
existing kit sprites (roofs to snow, caps on top faces, warm windows) or
painted from scratch (snowy pines, small firs, snow mounds).

    python3 build_tools/northgate_snow/build_northgate_snow_kit.py
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import snow_ground  # noqa: E402
import snow_props  # noqa: E402

ROOT = HERE.parents[1]
ART = ROOT / "art" / "world" / "crosshaven"


def main() -> None:
    only = set(sys.argv[1:])
    written: list[str] = []
    if not only or "ground" in only:
        written += snow_ground.build(ART)
    if not only or "props" in only:
        written += snow_props.build(ART)
    for path in written:
        print(Path(path).relative_to(ROOT))


if __name__ == "__main__":
    main()
