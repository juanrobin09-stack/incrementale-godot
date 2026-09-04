class_name WorldScene
extends Node2D
## Composes the village: background layer (sky/hills/ground/road,
## storm tint, clouds) + houses/trees/well/fence/lamp post/windmill/
## bushes/flowers, positioned via the exact same fractional layout as
## buildLayout() in render.js, so proportions match regardless of
## screen size. `y_sort_enabled` on the entities container replaces the
## original's manual `entities.sort(by sortY)` painter's algorithm —
## Godot draws y-sorted children back-to-front by position.y natively,
## and every sprite here is anchored at its own ground-contact point,
## so sorting by position.y is exactly sorting by the original's
## `sortY`. WeatherLayer (rain/lightning/wind streaks) draws after
## entities, on top, matching the original's foreground weather pass.
##
## Owns the single WindEngine instance shared by every wind-reactive
## sprite (trees, bushes, fence, clouds, wind streaks) and drives it
## once per frame here — see WindEngine's own header for why reading a
## shared object is safe regardless of Godot's exact _process() order
## between this node and its children.
##
## Also passes `entities` (the Y-sorted container itself) to trees/
## houses/windmill so their wind-damage state machines can spawn
## DebrisFragment/DustPuff children into it directly — see
## DebrisSpawner. Trees fall permanently once strain maxes out (no
## regrow); houses/windmill likewise never rebuild once truly collapsed
## — see each sprite's own header for the exact boundary.
##
## Trees are kept clear of houses (and of each other) by construction,
## not by placing them at hand-picked fx/fy and hoping: reported that
## some trees landed inside a house's footprint, which traced back to
## houses being anchored at their own BASE and extending UPWARD by their
## full height — a tree whose fy looks comfortably far from a house's fy
## can still land inside that house's actual destination rect once the
## house is tall enough, and eyeballing fractional coordinates doesn't
## surface that. Fixed generically: _add_houses() computes each house's
## exact destination rect (the same formula HouseSprite._draw() itself
## uses) and returns it; _add_trees() treats each tree as a circle sized
## to its own worst-case canopy reach (see its own header) and nudges
## its position (_clear_of_rects/_clear_of_circles) away from any house
## rect or already-placed tree it would otherwise overlap, resolved
## BEFORE the tree is ever instantiated. Houses themselves get the same
## treatment against each other first (_resolve_house_positions) —
## current curated fx/fy don't overlap at common resolutions, but the
## check is real, not assumed, since aspect ratio varies by viewport.
## All of this is plain reusable geometry, not tied to the current
## static defs arrays, so it applies the same way to any future dynamic
## spawn — there just isn't one yet.
##
## A tree could still end up floating clear of the ground band entirely
## (reported directly, screenshot: a tree adrift in the clouds) — traced
## to the original per-rect push (move out through whichever single
## edge of whichever single rect is nearest) having no notion of "stay
## within the ground area" at all: when two houses' grown zones overlap
## each other at a tree's height (confirmed happening between the gold
## and green houses, and separately between the blue house and the
## windmill, at ordinary resolutions), the nearest escape from ONE of
## them can be straight up, with nothing stopping it once clear of that
## rect — even though the new spot is still inside the OTHER rect, or
## the sky. The same per-rect approach can also fail more quietly:
## escaping rect A by the shortest path can land inside rect B, whose
## own shortest escape lands back inside A — an infinite bounce that
## still silently returns *some* position once the iteration cap is hit,
## one that in this project's own testing was still measurably inside
## the very rect it was supposed to have cleared.
##
## Fixed by resolving all of a tree's blocking rects AT ONCE rather than
## one at a time: at the tree's own (fixed) y, every rect whose grown
## span covers that y contributes a horizontal interval; overlapping
## intervals are merged first, and the tree escapes past the OUTER edge
## of whichever merged span currently contains it — a single move that
## clears every rect in that cluster together, never just the one it
## happened to touch first, so it can't bounce back into a neighbour or
## "escape" through a direction that was never actually clear. Movement
## is also now strictly horizontal — a tree's fy is its curated depth/
## row in the layout and this is the only thing that makes that
## guaranteed to survive collision resolution intact; vertical movement
## is what let a tree leave the ground band for the sky in the first
## place, and nothing in this layout ever needs a tree pushed toward or
## away from the viewer to explain a horizontal gap.
##
## This village is laid out densely enough that a handful of aspect
## ratios genuinely have no fully clear horizontal spot at some tree
## heights at all (checked directly: several houses' combined margins
## can span nearly the full screen width at once) — TREE_MAX_PUSH_MUL
## bounds how far a single tree will travel chasing a perfect spot, and
## the position is clamped back onto the screen afterwards, so a village
## this tight settles for the best reachable position instead of parking
## a tree off-screen or clear across it. Several trees' fy were also
## moved deeper (see _add_trees' own defs) to rows with genuinely more
## room in the first place, rather than leaning on the push alone.
##
## The windmill (_add_windmill) is a HouseSprite too, now that real
## reference art exists for it (assets/windmill/) — requested explicitly:
## same logic as the 5 houses rather than an independent system, and
## HouseSprite has nothing house-specific baked into it (the wall/roof
## colour params only tint debris), so it's a straight reuse, zero
## changes to house_sprite.gd itself. Its footprint feeds into the same
## tree-avoidance array _add_houses()'s rects do. Position/size moved
## from the old procedural windmill's (fx=0.90, fy=0.36, h=u*0.32): that
## windmill drew a narrow tower via pxRect primitives, but the real
## reference art is a ~1:1 square (the diagonal sails reach almost to the
## canvas edges) — nearly 3x wider, at the same height, than the old
## procedural approximation. Kept at fx=0.90 it clipped off the right
## edge on portrait/narrow viewports and overlapped the blue/purple
## houses; confirmed by computing every house's and the windmill's real
## rect (same formula _add_houses() uses) across a wide battery of
## resolutions (390x844 up to 3440x1440, plus square and tall-phone
## ratios). (fx=0.76, fy=0.54, h=u*0.30) is the largest footprint found
## clear of all 5 houses and the screen edges across that whole set.

var entities: Node2D
var _wind: WindEngine

func _ready() -> void:
	# Built once, here, rather than inside build(): build() re-runs on
	# every window resize, and re-creating WindEngine there would
	# re-randomize its direction each time — the original computes
	# WIND_DIRECTION exactly once, at load, and resize() never touches
	# it. _ready() fires exactly once per session (this node is created
	# once by WorldViewportHost), matching that.
	_wind = WindEngine.new()

func build(logical_w: float, logical_h: float) -> void:
	for child in get_children():
		child.queue_free()

	var ground_top: float = logical_h * 0.34
	var ground_h: float = logical_h - ground_top
	var u: float = ground_h

	var gx := func(f: float) -> float: return f * logical_w
	var gy := func(f: float) -> float: return ground_top + f * ground_h

	var background := BackgroundLayer.new()
	add_child(background)
	var road_x: float = gx.call(0.49)
	var road_w: float = max(10.0, u * 0.12)
	background.setup(logical_w, logical_h, ground_top, ground_h, road_x, road_w, _wind)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	var house_rects: Array = _add_houses(gx, gy, u)
	var windmill_rect: Rect2 = _add_windmill(gx, gy, u)
	_add_trees(gx, gy, u, house_rects + [windmill_rect])
	_add_decor(gx, gy, ground_h, u)

	var weather := WeatherLayer.new()
	add_child(weather)
	weather.setup(logical_w, logical_h, _wind)

func _process(delta: float) -> void:
	if _wind == null:
		return
	_wind.update(delta, GameState.compute_stage("wind"))

## Reference art (assets/houses/) provided directly, one per roof colour,
## intact and damaged — see HouseSprite's own header for why both states
## are real sprites instead of the procedural drawing every other village
## element uses, and for the collapse sequence that plays between them.
## "wall" stays in each def below only because it still feeds the wall/
## facade splinter colours the collapse sequence spawns; it no longer has
## any visual effect on the house itself, which is baked into the sprites.
##
## "tier" is the collapse sequence's size_tier (see HouseSprite): the 5
## houses are only 3 distinct shapes (red/green share one, blue/purple
## share one), so tier tracks the shape, not the colour — small red/green
## get a quick partial roof collapse, the taller gold house adds facade
## pieces, the large blue/purple houses get the biggest, most staggered
## collapse plus a faint shake.
const HOUSE_TEXTURES := {
	"roofRed": preload("res://assets/houses/house_red.png"),
	"roofGold": preload("res://assets/houses/house_gold.png"),
	"roofGreen": preload("res://assets/houses/house_green.png"),
	"roofBlue": preload("res://assets/houses/house_blue.png"),
	"roofPurple": preload("res://assets/houses/house_purple.png"),
}
const HOUSE_TEXTURES_DAMAGED := {
	"roofRed": preload("res://assets/houses/house_red_damaged.png"),
	"roofGold": preload("res://assets/houses/house_gold_damaged.png"),
	"roofGreen": preload("res://assets/houses/house_green_damaged.png"),
	"roofBlue": preload("res://assets/houses/house_blue_damaged.png"),
	"roofPurple": preload("res://assets/houses/house_purple_damaged.png"),
}
const WINDMILL_TEXTURE := preload("res://assets/windmill/windmill.png")
const WINDMILL_TEXTURE_DAMAGED := preload("res://assets/windmill/windmill_damaged.png")

## Returns each house's exact destination rect (post-overlap-resolution)
## so _add_trees() can keep trees out of them — see the class header for
## why this has to be the real rect, not just "trees far enough from the
## house's fx/fy".
func _add_houses(gx: Callable, gy: Callable, u: float) -> Array:
	var defs := [
		{"fx": 0.05, "fy": 0.22, "scale": 1.00, "roof": "roofRed", "wall": "wallCream", "tier": 0},
		{"fx": 0.235, "fy": 0.16, "scale": 0.94, "roof": "roofGold", "wall": "wallSlate", "tier": 1},
		{"fx": 0.335, "fy": 0.30, "scale": 0.90, "roof": "roofGreen", "wall": "wallSlate", "tier": 0},
		{"fx": 0.605, "fy": 0.24, "scale": 1.06, "roof": "roofPurple", "wall": "wallRose", "tier": 2},
		{"fx": 0.775, "fy": 0.17, "scale": 0.96, "roof": "roofBlue", "wall": "wallCream", "tier": 2},
	]

	var sizes: Array = []
	for d in defs:
		var tex: Texture2D = HOUSE_TEXTURES[d["roof"]]
		var h_house: float = u * 0.325 * d["scale"]
		var w_house: float = h_house * (float(tex.get_width()) / float(tex.get_height()))
		sizes.append(Vector2(w_house, h_house))
	var positions: Array = _resolve_house_positions(defs, sizes, gx, gy)

	var house_rects: Array = []
	for i in range(defs.size()):
		var d = defs[i]
		var size: Vector2 = sizes[i]
		var pos: Vector2 = positions[i]

		var house := HouseSprite.new()
		house.position = pos
		house.setup(
			size.y, HOUSE_TEXTURES[d["roof"]], HOUSE_TEXTURES_DAMAGED[d["roof"]],
			Palette.c(d["wall"]), Palette.c(d["wall"] + "Shadow"),
			Palette.c(d["roof"]), Palette.c(d["roof"] + "Shadow"),
			0.75 + _seeded(i * 9.1) * 0.6, i * 4.1 + 3.0, _wind, entities, d["tier"],
		)
		entities.add_child(house)
		house_rects.append(Rect2(pos.x - size.x / 2.0, pos.y - size.y, size.x, size.y))
	return house_rects

## Nudges any two houses whose exact destination rects overlap apart
## horizontally (never vertically — that would shift which one paints in
## front via y_sort, an unrelated concern) until clear. Defensive rather
## than reactive to an observed bug: the current curated fx/fy don't
## overlap at common viewport aspect ratios (checked), but "don't
## overlap at the resolutions I tried" isn't the same guarantee as
## "can't overlap", and the same relaxation _add_trees() needs anyway
## is right here to reuse instead of assuming.
func _resolve_house_positions(defs: Array, sizes: Array, gx: Callable, gy: Callable) -> Array:
	var positions: Array = []
	for d in defs:
		positions.append(Vector2(gx.call(d["fx"]), gy.call(d["fy"])))

	for _iter in range(8):
		var moved: bool = false
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				var ra := Rect2(positions[i].x - sizes[i].x / 2.0, positions[i].y - sizes[i].y, sizes[i].x, sizes[i].y)
				var rb := Rect2(positions[j].x - sizes[j].x / 2.0, positions[j].y - sizes[j].y, sizes[j].x, sizes[j].y)
				if ra.intersects(rb):
					var dx: float = positions[j].x - positions[i].x
					var dir_x: float = 1.0 if dx >= 0.0 else -1.0
					var overlap_x: float = (sizes[i].x + sizes[j].x) / 2.0 - abs(dx)
					var push: float = max(1.0, overlap_x / 2.0 + 1.0)
					positions[i] = positions[i] - Vector2(dir_x * push, 0.0)
					positions[j] = positions[j] + Vector2(dir_x * push, 0.0)
					moved = true
		if not moved:
			break
	return positions

## Same HouseSprite class the 5 houses use, real windmill reference art
## (assets/windmill/) as its texture pair instead — see class header for
## why it's positioned differently than the old procedural windmill was.
## Not part of _add_houses()'s own `defs`/loop (keeps "5 houses" an exact
## count and this a distinct, findable block) but returns its rect the
## same way, so it slots into the same tree-avoidance array a house's
## rect would. resilience/seed follow the houses' own per-index formula,
## continued at index 5 (the houses use 0-4) rather than a bespoke
## constant, so it's drawn from the same deterministic scheme, not a
## special case. size_tier 2 (large): the tallest single structure in the
## village, its collapse should read at least as substantial as the
## blue/purple houses'.
##
## Static, like the reference art itself — its own painted sails included
## as-is, not a separately rotating element. Two things were tried and
## both reported back as looking wrong once actually seen in the game
## (see git history: extracted-art blades turned to mush at this
## renderer's nearest-neighbour scale; procedural blades on top of the
## unmodified tower doubled up with the art's own painted sails
## underneath, and read as disproportionate even after retuning) — rather
## than a third attempt, the windmill stays exactly what the provided
## reference art shows, the same footing every house's sprite is already
## on.
func _add_windmill(gx: Callable, gy: Callable, u: float) -> Rect2:
	var h_mill: float = u * 0.30
	var w_mill: float = h_mill * (float(WINDMILL_TEXTURE.get_width()) / float(WINDMILL_TEXTURE.get_height()))
	var pos := Vector2(gx.call(0.76), gy.call(0.54))

	var mill := HouseSprite.new()
	mill.position = pos
	mill.setup(
		h_mill, WINDMILL_TEXTURE, WINDMILL_TEXTURE_DAMAGED,
		Palette.c("stone"), Palette.c("stoneDark"),
		Palette.c("roofBlue"), Palette.c("roofBlueShadow"),
		0.75 + _seeded(5 * 9.1) * 0.6, 5 * 4.1 + 3.0, _wind, entities, 2,
	)
	entities.add_child(mill)

	return Rect2(pos.x - w_mill / 2.0, pos.y - h_mill, w_mill, h_mill)

## house_rects: exact destination rects from _add_houses(), already
## resolved against each other — trees are kept clear of these AND of
## each other (see class header). TREE_CANOPY_R_MUL is generous on
## purpose: a round tree's canopy is drawn as several overlapping
## clusters reaching out from branch tips (see tree_sprite.gd's own
## _draw_foliage_cluster), and the outermost branch+cluster combination
## can reach roughly a full `width` from the trunk centre, not the
## `width/2` a naive "radius" reading of the parameter would suggest —
## sized from that worst case, not the average, since the one thing that
## must never happen is a canopy still visibly clipping into a house.
## TREE_HOUSE_MARGIN doubled (was 4.0) for some slack against wind-driven
## sway on top of that resting shape (tree_sprite.gd's LEVEL_BEND_MUL/
## LEVEL_FLUTTER_MUL, reported as still grazing a house under strong
## wind) — not the full worst-case sway reach (measured directly from
## tree_sprite.gd's own bend/flutter/cluster formulas at max wind: 2-3x
## a tree's width, which this village's current house spacing has no
## room for at all, several aspect ratios tested) but a real, if partial,
## improvement over the original's zero.
const TREE_CANOPY_R_MUL := 1.0
const TREE_HOUSE_MARGIN := 8.0
const TREE_MAX_PUSH_MUL := 6.0

## fy moved deeper than the original 0.06-0.15 band for the 4 trees that
## needed it (tree4's own 0.42 was always fine) — that original band
## sits right where several houses' own footprints are, so clearing them
## meant squeezing into whatever gap happened to be left, which wasn't
## always wide enough to hold a full canopy once the margin above is
## accounted for. Re-picked by checking, for each tree's own fx, how
## deep it has to sit before _clear_of_rects needs only a small nudge
## instead of a large one, across the same wide battery of resolutions
## used elsewhere in this file — not eyeballed. Reads as a village with
## a row of trees standing a little further forward than the houses
## rather than tucked directly beside them; flagged here since it's a
## real, visible layout change, not just a bugfix.
func _add_trees(gx: Callable, gy: Callable, u: float, house_rects: Array) -> void:
	var defs := [
		{"fx": 0.145, "fy": 0.32, "type": "round", "width": u * 0.11, "height": u * 0.30, "flex": 1.1},
		{"fx": 0.30, "fy": 0.32, "type": "round", "width": u * 0.09, "height": u * 0.24, "flex": 1.2},
		{"fx": 0.70, "fy": 0.45, "type": "round", "width": u * 0.105, "height": u * 0.28, "flex": 1.0},
		{"fx": 0.865, "fy": 0.40, "type": "round", "width": u * 0.095, "height": u * 0.25, "flex": 1.15},
		{"fx": 0.015, "fy": 0.42, "type": "round", "width": u * 0.135, "height": u * 0.35, "flex": 0.9},
	]
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var placed: Array = []
	for i in range(defs.size()):
		var d = defs[i]
		var canopy_r: float = float(d["width"]) * TREE_CANOPY_R_MUL
		var pos: Vector2 = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		pos = _clear_of_rects(pos, canopy_r, house_rects, screen_x0, screen_x1)
		pos = _clear_of_circles(pos, canopy_r, placed)

		var tree := TreeSprite.new()
		tree.position = pos
		tree.setup(d["type"], d["width"], d["height"], d["flex"], i * 3.7 + 1.0, _wind, entities)
		entities.add_child(tree)
		placed.append({"pos": pos, "r": canopy_r})

## Nudges `pos` horizontally clear of every rect in `rects`, each grown
## by `radius` (canopy reach) plus TREE_HOUSE_MARGIN — horizontal-only,
## never vertical (see class header for why: a tree's fy is its curated
## depth and must survive this intact). Resolves every blocking rect AT
## the tree's own fixed y AT ONCE rather than one at a time: their grown
## horizontal spans are merged into a union of intervals first, and the
## tree escapes past the outer edge of whichever merged interval
## currently contains it — a naive "escape whichever single rect is
## nearest" approach can bounce forever between two rects whose grown
## zones overlap each other at this y (confirmed happening in this exact
## layout), since escaping one lands back inside the other.
##
## TREE_MAX_PUSH_MUL bounds how far a single tree will travel chasing a
## fully clear spot (measured from its own curated position, not
## iteration to iteration) — see class header for why this layout can't
## always offer one — and the result is clamped back onto the screen
## afterwards (canopy allowed a little overhang past the edge, same as
## this file already accepts for the leftmost tree today) rather than
## left to land off it entirely.
func _clear_of_rects(pos: Vector2, radius: float, rects: Array, screen_x0: float, screen_x1: float) -> Vector2:
	var p: Vector2 = pos
	var max_push: float = radius * TREE_MAX_PUSH_MUL
	for _iter in range(8):
		var intervals: Array = []
		for rect in rects:
			var r: Rect2 = rect
			var gy0: float = r.position.y - radius - TREE_HOUSE_MARGIN
			var gy1: float = r.position.y + r.size.y + radius + TREE_HOUSE_MARGIN
			if gy0 <= p.y and p.y <= gy1:
				var gx0: float = r.position.x - radius - TREE_HOUSE_MARGIN
				var gx1: float = r.position.x + r.size.x + radius + TREE_HOUSE_MARGIN
				intervals.append(Vector2(gx0, gx1))
		if intervals.is_empty():
			break
		intervals.sort_custom(func(a, b): return a.x < b.x)
		var merged: Array = [intervals[0]]
		for i in range(1, intervals.size()):
			var iv: Vector2 = intervals[i]
			var last: Vector2 = merged[merged.size() - 1]
			if iv.x <= last.y:
				merged[merged.size() - 1] = Vector2(last.x, max(last.y, iv.y))
			else:
				merged.append(iv)
		var found_blocking: bool = false
		var blocking: Vector2 = Vector2.ZERO
		for iv in merged:
			if iv.x <= p.x and p.x <= iv.y:
				blocking = iv
				found_blocking = true
				break
		if not found_blocking:
			break
		var target_x: float = blocking.x - 0.5 if (p.x - blocking.x <= blocking.y - p.x) else blocking.y + 0.5
		if abs(target_x - pos.x) > max_push:
			target_x = pos.x + max_push * (1.0 if target_x > pos.x else -1.0)
		if is_equal_approx(target_x, p.x):
			break
		p = Vector2(target_x, p.y)
	p.x = clamp(p.x, screen_x0 - radius * 0.7, screen_x1 + radius * 0.7)
	return p

## Same idea as _clear_of_rects but against already-placed trees, each
## treated as a circle (canopy radius + margin) rather than a rect —
## also horizontal-only, for the same reason. y is fixed, so the
## horizontal offset needed to clear a circle at a given fixed vertical
## separation is a plain right triangle: dx = sqrt(min_dist^2 - dy^2).
func _clear_of_circles(pos: Vector2, radius: float, placed: Array) -> Vector2:
	var p: Vector2 = pos
	for _iter in range(8):
		var moved: bool = false
		for other in placed:
			var opos: Vector2 = other["pos"]
			var min_dist: float = radius + float(other["r"]) + TREE_HOUSE_MARGIN
			var dy: float = p.y - opos.y
			if abs(dy) >= min_dist:
				continue
			var dist: float = Vector2(p.x - opos.x, dy).length()
			if dist < min_dist:
				var sign: float = 1.0 if p.x >= opos.x else -1.0
				var need_dx2: float = min_dist * min_dist - dy * dy
				p.x = opos.x + sign * (sqrt(need_dx2) if need_dx2 > 0.0 else min_dist)
				moved = true
		if not moved:
			break
	return p

func _add_decor(gx: Callable, gy: Callable, ground_h: float, u: float) -> void:
	var well := WellSprite.new()
	well.position = Vector2(gx.call(0.565), gy.call(0.30))
	well.setup(max(4.0, u * 0.032))
	entities.add_child(well)

	var fence := FenceSprite.new()
	fence.position = Vector2(gx.call(0.02), gy.call(0.52))
	fence.setup(u * 0.24, _wind)
	entities.add_child(fence)

	var lamp := LampPostSprite.new()
	lamp.position = Vector2(gx.call(0.44), gy.call(0.42))
	lamp.setup(ground_h * 0.34)
	entities.add_child(lamp)

	var bush_defs := [{"fx": 0.40, "fy": 0.35}, {"fx": 0.665, "fy": 0.37}]
	for b in bush_defs:
		var bush := BushSprite.new()
		bush.position = Vector2(gx.call(b["fx"]), gy.call(b["fy"]))
		bush.setup(ground_h * 0.038, _wind)
		entities.add_child(bush)

	var flower_defs := [{"fx": 0.22, "fy": 0.44}, {"fx": 0.79, "fy": 0.42}]
	for i in range(flower_defs.size()):
		var f = flower_defs[i]
		var flower := FlowerPatchSprite.new()
		flower.position = Vector2(gx.call(f["fx"]), gy.call(f["fy"]))
		flower.setup(i * 7.0)
		entities.add_child(flower)

## Same formula as PixelDrawer.seeded() — duplicated rather than shared
## because WorldScene extends Node2D, not PixelDrawer (it does no
## drawing of its own), and this is the one place outside a sprite that
## needs it (per-house resilience).
func _seeded(n: float) -> float:
	var x: float = sin(n * 12.9898) * 43758.5453
	return x - floor(x)
