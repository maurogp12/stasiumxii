# STASIUM XII Mobile — Stasis gates

Mobile track only. These scenes stay off PC `main`. Do not merge `scenes/stasis_run.tscn`, `scenes/stasis_fight.tscn`, `backend/stasis_catalog.gd`, or `backend/stasis_ai.gd` onto the PC branch.

Luca Garza (overnight, 2026-09-25) unparked Stasis so the phone APK shows a real dungeon when a hub door is tapped. The old “Stasis coming soon” stub is no longer the door target. Shade, Ambush, and Koliseo kit numbers are unchanged. Gender and color cosmetics stay parked.

## What a door does

1. Hub button (`Crosshaven Stasis` and the other four Title Case ids) stores the biome id and opens `scenes/stasis_run.tscn`.
2. That screen shows the Proposed door name, the trash, and the boss. The player picks one of the five Locked classes. **Back to hub** leaves.
3. `scenes/stasis_fight.tscn` loads that biome’s existing `art/maps/arena_colosseum_v2/tiled/{id}_15x15` tags. CombatSim runs the duel. Deploy blobs are skipped so the room starts in combat.
4. Room A is three trash duels in order, then Room B is the boss. CombatSim is still two seats, so the trash are fought one at a time on the same board. Player HP carries. There is no loot, key, or heal between foes in this slice.
5. Win, lose, or **Back to hub** returns to the hub. The foe’s turn is a simple walk-then-Strike AI. The player cannot move the foe.

| Hub id | Door (Proposed) | Trash | Boss |
| --- | --- | --- | --- |
| `crosshaven` | Threshgate | Scarecrow Drudge · Grain Hound · Threshling | Warden of the Sheaves |
| `brinewake` | Tidehold | Tide Skitter · Silt Raider · Brine Gullkin | Captain Brineclaw |
| `slagcrown` | Ashmarch | Cinder Imp · Ash Stalker · Slag Mite | Slagheart the Emberbrute |
| `windmere` | Galevault | Gale Skitter · Gustling · Frost Wisp | Serra the Gale Sentinel |
| `stormspire` | Coilgate | Sparkin · Volt Mote · Coil Tick | Tyrant Coilspire |

Grammar from the package: 2 rooms (A trash → B boss), solo, about 4 minutes, 15×15, ground / mud / water / lava tags, paint-only props. Boss 4H/5H sheets are not in this slice. Foes use the Ironjaw sprite as a stand-in and only offer Strike.

## Provisional Open numbers (playtest, not Locked)

Balance has not stamped these. They are not Soft Lock. Do not copy them into `data/kits.gd`.

The attack base is applied before the Locked facing multiplier (front/side ×1.00, back ×1.20). A back hit is higher than the base. The player’s own spells stay the Locked cards, including Strike 16.

| Foe | HP | Attack base | Stand-in card |
| --- | --- | --- | --- |
| Each trash | 22 | 6 | Ironjaw Strike, range 1, 3 AP. Coach shows a door-specific label (for example Straw Swipe). |
| Boss | 56 | 10 | Same card. Coach shows the boss label (for example Sheaf Cleave). |

Player pool stays **80 HP**, **6 AP / 3 MP**. Strike still grants Impact on the stand-in body. The AI will not cast Advance, Shoulder, or Crush.

## Playtest on device or in the editor

This note does not publish an APK. A playable sideload is a separate export (see `docs/mobile_android_export.md`).

Editor:

1. Open `project.godot` on the `mobile` branch. Press **F5**. The hub is the main scene.
2. Tap a Stasis door (not Koliseo). Confirm the door name, three trash, and the boss. There is no “coming soon” line.
3. Tap a class. Room A starts on that biome’s board. Walk and cast with the existing combat buttons.
4. Clear the three trash, then the boss, or tap **Back to hub** mid-fight. A loss also offers **Back to hub**.

APK, after you export `builds/android/stasiumxii-mobile-debug.apk` from this branch:

1. Install that build (same debug cert pin as the previous sideload, or uninstall first if the cert changed).
2. Open the app. Tap each of the five Stasis doors once and confirm a fight starts on that board.
3. On one door, play Room A into Room B, then use **Back to hub** from the clear screen. On another, lose or back out early and confirm the hub is still there.
4. Open Koliseo and confirm hot-seat is unchanged (class pick, random arena, Locked kits).

## Headless

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . -s res://tests/run_stasis_tests.gd
```
