class_name WellSprite
extends PixelDrawer
## Direct translation of drawWell() from render.js.

var r: float

func setup(p_r: float) -> void:
	r = p_r
	queue_redraw()

func _draw() -> void:
	px_circle(0, -r * 0.5, r, Palette.c("stoneLight"), Palette.c("stoneDark"))
	px_circle(0, -r * 0.5, r * 0.6, Color("#3a4048"), Color("#20242a"))
	px_triangle_up(0, -r * 2.4, r * 1.2, r * 1.5, Palette.c("roofRed"), Palette.c("roofRedShadow"))
	var wood_dark: Color = Palette.c("woodDark")
	px_rect(-r * 0.9, -r * 1.3, 2, r * 0.8, wood_dark)
	px_rect(r * 0.9 - 2, -r * 1.3, 2, r * 0.8, wood_dark)
