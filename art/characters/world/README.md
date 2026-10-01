# PC world characters

Copies for the Crosshaven walker on `main`. The mobile branch is unchanged.

Source commit: `d9ec4044c98581805cce2a6732f89d0de95fbb83` (mobile 0.1.61, "Mobile 0.1.61: Berserker Ironjaw kept, Stills test fix").

Copied read-only from `art/export_2x/characters/<class>/`:

- `anims/<class>_walk_{n,e,s,w}.png` — 864×160, six 144×160 cells, for ironjaw, kestrel, gloam, mender, bastion
- `idle/<class>_idle_plant_{n,e,s,w}_v1.png` — ironjaw and bastion only

Kestrel, Gloam, and Mender have no idle plant on mobile. Their idle frame is walk cell 0 (the foot-down plant).

## What changed on the PC copies

Mobile playback is six frames. These strips are twelve frames: each authored cell is kept, in the same order, and an in-between is inserted before the next cell (including the loop from cell 5 back to cell 0).

The in-between blends only the body. Pixels from y=128 down stay on the leading authored frame, with a 12px feather, so the soles do not double. There is no separate mobile run sheet. The run strip uses the same order with the airborne in-between's body lifted 3px; the feet stay planted.

The world walker does not play these strips on a clock. It picks the frame from distance traveled, one walk cycle per tile, and a longer stride while running. Facing stays the mobile four-direction lock (east, south, north, west). Pivot matches the mobile pawn: centered sprite, offset `(0, -72)` before scale.

Combat pawns still use `art/characters/<class>/` static facings. These files are only for the open-world walker.

`bake_world_strips.py` rebuilds the strips from an extract of that mobile commit.
