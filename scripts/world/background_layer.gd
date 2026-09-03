class_name BackgroundLayer
extends PixelDrawer
## Sky (24-band gradient + sun — clouds and the storm color-shift are a
## later weather-layer pass), hills, horizon haze, textured ground, and
## the road. Direct translation of drawSky/drawHills/drawHorizonHaze/
## drawGround/drawRoad from render.js. Storm tint is hardcoded to 0 for
## this static-village pass — the original blends toward a darker sky
## and grass as storm/rain rise, ported later alongside weather.

var logical_w: float
var logical_h: float
var ground_top: float
var ground_h: float
var road_x: float
var road_w: float

var _ground_texture: Array = []

func setup(p_w: float, p_h: float, p_ground_top: float, p_ground_h: float, p_road_x: float, p_road_w: float) -> void:
	logical_w = p_w
	logical_h = p_h
	ground_top = p_ground_top
	ground_h = p_ground_h
	road_x = p_road_x
	road_w = p_road_w
	_build_ground_texture()
	queue_redraw()

func _build_ground_texture() -> void:
	_ground_texture.clear()
	var n: int = int(round((logical_w * ground_h) / 90.0))
	for i in range(n):
		_ground_texture.append({
			"x": seeded(i * 3.1) * logical_w,
			"y": seeded(i * 7.7 + 1) * ground_h,
			"dark": seeded(i * 2.3) > 0.5,
		})

func _draw() -> void:
	_draw_sky()
	_draw_hills()
	_draw_horizon_haze()
	_draw_ground()
	_draw_road()

func _draw_sky() -> void:
	var top: Color = Palette.c("skyTop")
	var mid: Color = Palette.c("skyMid")
	var horizon: Color = Palette.c("skyHorizon")
	var band_h: float = ceil(logical_h / 24.0)
	for i in range(24):
		var p: float = float(i) / 23.0
		var color: Color = top.lerp(mid, p / 0.6) if p < 0.6 else mid.lerp(horizon, (p - 0.6) / 0.4)
		px_rect(0, i * band_h, logical_w, band_h + 1, color)

	var sun_x: float = logical_w * 0.82
	var sun_y: float = logical_h * 0.16
	var r: float = max(6.0, logical_w * 0.028)
	draw_circle(Vector2(sun_x, sun_y), r * 2.1, Color(1.0, 0.847, 0.451, 0.25))
	px_circle(sun_x, sun_y, r, Palette.c("sun"), Palette.c("sunMid"))

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
func _draw_horizon_haze() -> void:
	var haze_color: Color = Palette.c("skyHorizon")
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

func _draw_ground() -> void:
	px_rect(0, ground_top, logical_w, ground_h, Palette.c("grassMid"))
	var light: Color = Palette.c("grassLight")
	var shadow: Color = Palette.c("grassShadow")
	for d in _ground_texture:
		px_rect(d["x"], ground_top + d["y"], 1, 1, shadow if d["dark"] else light)

func _draw_road() -> void:
	var h: float = ground_h * 0.78
	px_rect(road_x - road_w / 2.0, ground_top, road_w, h, Palette.c("dirt"))
	px_rect(road_x - road_w / 2.0, ground_top, 1, h, Palette.c("dirtDark"))
	px_rect(road_x + road_w / 2.0 - 1, ground_top, 1, h, Palette.c("dirtDark"))
	var y: float = 0.0
	while y < h:
		px_rect(road_x - 1, ground_top + y, 2, 4, Palette.c("dirtLight"))
		y += 10
