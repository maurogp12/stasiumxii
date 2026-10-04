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

**Base branches:** `pc/world-zones` @ `280487b` (34 suites green). `pc/combat-look` @ `8d93797` (#242 merged; all 20 suites green on a fresh worktree, 4 Oct 10:45).

---

## 1. World zones bot (Cursor agent, suffix `a156`): map, zones, NPCs, missions (base `pc/world-zones`)

| Work | PR / branch | Head (last push) | Where it stopped | Next step |
|---|---|---|---|---|
| Water regrade + sea shoreline | #251 `cursor/water-regrade-a156` | `bb2d056` (10:20) | Rework 2 pushed: 19 net racks back, sand lip, edge fade, tile overlap, river-mouth blend. **My re-review is in progress.** From its own stills: lone fence panels still stand on Eastmarch grass; three water styles meet in straight lines at the Eastmarch beach (regraded blue, a gridded fade band, the kit's teal); the map edge still shows a yellow-green rim line, a dark rectangle and diamond seams; Northgate's north edge has no sand lip | Fix those, then one combined still per issue, all 34 suites |
| Town NPCs + missions | #253 `cursor/town-npcs-a156` | `a1e3da8` (10:28) | Rework pushed: per-town welcome, scout and dungeon lines (`1229bc8`). **Needs my re-review**, including the hand-over chain Stoneford → Northgate → Eastmarch → Southbridge → Westwatch → Herald | After #249 merges, bring `pc/world-zones` in and drop Millrace from `rewards.json`, `build_rewards.py`, `build_missions.py` and the Crossroads mission |
| Drop Millrace dungeon | #249 `cursor/drop-millrace-dungeon-a156` | `ccb7c56` (10:22) | Rebased onto `280487b` (was dirty). Approved before; **suite re-check in progress** | Merge into `pc/world-zones` once my check is green |
| Old NPC stand-ins | #250 `cursor/town-npc-standins-a156` | `808d3d8` | Superseded by #253 | Close #250 once #253 merges |
| **Queue after these** | | | | (1) L10 world walker: new bodies and world light. (2) Painted NPC sprites: 19 roles, idle/walk/talk, wardens patrol, townsfolk wander, everyone turns to the player; media = one still per role beside its concept and a walk clip per town. (3) **Northgate snow town** (`docs/pc/look_target/northgate_snow/`). (4) WP7 dungeon doors. (5) WP8 dungeon runs. (6) WP9 world monsters, with the danger zone at level 30+ and aggro within 3 cells. (7) Crag/coast passes when kits land. (8) WP2 zone banner. Regions stay paused (`world.regions_enabled`) |

## 2. Combat look bots (Cursor agents) (base `pc/combat-look`)

| Bot | Work | PR / branch | Head | Where it stopped | Next step |
|---|---|---|---|---|---|
| `ae16` | L9 Crosshaven board, light grade | #242 (merged 10:19) | `c15941b` | **Done.** Media sent to Mauro | none |
| `ae16` | L9b Crosshaven v1 decoration | `cursor/l9b-v1-decor-ae16` (no PR yet) | `af040d7` (10:39) | Code ready for the leaf frame, clearing and sky swap; it draws nothing until the art files exist. Rim props stay off until `props_live` | Wait for the art, open a PR with media, I review |
| `1dff` | L10 new PC characters (Ironjaw v3.1, Kestrel v3), PC walk 0.42 s/cell | #248 draft `cursor/l10-pc-characters-1dff` | `714e6ed` (01:32, **no push since**) | In rework. Owes the 0.22 vs 0.42 walk clip for Mauro | If still silent at the next check-in, treat as stopped: take over from `714e6ed`, finish the rework, make the clip. Kestrel/Bastion/Gloam now have new designs and blockouts (§3), so L10 Kestrel should follow the new Kestrel |

## 3. Scenario Art (Luca's art bot) and Technical Artist

| Work | Where | Head | Where it stopped | Next step |
|---|---|---|---|---|
| Ironjaw HD walk | #252 draft `art/ironjaw-walk-help` (do not merge) | `41c75b0` (10:41): v7 leg test set and updated TA joints | Mauro: "the only thing I'm not liking is the legs." My fix list is on #252: matte dark leg paint like the idle, knee cops, shorter thighs and longer greaves, bigger boots, tassets from the belt, the f11 boot. Their v7 leg test landed after it | Re-check v7 against the idle legs with `docs/pc/art_help/ironjaw_walk/claude/scripts/match_metric.py` (and qa_walk 48/48), then send Mauro the GIF and f00/f06 stills |
| 19 NPC role sheets | tarball not delivered | none | Painted, waiting to hand over | When it lands: the world bot puts them in game (§1 queue 2) |
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

- **Mender:** the new design.
- **Store:** Q16 (what's sold, prices, billing).
- **Main merge:** his review of the PC branches.
- **Mobile team:** the APK size note.

## 6. Not ours (record only, do not touch)

The mobile team's work: `mobile`, `apk/*`, and the `cursor/*-04b3` / `-d1e3` walk branches. PRs #216, #190 and #211 are mobile or older main-based work.
