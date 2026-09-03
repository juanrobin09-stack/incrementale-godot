class_name HouseSprite
extends PixelDrawer
## Intact house is a real sprite (assets/houses/house_*.png, reference art
## provided directly) instead of the procedural pxRect/pxTriangle drawing
## every other village element uses — the reference art's rounded shingle
## tiles, half-timbering and lived-in detail aren't realistically
## reproducible with this renderer's flat-shaded pixel primitives, and
## exact visual fidelity to the references was the explicit ask here.
## Damage stays procedural on top, same as before: crack lines drawn over
## the intact sprite as stress rises, then a full swap to the existing
## procedural rubble pile at collapse — DebrisSpawner bursts (fully
## procedural, unaffected by any of this) still fire at the same stress
## thresholds as before.
##
## The previous roofless_t stage (an intermediate "roof gone, attic
## exposed" look between cracks and rubble) has no equivalent with a
## single flat reference image — no way to selectively erase just the
## roof from a baked sprite — so that stage is dropped: cracks now worsen
## straight through to the rubble cut point instead of pausing at a
## distinct roofless silhouette.
##
## resilience / no-respawn / no-recovery-from-collapse behaviour is
## unchanged from before — see tree_sprite.gd's own header for the
## "no respawn" product decision this follows.

var h: float
var texture: Texture2D
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color
var resilience: float
var wind: WindEngine
var entities_parent: Node2D

var _w: float
var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false

func setup(p_h: float, p_texture: Texture2D, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color,
		p_resilience: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	h = p_h
	texture = p_texture
	wall_color = p_wall
	wall_shadow_color = p_wall_shadow
	roof_color = p_roof
	roof_shadow_color = p_roof_shadow
	resilience = p_resilience
	_house_seed = p_seed
	wind = p_wind
	entities_parent = p_entities_parent
	var tex_h: float = float(texture.get_height())
	var tex_w: float = float(texture.get_width())
	_w = h * (tex_w / tex_h if tex_h > 0.0 else 1.0)
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
	var wall_h: float = h * 0.42

	if _last_stress < 0.65 and _stress >= 0.65:
		DebrisSpawner.burst(entities_parent, position.x + _w * 0.25, position.y - wall_h,
			5, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], _w * 0.5, dir)
	if _last_stress < 0.90 and _stress >= 0.90:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4,
			10, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], _w * 0.9, 1.0)
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4, 0, [], 0.0, -1.0)
	var jitter: float = (seeded(_house_seed + 12) - 0.5) * 0.02
	if _last_stress < 0.93 + jitter and _stress >= 0.93 + jitter:
		DebrisSpawner.burst(entities_parent, position.x + (seeded(_house_seed + 20) - 0.5) * _w * 0.6, position.y - wall_h * 0.65,
			3, [wall_color, wall_shadow_color, Palette.c("rubbleWood")], _w * 0.25, dir)
	if _last_stress < 0.985 + jitter and _stress >= 0.985 + jitter:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.35,
			9, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], _w * 0.8, dir)
		DebrisSpawner.dust(entities_parent, position.x, position.y + 2.0, 3.0, _w * 0.6, 1.1)
	if _stress >= 1.0:
		_collapsed = true
	_last_stress = _stress

func _draw() -> void:
	var crack_t: float = clamp((_stress - 0.40) / 0.25, 0.0, 1.0)
	var cut_point: float = 0.985 + (seeded(_house_seed + 12) - 0.5) * 0.02
	if _stress >= cut_point:
		_draw_rubble()
		return
	draw_texture_rect(texture, Rect2(-_w / 2.0, -h, _w, h), false)
	if crack_t > 0.01:
		_draw_cracks(crack_t)

func _draw_cracks(crack_t: float) -> void:
	var crack_color := Color(35.0 / 255.0, 25.0 / 255.0, 20.0 / 255.0, 0.7 * crack_t)
	_draw_crack_line(-_w * 0.05, -h * 0.55, _house_seed, h * 0.35, _w * 0.12, crack_color)
	if crack_t > 0.5:
		_draw_crack_line(_w * 0.15, -h * 0.45, _house_seed + 4.0, h * 0.30, _w * 0.10, crack_color)

func _draw_crack_line(x: float, y: float, seed: float, length: float, wobble: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(x, y))
	var steps: int = 4
	for i in range(1, steps + 1):
		var yy: float = y + (length * i) / steps
		var xx: float = x + (seeded(seed + i) - 0.5) * wobble
		points.append(Vector2(xx, yy))
	draw_polyline(points, color, 1.0)

func _draw_rubble() -> void:
	var wall_h: float = h * 0.42
	px_rect(-_w / 2.0, -3, _w, 3, Palette.c("rubbleWoodDark"))
	var chunks := [
		{"dx": -0.32, "dw": 0.22, "dh": 0.5, "c": wall_shadow_color},
		{"dx": -0.05, "dw": 0.26, "dh": 0.7, "c": wall_color},
		{"dx": 0.28, "dw": 0.2, "dh": 0.42, "c": roof_shadow_color},
		{"dx": 0.1, "dw": 0.16, "dh": 0.3, "c": roof_color},
		{"dx": -0.2, "dw": 0.14, "dh": 0.24, "c": Palette.c("rubbleWood")},
	]
	for c in chunks:
		var cw: float = _w * c["dw"]
		var ch: float = h * c["dh"] * 0.4
		px_rect(_w * c["dx"] - cw / 2.0, -ch, cw, ch, c["c"])
	var rubble_dark: Color = Palette.c("rubbleWoodDark")
	px_rect(-_w * 0.12, -wall_h * 0.55, 2, wall_h * 0.55, rubble_dark)
	px_rect(_w * 0.05, -wall_h * 0.4, 2, wall_h * 0.4, rubble_dark)
