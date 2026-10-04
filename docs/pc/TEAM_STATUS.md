# PC team status and hand-over record

Kept by Claude, the PC supervisor (Mauro, 4 Oct 2026: "keep a record of everything the other bots are working on and where they stop, in case they run out of usage, so you can take over"). It's updated at every check-in and review. Newest state first. Times are UTC.

**HAND-OVER IN PROGRESS (4 Oct 14:50 UTC).** Scenario update 15:05: Luca keeps Scenario on Kestrel (no Claude take-over of Kestrel). WIP safety copies: Kestrel `4bc925a`, Gloam/Mender `6650f02`, NPC sprites `8763e14`. The Northgate snow kit was not in their archives (not started). `HANDOFF_SCENARIO.md` landed at `b49749b` (fallback; Kestrel state, run commands, open problems). Claude answered its open problems (E-ALT ok, target thigh ratio, Luca's upright legs win, Kestrel blockout v3.1 `ec4beff` fixes the S knee crossing). Mauro: the team bots are about to run out of usage. All bots have been asked to push their WIP and write hand-off files:
- Scenario Art / TA → `art/ironjaw-walk-help` `docs/pc/art_help/HANDOFF_SCENARIO.md` (asked on #252)
- World bot → `docs/pc/HANDOFF_WORLD.md` on its WIP branch (asked on #251)
- Combat bots → `docs/pc/HANDOFF_COMBAT.md` if anything is in progress


**World hand-off received (15:10):** `wip/world-handoff` @ `f5ac779`, `docs/pc/HANDOFF_WORLD.md`. No unpushed world code existed.
- L10 world walker: **not started; Luca put the new characters on hold** for the walker. Don't wire it until that lifts.
- Painted NPC wiring: not started. The world bot says Scenario was rewriting all 19 and to wait for a **fresh** tarball. Scenario's `8763e14` push is labelled WIP from their machine, so confirm with Scenario/Luca it's final before importing.
- Northgate snow town, WP7 doors, WP8 Old Granary run, WP9 monsters: not started, in that queue order.
- #251: Claude-owned. The world bot reports it conflicts with `pc/world-zones` @ `ef3bcc9`, so merge the base before approving.


**TA hand-off received (15:14):** `art/ironjaw-walk-help` `HANDOFF_TA.md` @ `8893931`; copies in `docs/pc/art_help/handoff_wip/technical_artist/` (Ironjaw `.blend` and src included; venvs and backups stay on Luca's box). Flags:
1. The L9 outdoor board kit was rewritten to "v1.4" (sand fringe) on Luca's box after TA accepted v1.3, and TA hasn't checked it. **The shipped L9/L9b in `pc/combat-look` is v1.3; check v1.4 if it's ever pushed.**
2. `PC_IMPORT_WIRING_NOTE.md` says Ironjaw v3, but the json is v3.2.
3. Ironjaw `SHA256SUMS` is stale (README, pad512.py).
4. Ironjaw knee cop and tassets aren't separate joint parts. That matters only if Ironjaw v8+ resumes (parked).
5. Scripts use hard-coded `/workspace` paths and write in place.

When those land, Claude reads them, copies the key facts into this file, and continues each open item from its last commit.

**How to take over a stopped bot's work**
1. Find its row below: the branch, the head commit it stopped on, and the next step.
2. `git fetch origin <branch> && git worktree add /home/user/wt/<name> origin/<branch>`, then continue on that branch with a merge commit, never a rebase or force-push. Keep the bot's commit style and add a change-log row naming the take-over.
3. Run every `tests/run_*_tests.gd` headless (Godot 4.7.2) before pushing, and post on its PR what was taken over and from which commit.
4. Rules don't change on a take-over:
   - PC only. Never touch mobile/APK.
   - Never merge into main or mobile; only Mauro does.
   - Team branches merge into `pc/world-zones` or `pc/combat-look` only after Claude's approval.
   - Log every decision in `docs/pc/CHANGE_LOG_PC.md`.

**Base branches:** `pc/world-zones` @ `ef3bcc9` (#253 merged 12:54; 34-suite check running). `pc/combat-look` @ `a0aec2e` (#254 L9b and #248 L10 merged; 21/21 green on the L10 merge head). `pc/combat-look` @ `8d93797` (#242 merged; all 20 suites green on a fresh worktree, 4 Oct 10:45).

---

## 1. World zones bot (Cursor agent, suffix `a156`): map, zones, NPCs, missions (base `pc/world-zones`)

| Work | PR / branch | Head (last push) | Where it stopped | Next step |
|---|---|---|---|---|
| Water regrade + sea shoreline | #251 `cursor/water-regrade-a156` | `57a8517` | **Claude take-over DONE (15:20):** seamless world-space sea (lattice gone), Northgate snow shore, map-edge cloud sheet follows the camera plus a 4-cell fade, soft foam; world bot commits merged; `pc/world-zones` ef3bcc9 merged in; Fisher-cell rack moved. Agent's run 34/34; **my 34-suite verification is running**. Northgate before/after sent to Mauro. Remaining: faint grid in the Eastmarch inlet/rivers (per-tile water, out of scope); foam steps on stepped coast | When green: post on #251 that the take-over is done, approve, merge into `pc/world-zones` |
| Town NPCs + missions | #253 (**merged 12:54**) | `4dc3b7d` | **Done.** #250 closed. 34-suite check on the merged `pc/world-zones` (`ef3bcc9`) running | none |
| Drop Millrace dungeon | #249 (merged 11:12) | `ccb7c56` | **Done** | none |
| Old NPC stand-ins | #250 | `808d3d8` | **Closed** (superseded by #253) | none |
| **Queue after these** | | | | (1) L10 world walker: new bodies and world light. (2) Painted NPC sprites: 19 roles, idle/walk/talk, wardens patrol, townsfolk wander, everyone turns to the player; media = one still per role beside its concept and a walk clip per town. (3) **Northgate snow town** (`docs/pc/look_target/northgate_snow/`). (4) WP7 dungeon doors. (5) WP8 dungeon runs. (6) WP9 world monsters, with the danger zone at level 30+ and aggro within 3 cells. (7) Crag/coast passes when kits land. (8) WP2 zone banner. Regions stay paused (`world.regions_enabled`) |

## 2. Combat look bots (Cursor agents) (base `pc/combat-look`)

| Bot | Work | PR / branch | Head | Where it stopped | Next step |
|---|---|---|---|---|---|
| `ae16` | L9 Crosshaven board, light grade | #242 (merged 10:19) | `c15941b` | **Done.** Media sent to Mauro | none |
| `ae16` | L9b Crosshaven v1 decoration | #254 (**merged 14:07**) | `347d7ad` | **Done.** `pc/combat-look` @ `a69f7c3`, 20/20 green after the merge | none |
| `1dff` → **Claude (took over 11:40)** | L10 new PC characters, PC walk 0.42 s/cell locked | #248 (**merged 14:30** at Mauro's request) | `81cbc6a` → `pc/combat-look` `a0aec2e` | **Done.** 21/21 green on the merged head | none |

## 3. Scenario Art (Luca's art bot) and Technical Artist

| Work | Where | Head | Where it stopped | Next step |
|---|---|---|---|---|
| Ironjaw HD walk | #252 draft `art/ironjaw-walk-help` (do not merge) | `ef6b8ab`: v7 frames and targets. **v7 verified by me** (S look 87.5, E 85.1, motion passes). **v8 `9b2e7ee` verified (S look 88.6, E 85.1) and shown to Mauro. Mauro: "Move to the next 3"**, so Ironjaw stops at v8 (E legs and the f09 gap parked) | Mauro: "the only thing I'm not liking is the legs." My fix list is on #252: matte dark leg paint like the idle, knee cops, shorter thighs and longer greaves, bigger boots, tassets from the belt, the f11 boot. Their v7 leg test landed after it | Re-check v7 against the idle legs with `docs/pc/art_help/ironjaw_walk/claude/scripts/match_metric.py` (and qa_walk 48/48), then send Mauro the GIF and f00/f06 stills |
| 19 NPC role sprites | `art/ironjaw-walk-help` `npc_sprites_wip/` (`8763e14`) | `8763e14` | **Confirmed FINAL by Scenario (15:14).** Claude is importing them on `claude/npc-painted-sprites` (from `pc/world-zones` `ef3bcc9`): `art/characters/world/npc/<role>/`, wired by role, idle/walk/talk/work, face the player, warden patrol and townsfolk wander, tests, tour video and per-role stills | When the worker reports: verify suites and media, send Mauro the tour, open the PR into `pc/world-zones` |
| **Class looks on the approved blockouts** (Bastion → Kestrel → Gloam → Mender) | `art/ironjaw-walk-help` `class_walk_looks/` | `536fb46` | Bastion v3 LOCKED. **Kestrel walk LOCKED 17:50.** **Gloam walk LOCKED (Mauro: "Lock in") at `8119c9e` on `claude/gloam-legs`, S on Gloam blockout v3.1 `42d8d7c` (foot_w 1.5, Mauro's pick of the wide crouch); look S 88.6 / E 87.8, far boot ≥67%. **Mender walk LOCKED (Mauro: "Lock in Mender") at `d83d9bb` on `claude/mender-legs`, S on Mender blockout v3.1 `ca1a7c3` (foot_w 0.3, Mauro's pick; far-boot gate dropped because the robe covers the boot); look S 90.5 / E 87.0.** All four class walks (Bastion, Kestrel, Gloam, Mender) are locked.** **Actions LOCKED (4 Oct): Kestrel on `claude/kestrel-actions`, Bastion on `claude/bastion-actions`; the open issues are listed in each `actions_v1/README.md` for a future pass. Gloam `94891db`, Mender `0afabd7` and Ironjaw `9d784a1` actions LOCKED too (open issues in each README). Ironjaw's look is dark-steel v7 everywhere. Next: one mobile PR with all 5 action sets plus the Ironjaw walk switch.** **Kestrel legs TAKEN OVER by Claude (15:45, Mauro: "they could not fix it and took too long")** on `claude/kestrel-legs`, from Scenario's hand-off scripts and blockout v3.1. One continuous leg cut from the target, skinned on hip/knee/ankle, upright legs, no seams. Luca confirmed the hand-off (15:51): Scenario's final Kestrel package is `3c74b8e` (sheet B rejected: crotch grey box, S seam, E flat thigh tops, E belt +6.1%). **Gloam and Mender: not started; Scenario is out**, so Claude does them after Kestrel | **Kestrel walk LOCKED (17:50, Mauro: "Lock in Kestrel") at `1abc051` (lock note `d08e0b7`) on `claude/kestrel-legs`.** S on blockout v3.2 (narrow track): crotch closed (0 px every frame), swing thigh ≤25°, far boot ≥63% visible, skate ≤0.57 px, look S 91.9. E byte-identical to the approved one. W/N are mirrors. Known and accepted: strong heel kick at f08/f09; planted-leg lean of 8–13° on 4 S frames; specks near the inner knee at f03 | Arm swing and cape lag, then Kestrel actions, then Gloam and Mender painted walks |
| **Mender** | concepts in `art/ironjaw-walk-help` `class_walk_looks/mender_concepts/`; blockout `claude/class-walk-blockouts` `ff1c649` | `ff1c649` | **Mauro picked B; blockout approved (12:20).** Scenario to paint the Mender S/E look targets | Mauro approves the targets; parts come after Gloam |
| Northgate snow town | `claude/northgate-snow-town` (from water `57a8517`) | none yet | **Claude building it (15:30)** after Mauro: "road should have snow, snow falling and trees, nothing looks like this". Scenario never made the kit. Scope: snow ground, snowy cobble roads, snow-loaded pines, warm windows and lamps, stone chapel, falling snow, cool daylight grade; bench +25% cap | When the worker reports: check the stills against the reference, run suites, send Mauro before/after and the clip |
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
