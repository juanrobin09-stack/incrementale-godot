class_name FenceSprite
extends PixelDrawer
## Direct translation of drawFence() from render.js (sway=0 — that's a
## wind-reactive term for a later pass). Position anchors the fence's
## LEFT edge (not its center), matching the original's `x` parameter.

var w: float

func setup(p_w: float) -> void:
	w = p_w
	queue_redraw()

func _draw() -> void:
	var post_count: int = max(3, int(round(w / 8.0)))
	var gap: float = w / post_count
	px_rect(0, -6, w, 2, Palette.c("wood"))
	var wood_dark: Color = Palette.c("woodDark")
	for i in range(post_count + 1):
		px_rect(i * gap, -9, 2, 9, wood_dark)
