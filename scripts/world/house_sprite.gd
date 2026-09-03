class_name HouseSprite
extends PixelDrawer
## Static, undamaged house — direct translation of drawHouseBody() (at
## rooflessT=0, crackT=0) + drawRoof() from render.js. Position is set
## externally to (x, groundY); everything below draws relative to that
## bottom-center ground-contact point, matching the original's anchor
## convention. Wind-damage states (cracks, lost roof, collapse) are a
## later pass, alongside the wind-physics engine they depend on.

var w: float
var wall_h: float
var roof_h: float
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color

func setup(p_w: float, p_wall_h: float, p_roof_h: float, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color) -> void:
	w = p_w
	wall_h = p_wall_h
	roof_h = p_roof_h
	wall_color = p_wall
	wall_shadow_color = p_wall_shadow
	roof_color = p_roof
	roof_shadow_color = p_roof_shadow
	queue_redraw()

func _draw() -> void:
	_draw_body()
	_draw_roof()

func _draw_body() -> void:
	var left: float = -w / 2.0
	var wall_top: float = -wall_h
	var shadow_w: float = max(2.0, round(w * 0.12))

	px_rect(left - 1, -1, w + 2, 2, Palette.c("stoneDark"))

	px_rect(left, wall_top, w, wall_h, wall_color)
	px_rect(left + w - shadow_w, wall_top, shadow_w, wall_h, wall_shadow_color)

	var wood_dark: Color = Palette.c("woodDark")
	px_rect(left, wall_top, 2, wall_h, wood_dark)
	px_rect(left + w - 2, wall_top, 2, wall_h, wood_dark)
	px_rect(left + w * 0.46, wall_top, 2, wall_h, wood_dark)
	px_rect(left + w * 0.78, wall_top, 2, wall_h, wood_dark)
	px_rect(left, wall_top + wall_h * 0.5, w, 2, wood_dark)
	px_rect(left, -2, w, 2, wood_dark)

	var chimney_x: float = round(w * 0.22)
	var chimney_w: float = max(2.0, round(w * 0.11))
	var chimney_top_y: float = wall_top - roof_h * 0.6
	var chimney_h: float = roof_h * 0.55 + wall_h * 0.15
	px_rect(chimney_x, chimney_top_y, chimney_w, chimney_h, Palette.c("stoneDark"))
	px_rect(chimney_x, chimney_top_y, chimney_w, 1, Palette.c("stoneLight"))

	var door_w: float = max(3.0, round(w * 0.2))
	var door_h: float = round(wall_h * 0.5)
	var door_x: float = -round(w * 0.3)
	px_rect(door_x, -door_h, door_w, door_h, Palette.c("door"))
	px_rect(door_x, -door_h, 1, door_h, Palette.c("doorShadow"))
	px_rect(door_x + door_w - 2, -door_h * 0.45, 1, 1, Palette.c("gold"))

	var win_size: float = max(3.0, round(w * 0.16))
	var win_x: float = round(w * 0.02)
	var win_y: float = wall_top + round(wall_h * 0.22)
	var window_frame: Color = Palette.c("windowFrame")
	px_rect(win_x - 1, win_y - 1, win_size + 2, win_size + 2, window_frame)
	px_rect(win_x, win_y, win_size, win_size, Palette.c("windowGlass"))
	px_rect(win_x, win_y, win_size, 1, Color.WHITE)
	var mid: float = round(win_size / 2.0)
	px_rect(win_x + mid, win_y, 1, win_size, window_frame)
	px_rect(win_x, win_y + mid, win_size, 1, window_frame)

func _draw_roof() -> void:
	var overhang: float = max(2.0, w * 0.10)
	var hw: float = w / 2.0 + overhang
	var wall_top: float = -wall_h

	px_triangle_up(0, wall_top - roof_h, roof_h, hw, roof_color, roof_shadow_color)

	draw_line(Vector2(0, wall_top - roof_h), Vector2(-hw * 0.52, wall_top - roof_h * 0.06), roof_shadow_color, 1.0)
	draw_line(Vector2(0, wall_top - roof_h), Vector2(hw * 0.52, wall_top - roof_h * 0.06), roof_shadow_color, 1.0)

	px_rect(-hw, wall_top - 2, hw * 2, 2, roof_shadow_color)

	var rows: int = 5
	for i in range(1, rows + 1):
		var f: float = float(i) / (rows + 1)
		var row_y: float = (wall_top - roof_h) + roof_h * f
		var row_hw: float = hw * f
		px_rect(-row_hw, row_y, row_hw * 2, 1, roof_shadow_color)
