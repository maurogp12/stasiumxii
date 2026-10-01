# PC world characters

Copies for the Crosshaven walker on `main`. The mobile branch is unchanged.

Source commit: `d9ec4044c98581805cce2a6732f89d0de95fbb83` (mobile 0.1.61, "Mobile 0.1.61: Berserker Ironjaw kept, Stills test fix").

Copied read-only from `art/export_2x/characters/<class>/`:

- `anims/<class>_walk_{n,e,s,w}.png` — 864×160, six 144×160 cells, for ironjaw, kestrel, gloam, mender, bastion
- `idle/<class>_idle_plant_{n,e,s,w}_v1.png` — ironjaw and bastion only

Kestrel, Gloam, and Mender have no idle plant on mobile. Their idle frame is walk cell 0 (the foot-down plant).

## What changed on the PC copies

Mobile playback is six frames. These strips are twelve frames: each authored cell is kept, in the same order, and an in-between is inserted before the next cell (including the loop from cell 5 back to cell 0).

The in-between is a 35% mix of the next pose after that pose is shifted onto the current torso, so the axes and cape do not double. Pixels from y=128 down stay on the leading authored frame, with a 12px feather. The body of that in-between is then lifted (3px walk, 7px run) and swayed sideways by 2px / 3px on alternating steps. There is no separate mobile run sheet. The run strip is this same order with the taller loft and a wider sway. The feet stay planted.

The world walker does not play these strips on a clock. It picks the frame from distance traveled, one walk cycle per tile, and a longer stride while running. Each step holds the planted frame at the start and end, and shows the lifted in-between through the middle of the step. Facing stays the mobile four-direction lock (east, south, north, west). Pivot matches the mobile pawn: centered sprite, offset `(0, -72)` before scale.

Combat pawns still use `art/characters/<class>/` static facings. These files are only for the open-world walker.

`bake_world_strips.py` rebuilds the strips from an extract of that mobile commit.
