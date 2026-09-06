class_name TownHazardLayer
extends PixelDrawer
## Visual home of the level 2's own two disasters (quake/blight — see
## game_data.gd's own header for why these two specifically) — modelled
## directly on weather_layer.gd's own shape (setup() builds seeded
## particle arrays once, _process() advances them read from
## GameState.compute_stage(), _draw() paints them) rather than inventing a
## new pattern, but a SEPARATE class rather than extending WeatherLayer:
## rain/lightning/wind-streaks are all sky/air phenomena keyed off `wind`,
## these two are ground/arcane phenomena that need no WindEngine at all,
## and folding four unrelated concerns into one class would only make
## weather_layer.gd harder to follow for no shared code actually saved.
##
## quake: a fixed set of seeded jagged crack lines across the ground band,
## more of them viscible the higher compute_stage("quake") climbs, plus an
## occasional dust puff (DebrisSpawner.dust(), already used everywhere
## else debris/dust is needed in this project) at a random crack tip —
## the same structural/ground-based damage language _update_stress()
## already uses for houses, just drawn into the terrain itself instead of
## a building's own texture, which is the one kind of damage no existing
## system already covered.
##
## blight: a handful of slowly drifting violet glyph motes (this project's
## own established "chaos" colour — the Chaos Tree's core node, its
## always-owned violet glow, uses the same hue) plus a soft violet
## vignette wash at higher stages — deliberately NOT touching any
## building's own texture/tint (HouseSprite exposes no such hook, and
## adding one purely for this would be a much bigger, riskier change than
## a first base for two new disasters calls for); the corruption reads as
## ambient/atmospheric instead, which is still a genuinely different
## visual language from every rain/wind/storm effect already in this game.
const CRACK_COUNT := 8
const CRACK_MAX_STAGE := 3
const GLYPH_COUNT := 12
const GLYPH_COLOR := Color(0.62, 0.35, 0.85, 0.85)
const VIGNETTE_COLOR := Color(0.45, 0.15, 0.65, 1.0)

var logical_w: float
var logical_h: float
var ground_top: float
var ground_h: float
var entities_parent: Node2D

var _cracks: Array = []
var _glyphs: Array = []
var _elapsed: float = 0.0
var _next_dust_at: float = -1.0

func setup(p_w: float, p_h: float, p_ground_top: float, p_ground_h: float, p_entities_parent: Node2D) -> void:
	logical_w = p_w
	logical_h = p_h
	ground_top = p_ground_top
	ground_h = p_ground_h
	entities_parent = p_entities_parent
	_build_cracks()
	_build_glyphs()

## Each crack is a short jagged polyline anchored at a seeded ground
## point, generated once — quake's own stage only ever controls how MANY
## of these already-fixed cracks are currently drawn (see _draw_cracks()),
## not their shape, so a crack never visibly jumps to a new position as
## the stage rises, it simply joins the ones already showing.
func _build_cracks() -> void:
	_cracks.clear()
	for i in range(CRACK_COUNT):
		var s: float = i * 17.0 + 300.0
		var x0: float = seeded(s) * logical_w
		var y0: float = ground_top + seeded(s + 1.0) * ground_h * 0.85 + ground_h * 0.1
		var length: float = ground_h * (0.08 + seeded(s + 2.0) * 0.10)
		var segs: int = 4
		var points := PackedVector2Array()
		points.append(Vector2(x0, y0))
		var x: float = x0
		var y: float = y0
		var dir_x: float = (seeded(s + 3.0) - 0.5) * 2.0
		for j in range(segs):
			x += dir_x * (length / segs) + (seeded(s + 4.0 + j) - 0.5) * 6.0
			y += (length / segs) * 0.5
			points.append(Vector2(x, y))
		_cracks.append(points)

func _build_glyphs() -> void:
	_glyphs.clear()
	for i in range(GLYPH_COUNT):
		var s: float = i * 23.0 + 700.0
		_glyphs.append({
			"x": seeded(s) * logical_w,
			"y0": ground_top + seeded(s + 1.0) * ground_h,
			"speed": 6.0 + seeded(s + 2.0) * 10.0,
			"size": 2.0 + seeded(s + 3.0) * 2.0,
			"drift": (seeded(s + 4.0) - 0.5) * 6.0,
			"phase": seeded(s + 5.0) * TAU,
			"rise": 0.0,
		})

func _process(delta: float) -> void:
	_elapsed += delta
	var quake_stage := GameState.compute_stage("quake")
	if quake_stage > 0:
		_update_quake_dust(delta, quake_stage)
	if GameState.compute_stage("blight") > 0:
		_update_glyphs(delta)
	queue_redraw()

## Number of cracks currently visible at a given quake stage — the single
## formula _draw_cracks() and _update_quake_dust() both key off, so a dust
## puff can never land on a crack that isn't drawn yet.
func _visible_crack_count(stage: int) -> int:
	return clamp(int(round(float(CRACK_COUNT) * stage / float(CRACK_MAX_STAGE))), 0, _cracks.size())

## Sparse, occasional puffs rather than continuous — this is ambient
## ground detail, not the focal effect (the cracks themselves are), and a
## puff every frame at this scale would read as smoke, not settling dust.
func _update_quake_dust(_delta: float, stage: int) -> void:
	if entities_parent == null:
		return
	if _next_dust_at < 0.0:
		_next_dust_at = _elapsed + 1.5
	if _elapsed >= _next_dust_at:
		var visible: int = _visible_crack_count(stage)
		if visible > 0:
			var idx: int = randi_range(0, visible - 1)
			var tip: Vector2 = _cracks[idx][_cracks[idx].size() - 1]
			DebrisSpawner.dust(entities_parent, tip.x, tip.y, 1.5, 10.0 + stage * 3.0, 1.2)
		_next_dust_at = _elapsed + 2.5 - stage * 0.4 + randf() * 1.5

func _update_glyphs(delta: float) -> void:
	for g in _glyphs:
		g["rise"] += g["speed"] * delta
		if g["rise"] > ground_h * 0.9:
			g["rise"] = 0.0

func _draw() -> void:
	var quake_stage := GameState.compute_stage("quake")
	if quake_stage > 0:
		_draw_cracks(quake_stage)
	var blight_stage := GameState.compute_stage("blight")
	if blight_stage > 0:
		_draw_vignette(blight_stage)
		_draw_glyphs(blight_stage)

func _draw_cracks(stage: int) -> void:
	var visible: int = _visible_crack_count(stage)
	var crack_color := Color(0.16, 0.12, 0.10, 0.85)
	for i in range(visible):
		draw_polyline(_cracks[i], crack_color, 1.0)

func _draw_vignette(stage: int) -> void:
	var alpha: float = 0.05 + 0.06 * stage
	draw_rect(Rect2(0, 0, logical_w, logical_h), Color(VIGNETTE_COLOR.r, VIGNETTE_COLOR.g, VIGNETTE_COLOR.b, alpha))

func _draw_glyphs(stage: int) -> void:
	var visible: int = clamp(int(round(float(GLYPH_COUNT) * stage / 3.0)), 0, _glyphs.size())
	for i in range(visible):
		var g: Dictionary = _glyphs[i]
		var y: float = g["y0"] - g["rise"]
		var x: float = g["x"] + sin(_elapsed * 0.6 + g["phase"]) * g["drift"]
		var t: float = g["rise"] / max(1.0, ground_h * 0.9)
		var alpha: float = GLYPH_COLOR.a * (1.0 - t) * 0.9
		var size: float = g["size"]
		var pts := PackedVector2Array([
			Vector2(x, y - size), Vector2(x + size, y), Vector2(x, y + size), Vector2(x - size, y),
		])
		draw_colored_polygon(pts, Color(GLYPH_COLOR.r, GLYPH_COLOR.g, GLYPH_COLOR.b, alpha))
