extends Sprite2D

## Amber eyes. Hold open (frame 0) for a few seconds, then half, closed,
## half at 12 fps, then open again. The interval comes from the cell hash
## and shifts after each blink.

var frames: Array[Texture2D] = []
var hold := 3.0
var playing := false
var _t := 0.0
var _blink := -1.0


func arm(textures: Array, hold_s: float, animate: bool) -> void:
	frames = []
	for tex in textures:
		frames.append(tex)
	hold = hold_s
	playing = animate
	centered = true
	if frames.size() > 0:
		texture = frames[0]
	set_process(animate and frames.size() >= 4)


func _process(delta: float) -> void:
	if _blink < 0.0:
		_t += delta
		texture = frames[0]
		if _t < hold:
			return
		_blink = 0.0
		_t = 0.0
		return
	_blink += delta
	var step := int(_blink * 12.0)
	if step >= 3:
		_blink = -1.0
		texture = frames[0]
		hold = 2.0 + fmod(hold * 1.7 + 0.6, 3.0)
		return
	texture = frames[1 + step]
