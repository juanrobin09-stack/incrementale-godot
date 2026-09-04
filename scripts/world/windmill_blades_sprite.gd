class_name WindmillBladesSprite
extends PixelDrawer
## Procedurally-drawn rotating sails for the windmill (world_scene.gd),
## a small child of the windmill's own HouseSprite — NOT a texture.
##
## The real reference art has no separable blade layer (one flat painted
## image, tower and sails together), so a first pass extracted the sails
## by image processing (hub detection, geometric/colour masking,
## inpainting the tower underneath) and mirrored the one cleanly-
## separable sail into a 4-fold rotor. That held up in isolated renders
## but not once actually seen in the game: this renderer scales its low-
## resolution canvas up WITHOUT smoothing to keep the pixel-art look
## (world_viewport_host.gd), and fine painted gradient detail turns to
## mush under that nearest-neighbour scaling at the sail's small on-
## screen size — reported directly ("ressemble à rien"). This is exactly
## why every OTHER small/thin element in this renderer (trees, lamppost,
## fence, bushes...) is flat-shaded procedural primitives rather than
## painted art in the first place; the sails just hadn't been brought in
## line with that yet. Tower stays the real reference art (large enough
## to hold up fine, same as the houses) — reverted to the ORIGINAL,
## unmodified PNGs, no inpainting attempt at all, since the inpainted
## version was the other half of the same first pass and isn't needed
## anymore now the sails aren't cut out of it.
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
	var blade_len: float = h * 0.30
	var min_hw: float = 1.2
	var max_hw: float = 4.0
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
		draw_line(Vector2.ZERO, Vector2(blade_len, 0), trim, 1.6)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_circle(Vector2.ZERO, 2.8, trim)
