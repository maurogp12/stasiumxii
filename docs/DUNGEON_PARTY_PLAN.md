# STASIUM XII — Dungeon (Stasis) party + finder plan

Mauro, 1 Oct 2026: "dungeons are so easy to pass on 5 stars being lvl 30 and
full set, make it harder so everyone depends in a team. 1 star can be done
alone, 2 stars need a team mate … above 3 full team." Follow-ups the same day
(answers in chat):

- **Party size**: ★1 = 1 player, ★2 = 2, ★3–★5 = full party of **4**
  (example: Tank, Healer, 2 DPS).
- **Classes**: any mix is allowed (roles are a label for requests, not a lock).
  Tank = Bastion, Healer = Mender, DPS = Kestrel / Ironjaw / Gloam.
- **Fewer players than the party size**: allowed, but brutal (tuned for the
  full party).
- **Difficulty target** (full party, level 30, full set): ★3 ≈ 80% wins,
  ★4 ≈ 65%, ★5 ≈ 50%. ★1 solo stays easy.
- **Finder ("B")**: pick dungeon + star + your role. A party (friends) enters
  together. You can **request only the roles you miss** (e.g. Tank + 2 DPS
  request a Healer). The online queue looks for real players with that role.
  If nobody is found, offer **"Fill with AI"** (an AI companion plays the
  missing seat). You can keep waiting instead.

- **Party board** (Mauro, same day): before a dungeon starts, players can
  **create a party** for a door + star (e.g. the lava boss, Slagcrown ★4) or
  **join an open party** from a list. The list shows door, star, leader, who
  is in (class / role) and which roles are still requested. The leader starts
  when ready; empty seats can still be filled with AI.

## Build order

1. **Engine (offline)** — `CombatSim`: a Stasis party of 1–4 heroes (team 0,
   seats 0..P−1) vs the monsters (team 1). Heroes heal / shield each other;
   monsters target any hero; the run is lost only when every hero is down.
2. **AI companions** — a hero planner (heal hurt allies, hit the best target,
   keep the class's fighting range) for seats filled by AI.
3. **Difficulty** — monster HP / damage / pack size scale with star AND party
   size; tuned with a party simulator to the targets above.
4. **Finder UI (offline first)** — star + role pick, party slots, per-slot
   "request role", "Fill with AI".
5. **Online party board + finder** — create / join a party for a door + star,
   server queue by role on Mauro's server
   (`68.201.184.207:7777`), friends' party, role requests, AI fallback.
   Built together with online 2v2 / 3v3.

Rules from `CLAUDE.md` apply (approved changes only, change log, all suites,
2D look). Monster HP / EV were Open; Mauro's order above makes tuning them
part of this work.
