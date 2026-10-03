#!/usr/bin/env python3
"""Build data/world/missions.json and data/world/task_templates.json.

Story XP is the section 4.7 share of xp_to_next(level_min), stored in the
file: talk-only 15%, reach 25%, dungeon 60%. The example reward_xp of 40 is
not used. Coins are the low end of the section 4.9 band for level_min.
Items stay empty because the reward catalog is not on this branch.

The section 4.5 summary says 18 extra NPCs. The shipped roster has 20, so
this file has 20 side missions (53 with the 33 warden-chain missions).
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

DUNGEON_NAMES = {
    "old_granary_cellar": "Old Granary Cellar",
    "millrace_vaults": "Millrace Vaults",
    "rotting_orchard_barrow": "Rotting Orchard Barrow",
    "frostspire_archive": "Frostspire Archive",
    "saltmaw_grotto": "Saltmaw Grotto",
    "cinderforge_depths": "Cinderforge Depths",
    "sunken_mill": "Sunken Mill",
    "drowned_abbey": "Drowned Abbey",
    "thunderwell_core": "Thunderwell Core",
    "shard_hollow": "Shard Hollow",
    "heart_of_the_blight": "Heart of the Blight",
}

SHORT = {
    "crosshaven_heart": "heart",
    "crosshaven_towns": "towns",
    "rowanvale": "rowanvale",
    "windmere": "windmere",
    "brinewake": "brinewake",
    "slagcrown": "slagcrown",
    "eastmarch_fen_edge": "fen",
    "gloomfen_mire": "gloomfen",
    "stormspire": "stormspire",
    "ashen_shardfields": "ashen",
    "blightwood_hollow": "blightwood",
}

CORE_ROLES = {"warden", "trader", "door_keeper"}

# Town chunks have a town-center point of interest, not a landmark.
TOWN_CENTERS = {
    "crosshaven_northgate": (20, 12, "Northgate square"),
    "crosshaven_stoneford": (16, 16, "Stoneford square"),
    "crosshaven_eastmarch": (16, 16, "Eastmarch square"),
    "crosshaven_westwatch": (16, 10, "Westwatch square"),
    "crosshaven_southbridge": (20, 10, "Southbridge square"),
}


def xp_for(level_min: int, percent: int, steps: list[int]) -> int:
    need = steps[level_min - 1]
    return (need * percent + 50) // 100


def coins_for(level: int) -> int:
    if level <= 10:
        return 20
    if level <= 20:
        return 60
    if level <= 30:
        return 150
    if level <= 40:
        return 300
    return 600


def load_landmarks() -> dict[str, list[dict]]:
    found: dict[str, list[dict]] = {}
    for path in ROOT.rglob("*.json"):
        if "schema" in path.parts:
            continue
        try:
            doc = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        if doc.get("format") != "stasium.zone":
            continue
        chunk = doc["zone_id"]
        for poi in doc.get("points_of_interest", []):
            if poi.get("kind") != "landmark":
                continue
            found.setdefault(chunk, []).append(poi)
    return found


def main() -> None:
    zones = json.loads((ROOT / "level_zones.json").read_text())["zones"]
    npcs = json.loads((ROOT / "npcs.json").read_text())["npcs"]
    steps = json.loads((ROOT / "level_curve.json").read_text())["xp_to_next"]
    landmarks = load_landmarks()
    chunk_zone = {}
    for zone in zones:
        for chunk in zone["chunks"]:
            chunk_zone[chunk] = zone["id"]
    npc_by_id = {row["id"]: row for row in npcs}

    def landmark(chunk: str, landmark_id: str | None = None) -> dict:
        rows = landmarks.get(chunk, [])
        if not rows:
            raise SystemExit(f"no landmark on {chunk}")
        picked = rows[0]
        if landmark_id is not None:
            picked = next(row for row in rows if row["id"] == landmark_id)
        return {
            "type": "reach",
            "zone_id": chunk,
            "landmark": picked["id"],
            "cell": {"x": int(picked["x"]), "y": int(picked["y"])},
            "place": picked["name"],
        }

    def cell_step(chunk: str, x: int, y: int, place: str) -> dict:
        return {
            "type": "reach",
            "zone_id": chunk,
            "cell": {"x": x, "y": y},
            "place": place,
        }

    def talk_step(npc_id: str) -> dict:
        return {
            "type": "talk",
            "npc": npc_id,
            "place": npc_by_id[npc_id]["name"],
        }

    reach_index = []
    for zone in zones:
        for chunk in zone["chunks"]:
            for poi in landmarks.get(chunk, []):
                reach_index.append({
                    "level_zone": zone["id"],
                    "zone_id": chunk,
                    "landmark": poi["id"],
                    "name": poi["name"],
                    "x": int(poi["x"]),
                    "y": int(poi["y"]),
                    "proximity": "landmark",
                })
            if chunk in TOWN_CENTERS:
                x, y, place = TOWN_CENTERS[chunk]
                reach_index.append({
                    "level_zone": zone["id"],
                    "zone_id": chunk,
                    "landmark": chunk + "_square",
                    "name": place,
                    "x": x,
                    "y": y,
                    "proximity": "cell",
                })

    missions = []
    prev_scout = ""
    for zone in zones:
        zid = zone["id"]
        short = SHORT[zid]
        band_min = int(zone["level_min"])
        members = [row for row in npcs if chunk_zone.get(row["zone_id"]) == zid]
        by_role: dict[str, list[dict]] = {}
        for row in members:
            by_role.setdefault(row["role"], []).append(row)
        warden = by_role["warden"][0]
        trader = by_role["trader"][0]
        door = by_role["door_keeper"][0]
        zone_name = zone["name"]
        welcome_name = "Welcome to Crosshaven" if zid == "crosshaven_heart" else f"Welcome to {zone_name}"
        welcome_id = f"{short}_welcome"
        scout_id = f"{short}_scout"
        dungeon_id = f"{short}_dungeon"
        if zid == "crosshaven_heart":
            welcome_id = "heart_welcome"
        requires = [] if prev_scout == "" else [prev_scout]
        missions.append(_mission(
            welcome_id, welcome_name, "story", "welcome", zid, warden["id"], band_min, requires,
            [talk_step(trader["id"]), talk_step(door["id"])], steps,
            f"New face? Meet the trader and the door keeper.",
            "The trader and the door keeper are still waiting.",
            "You met them. I can mark this done.",
            "Good. Now you know who to ask.",
        ))
        scout_steps = _scout_steps(zid, zone["chunks"], landmark, cell_step)
        missions.append(_mission(
            scout_id, f"Scout {zone_name}", "story", "scout", zid, warden["id"], band_min, [welcome_id],
            scout_steps, steps,
            "Walk the marks I named. Learn the ground before you go down.",
            "A mark is still waiting.",
            "You have seen the ground. I can mark this done.",
            "The roads are yours now.",
        ))
        dungeon_name = DUNGEON_NAMES[zone["dungeon"]]
        missions.append(_mission(
            dungeon_id, f"The {dungeon_name}", "story", "dungeon", zid, warden["id"], band_min, [scout_id],
            [{
                "type": "clear_dungeon",
                "dungeon": zone["dungeon"],
                "place": dungeon_name,
            }],
            steps,
            f"Clear {dungeon_name}. The way down is not open yet.",
            f"{dungeon_name} is still ahead.",
            f"You cleared {dungeon_name}.",
            "The cellar can rest.",
        ))
        prev_scout = scout_id

    side_plan = _side_plan(landmark, cell_step, talk_step)
    extras = [row for row in npcs if row["role"] not in CORE_ROLES]
    extra_ids = {row["id"] for row in extras}
    if set(side_plan) != extra_ids:
        missing = extra_ids - set(side_plan)
        extra = set(side_plan) - extra_ids
        raise SystemExit(f"side plan mismatch missing={missing} extra={extra}")
    for row in extras:
        zone_id = chunk_zone[row["zone_id"]]
        zone = next(item for item in zones if item["id"] == zone_id)
        plan = side_plan[row["id"]]
        missions.append(_mission(
            f"{row['id']}_errand",
            plan["name"],
            "side",
            "side",
            zone_id,
            row["id"],
            int(zone["level_min"]),
            [],
            [plan["step"]],
            steps,
            plan["offer"],
            plan["active"],
            plan["ready"],
            plan["done"],
        ))

    doc = {
        "format": "stasium.world_missions",
        "format_version": 1,
        "status": "proposed",
        "notes": [
            "Story XP is the 4.7 share of xp_to_next(level_min): talk-only 15%, reach 25%, dungeon 60%. The numbers are stored. Pace is not applied again.",
            "The sample reward_xp of 40 is not used. Welcome to Crosshaven pays 15, which is 15% of the first curve step.",
            "Coins are the low end of the 4.9 band for level_min. Items are empty until the reward catalog is on this branch.",
            "The 4.5 summary says 18 extra NPCs and about 51 missions. The shipped roster has 20 extras, so this file has 33 chain missions and 20 sides.",
            "Town chunks have no landmark point of interest. Town scouts and some sides use the town-center cell.",
            "The Fisher sends you to the cell beside the Eastmarch fishing hut. The Fen Guide sends you to the Sunken Mill door. The Last Watcher sends you to the Heart of the Blight door.",
            "clear_dungeon steps cannot be accepted until dungeon runs exist. They show as coming soon.",
            "Each zone welcome requires the previous zone's scout, in the level_zones.json order, so the chains open in level order. Fen Edge stays after Slagcrown in that file.",
        ],
        "reach_index": reach_index,
        "missions": missions,
    }
    (ROOT / "missions.json").write_text(json.dumps(doc, indent=2) + "\n")
    templates = {
        "format": "stasium.world_task_templates",
        "format_version": 1,
        "status": "proposed",
        "notes": [
            "Reach tasks are offered now, one at a time, scaled to the hero level.",
            "Defeat stays offer_now false. Monster families are not listed yet, so none are invented.",
            "clear_dungeon stays offer_now false until dungeon runs exist.",
            "Task XP is the 4.8 share of xp_to_next(player level) at turn-in: reach 6%, defeat 10%, clear 30%. Pace is not applied.",
            "Task coins are the low end of the 4.9 band for the hero level. Items stay empty.",
        ],
        "templates": [
            {"id": "reach_landmark", "step": "reach", "offer_now": True, "xp_percent": 6},
            {"id": "defeat_family", "step": "defeat", "offer_now": False, "xp_percent": 10, "family": "Open"},
            {"id": "clear_band_dungeon", "step": "clear_dungeon", "offer_now": False, "xp_percent": 30},
        ],
    }
    (ROOT / "task_templates.json").write_text(json.dumps(templates, indent=2) + "\n")
    print(f"missions {len(missions)} reach_index {len(reach_index)}")


def _scout_steps(zone_id: str, chunks: list[str], landmark, cell_step) -> list[dict]:
    if zone_id == "crosshaven_heart":
        return [
            landmark("crosshaven_road_north"),
            landmark("crosshaven_road_east"),
            landmark("crosshaven_road_south"),
        ]
    if zone_id == "crosshaven_towns":
        return [
            cell_step("crosshaven_northgate", 20, 12, "Northgate square"),
            cell_step("crosshaven_stoneford", 16, 16, "Stoneford square"),
            cell_step("crosshaven_eastmarch", 16, 16, "Eastmarch square"),
        ]
    picked = []
    for chunk in chunks:
        if chunk.endswith("_entry"):
            picked.append(landmark(chunk))
            break
    for chunk in chunks:
        if chunk.endswith("_entry") or chunk.endswith("_door") or chunk.endswith("_hub"):
            continue
        try:
            picked.append(landmark(chunk))
            break
        except SystemExit:
            continue
    for chunk in chunks:
        if chunk.endswith("_door"):
            picked.append(landmark(chunk))
            break
    if len(picked) < 2:
        raise SystemExit(f"{zone_id} scout has {len(picked)} marks")
    return picked[:3]


def _side_plan(landmark, cell_step, talk_step) -> dict[str, dict]:
    def reach(name, step, offer, active, ready, done) -> dict:
        return {
            "name": name,
            "step": step,
            "offer": offer,
            "active": active,
            "ready": ready,
            "done": done,
        }

    return {
        "crossroads_guide": reach(
            "Ask the trader",
            talk_step("crossroads_trader"),
            "The trader knows the roads. Go and speak with them.",
            "The trader is still waiting.",
            "You spoke with the trader.",
            "That is the first friend to make.",
        ),
        "crossroads_herald": reach(
            "The north road",
            landmark("crosshaven_road_north"),
            "Walk the North Road and see the mark.",
            "The North Road mark is still ahead.",
            "You stood at the North Road.",
            "The Koliseo can wait. The road cannot.",
        ),
        "crossroads_banker": reach(
            "The south crossing",
            landmark("crosshaven_road_south"),
            "Walk to the Southbridge crossing.",
            "The crossing is still ahead.",
            "You reached the crossing.",
            "The bank is shut. The road is not.",
        ),
        "northgate_elder": reach(
            "Northgate square",
            cell_step("crosshaven_northgate", 20, 12, "Northgate square"),
            "Stand in Northgate square.",
            "The square is still waiting.",
            "You stood in the square.",
            "Northgate knows your face.",
        ),
        "stoneford_elder": reach(
            "Stoneford square",
            cell_step("crosshaven_stoneford", 16, 16, "Stoneford square"),
            "Stand in Stoneford square.",
            "The square is still waiting.",
            "You stood in the square.",
            "Stoneford knows your face.",
        ),
        "eastmarch_elder": reach(
            "Eastmarch square",
            cell_step("crosshaven_eastmarch", 16, 16, "Eastmarch square"),
            "Stand in Eastmarch square.",
            "The square is still waiting.",
            "You stood in the square.",
            "Eastmarch knows your face.",
        ),
        "westwatch_elder": reach(
            "Westwatch square",
            cell_step("crosshaven_westwatch", 16, 10, "Westwatch square"),
            "Stand in Westwatch square.",
            "The square is still waiting.",
            "You stood in the square.",
            "Westwatch knows your face.",
        ),
        "southbridge_elder": reach(
            "Southbridge square",
            cell_step("crosshaven_southbridge", 20, 10, "Southbridge square"),
            "Stand in Southbridge square.",
            "The square is still waiting.",
            "You stood in the square.",
            "Southbridge knows your face.",
        ),
        "stoneford_smith": reach(
            "The stone ford",
            landmark("crosshaven_road_west"),
            "Walk to the Stone Ford on the west road.",
            "The ford is still ahead.",
            "You reached the ford.",
            "The anvil can wait. You know the ford.",
        ),
        "eastmarch_fisher": reach(
            "Eastmarch docks",
            cell_step("crosshaven_eastmarch", 22, 14, "Eastmarch docks"),
            "Walk to the docks beside the fishing hut.",
            "The docks are still ahead.",
            "You stood at the docks.",
            "The nets can wait. You know the water.",
        ),
        "rowanvale_farmer": reach(
            "The far fields",
            landmark("rowanvale_farmland_3"),
            "Walk the far fields and find the mark.",
            "The far fields are still ahead.",
            "You reached the far fields.",
            "The rows will keep.",
        ),
        "rowanvale_woodcutter": reach(
            "Rowanvale's gate",
            landmark("rowanvale_entry"),
            "Walk back to the Rowanvale entry mark.",
            "The entry mark is still ahead.",
            "You reached the entry.",
            "The timber can wait.",
        ),
        "windmere_archivist": reach(
            "The outer spire",
            landmark("windmere_outer_3"),
            "Walk to the outer spire mark.",
            "The outer mark is still ahead.",
            "You reached the outer spire.",
            "The shelves can wait.",
        ),
        "brinewake_ferry_captain": reach(
            "Brinewake landing",
            landmark("brinewake_entry"),
            "Walk to the Brinewake landing.",
            "The landing is still ahead.",
            "You reached the landing.",
            "The ferry can wait.",
        ),
        "slagcrown_forge_master": reach(
            "The volcanic shelf",
            landmark("slagcrown_volcanic_3"),
            "Walk the volcanic shelf and find the mark.",
            "The shelf is still ahead.",
            "You reached the shelf.",
            "The forge can wait.",
        ),
        "fen_edge_guide": reach(
            "The swamp gate",
            landmark("eastmarch_fen_edge_door"),
            "Walk to the swamp gate at Sunken Mill.",
            "The swamp gate is still ahead.",
            "You reached the swamp gate.",
            "You can find the way back.",
        ),
        "gloomfen_hermit": reach(
            "The long boardwalk",
            landmark("gloomfen_mire_boardwalk_6"),
            "Walk the long boardwalk and find the mark.",
            "The boardwalk is still ahead.",
            "You reached the boardwalk.",
            "The fog did not take you.",
        ),
        "stormspire_coil_engineer": reach(
            "The coil door",
            landmark("stormspire_door"),
            "Walk to the Thunderwell door.",
            "The coil door is still ahead.",
            "You reached the coil door.",
            "The coils can wait.",
        ),
        "ashen_seer": reach(
            "The shard door",
            landmark("ashen_shardfields_door"),
            "Walk to the Shard Hollow door.",
            "The shard door is still ahead.",
            "You reached the shard door.",
            "The vision can wait.",
        ),
        "blightwood_last_watcher": reach(
            "The deepest hollow",
            landmark("blightwood_hollow_door"),
            "Walk to Blightwood's deepest chunk, the Heart of the Blight door.",
            "The deepest door is still ahead.",
            "You reached the deepest door.",
            "You have seen the end of the wood.",
        ),
    }


def _mission(
    mission_id: str,
    name: str,
    kind: str,
    chain: str,
    level_zone: str,
    giver: str,
    level_min: int,
    requires: list[str],
    mission_steps: list[dict],
    curve: list[int],
    offer: str,
    active: str,
    ready: str,
    done: str,
) -> dict:
    percent = 15
    for step in mission_steps:
        if step["type"] == "clear_dungeon":
            percent = 60
            break
        if step["type"] == "reach":
            percent = 25
    return {
        "id": mission_id,
        "name": name,
        "kind": kind,
        "chain": chain,
        "level_zone": level_zone,
        "giver": giver,
        "turn_in": giver,
        "min_level": level_min,
        "requires": requires,
        "steps": mission_steps,
        "rewards": {
            "xp": xp_for(level_min, percent, curve),
            "coins": coins_for(level_min),
            "items": [],
        },
        "lines": {
            "offer": [offer],
            "active": [active],
            "ready": [ready],
            "done": [done],
        },
    }


if __name__ == "__main__":
    main()
