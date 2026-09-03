class_name LampPostSprite
extends PixelDrawer
## Direct translation of drawLampPost() from render.js, unlit — lighting
## up at night/storm is a later pass alongside the rest of weather.

var h: float

func setup(p_h: float) -> void:
	h = p_h
	queue_redraw()

func _draw() -> void:
	px_rect(-1, -h, 2, h, Color("#333a40"))
	px_rect(-3, -h - 3, 6, 4, Color("#2a2f34"))
	px_rect(-2, -h - 2, 4, 3, Color("#8a8f94"))
