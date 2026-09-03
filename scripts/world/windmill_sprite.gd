class_name WindmillSprite
extends PixelDrawer
## Windmill with live wind-driven blade rotation and wind-stress damage
## — direct translation of drawWindmill()/drawWindmillRubble()/
## drawWindmillByStress()/updateWindmillDamage() from render.js.
##
## Note the original's own two-tier design here (kept as-is, it isn't
## the "respawning" case TreeSprite/HouseSprite deliberately drop):
## rubble is shown once stress crosses 0.90, and stress can still rise
## or fall freely below 1.0 — including dropping back under 0.90 and
## un-rendering the rubble — right up until it actually maxes out at
## 1.0. Only THAT point (truly, permanently destroyed) stops updating
## for good; the 0.90–1.0 range is "teetering", not "destroyed".

const WINDMILL_CUT := 0.90

var h: float
var wind: WindEngine
var entities_parent: Node2D

var _windmill_angle: float = 0.0
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false

func setup(p_h: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	h = p_h
	wind = p_wind
	entities_parent = p_entities_parent
	queue_redraw()

func _process(delta: float) -> void:
	_update_blade_angle(delta)
	_update_stress(delta)
	queue_redraw()

func _update_blade_angle(delta: float) -> void:
	var wind_level: int = GameState.compute_stage("wind")
	var base_speeds := [0.0, 1.4, 3.2, 6.0]
	var base_speed: float = base_speeds[wind_level] if wind_level < base_speeds.size() else 0.0
	var speed: float = base_speed + wind.force * 2.2
	_windmill_angle += speed * delta * wind.direction

func _update_stress(delta: float) -> void:
	if _collapsed:
		return
	var wind_level: int = GameState.compute_stage("wind")
	var extreme: bool = wind_level >= 3 and wind.force > 0.9
	if extreme:
		_stress += delta * 0.12 * (wind.force - 0.9)
	else:
		_stress -= delta * 0.04
	_stress = clamp(_stress, 0.0, 1.0)

	var dir: float = wind.direction if wind.direction != 0.0 else 1.0

	if _last_stress < 0.35 and _stress >= 0.35:
		DebrisSpawner.burst(entities_parent, position.x - h * 0.15, position.y - h * 0.2,
			3, [Palette.c("wood"), Palette.c("woodDark"), Palette.c("rubbleWood")], h * 0.3, dir)
	if _last_stress < 0.55 and _stress >= 0.55:
		DebrisSpawner.burst(entities_parent, position.x, position.y - h * 0.85,
			4, [Color("#f4ede0"), Palette.c("roofRed"), Palette.c("roofRedShadow")], h * 0.4, dir)
	if _last_stress < 0.75 and _stress >= 0.75:
		DebrisSpawner.burst(entities_parent, position.x, position.y - h * 0.5,
			8, [Palette.c("stone"), Palette.c("stoneDark"), Palette.c("roofRed"), Palette.c("rubbleWood")], h * 0.7, dir)
	if _last_stress < WINDMILL_CUT and _stress >= WINDMILL_CUT:
		DebrisSpawner.burst(entities_parent, position.x, position.y - h * 0.3,
			9, [Palette.c("stone"), Palette.c("stoneDark"), Palette.c("wood"), Palette.c("rubbleWoodDark")], h * 0.8, dir)
		DebrisSpawner.dust(entities_parent, position.x, position.y + 2.0, 3.0, h * 0.55, 1.1)
	if _stress >= 1.0:
		_collapsed = true
	_last_stress = _stress

func _draw() -> void:
	if _stress >= WINDMILL_CUT:
		_draw_rubble()
		return

	var tower_base_w: float = h * 0.30
	var tower_top_w: float = h * 0.19
	var tower_top: float = -h

	px_tapered_bend(0, 0, h, tower_base_w, tower_top_w, 0.0, Palette.c("stone"), Palette.c("stoneDark"))

	var seam_hw: float = (tower_base_w + (tower_top_w - tower_base_w) * 0.25) / 2.0
	px_rect(-seam_hw, -h * 0.25, seam_hw * 2, 1, Palette.c("stoneDark"))

	var win_hw: float = (tower_base_w + (tower_top_w - tower_base_w) * 0.70) * 0.28
	var win_y: float = -h * 0.70
	px_rect(-win_hw - 1, win_y - win_hw - 1, win_hw * 2 + 2, win_hw * 2 + 2, Palette.c("windowFrame"))
	px_rect(-win_hw, win_y - win_hw, win_hw * 2, win_hw * 2, Palette.c("windowGlass"))

	var roof_cap_h: float = h * 0.28
	px_triangle_up(0, tower_top - roof_cap_h, roof_cap_h, tower_top_w / 2.0 + 2, Palette.c("roofRed"), Palette.c("roofRedShadow"))

	var shed_w: float = h * 0.30
	var shed_wall_h: float = h * 0.20
	var shed_roof_h: float = h * 0.11
	var shed_x: float = -tower_base_w / 2.0 - shed_w / 2.0 + 3.0
	px_rect(shed_x - shed_w / 2.0, -shed_wall_h, shed_w, shed_wall_h, Palette.c("wood"))
	px_rect(shed_x + shed_w / 2.0 - shed_w * 0.16, -shed_wall_h, shed_w * 0.16, shed_wall_h, Palette.c("woodDark"))
	var door_w: float = shed_w * 0.32
	var door_h: float = shed_wall_h * 0.62
	px_rect(shed_x - door_w / 2.0, -door_h, door_w, door_h, Palette.c("door"))
	px_rect(shed_x - door_w / 2.0, -door_h, 1, door_h, Palette.c("doorShadow"))
	px_triangle_up(shed_x, -shed_wall_h - shed_roof_h, shed_roof_h, shed_w / 2.0 + 1.5, Palette.c("roofRed"), Palette.c("roofRedShadow"))

	var brace_h: float = h * 0.36
	var brace_base_x: float = tower_base_w / 2.0 + 3.0
	var brace_tip_x: float = (tower_base_w + (tower_top_w - tower_base_w) * 0.36) / 2.0
	var brace_tip_y: float = -brace_h
	var brace_dx: float = brace_tip_x - brace_base_x
	var brace_dy: float = brace_tip_y
	px_rotated_rect((brace_base_x + brace_tip_x) / 2.0, brace_tip_y / 2.0,
		sqrt(brace_dx * brace_dx + brace_dy * brace_dy), 2.4, atan2(brace_dy, brace_dx), Palette.c("woodDark"))

	var hub_y: float = tower_top + h * 0.05
	_draw_blades(hub_y)
	px_circle(0, hub_y, 2.4, Palette.c("stone"), Palette.c("stoneDark"))

func _draw_blades(hub_y: float) -> void:
	var blade_len: float = h * 0.30
	var min_hw: float = 1.0
	var max_hw: float = 3.4
	var blade_colors := [
		{"body": Color("#f4ede0"), "tip": Palette.c("wallCreamShadow")},
		{"body": Palette.c("roofRed"), "tip": Palette.c("roofRedShadow")},
	]
	for i in range(4):
		draw_set_transform(Vector2(0, hub_y), _windmill_angle + (PI / 2.0) * i)
		var col = blade_colors[i % 2]
		var steps: int = 8
		for s in range(steps):
			var t0: float = float(s) / steps
			var t1: float = float(s + 1) / steps
			var hw: float = min_hw + (max_hw - min_hw) * t1
			draw_rect(Rect2(blade_len * t0, -hw, blade_len * (t1 - t0) + 0.5, hw * 2), col["body"])
		var tip_w: float = blade_len * 0.22
		draw_rect(Rect2(blade_len - tip_w, -max_hw, tip_w, max_hw * 2), col["tip"])
	draw_set_transform(Vector2.ZERO, 0.0)

func _draw_rubble() -> void:
	var stump_h: float = h * 0.26
	var stump_base_w: float = h * 0.30
	var stump_top_w: float = h * 0.25
	px_tapered_bend(0, 0, stump_h, stump_base_w, stump_top_w, 0.0, Palette.c("stone"), Palette.c("stoneDark"))
	var stone_dark: Color = Palette.c("stoneDark")
	px_rect(-stump_top_w * 0.32, -stump_h - 2, stump_top_w * 0.4, 3, stone_dark)
	px_rect(stump_top_w * 0.02, -stump_h - 4, stump_top_w * 0.28, 5, stone_dark)

	px_rect(-h * 0.42, -2, h * 0.84, 2, Palette.c("rubbleWoodDark"))
	var chunks := [
		{"dx": -0.30, "dw": 0.20, "dh": 0.5, "c": Palette.c("stoneDark")},
		{"dx": 0.24, "dw": 0.22, "dh": 0.36, "c": Palette.c("roofRed")},
		{"dx": -0.06, "dw": 0.16, "dh": 0.28, "c": Palette.c("roofRedShadow")},
		{"dx": 0.36, "dw": 0.14, "dh": 0.22, "c": Palette.c("wood")},
		{"dx": -0.20, "dw": 0.13, "dh": 0.20, "c": Palette.c("rubbleWood")},
	]
	for c in chunks:
		var cw: float = h * c["dw"]
		var ch: float = h * c["dh"] * 0.4
		px_rect(h * c["dx"] - cw / 2.0, -ch, cw, ch, c["c"])
	px_rect(-h * 0.40, -3, h * 0.15, 3, Color("#f4ede0"))
	px_rect(h * 0.18, -3, h * 0.13, 3, Palette.c("roofRed"))
