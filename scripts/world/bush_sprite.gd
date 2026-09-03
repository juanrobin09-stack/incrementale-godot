class_name BushSprite
extends PixelDrawer
## Direct translation of drawBush() from render.js (sway=0 — wind-
## reactive term for a later pass).

var r: float

func setup(p_r: float) -> void:
	r = p_r
	queue_redraw()

func _draw() -> void:
	var leaf_light: Color = Palette.c("leafLight")
	var leaf_mid: Color = Palette.c("leafMid")
	px_circle(0, -r * 0.7, r, leaf_light, leaf_mid)
	px_circle(-r * 0.6, -r * 0.5, r * 0.6, leaf_light, leaf_mid)
	px_circle(r * 0.6, -r * 0.5, r * 0.6, leaf_light, leaf_mid)
