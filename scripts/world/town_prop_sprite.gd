class_name TownPropSprite
extends PixelDrawer
## Small procedural street furniture for the level 2 town — barrels,
## crates, benches, sign posts, carts, woodpiles (see world_scene.gd's own
## header for why the town needed *some* of this and why it's procedural
## rather than real reference art like the houses/windmill/well: no
## image-generation tool exists in this environment, and unlike those
## three, no reference PNG was ever provided for street props either) —
## this is the same flat-shaded px_rect/px_circle/px_rotated_rect
## primitive approach the original village decor (fence/lamp post/bushes)
## already uses for exactly that reason, not a downgrade invented just for
## this class.
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
		"cart":
			_draw_cart()
		"woodpile":
			_draw_woodpile()

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

## A resting handcart: bed on two wheels, shaft trailing on the ground —
## px_rotated_rect (unused by the other props here) is the natural fit for
## the angled shaft, the one shape in this file that isn't axis-aligned.
func _draw_cart() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var wheel_r: float = max(2.0, h * 0.22)
	var bed_top: float = -h
	var bed_h: float = max(2.0, h - wheel_r * 1.6)
	px_rect(-w / 2.0, bed_top, w, bed_h, wood)
	px_rect(-w / 2.0, bed_top, w, 1, wood_dark)
	px_rect(-w / 2.0, bed_top + bed_h - 1, w, 1, wood_dark)
	var wheel_y: float = -wheel_r
	px_circle(-w * 0.28, wheel_y, wheel_r, wood_dark, wood_dark)
	px_circle(w * 0.28, wheel_y, wheel_r, wood_dark, wood_dark)
	px_circle(-w * 0.28, wheel_y, wheel_r * 0.3, wood, wood)
	px_circle(w * 0.28, wheel_y, wheel_r * 0.3, wood, wood)
	px_rotated_rect(-w * 0.6, -wheel_r * 0.6, w * 0.55, 1.5, -0.3, wood_dark)

## Stacked cut logs, narrower toward the top like a real pile, with a
## couple of end-cap rings on the frontmost (widest) row for a "cut wood"
## look rather than plain bars.
func _draw_woodpile() -> void:
	var wood: Color = Palette.c("wood")
	var wood_dark: Color = Palette.c("woodDark")
	var wood_light: Color = Palette.c("woodLight")
	var rows: int = 3
	var row_h: float = h / rows
	for i in range(rows):
		var y: float = -h + i * row_h
		var inset: float = row_h * 0.5 * float(rows - 1 - i)
		px_rect(-w / 2.0 + inset, y, w - inset * 2.0, max(1.0, row_h - 1.0), wood_dark)
	var cap_r: float = max(1.0, row_h * 0.4)
	var cap_y: float = -row_h * 0.5
	px_circle(-w * 0.25, cap_y, cap_r, wood, wood)
	px_circle(w * 0.15, cap_y, cap_r, wood, wood)
	px_circle(-w * 0.25, cap_y, cap_r * 0.4, wood_light, wood_light)
	px_circle(w * 0.15, cap_y, cap_r * 0.4, wood_light, wood_light)
