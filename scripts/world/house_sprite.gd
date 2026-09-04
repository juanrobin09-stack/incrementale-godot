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
## flip before lower/wall rows, matching wind hitting the roof first).
## This reads as the sprite actually breaking apart in blocky chunks,
## matching the game's hard-edged pixel-art style, instead of the smooth
## dissolve an alpha fade gives — a first pass used exactly that fade and
## it read as too soft/unphysical once tested.
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
## Two-phase damage, not one continuous slide to rubble:
##
## 1. "intact" — the tremor. Same accrual/decay _stress as before, still
##    revealing cells continuously as it climbs (cracks visibly spreading,
##    roof first), still fully reversible while wind stays calm. BUT a
##    seeded subset of cells (setup()'s _reserved_cells, sized by
##    size_tier) is permanently excluded from this continuous reveal, no
##    matter how long the tremor runs — otherwise crack_t saturates well
##    before real structural failure and the WHOLE grid is already
##    revealed by the time collapse would trigger, leaving nothing left
##    to visibly tear away for stage 2. These reserved cells read as the
##    pieces still structurally holding on until the real break.
## 2. "collapsing" — triggered once at COLLAPSE_TRIGGER stress, a one-shot
##    ~1.5-2.3s timed sequence (mirrors tree_sprite.gd's falling state:
##    not reversible, not re-entered). The reserved cells detach on a
##    staggered timeline; each one reveals its damaged-texture cell the
##    instant it lets go (a visible hole, not a delayed swap) and spawns
##    a DebrisFragment textured with a crop of the INTACT sprite's own
##    art from that exact cell — so what flies off visibly IS the
##    roof tile / wall panel that used to be there — plus, about half the
##    time, a small burst of flat-colour wood/wall splinters + dust via
##    the existing DebrisSpawner. Everything falls via the same cheap
##    gravity+drag+spin+settle DebrisFragment already used everywhere
##    else in this game — no physics engine, just the formulas. Large
##    houses also get a faint decaying shake. How many roof vs facade
##    cells detach and how long the sequence runs scale with size_tier
##    (small/medium/large — set per house shape in world_scene.gd, since
##    the 5 houses are really only 3 distinct shapes: red/green share one,
##    gold is one, blue/purple share one).
## 3. "ruined" — the sequence's terminal state. All cells are marked
##    revealed and _draw() switches to drawing texture_damaged directly,
##    whole-image, instead of assembling it from grid cells — guarantees
##    the sprite ends up pixel-identical to the provided ruin art, not a
##    100%-revealed approximation of it. Permanent, no further per-frame
##    work — matches tree_sprite.gd's "fallen" being inert for good. The
##    old procedural rubble-pile draw is retired: it existed only because
##    no ruin reference art existed yet, and now texture_damaged IS that
##    reference art.
##
## resilience / no-respawn / no-recovery-from-collapse behaviour is
## unchanged — see tree_sprite.gd's own header for the "no respawn"
## product decision this follows.

const GRID_COLS := 5
const GRID_ROWS := 6
const COLLAPSE_TRIGGER := 0.95

var h: float
var texture: Texture2D
var texture_damaged: Texture2D
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color
var resilience: float
var size_tier: int
var wind: WindEngine
var entities_parent: Node2D

var _w: float
var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _revealed: Array = []
var _reserved_cells: Array = []
var _reserved_lookup: Dictionary = {}

# "intact" | "collapsing" | "ruined" — see header.
var _state: String = "intact"
var _seq_t: float = 0.0
var _seq_duration: float = 1.8
var _seq_events: Array = []
var _seq_shake_x: float = 0.0

func setup(p_h: float, p_texture: Texture2D, p_texture_damaged: Texture2D, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color,
		p_resilience: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D, p_size_tier: int = 1) -> void:
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
	size_tier = p_size_tier
	var tex_h: float = float(texture.get_height())
	var tex_w: float = float(texture.get_width())
	_w = h * (tex_w / tex_h if tex_h > 0.0 else 1.0)
	_revealed.resize(GRID_COLS * GRID_ROWS)
	_revealed.fill(false)

	var roof_n: int
	var facade_n: int
	match size_tier:
		0:
			roof_n = 3
			facade_n = 0
		1:
			roof_n = 5
			facade_n = 3
		_:
			roof_n = 7
			facade_n = 4
	_reserved_cells = _pick_cells(0, 2, roof_n, 1.0) + _pick_cells(3, GRID_ROWS - 1, facade_n, 2.0)
	_reserved_lookup = {}
	for cell in _reserved_cells:
		_reserved_lookup[cell.y * GRID_COLS + cell.x] = true

	queue_redraw()

## Deterministic per-cell reveal point in [0,1] — a row bias (0 at the
## roof, rising toward the base) plus per-cell jitter from the house's
## own seed, so every house's crumble pattern is fixed but different.
func _cell_threshold(col: int, row: int) -> float:
	var row_bias: float = (float(row) / float(GRID_ROWS - 1)) * 0.35
	var n: float = seeded(_house_seed + col * 7.3 + row * 13.1 + 50.0)
	return clamp(0.12 + row_bias + (n - 0.5) * 0.55, 0.0, 0.97)

## Deterministic, seed-ranked pick of up to n cells from the given row
## band — used once, at setup(), to fix which cells are held in reserve
## for the collapse sequence (see header). A different salt per band call
## keeps the roof and facade picks independent instead of correlated.
func _pick_cells(row_lo: int, row_hi: int, n: int, salt: float) -> Array:
	if n <= 0:
		return []
	var candidates: Array = []
	for row in range(row_lo, row_hi + 1):
		for col in range(GRID_COLS):
			candidates.append(Vector2i(col, row))
	candidates.sort_custom(func(a, b):
		return seeded(_house_seed + a.x * 5.7 + a.y * 11.3 + salt) < seeded(_house_seed + b.x * 5.7 + b.y * 11.3 + salt))
	return candidates.slice(0, min(n, candidates.size()))

func _process(delta: float) -> void:
	match _state:
		"intact":
			_update_stress(delta)
			queue_redraw()
		"collapsing":
			_advance_collapse(delta)
			queue_redraw()
		_:
			pass # "ruined": permanent, nothing left to update.

func _update_stress(delta: float) -> void:
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
			if not _revealed[idx] and not _reserved_lookup.has(idx) and crack_t >= _cell_threshold(col, row):
				_revealed[idx] = true

	if _last_stress < 0.65 and _stress >= 0.65:
		DebrisSpawner.burst(entities_parent, position.x + _w * 0.25, position.y - wall_h,
			5, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], _w * 0.5, dir)
	_last_stress = _stress

	if _stress >= COLLAPSE_TRIGGER:
		_start_collapse()

func _start_collapse() -> void:
	_state = "collapsing"
	_seq_t = 0.0
	_seq_shake_x = 0.0
	match size_tier:
		0:
			_seq_duration = 1.5
		1:
			_seq_duration = 1.9
		_:
			_seq_duration = 2.3

	_seq_events = []
	var n: int = _reserved_cells.size()
	for i in range(n):
		var cell: Vector2i = _reserved_cells[i]
		var frac: float = float(i) / float(max(1, n - 1))
		var t0: float = frac * _seq_duration * 0.55 + (seeded(_house_seed + i * 3.7 + 40.0) - 0.5) * 0.2 * _seq_duration
		_seq_events.append({"t": clamp(t0, 0.0, _seq_duration * 0.65), "col": cell.x, "row": cell.y, "fired": false})

func _advance_collapse(delta: float) -> void:
	_seq_t += delta
	for ev in _seq_events:
		if not ev["fired"] and _seq_t >= ev["t"]:
			ev["fired"] = true
			_fire_piece_event(ev)
	if size_tier == 2:
		var shake_env: float = clamp(1.0 - _seq_t / _seq_duration, 0.0, 1.0)
		_seq_shake_x = (seeded(_seq_t * 53.0 + _house_seed) - 0.5) * 4.0 * shake_env
	if _seq_t >= _seq_duration:
		_finish_collapse()

## One cell letting go: reveals the hole immediately, flings a textured
## chunk cropped from the intact art at that exact cell (gravity/drag/
## spin/settle courtesy of DebrisFragment, unchanged), and — about half
## the time, so the sequence doesn't drown in dust — a small burst of
## flat-colour splinters + dust from the existing DebrisSpawner.
func _fire_piece_event(ev: Dictionary) -> void:
	var col: int = ev["col"]
	var row: int = ev["row"]
	_revealed[row * GRID_COLS + col] = true

	var wall_h: float = h * 0.42
	var cell_w: float = _w / GRID_COLS
	var cell_h: float = h / GRID_ROWS
	var local_cx: float = -_w / 2.0 + (col + 0.5) * cell_w
	var local_cy: float = -h + (row + 0.5) * cell_h
	var spawn_pos: Vector2 = position + Vector2(local_cx, local_cy)
	var row_t: float = float(row) / float(GRID_ROWS - 1)
	var ground_y: float = position.y - wall_h * clamp(1.0 - row_t, 0.15, 0.6)

	var dir: float = wind.direction if wind.direction != 0.0 else 1.0
	var side: float = 1.0 if local_cx >= 0.0 else -1.0
	var fling: float = side * 0.55 + dir * 0.45
	var speed: float = 18.0 + randf() * 35.0

	var tex_w: float = float(texture.get_width())
	var tex_h: float = float(texture.get_height())
	var src := Rect2(col * tex_w / GRID_COLS, row * tex_h / GRID_ROWS, tex_w / GRID_COLS, tex_h / GRID_ROWS)

	var frag := DebrisFragment.new()
	frag.position = spawn_pos
	frag.setup(
		fling * speed, -(40.0 + randf() * 50.0), (randf() - 0.5) * 5.0,
		cell_w * (0.7 + randf() * 0.3), cell_h * (0.7 + randf() * 0.3),
		roof_color, ground_y, 1.6 + randf() * 0.6,
	)
	frag.setup_textured(texture, src)
	entities_parent.add_child(frag)

	if seeded(_house_seed + col * 3.1 + row * 7.9 + 90.0) < 0.5:
		var band_colors: Array = [roof_color, roof_shadow_color, Palette.c("rubbleWood")] if row <= 2 else [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")]
		DebrisSpawner.burst(entities_parent, spawn_pos.x, ground_y, 2, band_colors, cell_w * 0.6, side)

func _finish_collapse() -> void:
	_state = "ruined"
	_revealed.fill(true)
	_seq_shake_x = 0.0
	var wall_h: float = h * 0.42
	DebrisSpawner.dust(entities_parent, position.x, position.y - wall_h * 0.15, 3.0, _w * 0.5, 1.3)
	queue_redraw()

func _draw() -> void:
	match _state:
		"ruined":
			draw_texture_rect(texture_damaged, Rect2(-_w / 2.0, -h, _w, h), false)
		"collapsing":
			var ox: float = _seq_shake_x
			draw_texture_rect(texture, Rect2(-_w / 2.0 + ox, -h, _w, h), false)
			_draw_revealed_cells(ox)
		_:
			draw_texture_rect(texture, Rect2(-_w / 2.0, -h, _w, h), false)
			_draw_revealed_cells(0.0)

func _draw_revealed_cells(ox: float) -> void:
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
			var dst := Rect2(-_w / 2.0 + ox + col * cell_w, -h + row * cell_h, cell_w, cell_h)
			var src := Rect2(col * src_cell_w, row * src_cell_h, src_cell_w, src_cell_h)
			draw_texture_rect_region(texture_damaged, dst, src)
