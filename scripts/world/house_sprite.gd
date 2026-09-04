class_name HouseSprite
extends PixelDrawer
## Intact + damaged states are both real sprites (assets/houses/,
## reference art provided directly) instead of the procedural
## pxRect/pxTriangle drawing every other village element uses — the
## reference art's rounded shingle tiles, half-timbering, cracked plaster
## and broken shutters aren't realistically reproducible with this
## renderer's flat-shaded pixel primitives, and exact visual fidelity to
## the references was the explicit ask here. A first pass tried keeping
## the intact sprite untouched and only spawning debris on top, then
## tearing literal chunks out of it as stress rose — dropped now that a
## proper damaged-state reference image exists: it shows cracked walls,
## broken windows/shutters and missing roof tiles all at once, in the
## same hand-painted style as the intact art, which no amount of
## procedural chunk-punching was going to match.
##
## Damage is a crossfade between the two full textures — draw_texture_rect
## twice, the damaged one on top with its own alpha ramped by crack_t —
## rather than a hard swap, so it still reads as gradual wear and not an
## instant change (the original's own stated design goal, still true
## here). Each texture keeps its own aspect ratio (_w vs _w_damaged): the
## two reference crops aren't pixel-aligned to each other, so stretching
## both into one shared rect would visibly warp whichever one doesn't
## match; independent aspect-correct scaling, both anchored bottom-
## center at the same ground point, is the honest compromise without
## hand-registering every pair of images.
##
## Debris still bursts at fixed stress thresholds, same as before — that
## part was never about matching a specific torn spot, so it doesn't need
## the sprite mutation the old approach used it to justify.
##
## Full collapse is still the old procedural rubble pile — reference art
## for actual ruin debris is a later pass. resilience / no-respawn /
## no-recovery-from-collapse behaviour is unchanged — see tree_sprite.gd's
## own header for the "no respawn" product decision this follows.

var h: float
var texture: Texture2D
var texture_damaged: Texture2D
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color
var resilience: float
var wind: WindEngine
var entities_parent: Node2D

var _w: float
var _w_damaged: float
var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false

func setup(p_h: float, p_texture: Texture2D, p_texture_damaged: Texture2D, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color,
		p_resilience: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	h = p_h
	texture = p_texture
	texture_damaged = p_texture_damaged
	wall_color = p_wall
	wall_shadow_color = p_wall_shadow
	roof_color = p_roof
	roof_shadow_color = p_roof_shadow
	resilience = p_resilience
	_house_seed = p_seed
	wind = p_wind
	entities_parent = p_entities_parent
	_w = h * _aspect(texture)
	_w_damaged = h * _aspect(texture_damaged)
	queue_redraw()

func _aspect(tex: Texture2D) -> float:
	var tex_h: float = float(tex.get_height())
	var tex_w: float = float(tex.get_width())
	return tex_w / tex_h if tex_h > 0.0 else 1.0

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
	var crack_t: float = clamp((_stress - 0.40) / 0.35, 0.0, 1.0)
	var cut_point: float = 0.985 + (seeded(_house_seed + 12) - 0.5) * 0.02
	if _stress >= cut_point:
		_draw_rubble()
		return
	draw_texture_rect(texture, Rect2(-_w / 2.0, -h, _w, h), false)
	if crack_t > 0.01:
		draw_texture_rect(texture_damaged, Rect2(-_w_damaged / 2.0, -h, _w_damaged, h), false, Color(1.0, 1.0, 1.0, crack_t))

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
