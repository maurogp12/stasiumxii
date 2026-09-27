Brinewake coast punch, Soft Lock agua + costa.

`brine_ground_punch.png`, `brine_elevation_punch.png`, and `brine_props_punch.png` are the source sheets. `slice_brine_punch.py` writes `brine_*` terrain and `brine_prop_*` from them.

Wet sand, pier wood, and tide scorch. Foam stays on the diamond seams. Props on `brine_props_punch.png` are sliced to about one tile. The elevation sheet is on hold: the upper-corner wooden deck (stairs, crates, and rope) is marked for removal, so `slice_brine_punch.py` does not overwrite the cliff tiles from it. The sheets are not a pending hook, and they do not change tags or geometry.
