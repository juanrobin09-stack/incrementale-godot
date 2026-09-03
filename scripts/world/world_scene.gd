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

	_add_houses(gx, gy, u)
	_add_trees(gx, gy, u)
	_add_decor(gx, gy, ground_h, u)

	var weather := WeatherLayer.new()
	add_child(weather)
	weather.setup(logical_w, logical_h, _wind)

func _process(delta: float) -> void:
	if _wind == null:
		return
	_wind.update(delta, GameState.compute_stage("wind"))

## Reference art (assets/houses/) provided directly, one per roof colour
## — see HouseSprite's own header for why the intact house is a real
## sprite here instead of the procedural drawing every other village
## element uses. "wall" stays in each def below only because it still
## feeds HouseSprite's rubble-pile colours after collapse; it no longer
## has any visual effect on the intact house itself, which is baked into
## the sprite.
const HOUSE_TEXTURES := {
	"roofRed": preload("res://assets/houses/house_red.png"),
	"roofGold": preload("res://assets/houses/house_gold.png"),
	"roofGreen": preload("res://assets/houses/house_green.png"),
	"roofBlue": preload("res://assets/houses/house_blue.png"),
}

func _add_houses(gx: Callable, gy: Callable, u: float) -> void:
	var defs := [
		{"fx": 0.05, "fy": 0.22, "scale": 1.00, "roof": "roofRed", "wall": "wallCream"},
		{"fx": 0.235, "fy": 0.16, "scale": 0.94, "roof": "roofGold", "wall": "wallSlate"},
		{"fx": 0.335, "fy": 0.30, "scale": 0.90, "roof": "roofGreen", "wall": "wallSlate"},
		{"fx": 0.605, "fy": 0.24, "scale": 1.06, "roof": "roofGold", "wall": "wallRose"},
		{"fx": 0.775, "fy": 0.17, "scale": 0.96, "roof": "roofBlue", "wall": "wallCream"},
	]
	for i in range(defs.size()):
		var d = defs[i]
		var house := HouseSprite.new()
		house.position = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		house.setup(
			u * 0.325 * d["scale"], HOUSE_TEXTURES[d["roof"]],
			Palette.c(d["wall"]), Palette.c(d["wall"] + "Shadow"),
			Palette.c(d["roof"]), Palette.c(d["roof"] + "Shadow"),
			0.75 + _seeded(i * 9.1) * 0.6, i * 4.1 + 3.0, _wind, entities,
		)
		entities.add_child(house)

func _add_trees(gx: Callable, gy: Callable, u: float) -> void:
	var defs := [
		{"fx": 0.145, "fy": 0.14, "type": "round", "width": u * 0.11, "height": u * 0.30, "flex": 1.1},
		{"fx": 0.30, "fy": 0.06, "type": "round", "width": u * 0.09, "height": u * 0.24, "flex": 1.2},
		{"fx": 0.70, "fy": 0.15, "type": "round", "width": u * 0.105, "height": u * 0.28, "flex": 1.0},
		{"fx": 0.865, "fy": 0.08, "type": "round", "width": u * 0.095, "height": u * 0.25, "flex": 1.15},
		{"fx": 0.015, "fy": 0.42, "type": "round", "width": u * 0.135, "height": u * 0.35, "flex": 0.9},
	]
	for i in range(defs.size()):
		var d = defs[i]
		var tree := TreeSprite.new()
		tree.position = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		tree.setup(d["type"], d["width"], d["height"], d["flex"], i * 3.7 + 1.0, _wind, entities)
		entities.add_child(tree)

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
