class_name TownPropSprite
extends PixelDrawer
## Small procedural street furniture for the level 2 town — barrels,
## crates, benches, sign posts (see world_scene.gd's own header for why
## the town needed *some* of this and why it's procedural rather than
## real reference art like the houses/windmill/well: no image-generation
## tool exists in this environment, and unlike those three, no reference
## PNG was ever provided for street props either) — this is the same
## flat-shaded px_rect primitive approach the original village decor
## (fence/lamp post/bushes) already uses for exactly that reason, not a
## downgrade invented just for this class.
##
## Deliberately static — no wind sway, no damage state. A barrel or crate
## rocking in the wind the way a tree or bush does would need its own
## physically-plausible motion this project has no reference for, and
## nothing asked for these to be destructible the way houses/windmill/
## well are; they're texture on the street, the same role bushes/flowers
## already play in the village.

var kind: String = "barrel"
var w: float = 10.0
var h: float = 10.0

func setup(p_kind: String, p_w: float, p_h: float) -> void:
	kind = p_kind
	w = p_w
	h = p_h
	queue_redraw()

func _draw() -> void:
	match kind:
		"barrel":
			_draw_barrel()
		"crate":
			_draw_crate()
		"bench":
			_draw_bench()
		"sign":
			_draw_sign()

## Anchored at its own base (0,0), extending upward — same convention as
## every other ground-contact sprite in this project (houses, trees,
## lamp posts), so it sorts correctly against them via y_sort.
func _draw_barrel() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var wood_light: Color = Palette.c("woodLight")
	var rows: int = max(4, int(round(h)))
	for i in range(rows):
		var t: float = float(i) / float(rows - 1)
		# Bulges outward toward the middle, narrower at both rims —
		# a barrel's actual silhouette, not a plain rectangle.
		var bulge: float = 1.0 - pow(2.0 * t - 1.0, 2.0) * 0.35
		var half_w: float = max(1.0, w * 0.5 * bulge)
		var y: float = round(-h + i)
		px_rect(-half_w, y, half_w, 1, wood_dark)
		px_rect(0, y, half_w, 1, wood)
	# Two darker hoop bands plus one light highlight column, all riding on
	# top of the rows already drawn above.
	for hoop_t in [0.22, 0.78]:
		var y: float = round(-h + h * hoop_t)
		px_rect(-w * 0.52, y, w * 1.04, 1, wood_dark)
	px_rect(-w * 0.08, -h * 0.9, 2, h * 0.8, wood_light)

func _draw_crate() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var wood_light: Color = Palette.c("woodLight")
	px_rect(-w / 2.0, -h, w, h, wood)
	px_rect(-w / 2.0, -h, w, 1, wood_dark)
	px_rect(-w / 2.0, -1, w, 1, wood_dark)
	px_rect(-w / 2.0, -h, 1, h, wood_dark)
	px_rect(w / 2.0 - 1, -h, 1, h, wood_dark)
	# Planked look: a couple of horizontal seams plus a light edge on the
	# top-left face, echoing the bevel language used on lamp_post_sprite's
	# painted metal.
	px_rect(-w / 2.0, -h * 0.66, w, 1, wood_dark)
	px_rect(-w / 2.0, -h * 0.33, w, 1, wood_dark)
	px_rect(-w / 2.0 + 1, -h + 1, w - 2, 1, wood_light)

func _draw_bench() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var seat_h: float = max(2.0, h * 0.28)
	px_rect(-w / 2.0, -h, w, seat_h, wood)
	px_rect(-w / 2.0, -h, w, 1, wood_dark)
	var leg_w: float = max(1.0, w * 0.1)
	px_rect(-w / 2.0 + leg_w * 0.3, -h + seat_h, leg_w, h - seat_h, wood_dark)
	px_rect(w / 2.0 - leg_w * 1.3, -h + seat_h, leg_w, h - seat_h, wood_dark)

func _draw_sign() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var wood_light: Color = Palette.c("woodLight")
	var post_w: float = max(1.0, w * 0.16)
	px_rect(-post_w / 2.0, -h, post_w, h, wood_dark)
	var plank_h: float = h * 0.32
	var plank_y: float = -h
	px_rect(-w / 2.0, plank_y, w, plank_h, wood)
	px_rect(-w / 2.0, plank_y, w, 1, wood_dark)
	px_rect(-w / 2.0, plank_y + plank_h - 1, w, 1, wood_dark)
	px_rect(-w / 2.0, plank_y, 1, plank_h, wood_light)
