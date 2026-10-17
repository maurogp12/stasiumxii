# Stasium XII: "super game" vision (draft 1)

Mauro, 17 Oct 2026: take the **look** of Baldur's Gate 3 and Wartales, add **Dofus PvP** and **Wakfu dungeons**, keep the best systems from BG3 and Wartales, and mix them into one game.

Everything is original: we take ideas and feel, never assets, names, characters or text from Larian, Shiro Games or Ankama.

---

## 1. The one-line pitch

A **gritty, cinematic medieval fantasy MMO-RPG**. You lead a **mercenary company** across a living world:
- you fight in **deep turn-based tactics**;
- you raid **mechanic-heavy dungeons** with friends;
- you settle scores in **ranked arenas and territory wars**;
- every choice in a conversation can change your company's story.

## 2. What we take from each game

| From | We take | How it shows up in Stasium |
|---|---|---|
| **Wartales**: look | Grounded, earthy, low-fantasy medieval; muted palette; real proportions; a top-down tactical camera | Overall art direction for the world, armour, towns and camps |
| **Wartales**: systems | The **company** (not a chosen hero): wages, food, morale, injuries; **camp** with professions (smith, cook, tinkerer, alchemist); prisoners; regional reputation; open-world travel | The core loop between fights |
| **BG3**: look | Cinematic lighting, high-detail characters, close-up **dialogue cinematics** | Story moments, companions, bosses |
| **BG3**: systems | **Dice-based skill checks**, branching dialogue, companions with **approval**, choices with consequences; **environment combat**: height advantage, shove off ledges, surfaces (oil, fire, water, ice), line of sight, reactions | Quests and the combat sandbox |
| **Dofus**: PvP | Turn-based **PvP arenas** (1v1, 3v3) with a ranked ladder; **alliance-vs-alliance territory conquest** (claim regions, defend them, tax them) | End-game competition |
| **Wakfu**: dungeons | **Room-by-room dungeons**, each boss with its own mechanic; optional **challenges** per fight for bonus loot; **difficulty tiers** that scale rewards | Group PvE content |

## 3. Combat: one system for PvE, dungeons and PvP

Turn-based, **free movement on the ground** (Wartales/BG3), not a square grid.

- **Each turn:** Movement + 1 Action + 1 Bonus action (BG3), plus **Valor points** shared by the company for powerful moves (Wartales).
- **Engagement:** stepping away from an adjacent enemy provokes an attack (Wartales zone of control).
- **Environment:** high ground gives a hit/damage bonus; you can **shove** off ledges, ignite oil, freeze water, electrify puddles, break cover (BG3).
- **Dice:** visible d20 rolls for hit chance and skill checks, with advantage/disadvantage (BG3).
- **Injuries:** a downed unit may get a lasting **injury** that is healed at camp (Wartales).
- **PvP rules:** the same system with a turn timer and fixed maps, plus ranked matchmaking (Dofus).

## 4. Dungeons (Wakfu style)

- 4–6 rooms per dungeon, ending in a boss with a **unique mechanic** (for example: a boss shielded while its totems stand, floors that collapse each turn, a mirror boss that copies your last spell).
- **Challenges**, a random optional objective per fight ("kill the boss last", "no one ends a turn adjacent to an ally") that grants **bonus loot**.
- **Difficulty tiers**, from Normal to Hard to Nightmare, with better drops and new mechanics.
- Party of up to 6 players, or a solo player with company members.

## 5. PvP (Dofus style, plus what Mauro decided)

- **Arena:** ranked 1v1 and 3v3 on fixed tactical maps, with seasons and rewards.
- **Territory war:** alliances claim regions, place a banner (a defended structure), collect taxes and fight over it at set times.
- **Open-world PvP by zone** (Mauro, 16 Oct): safe zones, contested zones, and **high-risk zones** where dying can lose items and your backpack. **Protection amulets and blessings** reduce or prevent the loss.

## 6. The company and the camp (Wartales)

- **Mercenaries:**
  - you recruit them, pay **daily wages** and feed them;
  - they have traits, likes and dislikes, and can desert;
  - companions with a **story** (BG3-style origin characters) have approval and personal quests.
- **Camp:**
  - rest, cook, craft, heal injuries, interrogate prisoners and talk with companions;
  - this is where BG3-style **camp scenes** happen.
- **Player housing** (already approved): Normal, Rare and Legendary houses with rooms and workshops become your company's home base.

## 7. Story and choices (BG3)

- Branching dialogue with **skill checks** (Persuasion, Intimidation, Insight…).
- Choices change **faction reputation** per region, which opens or closes quests, prices and allies (Wartales).
- Cinematic close-ups for key conversations.

## 8. The honest cost: this is a 3D game

The BG3 and Wartales look needs **3D**: real models, lighting and camera. Our current Godot build is **2D isometric** (Crosshaven, Wakfu style). So:

- **What we keep:** the design, the maps and layouts (Crosshaven's walls, gates, streets and plots), the turn-based logic, the housing and PvP rules, and the tests.
- **What changes:** all the art becomes 3D models (characters, buildings, terrain), and the camera becomes 3D. Godot 4 can do this.
- **Recommendation:** don't convert everything at once. Build **one vertical slice** first, as proof:
  1. Crosshaven's south gate and plaza in 3D, in the gritty Wartales/BG3 look;
  2. one mercenary company of 4 units;
  3. **one full fight** with dice, high ground, shove and a fire surface;
  4. one short dungeon room with a boss mechanic and a challenge.

  If Mauro likes the slice, we expand. If not, we've lost little.

## 9. Decisions (Mauro, 17 Oct)

- **3D: YES.** The game moves to 3D for the BG3/Wartales look.
- **Scale: MMO**, with many players online like Dofus.
- **Next step:** the vertical slice in section 8.

## 9b. Original open questions (answered above)

1. **3D:** confirm we go 3D for the BG3/Wartales look.
2. **Scale:** MMO (many players online at once, like Dofus/Wakfu), or co-op of up to 4–6 players (like BG3/Wartales)? This decides the server work.
3. **Vertical slice:** approve the slice above as the next step.

## 10. How Crosshaven is built in 3D

- **The layout stays.** The approved plan (`data/world/crosshaven_city/streetplan.json` on `claude/pc-crosshaven-city`) is the blueprint: a ring with 12 towers, 4 gates with wooden doors that open, 2 water tunnels, the river with 4 bridges, castle N, cathedral centre, townhall and bank on the plaza, the W crafts quarter and the mill, ~60 NPC houses, 10 player plots, gardens and the gazebo.
- **Scale in metres** (hero 1.8 m):

  | Piece | Height |
  |---|---|
  | NPC house | 5–6 m |
  | Wall | 6 m |
  | Gatehouse | 8 m, arch ≥ 4 m |
  | Tower | 11 m |
  | Legendary house | ~8 m |
  | Bank | 8.5 m |
  | Townhall | 9 m |
  | Cathedral | 11 m |
  | Castle | 13 m |

- **Pipeline:** Grok's concept turnaround → Meshy image-to-3D → cleanup (metre scale, foot pivot, collision, LOD) → Godot places it from data. The ground is a 3D terrain with texture blending, and the river uses a water shader. The day/night cycle, lamps and city life are reused.
- **Phases:**
  1. The slice: the S gate and plaza, the company, 1 fight, 1 dungeon room.
  2. The wall ring.
  3. Landmarks.
  4. Houses and workshops.
  5. Props, nature, river and life.
  6. The MMO server.
- Announced to every team on #252.

## 11. Correction (Mauro, 17 Oct): ONE character per player

The player controls **one character**, not a company of mercenaries; groups are made with other players, as in Dofus. Earlier mentions of the "company" now apply as follows:

- **Wages, food and desertion:** dropped.
- **Valor points:** become the hero's own pool.
- **Camp, professions, injuries and prisoners:** stay, for the single hero.
- **Companions:** optional BG3-style story companions may come later, as NPC allies on specific quests.

The slice shows 1 hero against bandits. The combat rules stay multi-unit, for groups and PvP.

**Groups (Mauro, 17 Oct):** BG3 gives you 4 characters because it isn't online. Here, as in Wakfu and Dofus, **each player is one character, and other players join as a team**. Recommended group size: up to **6 players** (Wakfu-style) for dungeons and group fights. PvP arenas run 1v1 and 3v3.
