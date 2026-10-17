#!/usr/bin/env python3
"""Import a Grok tile-kit group into the game kit (data only).

Copies the group's PNGs from the handoff tilekit folder into
art/world/crosshaven_tiles/kit_a/ (names without _CONCEPTO) and writes
kit_a/kit.json: the group's terrains and pieces from their own JSONs, and
every kind the group does not cover yet from the placeholder kit (so the town
stays complete while the groups land). Run again for each group / v2 drop-in.

Usage: python3 tilekit_import.py <repo root> <handoff tilekit dir>
"""
import json
import os
import shutil
import sys

from PIL import Image

TERRAINS = ["grass", "dirt", "cobble", "plaza", "water"]
# game kind -> kit file stem (walls group)
PIECES = {
    "wall_h": "walls/wall_h", "wall_h_b": "walls/wall_h_b", "wall_h_c": "walls/wall_h_c", "wall_diag_se": "walls/wall_diag_se", "wall_diag_ne": "walls/wall_diag_ne",
    "tower": "walls/tower_round",
    "gate_h": "walls/gate_h", "gate_diag_se": "walls/gate_diag_se", "gate_diag_ne": "walls/gate_diag_ne",
    "tunnel_h": "walls/water_tunnel_h", "tunnel_diag_se": "walls/water_tunnel_diag_se", "tunnel_diag_ne": "walls/water_tunnel_diag_ne",
    "bridge": "ground/bridge_stone", "bridge_wood": "ground/bridge_wood",
}


def clean(name):
    return os.path.basename(name).replace("_CONCEPTO", "")


def main():
    root, src = sys.argv[1], sys.argv[2]
    out = os.path.join(root, "art", "world", "crosshaven_tiles", "kit_a")
    os.makedirs(out, exist_ok=True)
    ph = json.load(open(os.path.join(root, "art", "world", "crosshaven_tiles", "placeholder", "kit.json")))
    kit = {"format": "stasium.tile_kit", "format_version": 1, "name": "Crosshaven kit A (style A)",
           "source": os.path.relpath(src, root) if src.startswith(root) else "docs/pc-map-handoff work/tilekit",
           "tile_px": [128, 64], "hero_px": 156, "autotile": "corner_wang_16",
           "corner_bits": {"N": 1, "E": 2, "S": 4, "W": 8}, "terrains": [], "pieces": {}}

    def copy(rel):
        s = os.path.join(src, rel)
        d = os.path.join(out, clean(rel))
        shutil.copyfile(s, d)
        return clean(rel)

    for prio, t in enumerate(TERRAINS):
        js = os.path.join(src, "ground", "%s_atlas_CONCEPTO.json" % t)
        if not os.path.exists(js):
            pt = next(x for x in ph["terrains"] if x["id"] == t)
            kit["terrains"].append(dict(pt, atlas="../placeholder/" + pt["atlas"], atlas_cols=16))
            continue
        meta = json.load(open(js))
        rec = {"id": t, "priority": prio, "atlas": copy("ground/%s_atlas_CONCEPTO.png" % t), "atlas_cols": 4}
        if meta.get("variants_file"):
            rec["full_variants"] = copy("ground/" + meta["variants_file"])
            rec["variants"] = int(meta.get("variants", 3))
        if meta.get("anim_file"):
            rec["anim"] = copy("ground/" + meta["anim_file"])
            rec["anim_frames"] = int(meta["frames"])
            rec["anim_fps"] = float(meta["fps"])
        kit["terrains"].append(rec)
    for kind, stem in PIECES.items():
        js = os.path.join(src, stem + "_CONCEPTO.json")
        if not os.path.exists(js):
            continue
        meta = json.load(open(js))
        rec = {k: meta[k] for k in ("foot", "footprint", "blocks", "height_px") if k in meta}
        rec["file"] = copy(stem + "_CONCEPTO.png")
        rec["size"] = list(Image.open(os.path.join(out, rec["file"])).size)
        for k in ("orient", "tile_step_px", "walkable", "layer", "passage", "grate", "gatehouse"):
            if k in meta:
                rec[k] = meta[k]
        if meta.get("door"):
            d = dict(meta["door"])
            d["file"] = copy(os.path.join(os.path.dirname(stem), d["file"]))
            rec["door"] = d
        kit["pieces"][kind] = rec
    # groups 2-5: houses, landmarks, workshops, props. Kind names:
    # house_npc_<x>; plot_<tier>; landmark_<x> -> <x>; workshop_mill -> mill;
    # workshop_<x>; props by their own name. A *_glow piece rides on its
    # parent (additive, night only); an "anim" strip JSON (later) animates it.
    def kind_of(stem):
        if stem.startswith("house_player_"):
            return stem.replace("house_player_", "plot_")
        if stem.startswith("landmark_"):
            return stem[len("landmark_"):]
        if stem == "workshop_mill":
            return "mill"
        return stem

    glows = []
    anims = []
    for sub in ("buildings", "props", "nature", "extras"):
        bdir = os.path.join(src, sub)
        if not os.path.isdir(bdir):
            continue
        for f in sorted(os.listdir(bdir)):
            if not f.endswith("_CONCEPTO.json"):
                continue
            meta = json.load(open(os.path.join(bdir, f)))
            stem = f[:-len("_CONCEPTO.json")]
            if meta.get("parent"):
                glows.append((stem, meta, sub))
                continue
            if meta.get("frames") and (stem.endswith("_sway") or stem.endswith("_anim")):
                anims.append((stem, meta, sub))
                continue
            kind = kind_of(stem)
            rec = {k: meta[k] for k in ("foot", "footprint", "blocks", "height_px", "tier", "door_side", "orient", "note") if k in meta}
            rec["file"] = copy(sub + "/" + stem + "_CONCEPTO.png")
            rec["size"] = list(Image.open(os.path.join(out, rec["file"])).size)
            if meta.get("frames") and meta.get("frame_w"):
                # a strip with no still (chimney smoke): it animates itself
                rec["anim"] = {"file": rec["file"], "frames": int(meta["frames"]), "fps": float(meta.get("fps", 8)),
                               "frame_w": int(meta["frame_w"]), "frame_h": int(meta["frame_h"]), "foot": meta["foot"]}
                rec["size"] = [int(meta["frame_w"]), int(meta["frame_h"])]
            if meta.get("anim"):
                a_ = dict(meta["anim"])
                a_["file"] = copy(sub + "/" + a_["file"])
                rec["anim"] = a_
            kit["pieces"][kind] = rec
    import numpy as np

    def base_point(img):
        a = np.asarray(img.convert("RGBA"))[..., 3] > 40
        ys, xs = np.nonzero(a)
        yb = ys.max()
        return float(xs[ys >= yb - 3].mean()), float(yb)

    for stem, meta, sub in anims:
        base = stem[: -len("_sway")] if stem.endswith("_sway") else stem[: -len("_anim")]
        kind = kind_of(base)
        a_ = {"file": copy(sub + "/" + stem + "_CONCEPTO.png"), "frames": int(meta["frames"]), "fps": float(meta.get("fps", 8)),
              "frame_w": int(meta["frame_w"]), "frame_h": int(meta["frame_h"])}
        # the strip's own foot: the still's foot moved by the base point shift
        strip = Image.open(os.path.join(out, a_["file"]))
        f0 = strip.crop((0, 0, a_["frame_w"], a_["frame_h"]))
        if kind in kit["pieces"]:
            still = Image.open(os.path.join(out, kit["pieces"][kind]["file"]))
            bs, bf = base_point(still), base_point(f0)
            fx, fy = kit["pieces"][kind]["foot"]
            a_["foot"] = [round(fx - bs[0] + bf[0], 1), round(fy - bs[1] + bf[1], 1)]
            kit["pieces"][kind]["anim"] = a_
        else:
            rec = {k: meta[k] for k in ("foot", "footprint", "blocks", "height_px", "note") if k in meta}
            a_["foot"] = meta["foot"]
            rec["file"] = a_["file"]
            rec["size"] = [a_["frame_w"], a_["frame_h"]]
            rec["anim"] = a_
            kit["pieces"][kind] = rec
    # ring features: the opaque run along the foot line, and where the
    # opening is (gates: the passage rect; tunnels: the dark grate)
    for kind, rec in kit["pieces"].items():
        if rec.get("placeholder") or not (kind.startswith("gate_") or kind.startswith("tunnel_") or kind.startswith("wall_")):
            continue
        im = np.asarray(Image.open(os.path.join(out, rec["file"])).convert("RGBA")).astype(int)
        a = im[..., 3] > 100
        fy = int(rec["foot"][1])
        # the run's whole opaque width (a sheared diagonal's base band only
        # holds part of it); the soft contact-shadow margin is 50 px each side
        cols = np.where((a.sum(axis=0) > 8))[0]
        rec["opaque_x"] = [int(cols.min()), int(cols.max())]
        if rec.get("passage", {}).get("rect"):
            r_ = rec["passage"]["rect"]
            rec["arch_x"] = round(r_[0] + r_[2] / 2.0, 1)
        elif kind.startswith("tunnel_"):
            lum = im[..., :3].mean(axis=2)
            dark = a & (lum < 70)
            dark[: fy // 3] = False
            ys, xs = np.nonzero(dark)
            rec["arch_x"] = round(float(np.median(xs)), 1) if len(xs) else float(rec["foot"][0])
    # chimney tops on the NPC houses (the highest narrow peak of the roof)
    for kind, rec in kit["pieces"].items():
        if kind.startswith("house_npc_"):
            a = np.asarray(Image.open(os.path.join(out, rec["file"])).convert("RGBA"))[..., 3] > 100
            cols = np.where(a.any(axis=0))[0]
            tops = np.array([np.argmax(a[:, c]) for c in cols])
            i = int(np.argmin(tops))
            rec["chimney"] = [int(cols[i]), int(tops[i]) + 6]
    for stem, meta, sub in glows:
        parent = kind_of(meta["parent"].replace("_CONCEPTO", ""))
        if parent in kit["pieces"]:
            kit["pieces"][parent]["glow"] = {"file": copy(sub + "/" + stem + "_CONCEPTO.png"),
                                             "offset": meta.get("offset_in_parent", [0, 0]),
                                             "blend": meta.get("blend", "add"), "night_only": bool(meta.get("night_only", True))}
    # kinds not in the groups yet: the placeholder boxes
    for kind, rec in ph["pieces"].items():
        if kind not in kit["pieces"]:
            r = dict(rec)
            r["file"] = "../placeholder/" + rec["file"]
            if r.get("door"):
                r["door"] = dict(r["door"], file="../placeholder/" + r["door"]["file"])
            r["placeholder"] = True
            kit["pieces"][kind] = r
    json.dump(kit, open(os.path.join(out, "kit.json"), "w"), indent=1)
    print("kit_a", len(kit["terrains"]), "terrains", len([k for k, v in kit["pieces"].items() if not v.get("placeholder")]),
          "kit pieces", len([k for k, v in kit["pieces"].items() if v.get("placeholder")]), "placeholders")


if __name__ == "__main__":
    main()
