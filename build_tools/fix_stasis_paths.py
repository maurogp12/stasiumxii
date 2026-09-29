# Make every Stasis room fully walkable-connected (Mauro 29 Sep 2026: "make
# sure every room has access or a clear path").
# Rules mirrored from the sim: voluntary walks refuse mud / water / lava and
# solid props (CellTagMap.BLOCKING_PROPS); climb max 1, drop max 2. A room is
# fixed when every standable cell and every spawn is reachable from the player
# spawn and back (steps of at most 1 level). Each cut-off area gets the cheapest
# crossing from the main area: water / mud tiles on the way become ground
# (a ford / plank bridge on the map) and too-steep steps get a ramp. Lava and
# solid props are never changed.
# Run: python3 build_tools/fix_stasis_paths.py   (edits art/maps/stasis_v1/*.json)
import glob, heapq, json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLOCKING = {"arc", "ash_rock", "basalt_pillar", "fence", "rock_cluster", "rock_pillar", "well"}
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def load(path):
    d = json.load(open(path))
    cells = {(c["x"], c["y"]): c for c in d["cells"]}
    return d, cells


def standable(c):
    return c["terrain"] == "ground" and not (set(c.get("paint_only", [])) & BLOCKING)


def region(cells, start):
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        e = cells[(x, y)]["elevation"]
        for dx, dy in DIRS:
            n = (x + dx, y + dy)
            if n in cells and n not in seen and standable(cells[n]) and abs(cells[n]["elevation"] - e) <= 1:
                seen.add(n)
                stack.append(n)
    return seen


def bridge(cells, main, targets):
    # Dijkstra from the main area; stepping onto a cell that must change costs 1.
    dist, prev, elev = {}, {}, {}
    heap = []
    for p in main:
        dist[p] = 0
        elev[p] = cells[p]["elevation"]
        heapq.heappush(heap, (0, p))
    while heap:
        d, p = heapq.heappop(heap)
        if d > dist[p]:
            continue
        if p in targets and p not in main:
            break
        e = elev[p]
        for dx, dy in DIRS:
            n = (p[0] + dx, p[1] + dy)
            if n not in cells:
                continue
            c = cells[n]
            if c["terrain"] == "lava" or set(c.get("paint_only", [])) & BLOCKING:
                continue
            if standable(c) and abs(c["elevation"] - e) <= 1:
                cost, ne = 0, c["elevation"]
            else:
                cost, ne = 1, max(e - 1, min(c["elevation"], e + 1)) if c["terrain"] == "ground" else e
            nd = d + cost
            if nd < dist.get(n, 1 << 30):
                dist[n], prev[n], elev[n] = nd, p, ne
                heapq.heappush(heap, (nd, n))
    goal = min((t for t in targets if t in dist), key=lambda t: dist[t], default=None)
    changed = []
    p = goal
    while p is not None and p not in main:
        c = cells[p]
        if not (standable(c) and c["elevation"] == elev[p]):
            changed.append((p, c["terrain"], c["elevation"], elev[p]))
            c["terrain"] = "ground"
            c["elevation"] = elev[p]
        p = prev.get(p)
    return changed


def fix(path):
    d, cells = load(path)
    spawn = tuple(d["spawns"][0])
    log = []
    for _ in range(40):
        main = region(cells, spawn)
        lost = {p for p, c in cells.items() if standable(c) and p not in main}
        lost |= {tuple(s) for s in d["spawns"] if tuple(s) not in main}
        if not lost:
            break
        log += bridge(cells, main, lost)
    json.dump(d, open(path, "w"), indent=2, ensure_ascii=True)
    open(path, "a").write("\n")
    return log


if __name__ == "__main__":
    for f in sorted(glob.glob(os.path.join(ROOT, "art", "maps", "stasis_v1", "*_tags.json"))):
        log = fix(f)
        print(os.path.basename(f), "changed", len(log), [(p, t, "z%d->z%d" % (a, b)) for p, t, a, b in log])
