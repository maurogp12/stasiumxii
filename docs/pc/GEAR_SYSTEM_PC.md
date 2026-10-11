# PC gear system (mobile ladder)

Status: **Proposed.** Branch `claude/pc-mobile-gear`, from `pc/world-zones` at `eb5bfb9`. Do not merge without Mauro.

Mauro, 11 Oct 2026: "Crea estos sets en el juego de pc", then "Ok entonces utiliza los de mobil". For dungeon drops: "Sí, como en el móvil". Earlier: "las piezas deberian ser random para cada clase y los jugadores podran tener la opcion de venderlas o intercambiarlas".

The PC game's 43 level-tier sets (`rewards.json` format 1, slots head / cape / belt / boots / amulet) are replaced by the mobile gear ladder: the sets, parts, fusing, AP/MP rules, crit and chest odds of `origin/mobile` commit 7035f8f (`backend/gear_bag.gd`, `koliseo_wallet.gd`, `combat_sim.gd`), the same source as the reference PDF `Sets_stasium.pdf`.

## What was ported

| Part | Where on PC | Notes |
|---|---|---|
| The sets: ids, names, part numbers, 2/4/5-piece bonuses | `backend/pc_gear.gd` (`FAMILIES`, `PARTS`) | Copied from mobile as they are. `tests/run_pc_gear_tests.gd` checks every set and slot against numbers read from the PDF. |
| Slots weapon, head, chest, legs, boots | `pc_gear.SLOTS`, `pc_progress.EQUIP_SLOTS` | The 4th slot is legs, as the PDF says. The trinket slots amulet, ring and ring_b stay for epics, relics and the Plain Band. An epic or relic with a head, weapon or boots slot takes that gear slot. |
| Item ids | `<set>.<slot>`, e.g. `cragmaw.head` | Mobile's ids. Instance rarity is the set tier in lower case (`normal`, `rare`, `legendary`, `ultra`); instances carry `plus` (0 to 5). |
| Fusing | `pc_progress.fuse_uid`, `fuse_partner`; `pc_gear.can_fuse`, `FUSE_MULT` | Two copies at the same plus make one at plus + 1, cap +5. x1.00 / 1.12 / 1.26 / 1.41 / 1.58 / 1.78 on HP, Mastery, Resist, Init. Crit and the Ultra extras do not grow. A worn copy stays worn. |
| AP / MP | `pc_gear.ap_mp_of_worn`, `combat_stats`; `pc_progress.sheet_view` | Base 6/3, cap 8/5. Legendary and Ultra 5pc +1 AP +1 MP. Rare weapon at +5 +1 AP, Rare boots at +5 +1 MP, each once. |
| PC level rule kept | `level_rewards.json` milestones | PC gives +1 AP at **level 30** (mobile: level 20). Kept as it is, added inside the same 8 AP cap, on the sheet and in the dungeon fight. PC has no Hourglass. |
| Crit | `combat_sim.gd` `_gear_crit_mult` | x1.3, chance cap 20%, at most one crit per fighter per turn, only on the fighter's own turn, heals crit for the Mender only. Crit rolls use their own RNG stream, so a fight's hit rolls are the same with or without crit gear. |
| HP % | `pc_gear.max_hp` | (base + level HP + part HP) x (1 + set HP%). PC base is the flat 80 (`level_rewards.json` sheet hp); PC has no class or level HP yet (`class_hp_per_level` is Open). |
| Set riders | `combat_sim.gd` `_gear_strike_damage`, `_apply_pc_gear` | First hit +N, first back hit +N, melee +N at range 1, back %, guard (first hit taken each turn deals N less), Mender heals +N, Oathgrave's starting Aegis (and a Ward shield hook, see Open points). |
| Resist | `combat_sim.gd` `_dealt` | Every set is `resist_all`: part resist counts against every element. Gear resist is capped at 50% (mobile `RESIST_CAP`). |
| Gear reaches the fight | `pc_progress.fight_gear()` → `pc_dungeon_run.hero_gear` → room config `hero.gear` → `CombatSim._apply_pc_gear` | Before this change the PC dungeon hero was a bare 80 HP body: worn gear and PC points did not reach CombatSim. Gear now does. PC points (Mastery / Vitality / Swift / Resist) still do not reach the dungeon fight (Open, not part of this port). |
| Ultra extras | `pc_gear.combat_stats(..., pvp)` | Ultra 2pc / 4pc lines, the special part of the 5pc, Ultra part extras and Ultra crit apply only in a Koliseo fight (`pvp = true`). PC fights are dungeon and world fights, so they stay off. Ultra HP / Mastery / Resist / Init and the 5pc +1 AP +1 MP work everywhere. |
| Class fit | `pc_gear.can_wear`, `pc_rewards.can_wear` | A class set fits only its class; Ashmantle and Brightedge fit any class. Gear has no level gate (mobile has none). A hero can receive and keep any class's piece. Changing class takes off pieces the new class cannot wear. |

The PDF lists **22 sets** (2 shared + 5 classes x 4), not 23: Ashmantle, Brightedge, and per class a Normal, a Rare, a Legendary and an Ultra set. Mobile's code has the same 22.

## Drops ("como en el móvil")

A chest rolls a tier, then a set of that tier at equal odds, then a slot (weapon 18%, every other slot 20.5%). One piece per chest, at +0 (mobile marks the chest size Provisional; PC keeps it).

| Row | Normal | Rare | Legendary |
|---|---|---|---|
| ★1-★2 | 100% | - | - |
| ★3-★4 | 70% | 30% | - |
| ★5 | 60% | 30% | 10% |
| Boss | 50% | 30% | 20% |

The PC dungeon star is the Stasis star. Equal odds over sets make every class equally likely, which is Mauro's "random para cada clase". The hero's class does not steer a drop (the old `class_bias` 0.6 is gone).

### Mapping choices (Proposed)

- **Dungeon win: two chests a run.** Room A's chest rolls the star row, room B's boss chest rolls the boss row (`rewards.json` `gear.dungeon_chests`). Both are paid on the win, as before; a loss pays nothing. Mobile pays one chest per Stasis clear (the boss row once room B is cleared) and caps it at 5 clears a UTC day. PC dungeons had no daily cap and keep none. Open: one chest or two, and whether PC wants a daily cap.
- **World fights:** the old 3% part chance stays (`gear.world_chance`); the piece is a Normal-tier piece (Ashmantle and the five class Normal sets at equal odds). Before, world fights dropped a level-tier set of the zone; the zone table (`zones`) is gone.
- **Missions:** the rank table stays. Its box share is a Mystery Box, its regular share a Normal-tier piece, its rare share a Rare-tier piece (`gear.mission_tiers`). The 10th mission's Mystery Box stays.
- **Mystery Box:** the coin row stays; the part rows are a Normal-tier (regular) or Rare-tier (rare) piece (`gear.box_tiers`).
- **Separate layer kept:** epics, relics, the Mystery Box chance by star and the dungeons' `star_drops` roll as before, after the chests. The ★5 Mystery Box stays guaranteed. Retired with the old sets: the ★5 guaranteed Rare part, the Rare-part roll by star (`dungeon_rare_by_stars`), the dungeon-set / class-set split, and the blight's tier-50 Rotting Elder pool in `star_drops`.
- **Coins and XP:** unchanged.
- **Ultra:** never drops. Source `koliseo_shop`, 30 coins a piece (`gear.ultra`). PC has no Koliseo shop or Koliseo wallet (`shop_built: false`).

## Old saves

`pc_progress.migrate_legacy_gear` runs on load, before the save is checked. A part of an old set (`<old set>_<slot>`, the 43 ids listed in `rewards.json` `legacy_gear.sets`) becomes the **Ashmantle** piece of the mapped slot: head → head, cape → chest, belt → legs, boots → boots, amulet → weapon. A regular part becomes +0; an old Rare part becomes +1 (worth two +0 copies). Ashmantle fits every class, so a worn old part stays worn in its new slot when that slot is free; otherwise it goes to the bag. A non-gear item worn in a retired slot (cape, belt) goes to the bag. Each change is written to `load_log`. Coins are not refunded (the pieces carry the value). A save with an unknown non-gear item id is refused as before (no crash).

## Character and inventory windows

- Inventory (`I`): the slot list is weapon, head, chest, legs, boots, amulet, ring, ring. Gear shows as `Name +N`. The item card shows the set, tier, who can wear it, the part's numbers at its plus, the set's 2/4/5 lines and whether it can be fused. **Fuse** replaces the dark "Upgrade" button (mobile's gear screen pattern: Fuse finds the partner). A piece the class cannot wear says to keep it to sell or trade later. Filters gain Normal, Legendary and Ultra.
- Character (`C`): HP is the geared max HP; a Gear block lists the five slots with their +, a Fuse button per worn piece that has a partner, the gear stats and the active set lines.

## For the paper doll (claude/pc-visible-gear)

`pc_progress.equipped_look(slot)` returns `{set_id, part_id, slot, plus, rarity, owner}` for a worn set part (or `{}`), e.g. `{"set_id": "cragmaw", "part_id": "cragmaw.chest", "slot": "chest", ...}`. `equipped_looks()` returns every worn slot's look. `pc_gear.look_of(item_id, plus)` does the same from an id. The ids are mobile's set and part ids.

## Selling, trading, Koliseo shop

- **Sell:** not built. The inventory's Sell and List buttons are dark ("Not built yet"); the Trader NPCs say "The shop is not open yet." No vendor exists, so no sell was added.
- **Trade:** not built, and not added (per the brief).
- **Koliseo shop / wallet:** PC has none. The Ultra sets are in the data with source `koliseo_shop` and a price of 30, ready for a shop.

## Balance

The dungeon star sims were rerun (`tests/sim_dungeon_stars.gd <id> 8 <level>`, solo hero bot, every class). The bot now wears its class's own set by star, the way mobile's `sim_dungeons.gd` gives its heroes a set (`GEAR_BY_STAR`, Proposed): ★1 Normal +0, ★2 Normal +1, ★3 Rare +0, ★4 Rare +1, ★5 Rare +2, all five pieces; the level milestone AP rides along. `gear none` reruns the bare body.

BALANCE_TABLE

## Open points

- One chest or two per dungeon run; a daily chest cap like mobile's 5 clears.
- The sim's gear assumption by star.
- PC points (Mastery / Vitality / Swift / Resist) do not reach the dungeon fight; gear does.
- Class base HP (mobile 75-110) is not ported; PC stays at a flat 80.
- Ultra Koliseo-only lines have no PC Koliseo fight to work in yet.
- Oathgrave 5pc "Ward shield 25 (cap 40). No Aegis refund when Ward breaks": on PC, Ward is a Mender spell and the Bastion kit has no team Ward, so this line has nothing to act on (the hook is there: a caster with `ward_shield` sets that shield). Its "Start with 1 Aegis" and +1 AP +1 MP work.
- The Ultra set lines (Gatewarden, Sandhawk, Pitmaw, Hushring, Mercywell riders) are data only on PC.
- Sell, trade and the Koliseo shop.
