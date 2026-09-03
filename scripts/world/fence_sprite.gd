class_name FenceSprite
extends PixelDrawer
## Direct translation of drawFence() from render.js, reading sway from a
## shared WindEngine each frame (sway = wind.force * wind.direction * 2).
## Position anchors the fence's LEFT edge (not its center), matching the
## original's `x` parameter.

var w: float
var wind: WindEngine

func setup(p_w: float, p_wind: WindEngine) -> void:
	w = p_w
	wind = p_wind
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sway: float = wind.force * wind.direction * 2.0
	var post_count: int = max(3, int(round(w / 8.0)))
	var gap: float = w / post_count
	px_rect(0, -6 + sway * 0.3, w, 2, Palette.c("wood"))
	var wood_dark: Color = Palette.c("woodDark")
	for i in range(post_count + 1):
		px_rect(i * gap + sway * 0.2, -9, 2, 9, wood_dark)
