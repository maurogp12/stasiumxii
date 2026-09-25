class_name BoardSize
extends RefCounted

## Koliseo playable size. Rules Keeper + Mauro: ship is 12×12. 8×8 is proto only.
## Ship matches omit board_size and get SHIP. Proto fixtures pass PROTO.

const SHIP := 12
const PROTO := 8


static func resolve(config: Dictionary, fallback: int = SHIP) -> int:
	var size := int(config.get("board_size", fallback))
	if size < 1:
		return fallback
	return size


static func is_proto_crop(size: int) -> bool:
	return size == PROTO
