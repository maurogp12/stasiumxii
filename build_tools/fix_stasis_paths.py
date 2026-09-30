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
# Max extra steps a single mud / water tile may force (Stasis walks are 3 MP).
DETOUR_LIMIT = 6


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


def walk_dist(cells, start):
    # MP to walk from start: 1 per step, +1 per level climbed (as the sim).
    dist = {start: 0}
    heap = [(0, start)]
    while heap:
        d, p = heapq.heappop(heap)
        if d > dist[p]:
            continue
        e = cells[p]["elevation"]
        for dx, dy in DIRS:
            n = (p[0] + dx, p[1] + dy)
            if n not in cells or not standable(cells[n]) or abs(cells[n]["elevation"] - e) > 1:
                continue
            nd = d + 1 + max(0, cells[n]["elevation"] - e)
            if nd < dist.get(n, 1 << 30):
                dist[n] = nd
                heapq.heappush(heap, (nd, n))
    return dist


def worst_wall_cell(cells):
    # A mud / water cell with walkable ground on two opposite sides whose walk
    # around is long. Returns (detour, cell) for the worst one.
    best = (0, None)
    for p, c in cells.items():
        if c["terrain"] not in ("mud", "water") or set(c.get("paint_only", [])) & BLOCKING:
            continue
        for dx, dy in ((1, 0), (0, 1)):
            a, b = (p[0] - dx, p[1] - dy), (p[0] + dx, p[1] + dy)
            if a not in cells or b not in cells or not standable(cells[a]) or not standable(cells[b]):
                continue
            ea, eb = cells[a]["elevation"], cells[b]["elevation"]
            if abs(ea - eb) > 2:
                continue
            d = walk_dist(cells, a).get(b, 99)
            if d - 2 > best[0]:
                best = (d - 2, p, max(min(ea, eb), max(ea, eb) - 1))
    return best


def open_walls(cells, limit):
    # Mauro 29 Sep 2026 ("still having issues with maps"): long mud / water
    # walls forced big walks around. Open a ford in the worst wall until no
    # single wet tile costs more than `limit` extra steps to walk around.
    log = []
    for _ in range(40):
        found = worst_wall_cell(cells)
        if found[0] <= limit:
            break
        _, p, z = found
        c = cells[p]
        log.append((p, c["terrain"], c["elevation"], z))
        c["terrain"] = "ground"
        c["elevation"] = z
    return log


def fix(path, limit=DETOUR_LIMIT):
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
    log += open_walls(cells, limit)
    json.dump(d, open(path, "w"), indent=2, ensure_ascii=True)
    open(path, "a").write("\n")
    return log


if __name__ == "__main__":
    for f in sorted(glob.glob(os.path.join(ROOT, "art", "maps", "stasis_v1", "*_tags.json"))):
        log = fix(f)
        print(os.path.basename(f), "changed", len(log), [(p, t, "z%d->z%d" % (a, b)) for p, t, a, b in log])
