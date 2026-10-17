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
    "wall_h": "walls/wall_h", "wall_diag_se": "walls/wall_diag_se", "wall_diag_ne": "walls/wall_diag_ne",
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
        for k in ("orient", "tile_step_px", "walkable", "layer", "passage", "grate"):
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
    for sub in ("buildings", "props"):
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
            kind = kind_of(stem)
            rec = {k: meta[k] for k in ("foot", "footprint", "blocks", "height_px", "tier", "door_side", "orient", "note") if k in meta}
            rec["file"] = copy(sub + "/" + stem + "_CONCEPTO.png")
            rec["size"] = list(Image.open(os.path.join(out, rec["file"])).size)
            if meta.get("anim"):
                a_ = dict(meta["anim"])
                a_["file"] = copy(sub + "/" + a_["file"])
                rec["anim"] = a_
            kit["pieces"][kind] = rec
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
