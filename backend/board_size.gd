class_name BoardSize
extends RefCounted

## Koliseo playable size. Mauro stamped 15×15 (12×12 superseded, 8×8 is proto only).
## Ship matches omit board_size and get SHIP. Proto fixtures pass PROTO or PROTO_12.

const SHIP := 15
const PROTO := 8
const PROTO_12 := 12


static func resolve(config: Dictionary, fallback: int = SHIP) -> int:
	var size := int(config.get("board_size", fallback))
	if size < 1:
		return fallback
	return size


static func is_proto_crop(size: int) -> bool:
	return size == PROTO
