class_name HouseSprite
extends PixelDrawer
## House with wind-stress damage — direct translation of
## drawHouseBody()/drawRoof()/drawRubble()/drawHouseByStress()/
## updateHouse() from render.js, EXCEPT: the original's stress-decay-
## then-uncollapse recovery cycle (a fully collapsed house eventually
## rebuilding itself) is deliberately not ported, matching the same
## "no respawning from destruction" decision as TreeSprite — once
## `_stress` reaches 1.0, the house is permanently collapsed. The
## pre-collapse stress fluctuation (cracks worsening/healing as wind
## rises/calms, never having fully collapsed) is kept exactly as the
## original, since that's normal stress response, not resurrection.

var w: float
var wall_h: float
var roof_h: float
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color
var resilience: float
var wind: WindEngine
var entities_parent: Node2D

var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false

func setup(p_w: float, p_wall_h: float, p_roof_h: float, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color,
		p_resilience: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	w = p_w
	wall_h = p_wall_h
	roof_h = p_roof_h
	wall_color = p_wall
	wall_shadow_color = p_wall_shadow
	roof_color = p_roof
	roof_shadow_color = p_roof_shadow
	resilience = p_resilience
	_house_seed = p_seed
	wind = p_wind
	entities_parent = p_entities_parent
	queue_redraw()

func _process(delta: float) -> void:
	_update_stress(delta)
	queue_redraw()

func _update_stress(delta: float) -> void:
	if _collapsed:
		return
	var wind_level: int = GameState.compute_stage("wind")
	var extreme: bool = wind_level >= 3 and wind.force > 0.6
	if extreme:
		_stress += delta * 0.055 * (wind.force - 0.5) * resilience
	else:
		_stress -= delta * 0.03
	_stress = clamp(_stress, 0.0, 1.0)

	var dir: float = wind.direction if wind.direction != 0.0 else 1.0

	if _last_stress < 0.65 and _stress >= 0.65:
		DebrisSpawner.burst(entities_parent, position.x + w * 0.25, position.y - wall_h,
			5, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], w * 0.5, dir)
	if _last_stress < 0.90 and _stress >= 0.90:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4,
			10, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], w * 0.9, 1.0)
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4, 0, [], 0.0, -1.0)
	var jitter: float = (seeded(_house_seed + 12) - 0.5) * 0.02
	if _last_stress < 0.93 + jitter and _stress >= 0.93 + jitter:
		DebrisSpawner.burst(entities_parent, position.x + (seeded(_house_seed + 20) - 0.5) * w * 0.6, position.y - wall_h * 0.65,
			3, [wall_color, wall_shadow_color, Palette.c("rubbleWood")], w * 0.25, dir)
	if _last_stress < 0.985 + jitter and _stress >= 0.985 + jitter:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.35,
			9, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], w * 0.8, dir)
		DebrisSpawner.dust(entities_parent, position.x, position.y + 2.0, 3.0, w * 0.6, 1.1)
	if _stress >= 1.0:
		_collapsed = true
	_last_stress = _stress

func _draw() -> void:
	var crack_t: float = clamp((_stress - 0.40) / 0.25, 0.0, 1.0)
	var roofless_t: float = clamp((_stress - 0.65) / 0.25, 0.0, 1.0)
	var collapse_t: float = clamp((_stress - 0.90) / 0.10, 0.0, 1.0)

	if collapse_t > 0.01:
		var cut_point: float = 0.985 + (seeded(_house_seed + 12) - 0.5) * 0.02
		if _stress < cut_point:
			_draw_body(roofless_t, crack_t)
		else:
			_draw_rubble()
		return

	_draw_body(roofless_t, crack_t)
	_draw_roof(1.0 - roofless_t)

func _draw_body(roofless_t: float, crack_t: float) -> void:
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

	if roofless_t > 0.01:
		var attic: Color = Palette.c("attic")
		var attic_a := Color(attic.r, attic.g, attic.b, roofless_t)
		px_triangle_up(0, wall_top - roof_h * 0.75, roof_h * 0.75, w / 2.0 - 1.0, attic_a, attic_a)
		var rd: Color = Palette.c("rubbleWoodDark")
		var rd_a := Color(rd.r, rd.g, rd.b, roofless_t)
		px_rect(-w * 0.18, wall_top - roof_h * 0.7, 2, roof_h * 0.7, rd_a)
		px_rect(w * 0.12, wall_top - roof_h * 0.5, 2, roof_h * 0.5, rd_a)

	var chimney_x: float = round(w * 0.22)
	var chimney_w: float = max(2.0, round(w * 0.11))
	var chimney_top_y: float = wall_top - roof_h * (0.6 - roofless_t * 0.35)
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

	if crack_t > 0.01:
		var crack_color := Color(35.0 / 255.0, 25.0 / 255.0, 20.0 / 255.0, 0.7 * crack_t)
		_draw_crack_line(-w * 0.1, wall_top + wall_h * 0.15, _house_seed, wall_h * 0.7, w * 0.14, crack_color)
		if crack_t > 0.5:
			_draw_crack_line(w * 0.22, wall_top + wall_h * 0.3, _house_seed + 4.0, wall_h * 0.5, w * 0.1, crack_color)

func _draw_crack_line(x: float, y: float, seed: float, length: float, wobble: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(x, y))
	var steps: int = 4
	for i in range(1, steps + 1):
		var yy: float = y + (length * i) / steps
		var xx: float = x + (seeded(seed + i) - 0.5) * wobble
		points.append(Vector2(xx, yy))
	draw_polyline(points, color, 1.0)

func _draw_roof(alpha: float) -> void:
	if alpha <= 0.01:
		return
	var overhang: float = max(2.0, w * 0.10)
	var hw: float = w / 2.0 + overhang
	var wall_top: float = -wall_h

	var roof_c := Color(roof_color.r, roof_color.g, roof_color.b, alpha)
	var roof_s := Color(roof_shadow_color.r, roof_shadow_color.g, roof_shadow_color.b, alpha)

	px_triangle_up(0, wall_top - roof_h, roof_h, hw, roof_c, roof_s)

	draw_line(Vector2(0, wall_top - roof_h), Vector2(-hw * 0.52, wall_top - roof_h * 0.06), roof_s, 1.0)
	draw_line(Vector2(0, wall_top - roof_h), Vector2(hw * 0.52, wall_top - roof_h * 0.06), roof_s, 1.0)

	px_rect(-hw, wall_top - 2, hw * 2, 2, roof_s)

	var rows: int = 5
	for i in range(1, rows + 1):
		var f: float = float(i) / (rows + 1)
		var row_y: float = (wall_top - roof_h) + roof_h * f
		var row_hw: float = hw * f
		px_rect(-row_hw, row_y, row_hw * 2, 1, roof_s)

func _draw_rubble() -> void:
	px_rect(-w / 2.0, -3, w, 3, Palette.c("rubbleWoodDark"))
	var chunks := [
		{"dx": -0.32, "dw": 0.22, "dh": 0.5, "c": wall_shadow_color},
		{"dx": -0.05, "dw": 0.26, "dh": 0.7, "c": wall_color},
		{"dx": 0.28, "dw": 0.2, "dh": 0.42, "c": roof_shadow_color},
		{"dx": 0.1, "dw": 0.16, "dh": 0.3, "c": roof_color},
		{"dx": -0.2, "dw": 0.14, "dh": 0.24, "c": Palette.c("rubbleWood")},
	]
	for c in chunks:
		var cw: float = w * c["dw"]
		var ch: float = (wall_h + roof_h) * c["dh"] * 0.4
		px_rect(w * c["dx"] - cw / 2.0, -ch, cw, ch, c["c"])
	var rubble_dark: Color = Palette.c("rubbleWoodDark")
	px_rect(-w * 0.12, -wall_h * 0.55, 2, wall_h * 0.55, rubble_dark)
	px_rect(w * 0.05, -wall_h * 0.4, 2, wall_h * 0.4, rubble_dark)
