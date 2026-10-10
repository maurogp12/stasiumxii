"""Painted-part 2D rig for the dungeon monsters (same idea as the hero action rigs).

A facing is one approved painting (chroma keyed). Parts are cut from it with
polygons; what a part covered on the body is back-filled with the painting's
own texture (shifted patches, no smooth fill). Each frame poses the parts by
FK rotations/offsets about painted joints, renders at 3x on the cell canvas,
area-downsamples, and cuts binary alpha with RGB 0 under alpha 0.

Angles are degrees, positive = clockwise on screen (y down).
Root offsets dx/dy are in cell pixels.
"""
from __future__ import annotations

import math
import os

import cv2
import numpy as np

import gkit

SS = 3  # render supersample


def rot_about(px, py, deg, sx=1.0, sy=1.0):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    T1 = np.array([[1, 0, -px], [0, 1, -py], [0, 0, 1]], np.float64)
    R = np.array([[c * sx, -s * sy, 0], [s * sx, c * sy, 0], [0, 0, 1]], np.float64)
    T2 = np.array([[1, 0, px], [0, 1, py], [0, 0, 1]], np.float64)
    return T2 @ R @ T1


def trans(dx, dy):
    return np.array([[1, 0, dx], [0, 1, dy], [0, 0, 1]], np.float64)


class Part:
    def __init__(self, name, poly, pivot, parent="body", fill=True, z=0):
        self.name, self.poly, self.pivot, self.parent, self.fill, self.z = name, poly, pivot, parent, fill, z


class Facing:
    """One painted facing, cut into parts."""

    def __init__(self, src, parts, ground, hip, scale, cell, cell_pivot, close_k=41, body_z=0, band_px=36, despill=False):
        rgb = gkit.load_rgb(src)
        self.prem = gkit.clean_alpha(gkit.key_auto(rgb), min_island=150)
        if despill:
            self.prem = gkit.despill_magenta(self.prem)
        self.parts = parts
        self.ground = np.array(ground, np.float64)
        self.hip = np.array(hip, np.float64)
        self.scale = scale
        self.cell = cell
        self.cell_pivot = cell_pivot
        self.body_z = body_z
        H, W = self.prem.shape[:2]
        solid = self.prem[..., 3] > 0.5
        self.layers = {}
        taken = np.zeros((H, W), bool)
        fillmask = np.zeros((H, W), bool)
        for p in parts:
            m = np.zeros((H, W), np.uint8)
            cv2.fillPoly(m, [np.array(p.poly, np.int32)], 1)
            m = (m > 0) & solid & ~taken
            taken |= m
            lay = np.zeros_like(self.prem)
            lay[m] = self.prem[m]
            self.layers[p.name] = lay
            if p.fill:
                fillmask |= m
        body = self.prem.copy()
        body[taken] = 0
        # Stray body bits cut off from the main body go to the nearest part.
        bsol = body[..., 3] > 0.5
        n, lab, st, _ = cv2.connectedComponentsWithStats(bsol.astype(np.uint8), 8)
        if n > 2:
            main = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
            dist = {}
            for p in parts:
                pm = (self.layers[p.name][..., 3] > 0.5).astype(np.uint8)
                if pm.any():
                    dist[p.name] = cv2.distanceTransform(1 - pm, cv2.DIST_L2, 3)
            for i in range(1, n):
                if i == main:
                    continue
                if st[i, cv2.CC_STAT_AREA] > 1500:
                    continue
                m = lab == i
                y, x = np.argwhere(m)[0]
                best = min(dist, key=lambda k: dist[k][y, x]) if dist else None
                if best is not None and dist[best][y, x] < 60:
                    self.layers[best][m] = self.prem[m]
                    body[m] = 0
                    if [p for p in parts if p.name == best][0].fill:
                        fillmask |= m
        bsol = body[..., 3] > 0.5
        closed = cv2.morphologyEx(bsol.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((close_k, close_k), np.uint8)) > 0
        band = cv2.dilate(bsol.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * band_px + 1, 2 * band_px + 1))) > 0
        from scipy.ndimage import binary_fill_holes
        enclosed = binary_fill_holes(bsol)
        hole = fillmask & (closed | band | enclosed) & ~bsol
        filled = patch_fill(body, hole)
        fs = (filled[..., 3] > 0.5).astype(np.uint8)
        n, lab, st, _ = cv2.connectedComponentsWithStats(fs, 8)
        if n > 2:
            main = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
            filled[(lab != main) & (lab > 0) & hole] = 0
        self.layers["body"] = filled
        self.hole_px = int(hole.sum())

    def matrices(self, pose):
        """Pose dict -> {layer: 3x3 source->source matrix}."""
        g = self.ground
        s = self.scale
        root = trans(pose.get("dx", 0.0) / s, pose.get("dy", 0.0) / s)
        rc = pose.get("rot_c")  # optional rotation centre (source px) for the root
        cx, cy = (rc if rc is not None else g)
        root = root @ rot_about(cx, cy, pose.get("rot", 0.0), pose.get("sx", 1.0), pose.get("sy", 1.0))
        if pose.get("flip"):
            root = root @ rot_about(cx, cy, 0.0, 1.0, -1.0)
        mats = {"root": root}
        mats["body"] = root @ rot_about(self.hip[0], self.hip[1], pose.get("body", 0.0),
                                       pose.get("body_sx", 1.0), pose.get("body_sy", 1.0))
        todo = list(self.parts)
        while todo:
            p = next(q for q in todo if q.parent in mats)
            todo.remove(p)
            par = mats[p.parent]
            off = trans(pose.get(p.name + ".dx", 0.0) / s, pose.get(p.name + ".dy", 0.0) / s)
            # Offsets are screen-space: apply them outside the parent's rotation.
            mats[p.name] = off @ par @ rot_about(p.pivot[0], p.pivot[1], pose.get(p.name, 0.0))
        return mats

    def point(self, pose, part, xy):
        """Where source pixel `xy` of `part` lands in the cell for this pose (before keep-in shifts)."""
        k = self.scale
        K = np.array([[k, 0, self.cell_pivot[0] - k * self.ground[0]],
                      [0, k, self.cell_pivot[1] - k * self.ground[1]], [0, 0, 1]], np.float64)
        p = K @ self.matrices(pose)[part] @ np.array([xy[0], xy[1], 1.0])
        return float(p[0]), float(p[1])

    def render(self, pose, order=None):
        W, H = self.cell
        k = self.scale * SS
        K = np.array([[k, 0, self.cell_pivot[0] * SS - k * self.ground[0]],
                      [0, k, self.cell_pivot[1] * SS - k * self.ground[1]],
                      [0, 0, 1]], np.float64)
        mats = self.matrices(pose)
        if order is None:
            order = sorted(["body"] + [p.name for p in self.parts],
                           key=lambda n: self.body_z if n == "body" else [p for p in self.parts if p.name == n][0].z)
        pad = 480
        can = np.zeros((H * SS + 2 * pad, W * SS + 2 * pad, 4), np.float32)
        P = trans(pad, pad)
        for name in order:
            if pose.get(name + ".hide"):  # optional: a part not drawn on this frame (a thrown weapon after release)
                continue
            M = (P @ K @ mats[name])[:2]
            lay = self.layers[name]
            out = cv2.warpAffine(lay, M, (can.shape[1], can.shape[0]), flags=cv2.INTER_LINEAR,
                                 borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            a = out[..., 3:4]
            can = out + can * (1.0 - a)
        solid = can[..., 3] > 0.5
        ys, xs = np.nonzero(solid)
        m = 2 * SS
        oy = ox = 0
        if len(ys):
            if ys.max() > pad + H * SS - m:
                oy = ys.max() - (pad + H * SS - m)
            if ys.min() < pad + m:
                oy = min(oy, ys.min() - (pad + m)) if oy == 0 else oy
            if xs.max() > pad + W * SS - m:
                ox = xs.max() - (pad + W * SS - m)
            if xs.min() < pad + m:
                ox = xs.min() - (pad + m)
        ox, oy = int(np.clip(ox, -pad, pad)), int(np.clip(oy, -pad, pad))
        self.last_shift = (-ox / SS, -oy / SS)
        inner = np.zeros_like(solid)
        inner[pad + oy:pad + oy + H * SS, pad + ox:pad + ox + W * SS] = True
        lost_px = int((solid & ~inner).sum())
        can = can[pad + oy:pad + oy + H * SS, pad + ox:pad + ox + W * SS]
        small = cv2.resize(can, (W, H), interpolation=cv2.INTER_AREA)
        im = gkit.binarize(small)
        im = fill_specks(im)
        return im, lost_px // (SS * SS)


def patch_fill(layer, hole, max_off=320):
    """Fill `hole` pixels with the layer's own texture copied from shifted patches."""
    out = layer.copy()
    todo = hole.copy()
    if not todo.any():
        return out
    src_ok = (layer[..., 3] > 0.99) & ~hole
    offs = []
    for r in range(12, max_off + 1, 8):
        for ang in range(0, 360, 30):
            a = math.radians(ang)
            offs.append((int(round(r * math.cos(a))), int(round(r * math.sin(a)))))
    H, W = hole.shape
    for _ in range(10):
        if not todo.any():
            break
        best = []
        for dx, dy in offs:
            M = np.float32([[1, 0, dx], [0, 1, dy]])
            ok = cv2.warpAffine(src_ok.astype(np.uint8), M, (W, H), flags=cv2.INTER_NEAREST) > 0
            best.append(((ok & todo).sum(), dx, dy, ok))
        best.sort(key=lambda t: -t[0])
        for cnt, dx, dy, ok in best:
            if cnt == 0:
                break
            sel = ok & todo
            if not sel.any():
                continue
            M = np.float32([[1, 0, dx], [0, 1, dy]])
            sh = cv2.warpAffine(layer, M, (W, H), flags=cv2.INTER_NEAREST)
            out[sel] = sh[sel]
            todo &= ~sel
            if not todo.any():
                break
    return out


def fill_specks(im, max_area=12):
    a = (im[..., 3] == 0).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(a, 4)
    if n <= 2:
        return im
    blur = cv2.blur(im.astype(np.float32), (3, 3))
    wa = np.maximum(blur[..., 3:4] / 255.0, 1e-3)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] <= max_area:
            x, y, w, h = st[i, :4]
            if x == 0 or y == 0 or x + w >= im.shape[1] or y + h >= im.shape[0]:
                continue
            m = lab == i
            col = np.clip(blur[..., :3][m] / wa[m], 0, 255)
            im[m, :3] = col.astype(np.uint8)
            im[m, 3] = 255
    return im


# ------------------------------------------------------------- pose helpers

def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


ONE = {"sx", "sy", "body_sx", "body_sy"}


def keys(frames, keyframes):
    """keyframes: list of (frame_index, {param: value}). Returns list of pose dicts (smoothstep blend)."""
    names = set()
    for _, d in keyframes:
        names |= set(d)
    out = []
    for f in range(frames):
        pose = {}
        for n in names:
            pts = [(i, d.get(n, 1.0 if n in ONE else 0.0)) for i, d in keyframes]
            if f <= pts[0][0]:
                v = pts[0][1]
            elif f >= pts[-1][0]:
                v = pts[-1][1]
            else:
                for (i0, v0), (i1, v1) in zip(pts, pts[1:]):
                    if i0 <= f <= i1:
                        v = v0 + (v1 - v0) * smooth((f - i0) / float(i1 - i0))
                        break
            pose[n] = v
        out.append(pose)
    return out


def add(poses, extra):
    """Add per-frame dicts of extra values onto poses (summing)."""
    for p, e in zip(poses, extra):
        for k, v in e.items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                p[k] = p.get(k, 0.0) + v
            else:
                p[k] = v
    return poses
