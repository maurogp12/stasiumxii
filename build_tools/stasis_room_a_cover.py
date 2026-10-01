# Room A cover (Mauro 30 Sep 2026: Room A maps were almost open; he picked
# option C "4 ruin pillars + 2 bushes" from the examples). Each door's Room A
# gets 4 tall pillars round the middle and 2 smaller cover pieces, from its
# own biome props. All block walking and line of sight. Run once, then
# fix_stasis_paths.py to confirm every tile and spawn stays reachable.
# Run: python3 build_tools/stasis_room_a_cover.py
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
COVER = {
    "crosshaven": {"ruins": [(5, 4), (9, 4), (4, 9), (9, 9)], "rubble": [(8, 7), (6, 7)]},
    "windmere": {"crystal": [(5, 4), (11, 5), (3, 9), (10, 9)], "ice_shard": [(7, 6), (8, 8)]},
    "slagcrown": {"basalt_pillar": [(5, 4), (10, 4), (4, 10), (9, 11)], "ash_rock": [(7, 6), (7, 10)]},
    "stormspire": {"rock_pillar": [(4, 5), (11, 4), (4, 10), (8, 11)], "arc": [(7, 3), (10, 6)]},
}

for biome, props in COVER.items():
    path = os.path.join(ROOT, "art", "maps", "stasis_v1", f"{biome}_room_a_15x15_tags.json")
    d = json.load(open(path))
    cells = {(c["x"], c["y"]): c for c in d["cells"]}
    spawns = {tuple(s) for s in d["spawns"]}
    for prop, spots in props.items():
        for p in spots:
            c = cells[p]
            assert c["terrain"] == "ground" and p not in spawns, (biome, p, c)
            if prop not in c.get("paint_only", []):
                c["paint_only"] = [prop]
    json.dump(d, open(path, "w"), indent=2, ensure_ascii=True)
    open(path, "a").write("\n")
    print(biome, sum(len(v) for v in props.values()), "cover pieces")
