"""Low-poly blockout primitives (boxes, tapered boxes, cylinders, cones). Own code."""
import math
from mathutils import Matrix, Vector


def box(c, s, top_scale=(1.0, 1.0), rot=None):
    """Axis-aligned box centred at c with size s; top face (+Z) scaled by top_scale. Optional 4x4 rot about c."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    v = []
    for z, sc in ((-hz, (1, 1)), (hz, top_scale)):
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            v.append(Vector((x * hx * sc[0], y * hy * sc[1], z)))
    if rot is not None:
        v = [rot.to_3x3() @ p for p in v]
    v = [Vector(c) + p for p in v]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return v, f


def slab(top_c, w_top, w_bot, length, thick):
    """Trapezoid slab hanging from top_c down -Z (cape). Thickness toward -Y."""
    x0, y0, z0 = top_c
    v = []
    for z, w in ((z0, w_top), (z0 - length, w_bot)):
        for x, y in ((-w / 2, y0), (w / 2, y0), (w / 2, y0 - thick), (-w / 2, y0 - thick)):
            v.append(Vector((x0 + x, y, z)))
    # 0-3 top ring, 4-7 bottom ring
    f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return v, f


def cyl(p0, p1, r0, r1, n=8):
    """Cylinder/cone from p0 to p1 (r1 = 0 -> cone)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = d.normalized().to_track_quat('Z', 'Y').to_matrix()
    v, f = [], []
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        v.append(p0 + q @ Vector((r0 * math.cos(a), r0 * math.sin(a), 0)))
    if r1 > 0:
        for i in range(n):
            a = 2 * math.pi * (i + 0.5) / n
            v.append(p1 + q @ Vector((r1 * math.cos(a), r1 * math.sin(a), 0)))
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
        f.append(tuple(range(n - 1, -1, -1)))
        f.append(tuple(range(n, 2 * n)))
    else:
        v.append(p1)
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n))
        f.append(tuple(range(n - 1, -1, -1)))
    return v, f


def merge(parts):
    V, F = [], []
    for v, f in parts:
        o = len(V)
        V += v
        F += [tuple(i + o for i in face) for face in f]
    return V, F


def prism(poly_yz, thick):
    """Flat outline in the YZ plane, extruded along X by +-thick/2 (n-gon caps, concave ok)."""
    n = len(poly_yz)
    v = [Vector((-thick / 2, y, z)) for y, z in poly_yz] + [Vector((thick / 2, y, z)) for y, z in poly_yz]
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, n + i, n + j, j))
    return v, f
