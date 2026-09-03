class_name WindmillSprite
extends PixelDrawer
## Static windmill, blade angle frozen at 0 — direct translation of
## drawWindmill() from render.js with windLevel=0, wind.force=0, dt=0.
## Wind-driven rotation and the stress/collapse rubble state are a
## later pass, alongside the wind-physics engine they depend on.

var h: float

func setup(p_h: float) -> void:
	h = p_h
	queue_redraw()

func _draw() -> void:
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
		draw_set_transform(Vector2(0, hub_y), (PI / 2.0) * i)
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
