class_name TreeSprite
extends PixelDrawer
## Tree with wind sway — direct translation of drawTreeStructure() from
## render.js, reading force/direction from a shared WindEngine each
## frame. The strain/fall/regrow state machine (a tree bending past its
## limit and coming down) is a separate follow-up pass, alongside house
## damage — this is "wind blows through the scene", not the disaster
## physics on top of it.

var tree_type: String
var width: float
var height: float
var flex: float
var seed_val: float
var wind: WindEngine

func setup(p_type: String, p_width: float, p_height: float, p_flex: float, p_seed: float, p_wind: WindEngine) -> void:
	tree_type = p_type
	width = p_width
	height = p_height
	flex = p_flex
	seed_val = p_seed
	wind = p_wind
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var bend_max: float = height * (0.22 if tree_type == "pine" else 0.30) * flex
	var bend: float = wind.direction * wind.force * bend_max
	var trunk_h: float = height * (0.32 if tree_type == "pine" else 0.42)
	var base_w: float = max(2.0, width * 0.16)
	var tip_w: float = max(1.0, base_w * 0.4)

	px_ellipse(0, 0, width * 0.32, width * 0.09, Color(30.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.25))
	var tip: Vector2 = px_tapered_bend(0, 0, trunk_h, base_w, tip_w, bend, Palette.c("trunk"), Palette.c("trunkDark"))

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
	for i in range(branch_defs.size()):
		var b = branch_defs[i]
		var base_y: float = -trunk_h * b["hf"]
		var base_bend: float = bend * pow(b["hf"], 1.6)
		var base_x: float = base_bend
		var flutter: float = 0.5 + 0.5 * sin(t * (3.2 + i * 0.7) + seed_val * 6.0 + i)
		var secondary: float = flutter * wind.force * wind.direction * flex * 0.35
		var angle: float = b["ang"] + secondary + bend * 0.01
		var len_: float = width * b["len"]
		var tx: float = base_x + sin(angle) * len_
		var ty: float = base_y - cos(angle) * len_
		draw_line(Vector2(base_x, base_y), Vector2(tx, ty), trunk_dark, line_width)
		tips.append(Vector2(tx, ty))

	if tree_type == "pine":
		var pine_light: Color = Palette.c("pineLight")
		var pine_dark: Color = Palette.c("pineDark")
		var trunk_tip_y: float = -trunk_h
		var tree_top_y: float = -trunk_h - height * 0.62
		var tip_bend: float = tip.x
		var apex_bend: float = tip_bend * 1.4
		for i in range(3):
			var tier_h: float = height * 0.34
			var tier_top: float = -trunk_h - height * 0.62 + i * (height * 0.26)
			var hw: float = (width / 2.0) * (1.0 - i * 0.24)
			var bend_at_bottom: float = _bend_at_y(tier_top + tier_h, trunk_tip_y, tree_top_y, tip_bend, apex_bend)
			var bend_at_top: float = _bend_at_y(tier_top, trunk_tip_y, tree_top_y, tip_bend, apex_bend)
			px_triangle_up_sheared(0, tier_top, tier_h, hw, bend_at_bottom, bend_at_top, pine_light, pine_dark)
		for tp in tips:
			px_circle(tp.x, tp.y, width * 0.12, pine_light, pine_dark)
	else:
		var leaf_light: Color = Palette.c("leafLight")
		var leaf_mid: Color = Palette.c("leafMid")
		px_circle(tip.x, tip.y - width * 0.18, width * 0.42, leaf_light, leaf_mid)
		for i in range(tips.size()):
			var tp: Vector2 = tips[i]
			var puff_flutter: float = 0.5 + 0.5 * sin(t * 6.0 + seed_val * 9.0 + i)
			var j: float = puff_flutter * wind.force * wind.direction * 1.2
			px_circle(tp.x + j, tp.y + j * 0.4, width * 0.27, leaf_light, leaf_mid)

func _bend_at_y(y: float, trunk_tip_y: float, tree_top_y: float, tip_bend: float, apex_bend: float) -> float:
	var f: float = clamp((trunk_tip_y - y) / (trunk_tip_y - tree_top_y), 0.0, 1.0)
	return tip_bend + (apex_bend - tip_bend) * f
