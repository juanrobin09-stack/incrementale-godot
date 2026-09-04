class_name BackgroundLayer
extends PixelDrawer
## Sky (gradient + sun), hills, horizon haze, textured ground, and the
## road — originally a direct translation of drawSky/drawHills/
## drawHorizonHaze/drawGround/drawRoad from render.js, including the
## storm-driven colour shift (computeSkyStormT/computeStormShade read
## live from GameState's disaster stages, same formulas as the
## original), and clouds (buildCloudSet()/drawClouds() — deterministic
## seeded blob clusters, drifting with the shared WindEngine). The storm
## darkening overlay and the always-on vignette are deferred — visual
## polish, not core weather.
##
## Ground/road/sky/cloud detail level raised in a later pass, once the
## houses became real painted reference art (assets/houses/) instead of
## procedural drawing — a flat rect road and a single light/dark ground
## speckle read as a different, much cruder game next to that art. Still
## the same flat-shaded px_rect/px_circle primitives (no new rendering
## technique, no texture assets for this layer — see palette.gd's header
## for why: no image-generation tool available, so this had to stay
## procedural), just noticeably more of them and more color variety.

var logical_w: float
var logical_h: float
var ground_top: float
var ground_h: float
var road_x: float
var road_w: float
var wind: WindEngine

var _ground_texture: Array = []
var _road_texture: Array = []
var _cloud_defs: Array = []

func setup(p_w: float, p_h: float, p_ground_top: float, p_ground_h: float, p_road_x: float, p_road_w: float, p_wind: WindEngine) -> void:
	logical_w = p_w
	logical_h = p_h
	ground_top = p_ground_top
	ground_h = p_ground_h
	road_x = p_road_x
	road_w = p_road_w
	wind = p_wind
	_build_ground_texture()
	_build_road_texture()
	_build_clouds()
	queue_redraw()

func _build_clouds() -> void:
	_cloud_defs.clear()
	var layers := [
		{"n": 3, "speedMul": 0.5, "scaleMul": 0.62, "alpha": 0.42, "fyLo": 0.02, "fyHi": 0.09},
		{"n": 3, "speedMul": 0.95, "scaleMul": 0.88, "alpha": 0.72, "fyLo": 0.08, "fyHi": 0.18},
		{"n": 2, "speedMul": 1.5, "scaleMul": 1.15, "alpha": 0.95, "fyLo": 0.14, "fyHi": 0.25},
	]
	var idx: int = 0
	for li in range(layers.size()):
		var layer = layers[li]
		for i in range(int(layer["n"])):
			var seed: float = idx * 13.7 + 4.0
			var core_count: int = 5 + int(floor(seeded(seed) * 4.0))
			var blobs: Array = []
			for b in range(core_count):
				var u: float = (float(b) / (core_count - 1)) - 0.5 if core_count > 1 else 0.0
				var taper: float = 1.0 - abs(u) * 1.5
				var jx: float = (seeded(seed + b * 2.1) - 0.5) * 0.55
				var jy: float = (seeded(seed + b * 3.3 + 1) - 0.5) * 0.4
				blobs.append({
					"dx": u * 3.6 + jx,
					"dy": -max(0.0, taper) * 0.55 + jy,
					"r": max(0.32, taper * 0.85 + 0.3) * (0.8 + seeded(seed + b * 1.7 + 2) * 0.45),
					"dark": seeded(seed + b * 5.1 + 3) > 0.6,
					"wisp": false,
				})
			var wisp_count: int = 2 + int(floor(seeded(seed + 20) * 2.0))
			for w2 in range(wisp_count):
				var side: float = 1.0 if seeded(seed + 30 + w2) > 0.5 else -1.0
				blobs.append({
					"dx": side * (1.9 + seeded(seed + 31 + w2) * 1.3),
					"dy": (seeded(seed + 32 + w2) - 0.5) * 0.7,
					"r": 0.22 + seeded(seed + 33 + w2) * 0.28,
					"dark": false,
					"wisp": true,
				})
			_cloud_defs.append({
				"layer": li, "speedMul": layer["speedMul"], "scaleMul": layer["scaleMul"], "baseAlpha": layer["alpha"],
				"fx0": seeded(seed + 9), "fy": float(layer["fyLo"]) + seeded(seed + 10) * (float(layer["fyHi"]) - float(layer["fyLo"])),
				"blobs": blobs, "traveled": 0.0,
			})
			idx += 1

func _update_clouds(delta: float) -> void:
	var wind_speed_mul: float = 1.0 + wind.force * 1.8
	for c in _cloud_defs:
		var speed: float = (3.0 + c["layer"] * 1.3) * c["speedMul"]
		c["traveled"] += speed * wind_speed_mul * delta

## Sparse detail layers instead of one flat scatter of light/dark dots —
## a single 1px light-or-dark speckle was the single biggest gap between
## this ground and the painted texture of the house references
## (assets/houses/) once those replaced the procedural house drawing:
## next to real material variation, one uniform green with speckle noise
## reads as flat. Each layer's colour is resolved once here (not per
## frame in _draw_ground) since setup() already reruns per resize.
##
## Started at four layers; two are gone on direct feedback since — a
## sparse flower-accent layer (too eye-catching at the real render
## scale), and a dirt/dry-grass patch layer (small brown/tan rects,
## reported as visual clutter) — leaving grass blades and pebbles as the
## two that read as texture rather than noise.
func _build_ground_texture() -> void:
	_ground_texture.clear()
	var area: float = logical_w * ground_h

	var blade_colors := [Palette.c("grassShadow"), Palette.c("grassDeep"), Palette.c("grassLight"), Palette.c("grassLight2")]
	var blade_n: int = int(round(area / 70.0))
	for i in range(blade_n):
		var n: float = seeded(i * 2.3)
		var color: Color = blade_colors[0] if n < 0.35 else (blade_colors[1] if n < 0.55 else (blade_colors[2] if n < 0.8 else blade_colors[3]))
		var tall: bool = seeded(i * 9.7 + 4.0) > 0.5
		_ground_texture.append({
			"x": seeded(i * 3.1) * logical_w, "y": seeded(i * 7.7 + 1.0) * ground_h,
			"w": 1.0, "h": 2.0 if tall else 1.0, "color": color,
		})

	var pebble_light: Color = Palette.c("stoneLight")
	var pebble_dark: Color = Palette.c("stoneDark")
	var pebble_n: int = int(round(area / 700.0))
	for i in range(pebble_n):
		var s: float = i * 6.7 + 200.0
		var color: Color = pebble_dark if seeded(s + 1.0) > 0.5 else pebble_light
		_ground_texture.append({
			"x": seeded(s) * logical_w, "y": seeded(s + 2.0) * ground_h,
			"w": 1.0 + seeded(s + 3.0), "h": 1.0, "color": color,
		})


## Sparse worn/pebble detail scattered across the road's own area —
## positions stored relative to (road_x - road_w/2, ground_top) so they
## stay put regardless of the edge jitter _draw_road() applies around
## them (see _road_edge_offset).
func _build_road_texture() -> void:
	_road_texture.clear()
	var area: float = road_w * ground_h
	var stone_c: Color = Palette.c("stone")
	var stone_dark_c: Color = Palette.c("stoneDark")
	var dirt_light_c: Color = Palette.c("dirtLight")
	var n: int = int(round(area / 75.0))
	for i in range(n):
		var s: float = i * 4.3 + 500.0
		var pick: float = seeded(s + 1.0)
		var color: Color = stone_dark_c if pick > 0.75 else (stone_c if pick > 0.5 else dirt_light_c)
		_road_texture.append({
			"x": seeded(s) * road_w, "y": seeded(s + 2.0) * ground_h,
			"w": 1.0 + seeded(s + 3.0), "h": 1.0, "color": color,
		})

func _process(delta: float) -> void:
	_update_clouds(delta)
	queue_redraw()

func _compute_sky_storm_t() -> float:
	var storm_stage: float = float(GameState.compute_stage("storm"))
	var rain_stage: float = float(GameState.compute_stage("rain"))
	return min(1.0, (storm_stage / 2.0) * 0.85 + (rain_stage / 4.0) * 0.4)

func _compute_storm_shade() -> float:
	var storm_stage: float = float(GameState.compute_stage("storm"))
	var rain_stage: float = float(GameState.compute_stage("rain"))
	return min(1.0, (storm_stage / 2.0) * 0.7 + (rain_stage / 4.0) * 0.35)

func _draw() -> void:
	var storm_sky_t: float = _compute_sky_storm_t()
	var storm_shade: float = _compute_storm_shade()
	_draw_sky(storm_sky_t)
	_draw_hills()
	_draw_horizon_haze(storm_sky_t)
	_draw_ground(storm_shade)
	_draw_road()

## Four gradient stops now, not three (skyUpperAccent added on top of
## the original top/mid/horizon) — one more band of depth at the zenith,
## which read as flat/empty next to the shading in the house references.
func _draw_sky(storm_t: float) -> void:
	var upper: Color = Palette.c("skyUpperAccent").lerp(Palette.c("skyTopStorm"), storm_t)
	var top: Color = Palette.c("skyTop").lerp(Palette.c("skyTopStorm"), storm_t)
	var mid: Color = Palette.c("skyMid").lerp(Palette.c("skyMidStorm"), storm_t)
	var horizon: Color = Palette.c("skyHorizon").lerp(Palette.c("skyHorizonStorm"), storm_t)
	var band_h: float = ceil(logical_h / 28.0)
	for i in range(28):
		var p: float = float(i) / 27.0
		var color: Color
		if p < 0.3:
			color = upper.lerp(top, p / 0.3)
		elif p < 0.6:
			color = top.lerp(mid, (p - 0.3) / 0.3)
		else:
			color = mid.lerp(horizon, (p - 0.6) / 0.4)
		px_rect(0, i * band_h, logical_w, band_h + 1, color)

	if storm_t < 0.85:
		var sun_x: float = logical_w * 0.82
		var sun_y: float = logical_h * 0.16
		var r: float = max(6.0, logical_w * 0.028)
		# Original uses ctx.globalAlpha around this whole block — Godot's
		# draw_*() calls have no ambient-alpha equivalent, so the fade has
		# to be multiplied into every colour used here instead.
		var fade: float = max(0.0, 1.0 - storm_t * 1.3)
		# Two nested halos (was one) — a wide faint one plus the tighter
		# original — reads as light diffusing into the sky instead of a
		# single flat ring around the disc.
		draw_circle(Vector2(sun_x, sun_y), r * 3.6, Color(1.0, 0.902, 0.6, 0.12 * fade))
		draw_circle(Vector2(sun_x, sun_y), r * 2.1, Color(1.0, 0.847, 0.451, 0.25 * fade))
		var sun_c: Color = Palette.c("sun")
		var sun_mid_c: Color = Palette.c("sunMid")
		px_circle(sun_x, sun_y, r,
			Color(sun_c.r, sun_c.g, sun_c.b, fade),
			Color(sun_mid_c.r, sun_mid_c.g, sun_mid_c.b, fade))

	_draw_clouds(storm_t)

func _draw_clouds(storm_t: float) -> void:
	var base: Color = Palette.c("cloudStorm") if storm_t > 0.4 else Palette.c("cloud")
	var shadow: Color = Palette.c("cloudStormShadow") if storm_t > 0.4 else Palette.c("cloudShadow")
	var highlight: Color = Color(1.0, 1.0, 1.0)
	var dir: float = wind.direction
	for c in _cloud_defs:
		var cycle: float = logical_w + 260.0
		var phase: float = fmod(c["fx0"] * cycle + c["traveled"], cycle)
		var x: float = phase - 130.0 if dir > 0 else (cycle - 130.0) - phase
		var y: float = c["fy"] * logical_h
		var scale: float = c["scaleMul"] * logical_w * 0.05
		for b in c["blobs"]:
			var r: float = max(1.0, scale * b["r"])
			# Same ctx.globalAlpha-to-per-colour-multiplication translation
			# as the sun fade above.
			var alpha: float = c["baseAlpha"] * (0.45 if b["wisp"] else 1.0)
			var bx: float = x + b["dx"] * scale
			var by: float = y + b["dy"] * scale
			if b["dark"]:
				var sc := Color(shadow.r, shadow.g, shadow.b, alpha)
				px_circle(bx, by, r, sc, sc)
			else:
				px_circle(bx, by, r, Color(base.r, base.g, base.b, alpha), Color(shadow.r, shadow.g, shadow.b, alpha))
				# A smaller, brighter "sunlit crown" layered on top of the
				# core blobs (not wisps, too thin to read a highlight on)
				# — px_circle only ever splits left/right two-tone, so a
				# top-lit puffy look needs a second, offset-up circle
				# rather than a new primitive shared by every other sprite.
				if not b["wisp"]:
					var hl := Color(highlight.r, highlight.g, highlight.b, alpha * 0.5)
					px_circle(bx - r * 0.12, by - r * 0.28, r * 0.5, hl, hl)

func _draw_hills() -> void:
	var w := logical_w
	var h := logical_h
	var gt := ground_top
	px_ellipse(w * 0.12, gt, w * 0.22, h * 0.05, Palette.c("hillsFar"))
	px_ellipse(w * 0.4, gt, w * 0.28, h * 0.06, Palette.c("hillsNear"))
	px_ellipse(w * 0.68, gt, w * 0.24, h * 0.05, Palette.c("hillsFar"))
	px_ellipse(w * 0.92, gt, w * 0.26, h * 0.06, Palette.c("hillsNear"))

## The one deliberately smooth (non-banded) gradient in the whole
## renderer — the original explicitly wants this seam to fade rather
## than cut, so it's drawn as two vertex-colour-interpolated quads
## instead of pixel bands.
func _draw_horizon_haze(storm_t: float) -> void:
	var haze_color: Color = Palette.c("skyHorizon").lerp(Palette.c("skyHorizonStorm"), storm_t)
	var band_h: float = max(6.0, ground_top * 0.16)
	var top_y: float = ground_top - band_h
	var total_h: float = band_h * 1.5
	var mid_y: float = top_y + total_h * 0.55
	var bottom_y: float = top_y + total_h
	var transparent := Color(haze_color.r, haze_color.g, haze_color.b, 0.0)
	var opaque := Color(haze_color.r, haze_color.g, haze_color.b, 0.5)
	draw_polygon(
		PackedVector2Array([Vector2(0, top_y), Vector2(logical_w, top_y), Vector2(logical_w, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([transparent, transparent, opaque, opaque])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, mid_y), Vector2(logical_w, mid_y), Vector2(logical_w, bottom_y), Vector2(0, bottom_y)]),
		PackedColorArray([opaque, opaque, transparent, transparent])
	)

func _draw_ground(storm_shade: float) -> void:
	var grass: Color = Palette.c("grassMid").lerp(Color("#4c5a44"), storm_shade)
	px_rect(0, ground_top, logical_w, ground_h, grass)
	for d in _ground_texture:
		px_rect(d["x"], ground_top + d["y"], d["w"], d["h"], d["color"])

## Smooth, low-amplitude wavy offset for one road edge at a given y —
## a sum of two incommensurate sine waves (same idea as WindEngine's
## force curve) rather than per-strip random jitter, so the edge reads
## as one continuous wandering line instead of a jagged/noisy one.
## side_seed offsets phase between the two edges so the road's width
## itself subtly breathes instead of both edges snaking in lockstep —
## a straight-sided rectangle was the clearest "this is a UI shape, not
## a place" tell once the houses became real reference art.
func _road_edge_offset(y: float, side_seed: float) -> float:
	var t: float = y / max(1.0, ground_h)
	# A single low frequency (under half a cycle across the visible road)
	# at a small amplitude — a first pass summed two faster sines and
	# read as a kinked/broken line rather than a road, not the gentle
	# meander it was going for.
	var wave: float = sin(t * 2.2 + side_seed)
	return wave * road_w * 0.045

func _draw_road() -> void:
	var h: float = ground_h
	var dirt_c: Color = Palette.c("dirt")
	var dirt_dark_c: Color = Palette.c("dirtDark")
	var dirt_light_c: Color = Palette.c("dirtLight")
	var grass_edge_c: Color = Palette.c("grassDark")
	var grass_edge_c2: Color = Palette.c("grassShadow")

	var step: float = 3.0
	var y: float = 0.0
	while y < h:
		var sh: float = min(step, h - y)
		var left_x: float = road_x - road_w / 2.0 + _road_edge_offset(y, 0.0)
		var right_x: float = road_x + road_w / 2.0 + _road_edge_offset(y, 7.3)
		px_rect(left_x, ground_top + y, right_x - left_x, sh, dirt_c)
		px_rect(left_x, ground_top + y, 1, sh, dirt_dark_c)
		px_rect(right_x - 1, ground_top + y, 1, sh, dirt_dark_c)
		# Grass tufts encroaching from the edges — sparse and seeded, not
		# every strip, so they read as occasional weeds, not a border.
		if seeded(y * 0.37 + 40.0) > 0.72:
			px_rect(left_x - 1.0 - seeded(y * 0.51) * 1.0, ground_top + y, 1, 1, grass_edge_c if seeded(y * 0.19) > 0.5 else grass_edge_c2)
		if seeded(y * 0.41 + 90.0) > 0.72:
			px_rect(right_x + seeded(y * 0.59) * 1.0, ground_top + y, 1, 1, grass_edge_c if seeded(y * 0.23) > 0.5 else grass_edge_c2)
		y += step

	# Worn centre path, wandering gently with the road rather than
	# staying perfectly straight against now-wavy edges.
	y = 0.0
	while y < h:
		px_rect(road_x - 1 + _road_edge_offset(y, 3.5) * 0.3, ground_top + y, 2, 4, dirt_light_c)
		y += 10

	for d in _road_texture:
		px_rect(road_x - road_w / 2.0 + d["x"], ground_top + d["y"], d["w"], d["h"], d["color"])
