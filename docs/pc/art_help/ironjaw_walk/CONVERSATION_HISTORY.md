# Ironjaw HD: decisions from Luca's conversation with Scenario Art (condensed, oldest first)

- 2026-10-03: Luca locked the Ironjaw HD look. Front (S) is the raw blackened-steel repaint (no crimson armor; crimson only on the cape and loincloth). Back (E) is a bulky three-quarter back turned up-right, with blackened steel, wide spiked shoulders, short heavy legs, a ragged crimson cape and skull axes held out from the body. He approved the full 64-frame set.
- A slightly warmer edge light on the shoulders and helm (Technical Artist's idea) keeps him from sinking into dark ground.
- Attack, hit, death and idle (front and back) were painted from 3/4 sheets and pass QA 80/80 (hd_set_idle/set_contact_1x.png, facing_check_v4hd.png).
- Walk: per-frame image-model painting failed 5 times (stiff, legs drift). Luca chose a 3D walk guide from Technical Artist. Painting over the guide frame by frame drifted the leg phase, so I built a cutout rig of painted parts posed from TA's joints.
- Hold approved by Luca (refs/luca_hold_reference.png): fists clenched on the handles at belt height, handles forward and down, blades vertical, near axe raised level with the far one. TA baked this into the joints (10/03 ~22:50-22:55).
- 10/03 10:34 PM: walk rig v1 shown. The back-view arms stuck out sideways and the front near axe crossed the belt.
- 10/03 ~11 PM: rig v2 built on TA's fixed joints (elbows by the ribs, near axe outside the right thigh). Automated QA passes 48/48.
- 10/04 3:52 AM, Luca: "the walking is perfect but you messed up everything else." Asked what's wrong, he said "All of the above": the look doesn't match the approved HD Ironjaw, plus the arms and fists, the axes and hold, the cape and the back view overall.
- 10/04 3:55 AM: two full repaints in the HD look over the v2 f00 poses (repaint_targets/). Look is right, but the painter narrowed the stride.
- 10/04 3:57 AM, Luca: "Dont stop until you match 85% to 100% these pictures."
- 10/04 4:03 AM, Luca: ask Claude for help, give him everything, walk and look at 85-100% match.
