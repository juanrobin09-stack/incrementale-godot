class_name HouseSprite
extends PixelDrawer
## Intact + damaged states are both real sprites (assets/houses/,
## reference art provided directly) instead of the procedural
## pxRect/pxTriangle drawing every other village element uses — the
## reference art's rounded shingle tiles, half-timbering, cracked plaster
## and broken shutters aren't realistically reproducible with this
## renderer's flat-shaded pixel primitives, and exact visual fidelity to
## the references was the explicit ask here.
##
## Damage reveals the damaged texture through a fixed GRID_COLS x
## GRID_ROWS grid of cells rather than a soft alpha crossfade: each cell
## has its own seeded reveal threshold (biased so upper/roof rows tend to
## flip before lower/wall rows, matching wind hitting the roof first),
## and _update_stress() permanently flips a cell from intact to damaged
## the moment stress crosses that cell's threshold — permanently, same as
## every other piece of wind damage in this game never healing once it
## happens. This reads as the sprite actually breaking apart in blocky
## chunks, matching the game's hard-edged pixel-art style, instead of the
## smooth dissolve an alpha fade gives — a first pass used exactly that
## fade and it read as too soft/unphysical once tested.
##
## Both textures are drawn into the SAME destination rect (driven by the
## intact texture's own aspect ratio) rather than each at its own native
## aspect ratio — a first pass let the damaged texture size itself
## independently and it visibly grew/shrank relative to the intact
## sprite the moment any cell revealed, since the two reference crops
## aren't the same aspect ratio. Per-cell src_rect regions still sample
## the damaged texture's own pixel dimensions (not warped, just addressed
## by fraction), so this is a one-time shared-footprint fix, not a
## per-cell distortion.
##
## Debris still bursts at fixed stress thresholds, same as before —
## that's a separate physical read (things flying off) layered on top of
## the visual one (the sprite itself changing), not tied to any specific
## cell.
##
## Full collapse is still the old procedural rubble pile — reference art
## for actual ruin debris is a later pass. resilience / no-respawn /
## no-recovery-from-collapse behaviour is unchanged — see tree_sprite.gd's
## own header for the "no respawn" product decision this follows.

const GRID_COLS := 5
const GRID_ROWS := 6

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
var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false
var _revealed: Array = []

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
	var tex_h: float = float(texture.get_height())
	var tex_w: float = float(texture.get_width())
	_w = h * (tex_w / tex_h if tex_h > 0.0 else 1.0)
	_revealed.resize(GRID_COLS * GRID_ROWS)
	_revealed.fill(false)
	queue_redraw()

## Deterministic per-cell reveal point in [0,1] — a row bias (0 at the
## roof, rising toward the base) plus per-cell jitter from the house's
## own seed, so every house's crumble pattern is fixed but different.
func _cell_threshold(col: int, row: int) -> float:
	var row_bias: float = (float(row) / float(GRID_ROWS - 1)) * 0.35
	var n: float = seeded(_house_seed + col * 7.3 + row * 13.1 + 50.0)
	return clamp(0.12 + row_bias + (n - 0.5) * 0.55, 0.0, 0.97)

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
	var crack_t: float = clamp((_stress - 0.40) / 0.35, 0.0, 1.0)

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			if not _revealed[idx] and crack_t >= _cell_threshold(col, row):
				_revealed[idx] = true

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
	var cut_point: float = 0.985 + (seeded(_house_seed + 12) - 0.5) * 0.02
	if _stress >= cut_point:
		_draw_rubble()
		return
	draw_texture_rect(texture, Rect2(-_w / 2.0, -h, _w, h), false)

	var dmg_w: float = float(texture_damaged.get_width())
	var dmg_h: float = float(texture_damaged.get_height())
	var cell_w: float = _w / GRID_COLS
	var cell_h: float = h / GRID_ROWS
	var src_cell_w: float = dmg_w / GRID_COLS
	var src_cell_h: float = dmg_h / GRID_ROWS
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if not _revealed[row * GRID_COLS + col]:
				continue
			var dst := Rect2(-_w / 2.0 + col * cell_w, -h + row * cell_h, cell_w, cell_h)
			var src := Rect2(col * src_cell_w, row * src_cell_h, src_cell_w, src_cell_h)
			draw_texture_rect_region(texture_damaged, dst, src)

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
