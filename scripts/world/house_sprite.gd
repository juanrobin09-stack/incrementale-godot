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
## TWO grids, two different jobs — don't confuse them:
##
## - The "dissolve" grid (_fine_cols x _fine_rows, ~FINE_CELL_PX source
##   pixels per cell) is what actually drives the visible crumbling
##   texture. It is NOT drawn as individual rects — a first pass did
##   exactly that with a coarse 5x6 grid and it read as "obvious squares
##   replacing squares", not real damage, because at this game's actual
##   on-screen size a cell that size is a big, perfectly rectangular,
##   hard-edged block. Instead, setup() bakes a _composite_img (a copy of
##   the intact image) and, as cells cross their seeded threshold, blits
##   small patches of the damaged image into it in place — draw_texture_
##   rect_region equivalent, but composited once into one Image instead
##   of issued as one draw call per visible cell. _draw() then just draws
##   that ONE composite texture, whole. FINE_CELL_PX (10px of SOURCE
##   image) lands at roughly one LOGICAL pixel once downscaled into this
##   game's low-res canvas (house sprites render at ~50-70 logical px
##   wide against ~465-614px source art — see world_viewport_host.gd) —
##   i.e. as fine as this renderer can ever make anything look, so the
##   result reads as texture eroding/dirtying, not shapes popping in, and
##   costs exactly one draw call per house regardless of how much has
##   crumbled, same as before this pass (actually fewer: no more per-
##   cell rects at all).
## - The "macro" grid (GRID_COLS x GRID_ROWS, unchanged at 5x6) has
##   nothing to do with what's visible. It only sizes the handful of
##   chunk-scale regions the collapse sequence turns into actual flying
##   pieces (see below) — a piece needs to be big enough to read as "a
##   piece of roof", which the dissolve grid's ~1px cells obviously
##   aren't. A macro cell reveals by blitting its whole source rect into
##   the composite in one shot, same blit primitive as the dissolve grid
##   just at a bigger scale, not a separate code path.
##
## Both textures still share the intact texture's own destination rect
## (a first pass let the damaged texture size itself independently and
## it visibly grew/shrank the moment any of it revealed, since the two
## reference crops aren't the same aspect ratio) — now enforced once, at
## setup(), by resizing a working copy of the damaged image to the
## intact image's exact pixel dimensions (nearest-neighbour, no blur) so
## every blit afterwards is a same-coordinates same-size copy. Visually
## identical mapping to sampling proportional per-cell source rects at
## draw time, just computed once up front instead of every cell.
##
## Two-phase damage, not one continuous slide to rubble:
##
## 1. "intact" — the tremor. Same accrual/decay _stress as before,
##    revealing dissolve cells continuously as it climbs (crumbling
##    visibly spreading, roof first), fully reversible while wind stays
##    calm — except dissolve cells under a RESERVED macro cell (see
##    setup()'s _reserved_cells, sized by size_tier) are permanently
##    excluded, no matter how long the tremor runs. Otherwise crack_t
##    saturates well before real structural failure and the whole
##    texture is already fully eroded by the time collapse would
##    trigger, leaving nothing left to visibly tear away for stage 2.
## 2. "collapsing" — triggered once at COLLAPSE_TRIGGER stress, a
##    one-shot ~1.5-2.3s timed sequence (mirrors tree_sprite.gd's
##    falling state: not reversible, not re-entered). The reserved macro
##    cells detach on a staggered timeline; each one blits its whole
##    region into the composite the instant it lets go (a real hole, not
##    a delayed swap) and spawns a DebrisFragment textured with a crop of
##    the INTACT sprite's own art from that exact region — so what flies
##    off visibly IS the roof tile / wall panel that used to be there —
##    plus, about half the time, a small burst of flat-colour wood/wall
##    splinters + dust via the existing DebrisSpawner. Everything falls
##    via the same cheap gravity+drag+spin+settle DebrisFragment already
##    used everywhere else in this game — no physics engine, just the
##    formulas. Large houses also get a faint decaying shake. How many
##    roof vs facade regions detach and how long the sequence runs scale
##    with size_tier (small/medium/large — set per house shape in
##    world_scene.gd, since the 5 houses are really only 3 distinct
##    shapes: red/green share one, gold is one, blue/purple share one).
## 3. "ruined" — the sequence's terminal state. _draw() switches to
##    drawing texture_damaged directly, whole-image, instead of the
##    composite — guarantees the sprite ends up pixel-identical to the
##    provided ruin art, not a fully-eroded approximation of it.
##    Permanent, no further per-frame work — matches tree_sprite.gd's
##    "fallen" being inert for good. The old procedural rubble-pile draw
##    is retired: it existed only because no ruin reference art existed
##    yet, and now texture_damaged IS that reference art.
##
## resilience / no-respawn / no-recovery-from-collapse behaviour is
## unchanged — see tree_sprite.gd's own header for the "no respawn"
## product decision this follows.

const GRID_COLS := 5
const GRID_ROWS := 6
const FINE_CELL_PX := 10.0
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

var _damaged_resized: Image
var _composite_img: Image
var _composite_texture: ImageTexture
var _composite_dirty: bool = false

var _fine_cols: int
var _fine_rows: int
var _fine_revealed: Array = []
var _fine_reserved: Array = []

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

	var intact_img: Image = texture.get_image()
	var tex_w: int = intact_img.get_width()
	var tex_h: int = intact_img.get_height()
	_w = h * (float(tex_w) / float(tex_h) if tex_h > 0 else 1.0)

	_damaged_resized = texture_damaged.get_image()
	if _damaged_resized.get_format() != intact_img.get_format():
		_damaged_resized.convert(intact_img.get_format())
	_damaged_resized.resize(tex_w, tex_h, Image.INTERPOLATE_NEAREST)

	_composite_img = intact_img.duplicate()
	_composite_texture = ImageTexture.create_from_image(_composite_img)

	_fine_cols = max(8, int(float(tex_w) / FINE_CELL_PX))
	_fine_rows = max(8, int(float(tex_h) / FINE_CELL_PX))
	_fine_revealed.resize(_fine_cols * _fine_rows)
	_fine_revealed.fill(false)

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

	_fine_reserved.resize(_fine_cols * _fine_rows)
	for fy in range(_fine_rows):
		for fx in range(_fine_cols):
			var macro_col: int = clamp(int((float(fx) + 0.5) / _fine_cols * GRID_COLS), 0, GRID_COLS - 1)
			var macro_row: int = clamp(int((float(fy) + 0.5) / _fine_rows * GRID_ROWS), 0, GRID_ROWS - 1)
			_fine_reserved[fy * _fine_cols + fx] = _reserved_lookup.has(macro_row * GRID_COLS + macro_col)

	queue_redraw()

## Deterministic per-cell reveal point in [0,1] for a macro cell — a row
## bias (0 at the roof, rising toward the base) plus per-cell jitter from
## the house's own seed, so every house's collapse picks a fixed but
## different set of pieces.
func _cell_threshold(col: int, row: int) -> float:
	var row_bias: float = (float(row) / float(GRID_ROWS - 1)) * 0.35
	var n: float = seeded(_house_seed + col * 7.3 + row * 13.1 + 50.0)
	return clamp(0.12 + row_bias + (n - 0.5) * 0.55, 0.0, 0.97)

## Same idea, for the fine dissolve grid — separate salt/coefficients so
## it isn't just a scaled repeat of the macro pattern.
func _fine_threshold(fx: int, fy: int) -> float:
	var row_bias: float = (float(fy) / float(_fine_rows - 1)) * 0.35
	var n: float = seeded(_house_seed + fx * 2.7 + fy * 4.1 + 150.0)
	return clamp(0.12 + row_bias + (n - 0.5) * 0.55, 0.0, 0.97)

## Deterministic, seed-ranked pick of up to n macro cells from the given
## row band — used once, at setup(), to fix which regions are held in
## reserve for the collapse sequence (see header). A different salt per
## band call keeps the roof and facade picks independent instead of
## correlated.
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

## Copies one cell's worth of pixels from the (already same-size)
## resized damaged image into the composite — a straight copy, alpha
## included, no blending, so the edge stays hard rather than fading.
func _blit_cell(x0: int, y0: int, x1: int, y1: int) -> void:
	var rect := Rect2i(x0, y0, max(1, x1 - x0), max(1, y1 - y0))
	_composite_img.blit_rect(_damaged_resized, rect, Vector2i(x0, y0))
	_composite_dirty = true

func _blit_fine_cell(fx: int, fy: int) -> void:
	var tw: int = _composite_img.get_width()
	var th: int = _composite_img.get_height()
	var x0: int = int(round(float(fx) * tw / _fine_cols))
	var x1: int = int(round(float(fx + 1) * tw / _fine_cols))
	var y0: int = int(round(float(fy) * th / _fine_rows))
	var y1: int = int(round(float(fy + 1) * th / _fine_rows))
	_blit_cell(x0, y0, x1, y1)

func _blit_macro_cell(col: int, row: int) -> void:
	var tw: int = _composite_img.get_width()
	var th: int = _composite_img.get_height()
	var x0: int = int(round(float(col) * tw / GRID_COLS))
	var x1: int = int(round(float(col + 1) * tw / GRID_COLS))
	var y0: int = int(round(float(row) * th / GRID_ROWS))
	var y1: int = int(round(float(row + 1) * th / GRID_ROWS))
	_blit_cell(x0, y0, x1, y1)

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

	if crack_t > 0.0:
		for fy in range(_fine_rows):
			for fx in range(_fine_cols):
				var idx: int = fy * _fine_cols + fx
				if not _fine_revealed[idx] and not _fine_reserved[idx] and crack_t >= _fine_threshold(fx, fy):
					_fine_revealed[idx] = true
					_blit_fine_cell(fx, fy)

	if _last_stress < 0.65 and _stress >= 0.65:
		DebrisSpawner.burst(entities_parent, position.x + _w * 0.25, position.y - wall_h,
			5, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], _w * 0.5, dir)
	_last_stress = _stress

	if _composite_dirty:
		_composite_texture.update(_composite_img)
		_composite_dirty = false

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
	if _composite_dirty:
		_composite_texture.update(_composite_img)
		_composite_dirty = false
	if size_tier == 2:
		var shake_env: float = clamp(1.0 - _seq_t / _seq_duration, 0.0, 1.0)
		_seq_shake_x = (seeded(_seq_t * 53.0 + _house_seed) - 0.5) * 4.0 * shake_env
	if _seq_t >= _seq_duration:
		_finish_collapse()

## One region letting go: blits its hole into the composite immediately,
## flings a textured chunk cropped from the intact art at that exact
## region (gravity/drag/spin/settle courtesy of DebrisFragment,
## unchanged), and — about half the time, so the sequence doesn't drown
## in dust — a small burst of flat-colour splinters + dust from the
## existing DebrisSpawner.
func _fire_piece_event(ev: Dictionary) -> void:
	var col: int = ev["col"]
	var row: int = ev["row"]
	_blit_macro_cell(col, row)

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
	_seq_shake_x = 0.0
	var wall_h: float = h * 0.42
	DebrisSpawner.dust(entities_parent, position.x, position.y - wall_h * 0.15, 3.0, _w * 0.5, 1.3)
	queue_redraw()

func _draw() -> void:
	match _state:
		"ruined":
			draw_texture_rect(texture_damaged, Rect2(-_w / 2.0, -h, _w, h), false)
		"collapsing":
			draw_texture_rect(_composite_texture, Rect2(-_w / 2.0 + _seq_shake_x, -h, _w, h), false)
		_:
			draw_texture_rect(_composite_texture, Rect2(-_w / 2.0, -h, _w, h), false)
