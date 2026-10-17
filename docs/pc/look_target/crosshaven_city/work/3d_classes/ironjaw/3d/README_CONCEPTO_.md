# Ironjaw male 3D: CONCEPTO

🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO. Not in the game, not tested in Godot.

- Model: Meshy multi-image (front/side/back crops) -> retexture -> auto-rig. 1.8 m, feet at y=0, front +Z, A-pose bind, 24 joints renamed to Godot humanoid names (map in JSON).
- LOD0 21,050 tris (2048 WebP) with 25 clips; LOD1 10,525 (1024); LOD2 4,210 (512). Same skeleton on every LOD.
- Axes: itm_ironjaw_axe_R/L_CONCEPTO_.glb (identical), 0.65 m, ~3k tris, origin = grip point 1/4 up the haft. Attach transforms (hand + back holster) are in the JSON under weapons.attach and weapons.holster.
- Grip v2: closed fist sculpted into the bind mesh (the gauntlet has no separate fingers, so no finger bones). See previews/ironjaw_grip_before_after_CONCEPTO_.jpg and ironjaw_holster_back_CONCEPTO_.jpg.
- Credits: 140 (see credits_log.csv). Previews: previews/*.jpg (5 frames per clip, both axes attached).

## Clips and the off-hand axe

| Clip | Meshy base (id) | Frames @30 | Off-hand axe |
|---|---|---|---|
| idle | Axe_Breathe_and_Look_Around (335) | 422 | Mirror: off-hand axe hangs head-down at left side; breathing reads fine with both. Base is Axe_Breathe (single axe). |
| walk | Slow_Orc_Walk_inplace (669) | 206 | Both axes hang head-down; Slow_Orc arm swing is symmetric, so the left axe already mirrors the right. |
| run | Standard_Forward_Charge_inplace (673) | 24 | Both axes trail; charge arm pump is symmetric. Tweak: raise both heads off the thighs. |
| turn_l | Combat_Idle_Turn_Left (575) | 48 | Clip holds right arm high; left axe stays low. Tweak: lower right arm to the idle pose. |
| turn_r | Idle_Turn_Right (586) | 40 | Idle turn, axes hang. Ends ~180 deg rotated (root rotation kept). |
| attack_melee_1 | Charged_Axe_Chop (237) | 288 | Charged_Axe_Chop: right axe chops; left axe COMPLEMENTS by bracing low/back. Custom: left follow-up chop on the recovery for a 1-2. |
| attack_melee_2 | Double_Combo_Attack (92) | 106 | Double_Combo_Attack: right then left strike; second axe mirrors the first. Best native dual-weapon clip. |
| attack_ranged | Crouch_Pull_and_Throw (239) | 218 | Crouch_Pull_and_Throw used as an axe throw: right axe is thrown (hide R axe at release, respawn on recovery); left stays in hand. |
| cast | Sword_Shout (101) | 231 | Sword_Shout war-cry: right axe raised overhead; left axe mirrors low. Custom: raise both for a berserk roar. |
| hit | Hit_Reaction (178) | 61 | Generic hit react; both axes flail with the arms. |
| block | Two_Handed_Parry (149) | 49 | Two_Handed_Parry: both fists meet overhead, so the two axes cross like an X block. Custom: separate the hands ~10 cm so the hafts do not intersect. |
| push | Shield_Push_Left (220) | 89 | Shield_Push_Left: left forearm shove; read as an off-hand axe-haft shove. Right axe low. |
| dodge | Stand_Dodge (156) | 52 | Stand_Dodge sidestep; axes passive. |
| downed | Knock_Down (187) | 94 | Knock_Down; axes stay in hands while on the ground (detach/drop is optional in Godot). |
| death | dying_backwards (189) | 82 | dying_backwards; recommend detaching both axes on impact to avoid clipping into the floor. |
| interact | open_door (285) | 195 | open_door; right hand reaches with the axe still in it. Custom: hide R axe or tuck it in the belt during interact. |
| sit | Chair_Sit_Idle_M (33) | 400 | Chair_Sit_Idle_M; axes rest across the knees (clips into thighs). Custom: unequip for sit. |
| victory | Victory_Fist_Pump (403) | 56 | Victory_Fist_Pump: right axe pumped up; left mirrors low. Custom: both axes up. |
| ironjaw_axe_stance | Axe_Stance (85) | 229 | Axe_Stance (single-axe transition): right axe forward guard; Custom: mirror left arm to hold the second axe forward-low. |
| ironjaw_axe_spin | Axe_Spin_Attack (238) | 94 | Axe_Spin_Attack single-axe: right axe leads; left arm is extended in the spin, so the left axe naturally adds a second arc (reads as a dual spin). |
| ironjaw_double_blade_spin | Double_Blade_Spin (91) | 212 | Double_Blade_Spin: authored for two blades, both axes work as-is. Signature dual clip. |
| ironjaw_ground_slam | Charged_Ground_Slam (127) | 112 | Charged_Ground_Slam: right arm slams; Custom: drive both axes into the ground together for the brute read. |
| ironjaw_taunt | Chest_Pound_Taunt (88) | 181 | Chest_Pound_Taunt: pounding with fists clips the axe heads into the chest. Custom: pound with haft butts, or hide axes. |
| ironjaw_jump | Regular_Jump (466) | 69 | Regular_Jump; axes passive. Custom: axes up on the landing for weight. |
| ironjaw_climb | Ladder_Climb_Loop (438) | 59 | Ladder_Climb_Loop; axes would clip ladder rungs. Custom: holster both on the back while climbing. |

## Known weaknesses

- Grip (v2): the fist is now a fixed sculpted shape. There are still no finger bones, so the hand can't open (no open hand for interact/climb; holster covers those). The thumb is part of the mitten and isn't wrapped separately.
- Single-axe bases (chop, axe stance, axe spin, ground slam, cast, victory, turn_l): the left arm was not authored for a weapon, so the second axe is passive. The custom tweaks are listed per clip.
- Clipping: taunt (heads into chest), sit (thighs), block (hafts cross), climb (no ladder holster), death/downed (axes into floor).
- In place: Hips horizontal motion flattened on all clips, but root ROTATION is kept, so the turns and some attacks end rotated. downed/death show a mid-air frame from the flattened fly-back.
- Textures: only baseColor survived the rig. Normal/ORM were lost, so the armour reads flatter than the concept, and the oxblood cape came out darker.
- Axe concept: itm_ironjaw_weapons_CONCEPTO_.png actually contains a stone wall image, so the axe was made with Meshy text-to-3D from the 'double-bit axe' spec rather than from an approved image. It needs Mauro's eye.
- Armature node scale 0.01 (cm bones). Fine in Godot, but the build agent may want to apply it on import.
- Missing from SkeletonProfileHumanoid: fingers, jaw, eyes.