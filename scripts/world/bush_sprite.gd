class_name BushSprite
extends PixelDrawer
## Direct translation of drawBush() from render.js, reading sway from a
## shared WindEngine each frame (sway = wind.force * wind.direction * 3).

var r: float
var wind: WindEngine

func setup(p_r: float, p_wind: WindEngine) -> void:
	r = p_r
	wind = p_wind
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sway: float = wind.force * wind.direction * 3.0
	var leaf_light: Color = Palette.c("leafLight")
	var leaf_mid: Color = Palette.c("leafMid")
	px_circle(sway, -r * 0.7, r, leaf_light, leaf_mid)
	px_circle(-r * 0.6 + sway * 0.7, -r * 0.5, r * 0.6, leaf_light, leaf_mid)
	px_circle(r * 0.6 + sway * 0.7, -r * 0.5, r * 0.6, leaf_light, leaf_mid)
