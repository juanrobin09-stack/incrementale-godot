class_name LampPostSprite
extends PixelDrawer
## Originally a direct translation of drawLampPost() from render.js: an
## unlit pole + a plain rectangular lamp housing, 3 flat-shaded rects in
## total. Rebuilt with an actual structure — stone base, banded iron
## pole, a forged scroll bracket, and a proper hexagonal lantern cage
## with a soft glow halo — once the houses became real painted reference
## art (assets/houses/) and 3 flat rects next to that read as the
## clearest "unfinished placeholder" element in the whole scene.
##
## Still no dynamic day/night lighting — the glow is a fixed decorative
## warm colour, not tied to any time-of-day/weather state, same as
## before this pass. Lighting it up conditionally is unrelated to visual
## richness and stays a later pass, as the original comment already said.
##
## The first version of this rebuild had the lantern floating 3 units
## above the pole's own top with nothing drawn between them along the
## centreline — held up visually only by the thin, off-centre scroll
## bracket — reported directly, and fixed by landing the cage's bottom
## edge exactly on the pole's top instead (see _draw()'s own comment).

var h: float

func setup(p_h: float) -> void:
	h = p_h
	queue_redraw()

func _draw() -> void:
	var iron: Color = Palette.c("lampIron")
	var iron_lit: Color = Palette.c("lampIronLit")
	var stone_c: Color = Palette.c("stone")
	var stone_dark_c: Color = Palette.c("stoneDark")
	var glow: Color = Palette.c("windowGlow")

	# Stone base.
	px_rect(-3, -3, 6, 3, stone_dark_c)
	px_rect(-2, -4, 4, 1, stone_c)

	# Pole — a highlight strip down one side instead of one flat tone,
	# plus two banded collars.
	px_rect(-1, -h, 2, h - 4.0, iron)
	px_rect(-1, -h * 0.35, 1, max(0.0, h - 4.0 - h * 0.35), iron_lit)
	px_rect(-2, -h * 0.35, 4, 1, iron_lit)
	px_rect(-2, -h * 0.75, 4, 1, iron_lit)

	# Forged scroll bracket curling from the pole toward the lantern —
	# two angled segments standing in for a real curve primitive.
	draw_line(Vector2(1, -h), Vector2(4, -h - 3), iron, 1.4)
	draw_line(Vector2(4, -h - 3), Vector2(3, -h - 5), iron, 1.2)

	# Lantern: iron cage + glowing glass with a pane divider + pointed
	# cap, plus a soft warm halo behind it — same "low-alpha circle
	# layered behind the shape" technique background_layer.gd uses for
	# the sun/cloud highlights.
	#
	# ly is the cage's centre: cage bottom = ly+3, which must land exactly
	# on the pole's own top (-h) or the lantern reads as floating above
	# the pole with a gap, held up only by the thin off-centre scroll
	# bracket — it did exactly that (ly was -h-6, so cage bottom was
	# -h-3, three units short of the pole top) until this fix.
	var lx: float = 0.0
	var ly: float = -h - 3.0
	draw_circle(Vector2(lx, ly), 6.5, Color(glow.r, glow.g, glow.b, 0.22))
	px_rect(lx - 3, ly - 3, 6, 6, iron)
	px_rect(lx - 2, ly - 2, 4, 4, glow)
	px_rect(lx - 2, ly - 2, 1, 4, Color(iron.r, iron.g, iron.b, 0.6))
	px_rect(lx + 1, ly - 2, 1, 4, Color(iron.r, iron.g, iron.b, 0.6))
	px_triangle_up(lx, ly - 5, 3, 3, iron, iron_lit)
	px_rect(lx - 1, ly - 5, 2, 1, iron_lit)
