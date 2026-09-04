class_name WindmillBladesSprite
extends PixelDrawer
## Procedurally-drawn rotating sails for the windmill (world_scene.gd),
## a small child of the windmill's own HouseSprite — NOT a texture.
##
## The real reference art has no separable blade layer (one flat painted
## image, tower and sails together). A first pass extracted the sails by
## image processing and mirrored the one cleanly-separable sail into a
## 4-fold rotor, texture and all — that held up in isolated renders but
## not once actually seen in the game: this renderer scales its low-
## resolution canvas up WITHOUT smoothing to keep the pixel-art look
## (world_viewport_host.gd), and fine painted gradient detail turns to
## mush under that nearest-neighbour scaling at the sail's small on-
## screen size ("ressemble à rien"). Reverting to flat-shaded procedural
## sails on the ORIGINAL, untouched tower fixed that — but left the
## original painted sails still visibly crossing the tower underneath
## the new ones (reported directly, screenshot: "on voit toujours les
## petites hélices derrière"), since only the overlay changed, not the
## art it's drawn on top of.
##
## Reinstated the inpainted tower (assets/windmill/windmill*.png, the
## original blade crossing removed and the gap filled — radial copy on
## the roof cone, a soft neighbourhood-average fill on the wall/window
## area, see git history for the extraction script) alongside these
## procedural sails, so there's exactly one set of blades, not two.
## Re-verified this time with the CORRECT methodology for each half: the
## tower is a TEXTURE stretched into a small destination rect, so
## nearest-neighbour minification is a fair proxy for how it actually
## samples; these sails are VECTOR shapes Godot rasterizes NATIVELY at
## the small on-screen size, not drawn "big" and downsampled afterwards
## — composited at that same small scale before judging it, which is
## what caught the first mistake in the first place.
##
## Also sized down (blade length 0.30h → 0.24h, half-width now scaled
## BY h too instead of fixed absolute pixels) after a report that the
## first pass read as disproportionate — thickness now tracks length so
## the sails keep the same silhouette regardless of the windmill's
## actual on-screen size at a given resolution, rather than a fixed
## pixel width that would read thin at some sizes and chunky at others.
##
## Cream sail + dark wood trim to roughly match the reference art's own
## blade palette (not the old red-roofed procedural windmill's
## alternating cream/red, which was tuned for a different roof colour).
##
## Positioned as an actual child of the windmill's HouseSprite (not a
## sibling in `entities`) so it always draws immediately after the tower
## and inherits the tower's own y-sort position, rather than being
## independently y-sorted by its own (much higher, near the roof) y —
## which would incorrectly sort it against unrelated nearby entities.
##
## Spins continuously off the shared WindEngine, same base-speed-per-
## wind-level table and force multiplier the original procedural
## windmill_sprite.gd used, so the rotation *feel* is unchanged — except
## gated by mill.is_intact() so the sails freeze once collapse begins
## instead of spinning through the ruin.

var h: float
var wind: WindEngine
var mill: HouseSprite
var _angle: float = 0.0

const BASE_SPEED_BY_LEVEL := [0.0, 1.4, 3.2, 6.0]
const FORCE_MUL := 2.2

func setup(p_h: float, p_wind: WindEngine, p_mill: HouseSprite) -> void:
	h = p_h
	wind = p_wind
	mill = p_mill
	queue_redraw()

func _process(delta: float) -> void:
	if mill != null and mill.is_intact():
		var wind_level: int = GameState.compute_stage("wind")
		var base_speed: float = BASE_SPEED_BY_LEVEL[wind_level] if wind_level < BASE_SPEED_BY_LEVEL.size() else 0.0
		_angle += (base_speed + wind.force * FORCE_MUL) * delta * wind.direction
	queue_redraw()

func _draw() -> void:
	var blade_len: float = h * 0.24
	var min_hw: float = h * 0.017
	var max_hw: float = h * 0.05
	var sail: Color = Palette.c("wallCream")
	var sail_shadow: Color = Palette.c("wallCreamShadow")
	var trim: Color = Palette.c("woodDark")
	for i in range(4):
		draw_set_transform(Vector2.ZERO, _angle + (PI / 2.0) * i)
		var steps: int = 8
		for s in range(steps):
			var t0: float = float(s) / steps
			var t1: float = float(s + 1) / steps
			var hw: float = min_hw + (max_hw - min_hw) * t1
			draw_rect(Rect2(blade_len * t0, -hw, blade_len * (t1 - t0) + 0.5, hw * 2.0), sail)
		var tip_w: float = blade_len * 0.22
		draw_rect(Rect2(blade_len - tip_w, -max_hw, tip_w, max_hw * 2.0), sail_shadow)
		draw_line(Vector2.ZERO, Vector2(blade_len, 0), trim, max(1.0, h * 0.012))
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_circle(Vector2.ZERO, h * 0.045, trim)
