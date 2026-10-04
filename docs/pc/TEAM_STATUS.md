# PC team status and hand-over record

Kept by Claude, the PC supervisor (Mauro, 4 Oct 2026: "keep a record of everything the other bots are working on and where they stop, in case they run out of usage, so you can take over"). It's updated at every check-in and review. Newest state first. Times are UTC.

**How to take over a stopped bot's work**
1. Find its row below: the branch, the head commit it stopped on, and the next step.
2. `git fetch origin <branch> && git worktree add /home/user/wt/<name> origin/<branch>`, then continue on that branch with a merge commit, never a rebase or force-push. Keep the bot's commit style and add a change-log row naming the take-over.
3. Run every `tests/run_*_tests.gd` headless (Godot 4.7.2) before pushing, and post on its PR what was taken over and from which commit.
4. Rules don't change on a take-over:
   - PC only. Never touch mobile/APK.
   - Never merge into main or mobile; only Mauro does.
   - Team branches merge into `pc/world-zones` or `pc/combat-look` only after Claude's approval.
   - Log every decision in `docs/pc/CHANGE_LOG_PC.md`.

**Base branches:** `pc/world-zones` @ `ef3bcc9` (#253 merged 12:54; 34-suite check running). `pc/combat-look` @ `a69f7c3` (#254 merged; 20/20 green). `pc/combat-look` @ `8d93797` (#242 merged; all 20 suites green on a fresh worktree, 4 Oct 10:45).

---

## 1. World zones bot (Cursor agent, suffix `a156`): map, zones, NPCs, missions (base `pc/world-zones`)

| Work | PR / branch | Head (last push) | Where it stopped | Next step |
|---|---|---|---|---|
| Water regrade + sea shoreline | #251 `cursor/water-regrade-a156` | `e96cb73` (world bot pushed 12:32/12:45 despite hands-off; now hard-stopped) | **Claude take-over agent finishing**: it merges their 2 commits, makes the Northgate shore snow (theirs was sand), keeps the better open-sea fill, and uses soft foam | When it reports: view the stills, run 34 suites, post on #251, send Mauro the Northgate before/after, approve |
| Town NPCs + missions | #253 (**merged 12:54**) | `4dc3b7d` | **Done.** #250 closed. 34-suite check on the merged `pc/world-zones` (`ef3bcc9`) running | none |
| Drop Millrace dungeon | #249 (merged 11:12) | `ccb7c56` | **Done** | none |
| Old NPC stand-ins | #250 | `808d3d8` | **Closed** (superseded by #253) | none |
| **Queue after these** | | | | (1) L10 world walker: new bodies and world light. (2) Painted NPC sprites: 19 roles, idle/walk/talk, wardens patrol, townsfolk wander, everyone turns to the player; media = one still per role beside its concept and a walk clip per town. (3) **Northgate snow town** (`docs/pc/look_target/northgate_snow/`). (4) WP7 dungeon doors. (5) WP8 dungeon runs. (6) WP9 world monsters, with the danger zone at level 30+ and aggro within 3 cells. (7) Crag/coast passes when kits land. (8) WP2 zone banner. Regions stay paused (`world.regions_enabled`) |

## 2. Combat look bots (Cursor agents) (base `pc/combat-look`)

| Bot | Work | PR / branch | Head | Where it stopped | Next step |
|---|---|---|---|---|---|
| `ae16` | L9 Crosshaven board, light grade | #242 (merged 10:19) | `c15941b` | **Done.** Media sent to Mauro | none |
| `ae16` | L9b Crosshaven v1 decoration | #254 (**merged 14:07**) | `347d7ad` | **Done.** `pc/combat-look` @ `a69f7c3`, 20/20 green after the merge | none |
| `1dff` → **Claude (took over 11:40)** | L10 new PC characters, PC walk 0.42 s/cell locked | #248 | `2910f5b`, with local merge `81cbc6a` (`pc/combat-look` a69f7c3 merged in, change-log conflict resolved, no rows lost) | **Mauro: "merge L10" (14:15).** 21-suite run on the merged result in progress | When green: push `81cbc6a`, merge #248 into `pc/combat-look` (not main/mobile), re-verify the base |

## 3. Scenario Art (Luca's art bot) and Technical Artist

| Work | Where | Head | Where it stopped | Next step |
|---|---|---|---|---|
| Ironjaw HD walk | #252 draft `art/ironjaw-walk-help` (do not merge) | `ef6b8ab`: v7 frames and targets. **v7 verified by me** (S look 87.5, E 85.1, motion passes). **v8 `9b2e7ee` verified (S look 88.6, E 85.1) and shown to Mauro. Mauro: "Move to the next 3"**, so Ironjaw stops at v8 (E legs and the f09 gap parked) | Mauro: "the only thing I'm not liking is the legs." My fix list is on #252: matte dark leg paint like the idle, knee cops, shorter thighs and longer greaves, bigger boots, tassets from the belt, the f11 boot. Their v7 leg test landed after it | Re-check v7 against the idle legs with `docs/pc/art_help/ironjaw_walk/claude/scripts/match_metric.py` (and qa_walk 48/48), then send Mauro the GIF and f00/f06 stills |
| 19 NPC role sheets | tarball not delivered | none | Painted, waiting to hand over | When it lands: the world bot puts them in game (§1 queue 2) |
| **Class looks on the approved blockouts** (Bastion → Kestrel → Gloam) | brief: `claude/class-walk-blockouts` `PAINT_BRIEF.md`; targets in `art/ironjaw-walk-help` `class_walk_looks/targets/` | `c9a8556` | Step 1 targets **approved by Mauro (11:30)**. **Step 2 painted parts STARTED (12:00)**: Bastion → Kestrel → Gloam. Frames go in `class_walk_looks/<class>/v1/frames/`; I score them before Mauro | Step 2: painted parts on the blockout joints. Step 3: match_metric look ≥ 85 and motion ≥ 95, qa_walk 48/48. I re-run before Mauro sees anything |
| **Mender** | concepts in `art/ironjaw-walk-help` `class_walk_looks/mender_concepts/`; blockout `claude/class-walk-blockouts` `ff1c649` | `ff1c649` | **Mauro picked B; blockout approved (12:20).** Scenario to paint the Mender S/E look targets | Mauro approves the targets; parts come after Gloam |
| Northgate snow kit | not started | none | New ask, 4 Oct: see `docs/pc/look_target/northgate_snow/README.md` | Paint the kit in the v7 style (2x masters) |
| Class blockouts to paint from | `claude/class-walk-blockouts` | `503c37f` | Built from Mauro's new designs (walk S/E + idle, joints in the TA format), with action videos. **Mauro approved Gloam, Bastion and Kestrel** (after the shield and bow fixes) | **Mender: waiting on Mauro's design.** Scenario and TA can start painting/rigging Gloam, Bastion and Kestrel |
| TA joints | in #252 `ta_joints/` | `41c75b0` | Updated joints for v7 | Raise the S pelvis about 13 px through the Blender re-export, feet pinned |

## 4. Claude (supervisor) — my own branches

| Branch | Head | What |
|---|---|---|
| `claude/pc-zones-spec` | latest | Spec, look targets, change log, this file |
| `claude/ironjaw-walk-help-reply` | `19b4ac1` | Ironjaw metric, rig fixes, punch list |
| `claude/class-walk-blockouts` | `9ade2ce` | Class blockouts + Blender scripts (`scripts/blockout.py`, `preview.py`); action renders are in the session scratchpad |

## 5. Waiting on Mauro

- **Store:** Q16 (what's sold, prices, billing).
- **Main merge:** his review of the PC branches.
- **Mobile team:** the APK size note.
- (Answered 4 Oct: the Mender repaint is approved, Kestrel keeps the new version, mirrors are fine.)

## 6. Not ours (record only, do not touch)

The mobile team's work: `mobile`, `apk/*`, and the `cursor/*-04b3` / `-d1e3` walk branches. PRs #216, #190 and #211 are mobile or older main-based work.
