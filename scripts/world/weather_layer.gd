class_name WeatherLayer
extends PixelDrawer
## Rain and lightning — originally a direct translation of the relevant
## parts of drawWeatherForeground()/triggerLightning()/drawBolt() from
## render.js, plus the lightning-scheduling logic from
## maybeTriggerLightning() in script.js (storm-level + time driven, not
## wind-dependent — safe to port ahead of the wind-physics engine).
## `_next_lightning_at` etc. are deliberately transient/local state,
## never persisted, matching the original's own `runtime` object.
##
## Rain leans and speeds up with the shared WindEngine — the original's
## rainAngle/speedMul formulas, but with the coefficients raised and a
## wind-driven DENSITY on top (the original never varied drop count with
## wind at all): reported that a violent-looking wind next to calmly-
## vertical rain read as incoherent, the two systems not feeling
## connected. At force 0 every one of these still reduces to the
## straight-down, unsped-up, un-thickened case, so no separate "calm"
## branch is needed anywhere below — same property the original had,
## preserved through the retuning.
##
## RAIN_COUNT raised from the original 90 to give the wind-density
## multiplier in _draw_rain() headroom to push past a rain-tier's own
## base count when wind is also high, instead of being capped at
## whatever the rain upgrade alone would already draw.
const RAIN_COUNT := 130
const RAIN_DEPTH_SPEED := [0.6, 1.0, 1.55]
const RAIN_DEPTH_LEN := [0.7, 1.0, 1.35]
const RAIN_DEPTH_ALPHA := [0.4, 0.72, 1.0]
const RAIN_STAGE_COUNTS := [0, 25, 50, 75, 95]
const STREAK_COUNT := 20
const STREAK_LEVEL_COUNT := [0, 8, 14, 20]

var logical_w: float
var logical_h: float
var wind: WindEngine

var _rain_particles: Array = []
var _wind_streaks: Array = []
var _elapsed: float = 0.0
var _next_lightning_at: float = -1.0
var _lightning_until: float = -1.0
var _bolt_seed: float = 0.0

func setup(p_w: float, p_h: float, p_wind: WindEngine) -> void:
	logical_w = p_w
	logical_h = p_h
	wind = p_wind
	_build_rain()
	_build_wind_streaks()

func _build_wind_streaks() -> void:
	_wind_streaks.clear()
	for i in range(STREAK_COUNT):
		_wind_streaks.append({
			"seed": float(i),
			"y": seeded(i + 70) * logical_h * 0.5,
			"traveled": 0.0,
		})

func _build_rain() -> void:
	_rain_particles.clear()
	for i in range(RAIN_COUNT):
		var depth: int = i % 3
		_rain_particles.append({
			"x": seeded(i) * logical_w,
			"y": seeded(i + 99) * logical_h,
			"speed": (90.0 + seeded(i + 5) * 60.0) * RAIN_DEPTH_SPEED[depth],
			"len": (3.0 + seeded(i + 3) * 3.0) * RAIN_DEPTH_LEN[depth],
			"alpha": RAIN_DEPTH_ALPHA[depth],
			"fallen": 0.0,
			"drift": 0.0,
		})

func _process(delta: float) -> void:
	_elapsed += delta
	_update_rain(delta)
	_update_wind_streaks(delta)
	_maybe_trigger_lightning()
	queue_redraw()

## Shared by _update_rain (drift) and _draw_rain (streak orientation) —
## pulled into one place since retuning meant touching both, and having
## them drift apart (pun aside) would desync the drops' actual travel
## direction from how they're drawn. Cap raised from the original 0.55
## rad (~31.5°) to 0.75 rad (~43°): with the wider per-level force range
## (see WindEngine), force*0.62 now reaches the cap comfortably below
## the new top level's force, still giving a full ramp instead of most
## of level 3 sitting flat against the ceiling.
func _rain_angle() -> float:
	return wind.direction * min(0.75, wind.force * 0.62)

func _update_rain(delta: float) -> void:
	if GameState.compute_stage("rain") <= 0:
		return
	var rain_angle: float = _rain_angle()
	var speed_mul: float = 1.0 + wind.force * 0.7
	for p in _rain_particles:
		var dy_step: float = p["speed"] * speed_mul * delta
		p["fallen"] += dy_step
		p["drift"] += dy_step * tan(rain_angle)

func _update_wind_streaks(delta: float) -> void:
	if GameState.compute_stage("wind") <= 0:
		return
	var speed: float = 40.0 + wind.force * 260.0
	for st in _wind_streaks:
		st["traveled"] += speed * delta

func _maybe_trigger_lightning() -> void:
	var storm: Dictionary = GameState.state.disasters["storm"]
	if not storm["unlocked"] or storm["level"] <= 0:
		return
	if _next_lightning_at < 0.0:
		_next_lightning_at = _elapsed + 3.0
	if _elapsed >= _next_lightning_at:
		_lightning_until = _elapsed + 0.5
		_bolt_seed = randf() * 1000.0
		var boosted: bool = GameState.has_lightning_boost()
		var min_gap: float = 1.8 if boosted else 3.0
		var range_: float = 3.5 if boosted else 6.0
		_next_lightning_at = _elapsed + min_gap + randf() * range_

func _draw() -> void:
	_draw_wind_streaks()
	_draw_rain()
	_draw_lightning()

func _draw_wind_streaks() -> void:
	var wind_level: int = GameState.compute_stage("wind")
	if wind_level <= 0:
		return
	var dir: float = wind.direction
	var streak_color := Color(1, 1, 1, 0.3)
	var visible: int = STREAK_LEVEL_COUNT[wind_level] if wind_level < STREAK_LEVEL_COUNT.size() else _wind_streaks.size()
	for i in range(min(visible, _wind_streaks.size())):
		var st: Dictionary = _wind_streaks[i]
		var cycle_pos: float = fmod(st["traveled"] + st["seed"] * 97.0, logical_w + 60.0) - 30.0
		var x: float = cycle_pos if dir > 0 else logical_w - cycle_pos
		var y: float = st["y"]
		draw_line(Vector2(x, y), Vector2(x + 16.0 * dir, y), streak_color, 1.0)

## count is the rain tier's own base allotment, boosted by how hard the
## wind is blowing (up to RAIN_COUNT's headroom, see its own header) —
## the original never varied drop count with wind, only angle/speed,
## which read as the two systems not agreeing on how bad the weather
## actually was.
func _draw_rain() -> void:
	var stage: int = GameState.compute_stage("rain")
	if stage <= 0:
		return
	var wind_density_mul: float = 1.0 + wind.force * 0.35
	var count: int = min(_rain_particles.size(), int(round(RAIN_STAGE_COUNTS[stage] * wind_density_mul)))
	var base_alpha: float = 0.8
	var rain_color: Color = Color(206.0 / 255.0, 228.0 / 255.0, 255.0 / 255.0, base_alpha)
	var rain_angle: float = _rain_angle()
	var len_mul: float = 1.0 + wind.force * 0.45
	var sin_a: float = sin(rain_angle)
	var cos_a: float = cos(rain_angle)
	for i in range(count):
		var p: Dictionary = _rain_particles[i]
		var y: float = fmod(p["y"] + p["fallen"], logical_h)
		var x: float = fmod(fmod(p["x"] + p["drift"], logical_w) + logical_w, logical_w)
		var len_: float = p["len"] * len_mul
		var color: Color = Color(rain_color.r, rain_color.g, rain_color.b, rain_color.a * p["alpha"])
		draw_line(Vector2(x, y), Vector2(x + sin_a * len_, y + cos_a * len_), color, 1.0)

func _draw_lightning() -> void:
	if _lightning_until <= _elapsed:
		return
	var remain: float = _lightning_until - _elapsed
	var alpha: float = clamp(remain / 0.5, 0.0, 0.85)
	draw_rect(Rect2(0, 0, logical_w, logical_h), Color(1, 1, 1, alpha))
	_draw_bolt(alpha)

func _draw_bolt(alpha: float) -> void:
	var x0: float = logical_w * (0.35 + seeded(_bolt_seed) * 0.3)
	var points := PackedVector2Array()
	var x: float = x0
	var y: float = 0.0
	points.append(Vector2(x, y))
	var segs: int = 6
	for i in range(1, segs + 1):
		y = (logical_h * 0.5) * (float(i) / segs)
		x += (seeded(_bolt_seed + i) - 0.5) * 18.0
		points.append(Vector2(x, y))
	draw_polyline(points, Color(255.0 / 255.0, 249.0 / 255.0, 214.0 / 255.0, alpha), 2.0)
