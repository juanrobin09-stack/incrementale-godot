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
## its position (_clear_of_rects/_clear_of_circles/_push_out_of_rect)
## away from any house rect or already-placed tree it would otherwise
## overlap, resolved BEFORE the tree is ever instantiated. Houses
## themselves get the same treatment against each other first
## (_resolve_house_positions) — current curated fx/fy don't overlap at
## common resolutions, but the check is real, not assumed, since aspect
## ratio varies by viewport. All of this is plain reusable geometry, not
## tied to the current static defs arrays, so it applies the same way to
## any future dynamic spawn — there just isn't one yet.

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
	_add_trees(gx, gy, u, house_rects)
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
const TREE_CANOPY_R_MUL := 1.0
const TREE_HOUSE_MARGIN := 4.0

func _add_trees(gx: Callable, gy: Callable, u: float, house_rects: Array) -> void:
	var defs := [
		{"fx": 0.145, "fy": 0.14, "type": "round", "width": u * 0.11, "height": u * 0.30, "flex": 1.1},
		{"fx": 0.30, "fy": 0.06, "type": "round", "width": u * 0.09, "height": u * 0.24, "flex": 1.2},
		{"fx": 0.70, "fy": 0.15, "type": "round", "width": u * 0.105, "height": u * 0.28, "flex": 1.0},
		{"fx": 0.865, "fy": 0.08, "type": "round", "width": u * 0.095, "height": u * 0.25, "flex": 1.15},
		{"fx": 0.015, "fy": 0.42, "type": "round", "width": u * 0.135, "height": u * 0.35, "flex": 0.9},
	]
	var placed: Array = []
	for i in range(defs.size()):
		var d = defs[i]
		var canopy_r: float = float(d["width"]) * TREE_CANOPY_R_MUL
		var pos: Vector2 = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		pos = _clear_of_rects(pos, canopy_r, house_rects)
		pos = _clear_of_circles(pos, canopy_r, placed)

		var tree := TreeSprite.new()
		tree.position = pos
		tree.setup(d["type"], d["width"], d["height"], d["flex"], i * 3.7 + 1.0, _wind, entities)
		entities.add_child(tree)
		placed.append({"pos": pos, "r": canopy_r})

## Standard minimum-translation-vector push: moves `p` out of `grown`
## along whichever of its 4 edges is closest, instead of always toward
## the rect's centre — cheaper displacement, and it can't overshoot into
## a neighbour on the far side of a wide house.
func _push_out_of_rect(p: Vector2, grown: Rect2) -> Vector2:
	var left: float = p.x - grown.position.x
	var right: float = grown.position.x + grown.size.x - p.x
	var top: float = p.y - grown.position.y
	var bottom: float = grown.position.y + grown.size.y - p.y
	var min_d: float = min(min(left, right), min(top, bottom))
	if min_d == left:
		return Vector2(grown.position.x - 0.5, p.y)
	elif min_d == right:
		return Vector2(grown.position.x + grown.size.x + 0.5, p.y)
	elif min_d == top:
		return Vector2(p.x, grown.position.y - 0.5)
	return Vector2(p.x, grown.position.y + grown.size.y + 0.5)

## Nudges `pos` clear of every rect in `rects`, each grown by `radius`
## (the tree's own canopy reach) plus a fixed margin — bounded iteration
## since resolving one overlap can reveal another, cheap at this scale
## (a handful of houses, once at build()).
func _clear_of_rects(pos: Vector2, radius: float, rects: Array) -> Vector2:
	var p: Vector2 = pos
	for _iter in range(8):
		var moved: bool = false
		for rect in rects:
			var grown: Rect2 = (rect as Rect2).grow(radius + TREE_HOUSE_MARGIN)
			if grown.has_point(p):
				p = _push_out_of_rect(p, grown)
				moved = true
		if not moved:
			break
	return p

## Same idea as _clear_of_rects but against already-placed trees, each
## treated as a circle (canopy radius + margin) rather than a rect.
func _clear_of_circles(pos: Vector2, radius: float, placed: Array) -> Vector2:
	var p: Vector2 = pos
	for _iter in range(8):
		var moved: bool = false
		for other in placed:
			var min_dist: float = radius + float(other["r"]) + TREE_HOUSE_MARGIN
			var diff: Vector2 = p - (other["pos"] as Vector2)
			var dist: float = diff.length()
			if dist < min_dist:
				var dir: Vector2 = diff / dist if dist > 0.01 else Vector2(1.0, 0.0)
				p = (other["pos"] as Vector2) + dir * min_dist
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

	var windmill := WindmillSprite.new()
	windmill.position = Vector2(gx.call(0.90), gy.call(0.36))
	windmill.setup(ground_h * 0.32, _wind, entities)
	entities.add_child(windmill)

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
