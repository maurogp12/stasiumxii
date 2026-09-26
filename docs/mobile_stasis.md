# STASIUM XII Mobile — Stasis gates

Mobile track only. These scenes stay off PC `main`. Do not merge `scenes/stasis_run.tscn`, `scenes/stasis_fight.tscn`, `backend/stasis_catalog.gd`, or `backend/stasis_ai.gd` onto the PC branch.

Luca Garza (overnight, 2026-09-25) unparked Stasis so the phone APK shows a real dungeon when a hub door is tapped. The old “Stasis coming soon” stub is no longer the door target. Shade, Ambush, and Koliseo kit numbers are unchanged. Gender and color cosmetics stay parked.

The 2026-09-26 playtest (Luca, phone) rejected the Ironjaw stand-in and the trash 1/3 → 2/3 → 3/3 chain. This slice follows the Stasis-1 package grammar instead.

## What a door does

1. Hub button (`Crosshaven Stasis` and the other four Title Case ids) stores the biome id and opens `scenes/stasis_run.tscn`.
2. That screen shows the Proposed door name, the trash pack, and the boss. The player picks one of the five Locked classes. **Back to hub** leaves.
3. `scenes/stasis_fight.tscn` loads that door’s Room A or Room B tags from `art/maps/stasis_v1/{biome}_room_{a|b}_15x15_tags.json`. Those boards approximate the package schematics (mud furrows, water channels, lava spokes, and the other room notes). They are not the Koliseo `arena_colosseum_v2` layouts. Koliseo still uses those arenas. Deploy blobs are skipped so the room starts in combat.
4. **Two rooms only.** Room A is one combat: the three trash stand on the board together and each living trash takes a turn after the player. Room B is the boss, one foe. Clearing Room A offers **Enter Room B**. There is no loot, key, or heal between rooms. Player HP carries. There is no trash 1/3 counter.
5. Win, lose, or **Back to hub** returns to the hub. A foe’s turn is a simple walk-then-Strike AI. The player cannot move a foe.

| Hub id | Door (Proposed) | Trash (Room A, together) | Boss (Room B) |
| --- | --- | --- | --- |
| `crosshaven` | Threshgate | Scarecrow Drudge · Grain Hound · Threshling | Warden of the Sheaves |
| `brinewake` | Tidehold | Tide Skitter · Silt Raider · Brine Gullkin | Captain Brineclaw |
| `slagcrown` | Ashmarch | Cinder Imp · Ash Stalker · Slag Mite | Slagheart the Emberbrute |
| `windmere` | Galevault | Gale Skitter · Gustling · Frost Wisp | Serra the Gale Sentinel |
| `stormspire` | Coilgate | Sparkin · Volt Mote · Coil Tick | Tyrant Coilspire |

Grammar from the package sheet is the Locked structure: 2 rooms (A trash → B boss), solo, about 4 minutes, 15×15, ground / mud / water / lava tags, paint-only props. The room pictures are Proposed. Boss 4★/5★ sheets are not a separate fight in this slice. Coilspire’s fight sprite is the door-sheet crop (spider body, tesla coils), checked against that evolution sheet for silhouette, not the starred form.

## Foe art

Portraits are crops of the package concept sheets, keyed out and fit onto the same 144×160 canvas as the class turnarounds:

`art/stasis/foes/<art_id>.png`

Warden of the Sheaves is the scarecrow, drawn at Ironjaw scale (tall in that canvas). Trash are shorter. Every facing uses that one crop, because the sheets are single views. The pawn does not play Ironjaw walk or attack strips for these bodies.

Strike still resolves on Ironjaw’s Locked card. Strike is not on the other four kits, and these numbers are not written into `data/kits.gd`. The coach label is the door attack (for example Straw Swipe). The card on screen is not the Ironjaw portrait.

## Provisional Open numbers (playtest, not Locked)

Balance has not stamped these. They are not Soft Lock. Do not copy them into `data/kits.gd`.

The attack base is applied before the Locked facing multiplier (front/side ×1.00, back ×1.20). A back hit is higher than the base. The player’s own spells stay the Locked cards, including Strike 16.

Room A did not retune these for the pack. Three bodies at 22 HP, each with a full turn, are hotter than the old one-at-a-time duels. That stays Open for Balance.

| Foe | HP | Attack base | Card |
| --- | --- | --- | --- |
| Each trash | 22 | 6 | Strike, range 1, 3 AP. Coach shows a door-specific label (for example Straw Swipe). |
| Boss | 56 | 10 | Same card. Coach shows the boss label (for example Sheaf Cleave). |

Player pool stays **80 HP**, **6 AP / 3 MP**. Strike still grants Impact on a foe whose resolver class is Ironjaw. The AI will not cast Advance, Shoulder, or Crush.

## Playtest on device or in the editor

This note does not publish an APK. A playable sideload is a separate export (see `docs/mobile_android_export.md`). Do not cut an APK for this slice.

Editor:

1. Open `project.godot` on the `mobile` branch. Press **F5**. The hub is the main scene.
2. Tap a Stasis door (not Koliseo). Confirm the door name, three trash, and the boss. There is no “coming soon” line.
3. Tap a class. Room A starts on that door’s schematic. The three trash are on the board, and they do not look like Ironjaw. Walk and cast with the existing combat buttons.
4. Clear the pack, enter Room B, clear the boss, or tap **Back to hub** mid-fight. A loss also offers **Back to hub**.

APK, after a later export (not this change):

1. Install that build (same debug cert pin as the previous sideload, or uninstall first if the cert changed).
2. Open the app. Tap each of the five Stasis doors once and confirm Room A is one pack fight on that schematic.
3. On one door, play Room A into Room B, then use **Back to hub** from the clear screen. On another, lose or back out early and confirm the hub is still there.
4. Open Koliseo and confirm hot-seat is unchanged (class pick, random arena, Locked kits).

## Headless

```text
godot --headless --path . -s res://tests/run_mobile_hub_tests.gd
godot --headless --path . -s res://tests/run_stasis_tests.gd
```
