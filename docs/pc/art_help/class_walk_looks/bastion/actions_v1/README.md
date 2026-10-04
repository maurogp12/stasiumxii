# Bastion actions v1: idle, attack, skill, hit and death

> **LOCKED, 4 Oct 2026, at `4677cadf`.** Mauro: "lock both of them as of right now, keep everything documented for a future modification." These frames ship to the game as they are. To change them later, read **Known issues for a future pass** below and the scripts in `scripts/`, then re-run the same pipeline. Don't hand-edit frames.

## Known issues for a future pass (recorded at lock)
- **Front death f06–f12:** reads as a heap rather than a body on its back. The pose is also lifted up to 12 px to stay inside the cell. Fix: paint a lying-on-back key.
- **Back death f12:** the mace sticks up into the air. It should lie flat on the ground.
- **Back attack f02/f05:** the mace tips back 43–44° so it doesn't cross the top of the cell, which makes the wind-up arc flatter than the blockout's.
- **Back skill f04–f09:** the mace tips back 13°, and the shield is hidden behind the body, as in the blockout.
- **Front attack f03/f04:** the raised upper arm is mostly hidden behind the shoulder plate, and the upturned fist is lit from below. The wind-up arm reads short.
- **Back hit f01–f03:** the shield is thrown out with only a sliver of arm showing.
- **Front idle look score:** 85.7, a thin margin. The blockout idle puts the other foot forward from the target.
- **Changes from the approved poses:**
  - the attack step goes forward and inward, so the front boot stays inside the cell;
  - the back death falls to his side;
  - the aim was fixed in our own `act_blockout.py`.
  The approved blockout files were not changed.
- **Painted parts:** the walk's painted parts (`parts_src`) were never in the repo, so these actions were rebuilt from the targets with the walk's polygons and scale.
