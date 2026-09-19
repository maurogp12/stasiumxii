class_name IntentCodec
extends RefCounted

## Encode / decode Intent + host state for ENet RPC and headless JSON tests.
## Vector2i becomes a tagged dict. Dictionary keys that are cells become "x,y".
## Does not invent rolls, legality, or transport.

const V2I_TAG := "__v2i"


static func encode_intent(intent: Dictionary) -> Dictionary:
	return encode(intent) as Dictionary


static func decode_intent(payload: Dictionary) -> Dictionary:
	var decoded: Variant = decode(payload)
	if typeof(decoded) != TYPE_DICTIONARY:
		return {}
	return decoded


static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I:
			var cell: Vector2i = value
			return {V2I_TAG: true, "x": cell.x, "y": cell.y}
		TYPE_DICTIONARY:
			var encoded := {}
			for key in value:
				encoded[_encode_key(key)] = encode(value[key])
			return encoded
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(encode(item))
			return items
		_:
			return value


static func decode(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		if bool(dict.get(V2I_TAG, false)) and dict.has("x") and dict.has("y"):
			return Vector2i(int(dict["x"]), int(dict["y"]))
		var decoded := {}
		for key in dict:
			decoded[_decode_key(key)] = decode(dict[key])
		return decoded
	if typeof(value) == TYPE_ARRAY:
		var items: Array = []
		for item in value:
			items.append(decode(item))
		return items
	return value


static func to_json(value: Variant) -> String:
	return JSON.stringify(encode(value))


static func from_json(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	return decode(parsed)


static func _encode_key(key: Variant) -> Variant:
	if key is Vector2i:
		var cell: Vector2i = key
		return "%d,%d" % [cell.x, cell.y]
	if typeof(key) == TYPE_INT:
		return key
	return key


static func _decode_key(key: Variant) -> Variant:
	if typeof(key) == TYPE_INT:
		return key
	if typeof(key) != TYPE_STRING:
		return key
	var raw := str(key)
	if raw.is_valid_int():
		return int(raw)
	var parts := raw.split(",")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return raw
