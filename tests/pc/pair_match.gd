extends RefCounted

## One match for every before/after pair. Both sides boot from this seed,
## these seats and these facings, so zone cells, fighters and the camera
## cannot drift between the frames. Claude's L7 nit on the Thunderwell pair:
## a second seed put the deploy zones in different cells.

const SEED := 1
const KESTREL := Vector2i(7, 7)
const IRONJAW := Vector2i(9, 7)
const KESTREL_FACING := "E"
const IRONJAW_FACING := "W"


static func args(map_id: String, extra: Dictionary = {}) -> Dictionary:
	var out := {
		"seed": SEED,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": KESTREL,
		"ironjaw_pos": IRONJAW,
		"kestrel_facing": KESTREL_FACING,
		"ironjaw_facing": IRONJAW_FACING,
	}
	for key in extra.keys():
		out[key] = extra[key]
	return out
