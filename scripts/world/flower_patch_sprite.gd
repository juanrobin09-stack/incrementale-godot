class_name FlowerPatchSprite
extends PixelDrawer
## Direct translation of drawFlowerPatch() from render.js.

var seed_val: float

func setup(p_seed: float) -> void:
	seed_val = p_seed
	queue_redraw()

func _draw() -> void:
	var colors := [Color("#f472b6"), Color("#fbbf24"), Color("#f87171"), Color("#c084fc")]
	var leaf_mid: Color = Palette.c("leafMid")
	for i in range(3):
		var dx: float = (seeded(seed_val + i) - 0.5) * 10.0
		var c: Color = colors[int(floor(seeded(seed_val + i + 9) * colors.size()))]
		px_rect(dx, -2, 2, 2, leaf_mid)
		px_rect(dx, -3, 1, 1, c)
		px_rect(dx + 1, -3, 1, 1, c)
