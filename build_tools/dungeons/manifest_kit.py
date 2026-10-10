"""Shared helpers for the dungeon art manifests (format stasium.dungeon_art v1):
file listing with sizes, monster entries from each meta.json, and the check that
every PNG on disk (outside _mock/) is listed.
"""
import glob
import json
import os

from PIL import Image

import gkit

GREEN_GLOW = "green emissive cracks/sludge bloomed + faint aura"


class Manifest:
    def __init__(self):
        self.root = gkit.OUT
        self.files = []

    def size(self, rel):
        with Image.open(os.path.join(self.root, rel)) as im:
            return list(im.size)

    def add(self, path, kind, **kw):
        e = {"path": path, "kind": kind, "size": self.size(path)}
        e.update(kw)
        self.files.append(e)

    def mm_dir(self, mid):
        for d in ("monsters/" + mid, "star5/monsters/" + mid):
            if os.path.exists(os.path.join(self.root, d, "meta.json")):
                return d
        raise FileNotFoundError(mid)

    def monster(self, mid, glow_what=GREEN_GLOW):
        mm = json.load(open(os.path.join(self.root, self.mm_dir(mid), "meta.json")))
        d = mm.get("dir", "monsters/" + mid)
        acts = {}
        for act, a in mm["actions"].items():
            acts[act] = {"frames": a["frames"], "loop": a["loop"], "fps": mm["fps"],
                         "duration_s": round(a["frames"] / mm["fps"], 3),
                         "pattern": "%s/%s/%s_{S,E}_f{00..%02d}.png" % (d, act, act, a["frames"] - 1)}
            if a.get("glow_files"):
                acts[act]["glow_pattern"] = "%s/%s/%s_{S,E}_f{00..%02d}_glow.png" % (d, act, act, a["frames"] - 1)
            for f in ("S", "E"):
                for i in range(a["frames"]):
                    p = "%s/%s/%s_%s_f%02d.png" % (d, act, act, f, i)
                    self.files.append({"path": p, "kind": "monster_frame", "size": mm["cell"], "pivot": mm["pivot"],
                                       "monster": mid, "action": act, "facing": f, "frame": i, "frames": a["frames"], "fps": mm["fps"]})
                    if a.get("glow_files"):
                        self.files.append({"path": p[:-4] + "_glow.png", "kind": "monster_glow_frame", "blend": "add", "size": mm["cell"],
                                           "pivot": mm["pivot"], "monster": mid, "action": act, "facing": f, "frame": i,
                                           "frames": a["frames"], "fps": mm["fps"], "for": p})
        e = {"id": mid, "name": mm["name"], "dir": d, "cell": mm["cell"], "pivot": mm["pivot"], "fps": mm["fps"],
             "facings": {"S": "front, facing screen down-right", "E": "back, facing screen up-right",
                         "mirrors": "the other two facings are game-side flip_h mirrors, as for the heroes: S flipped = front facing down-left, E flipped = back facing up-left"},
             "actions": acts, "qa": mm["qa"]}
        if mm.get("release"):
            e["release"] = mm["release"]
            e["release"]["note"] = ("spawn the projectile on this attack frame at point_px (cell pixels, same space as the pivot; "
                                    "mirror x about the cell centre for the mirrored facings)")
        if mm.get("star5"):
            e["star"] = 5
            e["replaces"] = mm.get("base_of")
            e["glow"] = ("every frame has a same-size additive light map <frame>_glow.png (%s): " % glow_what
                         + "draw it as a child of the same sprite, same offset/scale/flip, CanvasItemMaterial BLEND_MODE_ADD; it is black (adds nothing) elsewhere")
        if mm.get("role"):
            e["role"] = mm["role"]
        if mm.get("signature"):
            e["signature"] = mm["signature"]
        return e

    def check(self):
        listed = {f["path"] for f in self.files}
        on_disk = {os.path.relpath(p, self.root) for p in glob.glob(os.path.join(self.root, "**", "*.png"), recursive=True)
                   if "/_mock/" not in p and not os.path.relpath(p, self.root).startswith("_mock")}
        missing = sorted(on_disk - listed)
        extra = sorted(listed - on_disk)
        print("files", len(self.files), "missing", missing[:5], len(missing), "extra", extra[:5])
        return missing, extra
