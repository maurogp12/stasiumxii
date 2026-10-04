"""Write per-character wiring json (verified values) -> ship/characters_pc/json/<char>.json
pivot      = value to use (verified / corrected from check_chars.py measurements)
pivot_file = value stated in README / status PDF
Facings use the LOCKED art rule: S=front down-right, W=front down-left, N=back up-left, E=back up-right.
"""
import json, math, os, sys
sys.argv = ['x']
import check_chars as C
from check_chars import load, mask, bbox
OUT = "/workspace/stasium-pc-look/ship/characters_pc/json"
LOOP = {"walk": True, "idle": True}
# corrections: (char, state or '*', facing) -> pivot y to use
FIX_Y = {
  "ironjaw": {},   # v3: pivot y already on the soles (140 = v2 133 + 5 + 2 px top pad); file values used
  "kestrel": {("walk", "S"): 145},
  "gloam":   {("*", f): (151 if f in "SW" else 143) for f in "SWNE"},
  "bastion": {(s, f): y for s in ("idle", "attack", "hit", "death") for f, y in (("S", 166), ("W", 177), ("N", 180), ("E", 175))},
  "mender":  {**{(s, f): 168 for s in ("idle", "hit", "death") for f in "SW"}, **{("cast", f): 189 for f in "SW"}},
}
MIRROR = {  # facing -> facing it is a pixel-identical flip of (about the pivot)
  "ironjaw": {"W": "S", "N": "E"}, "gloam": {"W": "S", "E": "N"}, "mender": {"W": "S", "N": "E"},
  "kestrel": {}, "bastion": {},
}
TRAVEL = {  # cell px per 12-frame walk cycle, along the iso diagonal the walk is drawn on
  "ironjaw": dict(S=89.2, W=89.2, N=89.2, E=89.2),
  "kestrel": dict(S=129.0, W=128.9, N=128.9, E=128.9),
  "gloam":   dict(S=52.1, W=52.1, N=46.8, E=46.8),
  "bastion": dict(S=125.06, W=115.0, N=115.0, E=115.0),
  "mender":  dict(S=128.0, W=128.0, N=105.8, E=105.8),
}
# Class size tiers (Luca, 2026-10-03): on-board figure height of idle S f0 (opaque bbox x draw scale).
# Big: Ironjaw, Bastion ~78 px. Small: Kestrel, Gloam, Mender ~66 px. No resampling: the engine scales the sprite.
TIER = {"ironjaw": ("big", 78), "bastion": ("big", 78), "kestrel": ("small", 66), "gloam": ("small", 66), "mender": ("small", 66)}
STANCE_HEIGHT = {"ironjaw"}     # height = head top to min(sole, pivot): stride toe below the pivot not counted
WORLD_RATIO = 0.46 / 0.5          # world walker vs combat pawn, as before (0.46 / 0.5)
# Walk timing (Ironjaw v3.2): feet stick when walk frames advance at the rate the board moves the pawn.
# One combat move = one cell along the 2:1 diagonal of a 64x32 tile = hypot(32, 16) = 35.78 board px (board/tile.gd).
# The repo moves pawns one cell per WALK_TILE_SEC = 0.22 s (units/pawn.gd).
WALK_TIMING = {"ironjaw"}
CELL_STEP_BOARD_PX = math.hypot(32, 16); REPO_WALK_TILE_SEC = 0.22; AUTHORED_WALK_FPS = 1000/58.33
def walk_timing(n, ds):
    per_frame = min(TRAVEL[n].values())/12*ds              # board px per walk frame at the shipped draw_scale
    fpc = CELL_STEP_BOARD_PX/per_frame                      # walk frames per cell
    return {"walk_fps": round(AUTHORED_WALK_FPS, 3), "recommended_tile_sec": round(fpc/AUTHORED_WALK_FPS, 3),
            "walk_fps_if_tile_sec_0_22": round(fpc/REPO_WALK_TILE_SEC, 1),
            "frames_per_cell": round(fpc, 2), "cell_step_board_px": round(CELL_STEP_BOARD_PX, 2),
            "timing_note": "feet stick when walk_fps x board_px_per_frame_at_draw_scale = board speed. Recommended: keep the authored "
                           "walk_fps and move one cell per recommended_tile_sec (draw_scale %.3f). If WALK_TILE_SEC stays 0.22 s, the legs "
                           "need walk_fps_if_tile_sec_0_22 (%.1fx the authored cadence) to stick; with distance-driven frames that is "
                           "what they will run at." % (ds, (fpc/REPO_WALK_TILE_SEC)/AUTHORED_WALK_FPS)}
HP_CLEAR = 8                      # HEAD_HP_Y = -(head top above the feet at draw scale + 8 px)
STATUS = {"ironjaw": "v3.2 = movement fix of v3.1 (approved look, no pixel edits): walk N/E re-phased to start on the idle stance boot (f00 = v3.1 f03); v3.1: idle S/W stance = walk S f00 stride; v3: cells padded, pivot on the soles", "kestrel": "approved v3", "gloam": "v4 awaiting Mauro",
          "bastion": "v4 fixes in progress", "mender": "v3 fixes in progress"}
for n, cfg in C.CLAIM.items():
    fx = FIX_Y[n]; states = {}
    for st, (cnt, fps, cell, piv) in cfg["states"].items():
        fac = {}
        for f in C.FACINGS:
            px, py = piv[f]
            y = fx.get((st, f), fx.get(("*", f), py))
            fac[f] = {"pivot": [px, y], "offset": [-px, -y], "pivot_file": [px, py],
                      "frames": f"{cfg['dir']}/{st}/{n}_{st}_{f}_fNN.png"}
            if f in MIRROR[n]: fac[f]["baked_flip_of"] = MIRROR[n][f]
        states[st] = {"frames": cnt, "fps": round(1000/58.33, 3) if st == "walk" else fps, "loop": LOOP.get(st, False),
                      "cell": list(cell), "facings": fac}
    # measured idle f0 heights (cell px) and head top above the pivot actually used
    hts = {}; head = {}
    for f in C.FACINGS:
        b = bbox(mask(load(f"/workspace/art/{cfg['dir']}/idle/{n}_idle_{f}_f00.png")))
        py_ = states["idle"]["facings"][f]["pivot"][1]
        # Ironjaw v3.1: idle S/W stands in the walk stride (front toe 12 px below the feet line); measure the figure
        # height to the feet line (min(sole, pivot)) so a stance change does not rescale the class (approved size kept)
        sole = min(b[3], py_) if n in STANCE_HEIGHT else b[3]
        hts[f] = sole - b[1] + 1; head[f] = py_ - b[1]
    tier, target = TIER[n]
    ds = target / hts["S"]
    d = {"char": n, "status": STATUS[n], "source": f"/workspace/art/{cfg['dir']}",
         "facing_rule": "S=front down-right, W=front down-left, N=back up-left, E=back up-right (locked)",
         "combat_code_letter_from_art": {"e": "S", "s": "W", "n": "E", "w": "N"},
         "size_tier": tier, "target_board_height_px": target,
         "idle_f0_height_cell_px": hts,
         "draw_scale": round(ds, 3),
         "world_draw_scale": round(ds * WORLD_RATIO, 3),
         "board_height_px": {f: round(h * ds, 1) for f, h in hts.items()},
         "head_hp_y": -(math.ceil(max(head.values()) * ds) + HP_CLEAR),
         "draw_scale_note": "per class (size tiers): sprite scale = draw_scale in combat, world_draw_scale for the world walker (= draw_scale x 0.46/0.5). head_hp_y = -(tallest idle f0 head top above the feet x draw_scale + 8), node origin = feet.",
         "walk": {"advance": "by distance", "travel_diag_cell_px_per_cycle": TRAVEL[n],
                  "board_px_per_frame_at_draw_scale": {k: round(v/12*ds, 3) for k, v in TRAVEL[n].items()}},
         "states": states}
    if n in WALK_TIMING:   # recommended walk timing so the planted foot sticks at the shipped draw_scale (Ironjaw v3.2)
        d["walk"].update(walk_timing(n, d["draw_scale"]))
    if n == "gloam": d["walk"]["per_frame_rootmotion"] = f"/workspace/art/{cfg['dir']}/gloam_full_v4_rootmotion.json"
    if n == "bastion": d["note"] = "pack from frame PNGs; strips/bastion_attack_S_strip.png and bastion_hit_S_strip.png are stale renders"
    json.dump(d, open(f"{OUT}/{n}.json", "w"), indent=1)
    print("wrote", f"{OUT}/{n}.json")
