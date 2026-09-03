class_name TreeSprite
extends PixelDrawer
## Static tree (no wind bend) — direct translation of drawTreeStructure()
## from render.js with wind.force hardcoded to 0, which zeroes out
## every bend/sway/flutter term in the original formula and collapses
## it to this one fixed pose. `tree_type` is "round" (deciduous) or
## "pine". Wind sway/strain/falling is a later pass.

var tree_type: String
var width: float
var height: float

func setup(p_type: String, p_width: float, p_height: float) -> void:
	tree_type = p_type
	width = p_width
	height = p_height
	queue_redraw()

func _draw() -> void:
	var trunk_h: float = height * (0.32 if tree_type == "pine" else 0.42)
	var base_w: float = max(2.0, width * 0.16)
	var tip_w: float = max(1.0, base_w * 0.4)

	px_ellipse(0, 0, width * 0.32, width * 0.09, Color(30.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.25))
	var tip: Vector2 = px_tapered_bend(0, 0, trunk_h, base_w, tip_w, 0.0, Palette.c("trunk"), Palette.c("trunkDark"))

	var branch_defs: Array
	if tree_type == "pine":
		branch_defs = [
			{"hf": 0.35, "ang": -0.55, "len": 0.6},
			{"hf": 0.6, "ang": 0.5, "len": 0.55},
			{"hf": 0.85, "ang": -0.4, "len": 0.4},
		]
	else:
		branch_defs = [
			{"hf": 0.15, "ang": -0.7, "len": 0.85},
			{"hf": 0.55, "ang": 0.55, "len": 0.8},
			{"hf": 0.85, "ang": 0.15, "len": 0.55},
		]

	var trunk_dark: Color = Palette.c("trunkDark")
	var line_width: float = max(1.0, base_w * 0.32)
	var tips: Array[Vector2] = []
	for b in branch_defs:
		var base_y: float = -trunk_h * b["hf"]
		var angle: float = b["ang"]
		var len_: float = width * b["len"]
		var tx: float = sin(angle) * len_
		var ty: float = base_y - cos(angle) * len_
		draw_line(Vector2(0, base_y), Vector2(tx, ty), trunk_dark, line_width)
		tips.append(Vector2(tx, ty))

	if tree_type == "pine":
		var pine_light: Color = Palette.c("pineLight")
		var pine_dark: Color = Palette.c("pineDark")
		for i in range(3):
			var tier_h: float = height * 0.34
			var tier_top: float = -trunk_h - height * 0.62 + i * (height * 0.26)
			var hw: float = (width / 2.0) * (1.0 - i * 0.24)
			px_triangle_up_sheared(0, tier_top, tier_h, hw, 0.0, 0.0, pine_light, pine_dark)
		for tp in tips:
			px_circle(tp.x, tp.y, width * 0.12, pine_light, pine_dark)
	else:
		var leaf_light: Color = Palette.c("leafLight")
		var leaf_mid: Color = Palette.c("leafMid")
		px_circle(tip.x, tip.y - width * 0.18, width * 0.42, leaf_light, leaf_mid)
		for tp in tips:
			px_circle(tp.x, tp.y, width * 0.27, leaf_light, leaf_mid)
