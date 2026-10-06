"""Rebuild the Northgate crag chunks as soft snowy terraces (Mauro's design B).

Chunks: crosshaven_northgate_crags_west, _crags_east, _crags_far and
crosshaven_northgate_pass. The old ground was a cliff mass with walkable
pockets, drawn as a checkerboard of one-cell snow blocks. This builder keeps
everything other chunks and systems depend on and rewrites the rest.

Kept as they are:
  - the zone header, spawn, points of interest, exits and links, presentation;
  - every water tile (the coast does not move);
  - the outer ring of tiles (shared edges keep their terrain, walkability and
    height, so every link and neighbour join stays as it was);
  - the pass road (its dirt_road tiles);
  - the buildings: cottages, farmhouses, wells and watchtowers.

Rewritten:
  - tiles: open walkable snow (golden_plains under Northgate snow) at height 0
    and a few long terraces at height 2 along the grid axes. On screen they
    read as long diagonal ridges with a snow lip over a stone face. Each
    watchtower stands on its own terrace. Small bumps and notches are merged
    away, so the faces run as continuous walls.
  - ramps: height 1 cells where the path climbs a terrace and on each terrace
    edge, so every cell is reachable with a climb of at most 1 per step (and
    back down), even though the shipped open-world limit is unlimited.
  - frozen ponds: terrain "cliff" at height 0 (not walkable, not water). The
    ground draws a crag-chunk cliff cell as ice.
  - a trodden path (dirt_road) between the exits, past the POI and the pond.
    The ground draws crag dirt_road as packed snow with footprints.
  - dressing: pine clusters (tree props, drawn as snow pines) along the
    terrace tops, small firs (bush decor), snow-capped rocks in little groups
    and snow mounds (decor).

The builder reads only what it keeps, so running it again writes the same
files. It fails loudly if a kept cell changed, an exit cell is not free, or
any passable cell cannot be reached from the spawn and back.

Run: python3 data/world/crosshaven/build_crosshaven_crags.py [--check]
"""

from __future__ import annotations

import heapq
import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ZONES = ROOT / "zones"

KEEP_PROPS = {"red_roof_cottage", "farmhouse_2x2", "well", "watchtower_2x2"}
ORTHO = ((1, 0), (-1, 0), (0, 1), (0, -1))
TERRACE = 2
RAMP = 1
CLIMB = 1

# Terraces: (axis, lo, hi, center, half_width, seed)
#   axis "x": spans x in [lo, hi]; the band sits around y = center.
#   axis "y": spans y in [lo, hi]; the band sits around x = center.
# Edges wobble with smooth noise, so a band reads as a ridge, not a box.
# Ponds: (cx, cy, rx, ry). Paths visit their waypoints in order.
LAYOUT = {
    "crosshaven_northgate_crags_west": {
        "terraces": [
            ("x", 24, 46, 9, 3.2, 11),
            ("x", 50, 68, 8, 2.6, 12),
            ("x", 6, 30, 25, 2.4, 13),
            ("y", 15, 27, 54, 3.0, 14),
            ("x", 38, 52, 22, 2.2, 15),
        ],
        "ponds": [(30, 17, 2.2, 1.6), (60, 25, 1.8, 1.4)],
        "paths": [[(36, 30), (33, 22), (36, 16), (46, 17), (58, 15), (69, 12)]],
        "pines": 64,
        "rocks": 12,
    },
    "crosshaven_northgate_crags_east": {
        "terraces": [
            ("x", 2, 20, 7, 2.8, 21),
            ("x", 12, 30, 25, 2.6, 22),
            ("y", 9, 22, 6, 2.2, 23),
            ("x", 26, 34, 18, 3.0, 24),
        ],
        "ponds": [(22, 13, 2.0, 1.5)],
        "paths": [
            [(2, 12), (10, 14), (18, 16), (20, 21), (26, 23), (33, 26)],
            [(18, 16), (14, 23), (12, 29)],
        ],
        "pines": 40,
        "rocks": 8,
    },
    "crosshaven_northgate_crags_far": {
        "terraces": [
            ("x", 3, 12, 11, 2.6, 31),
            ("x", 8, 26, 23, 2.4, 32),
            ("y", 15, 27, 26, 2.2, 33),
        ],
        "ponds": [(14, 17, 2.0, 1.5)],
        "paths": [[(2, 14), (10, 17), (18, 16), (20, 20), (18, 28)]],
        "pines": 26,
        "rocks": 6,
    },
    "crosshaven_northgate_pass": {
        "terraces": [],
        "ponds": [],
        "paths": [],
        "keep_road": True,
        "pines": 10,
        "rocks": 3,
    },
}


def hash01(x: int, y: int, salt: int) -> float:
    h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h % 100000) / 100000.0


def wobble(t: float, seed: int) -> float:
    return (
        0.9 * math.sin(t * 0.37 + seed * 1.7)
        + 0.5 * math.sin(t * 0.83 + seed * 0.61)
        + 0.25 * math.sin(t * 1.91 + seed * 2.3)
    )


class Chunk:
    def __init__(self, doc: dict) -> None:
        self.doc = doc
        self.id = doc["zone_id"]
        self.w = int(doc["width"])
        self.h = int(doc["height"])
        self.old = {(t["x"], t["y"]): t for t in doc["tiles"]}
        self.terrain: dict = {}
        self.height: dict = {}
        self.locked: set = set()  # cells this builder must not change
        self.flat: set = set()  # cells kept at height 0
        self.blocked: set = set()  # building footprints

    def inside(self, c) -> bool:
        return 0 <= c[0] < self.w and 0 <= c[1] < self.h

    def ring(self, c) -> bool:
        return c[0] == 0 or c[1] == 0 or c[0] == self.w - 1 or c[1] == self.h - 1

    def cells(self):
        for y in range(self.h):
            for x in range(self.w):
                yield (x, y)

    def nbrs(self, c):
        for dx, dy in ORTHO:
            n = (c[0] + dx, c[1] + dy)
            if self.inside(n):
                yield n

    def walkable(self, c) -> bool:
        return self.terrain[c] not in ("water", "cliff")

    def land(self, c) -> bool:
        return self.terrain[c] != "water"


def _around(c, r: int):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            yield (c[0] + dx, c[1] + dy)


def build(zone_id: str) -> dict:
    path = ZONES / f"{zone_id}.json"
    doc = json.loads(path.read_text())
    lay = LAYOUT[zone_id]
    ch = Chunk(doc)

    # 1. Keep the coast, the ring and the pass road; the rest starts as flat snow.
    for c in ch.cells():
        old = ch.old[c]
        road = lay.get("keep_road", False) and old["terrain"] == "dirt_road"
        if old["terrain"] == "water" or ch.ring(c) or road:
            ch.terrain[c] = old["terrain"]
            ch.height[c] = int(old["height"])
            ch.locked.add(c)
        else:
            ch.terrain[c] = "golden_plains"
            ch.height[c] = 0

    # Flat margins: three cells in from the ring, the shore, spawn and POIs,
    # and a yard around each building but the watchtowers.
    for c in ch.cells():
        x, y = c
        if c in ch.locked or min(x, y, ch.w - 1 - x, ch.h - 1 - y) <= 3:
            ch.flat.add(c)
        if any(ch.inside(n) and ch.terrain[n] == "water" for n in _around(c, 2)):
            ch.flat.add(c)
    anchors = [(doc["spawn"]["x"], doc["spawn"]["y"])]
    anchors += [(p["x"], p["y"]) for p in doc["points_of_interest"]]
    for a in anchors:
        ch.flat |= {n for n in _around(a, 2) if ch.inside(n)}
    kept_props = [p for p in doc["props"] if p["type"] in KEEP_PROPS]
    towers = []
    for p in kept_props:
        cells = [(f["x"], f["y"]) for f in p["footprint"]]
        ch.blocked |= set(cells)
        if p["type"] == "watchtower_2x2":
            towers.append((p["origin"]["x"], p["origin"]["y"]))
            continue
        for f in cells:
            ch.flat |= {n for n in _around(f, 2) if ch.inside(n)}

    # 2. Terrace mask.
    mask = set()
    for axis, lo, hi, center, half, seed in lay["terraces"]:
        for t in range(lo, hi + 1):
            mid = center + 1.2 * wobble(t, seed)
            span = half + 0.6 * wobble(t + 40, seed + 5)
            end = min(t - lo, hi - t)
            if end < 2:
                span *= 0.55 + 0.2 * end
            for s in range(int(round(mid - span)), int(round(mid + span)) + 1):
                mask.add((t, s) if axis == "x" else (s, t))
    # Each watchtower stands on its own small terrace, with its yard on top.
    tower_top = set()
    for ox, oy in towers:
        for c in _around((ox, oy), 4):
            d = math.hypot(c[0] - ox - 0.5, c[1] - oy - 0.5)
            if d <= 3.3:
                mask.add(c)
                if d <= 2.4:
                    tower_top.add(c)
    mask = {c for c in mask if ch.inside(c) and c not in ch.flat}

    # 3. Smooth the mask: fill notches, drop spurs, then drop or fill small regions.
    for _ in range(3):
        nxt = set(mask)
        for c in ch.cells():
            if c in ch.flat:
                continue
            up = sum(1 for n in ch.nbrs(c) if n in mask)
            if c not in mask and up >= 3:
                nxt.add(c)
            elif c in mask and up <= 1 and c not in tower_top:
                nxt.discard(c)
        mask = nxt
    mask = _drop_small(ch, mask, 12, tower_top)
    # A one-cell-wide ledge reads as noise: each raised cell needs a raised
    # neighbour on both axes or on a 2x2 block.
    for _ in range(2):
        mask = {c for c in mask if c in tower_top or _thick(mask, c)}
        mask = _drop_small(ch, mask, 12, tower_top)

    # 4. Ponds: frozen water drawn as ice. Not walkable, not water. Kept off
    # terraces with a flat ring around them.
    pond_cells = set()
    for cx, cy, rx, ry in lay["ponds"]:
        for c in _around((int(cx), int(cy)), int(max(rx, ry)) + 2):
            if not ch.inside(c) or c in ch.locked or c in ch.blocked:
                continue
            e = ((c[0] - cx) / rx) ** 2 + ((c[1] - cy) / ry) ** 2
            if e <= 1.0:
                pond_cells.add(c)
    for c in pond_cells:
        for n in _around(c, 2):
            mask.discard(n)
    mask = _drop_small(ch, mask, 12, tower_top)
    for c in pond_cells:
        ch.terrain[c] = "cliff"
    for c in mask:
        ch.height[c] = TERRACE

    # 5. Trodden path between the exits. Climbs cost more, so the path keeps to
    # the flats. Where it still meets a terrace, the terrace opens into a cut
    # one cell wider than the path on each side, so the path never runs along
    # a ledge and the faces stay whole.
    path_cells = set()
    for pts in lay["paths"]:
        for a, b in zip(pts, pts[1:]):
            path_cells |= set(_route(ch, a, b, pond_cells))
    for c in path_cells:
        for n in _around(c, 1):
            if n not in tower_top:
                mask.discard(n)
    for _ in range(2):
        mask = {c for c in mask if c in tower_top or _thick(mask, c)}
        mask = _drop_small(ch, mask, 12, tower_top)
    for c in ch.cells():
        if c not in ch.locked and ch.land(c):
            ch.height[c] = TERRACE if c in mask else 0
    for c in path_cells:
        if c not in ch.locked and ch.terrain[c] == "golden_plains" and c not in ch.blocked:
            ch.terrain[c] = "dirt_road"

    # 6. Ramps until every cell is reachable with a climb of 1, and back.
    ramps: set = set()
    _ramp_up(ch, ramps, anchors[0])

    tiles = []
    for y in range(ch.h):
        for x in range(ch.w):
            c = (x, y)
            t = ch.terrain[c]
            tiles.append({"x": x, "y": y, "terrain": t, "walkable": t not in ("water", "cliff"), "height": ch.height[c]})
    doc["tiles"] = tiles

    # 7. Dressing.
    reserved = set(ch.blocked) | set(anchors)
    for e in doc["exits"]:
        for link in e["links"]:
            reserved.add((link["from"]["x"], link["from"]["y"]))
    for p in kept_props:
        for f in p["footprint"]:
            reserved |= set(_around((f["x"], f["y"]), 1))
    for a in anchors:
        reserved |= set(_around(a, 1))
    for r in ramps:
        reserved |= set(_around(r, 1))

    def free(c) -> bool:
        if not ch.inside(c) or c in reserved or not ch.walkable(c):
            return False
        x, y = c
        if min(x, y, ch.w - 1 - x, ch.h - 1 - y) <= 1:
            return False
        # One clear cell beside the path and the ponds.
        return not any(ch.terrain[n] in ("dirt_road", "cliff") for n in ch.nbrs(c))

    blockers: set = set()
    trees = []
    # Pines crown the terrace tops: raised cells score highest, most of all
    # on the visible south and east lips. Then clusters in the open.
    seeds = []
    for c in ch.cells():
        if not free(c):
            continue
        score = hash01(c[0], c[1], 3)
        if ch.height[c] >= TERRACE:
            score += 0.6
            if any(ch.inside(n) and ch.height[n] < ch.height[c] for n in ((c[0], c[1] + 1), (c[0] + 1, c[1]))):
                score += 0.4
        seeds.append((-score, c))
    seeds.sort()
    target = lay["pines"]
    for _, c in seeds:
        if len(trees) >= target:
            break
        if c in blockers or not free(c):
            continue
        if any(abs(c[0] - t[0]) + abs(c[1] - t[1]) <= 2 for t in trees):
            continue
        group = [c]
        for k in range(10):
            dx = int(round((hash01(c[0], c[1], 20 + k) - 0.5) * 4.0))
            dy = int(round((hash01(c[0], c[1], 40 + k) - 0.5) * 4.0))
            n = (c[0] + dx, c[1] + dy)
            if n not in group:
                group.append(n)
        size = 3 + int(hash01(c[0], c[1], 9) * 5)
        placed = 0
        for n in group:
            if placed >= size or len(trees) >= target:
                break
            if n in blockers or not free(n) or ch.height[n] != ch.height[c]:
                continue
            if not _all_reach(ch, blockers | {n}, anchors[0]):
                continue
            blockers.add(n)
            trees.append(n)
            placed += 1

    props = list(kept_props)
    for c in sorted(trees):
        props.append(_prop(zone_id, "tree", c))
    doc["props"] = props

    decor = []
    used = set()

    def add(kind: str, c) -> None:
        used.add(c)
        decor.append({"id": f"{zone_id}_decor_{len(decor) + 1:03d}", "type": kind, "x": c[0], "y": c[1]})

    def open_cell(c) -> bool:
        return (
            ch.inside(c) and c not in used and c not in blockers and c not in ch.blocked
            and ch.walkable(c) and not ch.ring(c) and c not in anchors and ch.terrain[c] != "dirt_road"
        )

    # Snow-capped rocks in little groups of two or three.
    rolls = sorted((hash01(c[0], c[1], 5), c) for c in ch.cells() if open_cell(c) and free(c))
    groups = []
    for _, c in rolls:
        if len(groups) >= lay["rocks"]:
            break
        if any(abs(c[0] - g[0]) + abs(c[1] - g[1]) < 7 for g in groups):
            continue
        groups.append(c)
        add("rock_small_d", c)
        for k, step in enumerate(((1, 0), (0, 1), (1, 1))):
            n = (c[0] + step[0], c[1] + step[1])
            if k < 1 + int(hash01(c[0], c[1], 6) * 2) and open_cell(n):
                add("rock_small_c", n)
    # Small firs at the feet of the pines, shrubs and mounds in the open.
    for c in ch.cells():
        if not open_cell(c):
            continue
        r = hash01(c[0], c[1], 11)
        near_tree = any(abs(c[0] - t[0]) <= 1 and abs(c[1] - t[1]) <= 1 for t in trees)
        if near_tree and r < 0.25:
            add("bush_small_a" if hash01(c[0], c[1], 12) < 0.5 else "bush_small_b", c)
        elif r < 0.03:
            add("bush_small_b", c)
        elif r < 0.09:
            add("tuft_a", c)
    doc["decor"] = decor

    _verify(ch, doc, blockers)
    return doc


def _thick(mask: set, c) -> bool:
    x, y = c
    for dx in (-1, 1):
        for dy in (-1, 1):
            if (x + dx, y) in mask and (x, y + dy) in mask and (x + dx, y + dy) in mask:
                return True
    return False


def _prop(zone_id: str, kind: str, c) -> dict:
    return {
        "id": f"{zone_id}_{kind}_{c[0]}_{c[1]}",
        "type": kind,
        "blocks": True,
        "origin": {"x": c[0], "y": c[1]},
        "footprint": [{"x": c[0], "y": c[1]}],
    }


def _drop_small(ch: Chunk, mask: set, limit: int, keep: set) -> set:
    """Raised regions under `limit` cells go; lowered holes under `limit` fill."""
    out = set(mask)
    for want_raised in (True, False):
        seen = set()
        for c in ch.cells():
            if c in seen or not ch.land(c) or (c in out) != want_raised:
                continue
            region = []
            touches_flat = False
            q = deque([c])
            seen.add(c)
            while q:
                cur = q.popleft()
                region.append(cur)
                touches_flat |= cur in ch.flat
                for n in ch.nbrs(cur):
                    if n not in seen and ch.land(n) and (n in out) == want_raised:
                        seen.add(n)
                        q.append(n)
            if len(region) >= limit:
                continue
            if want_raised and not any(r in keep for r in region):
                out -= set(region)
            elif not want_raised and not touches_flat:
                out |= set(region)
    return out


def _route(ch: Chunk, a, b, avoid: set) -> list:
    """A low-effort route between two cells: climbs and turns cost extra, so
    the path runs in long straight stretches that keep to the flats."""
    start, goal = tuple(a), tuple(b)
    first = (start, (0, 0))
    dist = {first: 0.0}
    prev = {}
    heap = [(0.0, first)]
    end = None
    while heap:
        d, state = heapq.heappop(heap)
        c, heading = state
        if c == goal:
            end = state
            break
        if d > dist.get(state, 1e9):
            continue
        for step in ORTHO:
            n = (c[0] + step[0], c[1] + step[1])
            if not ch.inside(n) or n in avoid or not ch.land(n) or n in ch.blocked:
                continue
            if ch.ring(n) and n != goal:
                continue
            cost = 1.0 + 6.0 * abs(ch.height[n] - ch.height[c]) + 0.3 * hash01(n[0], n[1], 17)
            if heading != (0, 0) and step != heading:
                cost += 1.6
            if any(m in avoid for m in ch.nbrs(n)):
                cost += 0.8
            # Keep off the shore line: the path walks inland of the ice rim.
            if any(ch.inside(m) and not ch.land(m) for m in _around(n, 1)):
                cost += 4.0
            nxt = (n, step)
            nd = d + cost
            if nd < dist.get(nxt, 1e9):
                dist[nxt] = nd
                prev[nxt] = state
                heapq.heappush(heap, (nd, nxt))
    if end is None:
        raise SystemExit(f"{ch.id}: no path {a} -> {b}")
    out = [end]
    while out[-1] != first:
        out.append(prev[out[-1]])
    out.reverse()
    return [state[0] for state in out]


def _passable(ch: Chunk, c, blockers: set) -> bool:
    return ch.walkable(c) and c not in blockers and c not in ch.blocked


def _reach(ch: Chunk, blockers: set, start, reverse: bool) -> set:
    """Cells reached from `start` (or that reach it, when `reverse`) climbing at most CLIMB a step."""
    seen = {start}
    q = deque([start])
    while q:
        cur = q.popleft()
        for n in ch.nbrs(cur):
            if n in seen or not _passable(ch, n, blockers):
                continue
            rise = (ch.height[cur] - ch.height[n]) if reverse else (ch.height[n] - ch.height[cur])
            if rise > CLIMB:
                continue
            seen.add(n)
            q.append(n)
    return seen


def _all_reach(ch: Chunk, blockers: set, start) -> bool:
    total = sum(1 for c in ch.cells() if _passable(ch, c, blockers))
    return len(_reach(ch, blockers, start, False)) == total and len(_reach(ch, blockers, start, True)) == total


def _ramp_up(ch: Chunk, ramps: set, start) -> None:
    """Add a ramp (height 1) on each terrace until every cell is reachable and can get back."""
    for _ in range(200):
        there = _reach(ch, set(), start, False)
        back = _reach(ch, set(), start, True)
        lost = [c for c in ch.cells() if _passable(ch, c, set()) and (c not in there or c not in back)]
        if not lost:
            return
        # A raised cell beside the reached ground, on the longest open run of
        # that edge, preferring the south and east lips that face the camera.
        best = None
        for c in lost:
            if ch.height[c] != TERRACE or c in ch.locked:
                continue
            for n in ch.nbrs(c):
                if n in there and n in back and ch.height[n] == 0 and _passable(ch, n, set()):
                    score = hash01(c[0], c[1], 29) + (0.5 if n[0] > c[0] or n[1] > c[1] else 0.0)
                    if best is None or score > best[0]:
                        best = (score, c)
        if best is None:
            raise SystemExit(f"{ch.id}: cannot ramp {lost[:4]}")
        ch.height[best[1]] = RAMP
        ramps.add(best[1])
    raise SystemExit(f"{ch.id}: ramps did not converge")


def _verify(ch: Chunk, doc: dict, blockers: set) -> None:
    spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
    if not _all_reach(ch, blockers, spawn):
        raise SystemExit(f"{ch.id}: some passable cell is cut off with a climb of {CLIMB}")
    for c in ch.locked:
        old = ch.old[c]
        if ch.terrain[c] != old["terrain"] or ch.height[c] != int(old["height"]):
            raise SystemExit(f"{ch.id}: kept cell {c} changed")
    for e in doc["exits"]:
        for link in e["links"]:
            c = (link["from"]["x"], link["from"]["y"])
            if not ch.walkable(c) or c in blockers or c in ch.blocked:
                raise SystemExit(f"{ch.id}: exit cell {c} is not free")
    for p in doc["points_of_interest"]:
        c = (p["x"], p["y"])
        if not ch.walkable(c) or c in blockers:
            raise SystemExit(f"{ch.id}: POI cell {c} is not free")


def ascii_map(doc: dict) -> str:
    w, h = doc["width"], doc["height"]
    g = [[" "] * w for _ in range(h)]
    for t in doc["tiles"]:
        ch = {"water": "~", "cliff": "o", "dirt_road": "="}.get(t["terrain"], ".")
        if t["height"] > 0:
            ch = "/" if t["height"] == RAMP else ("#" if ch == "." else ch)
        g[t["y"]][t["x"]] = ch
    for p in doc["props"]:
        mark = {"tree": "T"}.get(p["type"], "H")
        for f in p["footprint"]:
            g[f["y"]][f["x"]] = mark
    return "\n".join("".join(r) for r in g)


def main() -> None:
    check = "--check" in sys.argv
    for zone_id in LAYOUT:
        doc = build(zone_id)
        if check:
            print(zone_id)
            print(ascii_map(doc))
            continue
        (ZONES / f"{zone_id}.json").write_text(json.dumps(doc, indent=2) + "\n")
        print(f"{zone_id}: {len(doc['props'])} props, {len(doc['decor'])} decor")


if __name__ == "__main__":
    main()
