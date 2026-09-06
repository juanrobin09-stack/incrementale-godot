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
## houses; (fx=0.76, fy=0.54, h=u*0.30) was the first fix, picked as the
## largest static footprint clear of all 5 houses and the screen edges
## across a wide battery of resolutions (390x844 up to 3440x1440, plus
## square and tall-phone ratios).
##
## Reported directly as still much too small. Re-running that same
## static search with a bigger target size (rather than eyeballing one
## bigger guess) found its ceiling barely above the shipped 0.30 once
## checked against houses' real, already-resolved positions
## (_resolve_house_positions can and does move them off their curated
## fx/fy) — any single fx/fy/height fixed enough to clear every tested
## aspect ratio at once was only ever marginally bigger. That's the same
## shape of problem trees already had (see class header above), and the
## same fix applies: stop hunting for one static spot that happens to
## work everywhere, and instead give the windmill a real, meaningfully
## bigger target size at a curated "home" position, then push it
## horizontally clear of whatever houses it would otherwise overlap —
## _clear_windmill_of_houses, the same interval-merge idea as trees'
## _clear_of_rects, but not a straight reuse of that function: it tests
## the mover's anchor point against a rect's span grown by its own
## radius in both directions, which only reads correctly for a mover
## whose reach above its own base is roughly the same order as its
## radius (true for a tree canopy, false for the windmill — several
## times taller than it is wide) — this does a real mover-height-vs-
## house-rect vertical overlap test instead, so it doesn't flag houses
## the windmill's actual silhouette could never reach.
##
## (fx=0.82, fy=0.64, h=u*0.40) is the new curated home position — h up
## from u*0.30, fy pushed deeper to match (keeps the windmill's top edge
## roughly where it already was instead of climbing into the houses' own
## row as it grows). Verified clear, with zero push needed, across every
## ordinary landscape aspect ratio in that same battery. Same disclosed
## limitation as trees: a handful of narrow portrait ratios in that
## battery have no fully clear spot for a structure this size at all
## (checked directly) — WINDMILL_MAX_PUSH_MUL and the final on-screen
## clamp keep the result bounded there instead of broken, the same trade
## this file already makes for trees rather than a new one.
##
## Reported directly: a tree standing in the middle of the road. Every
## rect this file ever taught _clear_of_rects/_add_trees about was a
## house or the windmill — the road itself was never one of them, despite
## being drawn (BackgroundLayer._draw_road()) as a fixed obstacle-shaped
## strip right through the ground band a tree's curated fx/fy can land
## in just as easily as a house's footprint. Fixed the same way every
## other obstacle here is handled — as one more Rect2 in the array
## _add_trees() already resolves against, not a special case: `road_rect`
## spans the full ground band at (road_x ± road_w/2), built once in
## build() from the same road_x/road_w passed to BackgroundLayer.setup(),
## and joins house_rects/windmill_rect in the list _add_trees() receives.
## No change needed inside _clear_of_rects itself — it was already generic
## over "any rect", the road was just never in the list it saw.
##
## The well (_add_well) is the newest structure built this same way, real
## reference art (assets/well/) provided directly as an intact/damaged
## pair — see that function's own header for the full reasoning (why it
## reuses HouseSprite's complete crack/collapse behaviour rather than
## just its texture, tier/colour choices, and how its home position was
## found). Its rect joins house_rects/windmill_rect/road_rect in the same
## list _add_trees() resolves against, for the same reason the road
## itself just had to be added above: any real footprint a tree could
## otherwise spawn inside belongs in that one list.
##
## Flagged as still not quite right after that, at a couple of dense
## aspect ratios specifically: a tree grazing the windmill. Root cause
## wasn't the well/road addition itself but something both exposed —
## _add_trees() ran _clear_of_rects() then _clear_of_circles() exactly
## once each per tree, and the second has no notion of the fixed rects
## at all, so it could push a tree straight back into one rects had just
## cleared it from. Confirmed (small Python port of both functions,
## same battery of resolutions) to be a genuine back-and-forth between
## one specific pair of points, not slow convergence — more alternating
## passes alone never settle it, only rects running last, unconditionally,
## does. See _add_trees()'s own loop for the fix and why "close to
## another tree's canopy" is the right thing to end up on instead of
## "inside a building" when both can't be satisfied at once. That same
## check also surfaced a couple of narrow-portrait ratios where a tree
## already can't reach any fully clear spot at all within
## TREE_MAX_PUSH_MUL's own budget (see this header's own tree section
## above) — pre-existing and unrelated to this fix; letting rects win
## just stops circles from silently overriding that into a position
## that only looked clear by chance, at those same already-imperfect
## ratios, rather than actually being any more clear than before.
##
## LEVEL 2 — everything above this paragraph is level 1 (the village) and
## is UNCHANGED: build() now only dispatches on GameState.state.
## viewed_level (which WorldScene layout is actually on screen — see
## game_state.gd's own header on why that's a separate thing from
## state.level, the level the player has actually progressed to), calling
## either _build_level_1() (the exact body build() always was) or
## _build_level_2() (new — see that function's own header for the town's
## design). The two levels share every reusable placement/avoidance
## helper on this page (_clear_of_rects/_clear_of_circles/
## _resolve_house_positions (now _resolve_positions_mutually underneath)/
## _clear_windmill_of_houses) — only layout *data* differs per level, not
## the geometry that resolves it.
##
## A level 1 structure (5 houses + windmill + well, TOTAL_LEVEL_1_
## STRUCTURES) reaching HouseSprite's permanent "ruined" state now means
## something beyond that one sprite: _wire_structure_ruin() forwards it to
## GameState.notify_structure_ruined(), which flips state.level (and
## unlocks it, and points viewed_level at it) to 2 the moment every one of
## them has been ruined at some point (not necessarily in the same session
## — see that function's own header) — "le village est entièrement détruit"
## made concrete as a real, checkable condition rather than left implicit
## in the wind-stress numbers already driving individual collapses. Level
## 2's own structures (windmill + well only now — see TOTAL_LEVEL_2_
## STRUCTURES' own header) call the exact same function for forward-
## compatibility with a level 3 that doesn't exist yet, not because
## anything currently listens for level 2 being fully ruined too.

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

## Dispatches on GameState.state.viewed_level — which WorldScene layout is
## actually on screen, not necessarily the level the player has progressed
## to (see game_state.gd's own header on the two) — rather than being
## level 1's build logic directly. See this class's own header (level 2
## section) for why the split is a parallel _build_level_2() rather than
## parametrising this one function over both: level 1's entire body below
## is untouched, byte for byte, from before levels existed, so nothing
## about the village can regress from adding a second destination.
func build(logical_w: float, logical_h: float) -> void:
	for child in get_children():
		child.queue_free()

	if GameState.state.viewed_level >= 2:
		_build_level_2(logical_w, logical_h)
	else:
		_build_level_1(logical_w, logical_h)

func _build_level_1(logical_w: float, logical_h: float) -> void:
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

	var road_rect := Rect2(road_x - road_w / 2.0, ground_top, road_w, ground_h)
	var house_rects: Array = _add_houses(gx, gy, u)
	var windmill_rect: Rect2 = _add_windmill(gx, gy, u, house_rects)
	var well_rect: Rect2 = _add_well(gx, gy, u, house_rects)
	_add_trees(gx, gy, u, house_rects + [windmill_rect, road_rect, well_rect])
	_add_decor(gx, gy, ground_h, u)

	var weather := WeatherLayer.new()
	add_child(weather)
	weather.setup(logical_w, logical_h, _wind)

## Level 2: a small MEDIEVAL TOWN, not a bigger copy of the village — same
## art direction (same PixelDrawer primitives, same Palette, same real-
## texture HouseSprite treatment for windmill/well, same fractional gx/gy
## layout approach), deliberately denser and more urban: a real street
## hierarchy (one main artery, two secondary cross streets, two short
## tertiary spurs, and a small central plaza — see _add_town_streets())
## instead of one road, 8 reserved building LOTS rather than the village's
## 5 houses (see _compute_town_lots() — no building is actually built on
## them, see that function's own header), and its own two disasters
## (quake/blight — TownHazardLayer, see that class's own header). Trees/
## bushes/flowers are deliberately fewer and pushed to the periphery/plaza
## edges rather than removed outright — explicit ask: "une ville, pas
## tout recouvrir de pierre", the same reasoning that keeps grass as this
## file's own base ground layer under the streets rather than paving the
## whole band.
##
## Reuses every general-purpose helper level 1 already made reusable
## (_clear_of_rects/_clear_of_circles for trees, _resolve_house_positions/
## _clear_windmill_of_houses for structures) rather than duplicating that
## geometry — only the *layout data* (defs arrays, street rects) is new,
## same split already established between "reusable algorithm" and
## "level-specific data" everywhere else in this file.
##
## The 8 building lots used to be built as real HouseSprite instances,
## reusing the village's own 5 house textures as a temporary placeholder
## (explicitly asked for at the time). Explicitly asked to be REMOVED once
## that base was in place — real level-2 buildings will be provided and
## integrated separately later, and having 8 lookalike village houses
## sitting in the town in the meantime was never meant to be permanent.
## _compute_town_lots() keeps computing and returning the exact same
## resolved footprint rects (same positions, same anti-overlap/anti-street
## resolution) since trees/decor/the windmill/well still need real
## footprints to avoid — it just no longer instantiates anything into
## `entities` for them. A future real building system reads TOWN_LOT_DEFS/
## this function's return value as "where does building N go" without any
## of this placement work being redone.
func _build_level_2(logical_w: float, logical_h: float) -> void:
	var ground_top: float = logical_h * 0.34
	var ground_h: float = logical_h - ground_top
	var u: float = ground_h

	var gx := func(f: float) -> float: return f * logical_w
	var gy := func(f: float) -> float: return ground_top + f * ground_h

	var background := BackgroundLayer.new()
	add_child(background)
	# road_x/road_w still passed (the main street's own span) even though
	# setup_streets() below means _draw_road() is never actually reached
	# — see BackgroundLayer's own header — kept meaningful rather than
	# zeroed so nothing here relies on an unreachable branch's inputs
	# being garbage.
	var street_w: float = max(12.0, u * 0.16)
	background.setup(logical_w, logical_h, ground_top, ground_h, gx.call(0.5), street_w, _wind)

	var streets: Array = _add_town_streets(gx, gy, u, logical_w, ground_top, ground_h, street_w)
	background.setup_streets(streets)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	var lot_rects: Array = _compute_town_lots(gx, gy, u, streets)
	var windmill_rect: Rect2 = _add_town_windmill(gx, gy, u, lot_rects)
	var well_rect: Rect2 = _add_town_well(gx, gy, u, lot_rects)
	var obstacles: Array = lot_rects + streets + [windmill_rect, well_rect]
	_add_town_trees(gx, gy, u, obstacles)
	_add_town_decor(gx, gy, ground_h, u, streets)

	var hazards := TownHazardLayer.new()
	add_child(hazards)
	hazards.setup(logical_w, logical_h, ground_top, ground_h, entities)

	var weather := WeatherLayer.new()
	add_child(weather)
	weather.setup(logical_w, logical_h, _wind)

## A real hierarchy rather than "several roads that simply cross" (explicit
## ask): main artery (fx=0.5, the widest — same span the village's own
## single road used) through a small central plaza at the upper
## intersection, two secondary cross streets noticeably NARROWER than the
## artery (cross_h dropped from the first draft's u*0.13, too close to the
## artery's own u*0.16 to read as secondary, to u*0.10 — a real size step),
## and two short tertiary "petites rues" narrower again (u*0.06), branching
## off the artery toward the two side lot clusters (see TOWN_LOT_DEFS'
## fy=0.55 row) without literally reaching them — a visible hint that more
## streets continue toward the districts, not a fully routed network,
## which is more than "une première base" needs and would only add more
## surface for the exact kind of full-width collision trap documented on
## TOWN_LOT_DEFS below (kept deliberately short and centered on the
## artery, nowhere near either side cluster's own fx, specifically to stay
## clear of that trap rather than merely hoping to). Kept to a handful of
## straight rects rather than a tile-based road network: cheap to draw
## (BackgroundLayer.setup_streets(), same primitive fills as the village's
## single road, already orientation-agnostic — no new drawing code needed
## for the narrower/shorter entries here) and to reason about for
## placement (every one of these is a plain Rect2 the same obstacle-
## avoidance helpers already consume).
func _add_town_streets(gx: Callable, gy: Callable, u: float, logical_w: float, ground_top: float, ground_h: float, street_w: float) -> Array:
	var cross_h: float = max(8.0, u * 0.10)
	var main_street := Rect2(gx.call(0.5) - street_w / 2.0, ground_top, street_w, ground_h)
	var cross_top := Rect2(0.0, gy.call(0.24) - cross_h / 2.0, logical_w, cross_h)
	var cross_bottom := Rect2(0.0, gy.call(0.66) - cross_h / 2.0, logical_w, cross_h)
	var plaza_w: float = u * 0.36
	var plaza_h: float = u * 0.24
	var plaza := Rect2(gx.call(0.5) - plaza_w / 2.0, gy.call(0.24) - plaza_h / 2.0, plaza_w, plaza_h)

	var spur_h: float = max(6.0, u * 0.06)
	var spur_left := Rect2(gx.call(0.38), gy.call(0.55) - spur_h / 2.0, gx.call(0.5) - gx.call(0.38), spur_h)
	var spur_right := Rect2(gx.call(0.5), gy.call(0.55) - spur_h / 2.0, gx.call(0.62) - gx.call(0.5), spur_h)

	return [main_street, cross_top, cross_bottom, plaza, spur_left, spur_right]

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
const WELL_TEXTURE := preload("res://assets/well/well.png")
const WELL_TEXTURE_DAMAGED := preload("res://assets/well/well_damaged.png")

## 5 houses + windmill + well — every HouseSprite-backed structure level 1
## can ever have. Passed to notify_structure_ruined() alongside each
## structure's own id (see _wire_structure()) so GameState knows when
## every one of them has been ruined at least once and can advance
## state.level — see game_state.gd's own header on that function for why
## the count lives here (this file's own defs are the one source of truth
## for "how many structures a level has") rather than duplicated as a
## GameData constant.
const TOTAL_LEVEL_1_STRUCTURES := 7
## Windmill + well — the only two level-2 structures that are actually
## built (see _add_town_windmill()/_add_town_well()); the 8 building lots
## are placement-only now, nothing to ruin-track there (see
## _compute_town_lots()'s own header). Ruining both is already wired
## through the same notify_structure_ruined() call every level-1 structure
## uses, but is currently inert (see GameData.max_implemented_level()'s own
## header) until a level 3 exists.
const TOTAL_LEVEL_2_STRUCTURES := 2

## Shared by every level's structures (houses, windmill, well today;
## level 2's own building slots below) — two things a HouseSprite always
## needs from its owner once it exists as a persistent, save-tracked
## structure rather than a fresh one every rebuild: (1) whether GameState
## already recorded it ruined in an earlier session, checked BEFORE
## setup() so that can be passed straight into start_ruined instead of
## replaying a collapse that already happened; (2) a connection so the
## FIRST time it newly reaches ruined this session, GameState hears about
## it. `id` must be stable across rebuilds (a resize, a reload) — see each
## call site for how it's built (level + a fixed per-slot name, never an
## array index alone once ordering could ever change).
func _structure_start_ruined(id: String) -> bool:
	return GameState.is_structure_ruined(id)

func _wire_structure_ruin(sprite: HouseSprite, id: String, level: int, total: int) -> void:
	sprite.ruined.connect(func(): GameState.notify_structure_ruined(id, level, total))

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
		var id: String = "l1_house_%d" % i

		var house := HouseSprite.new()
		house.position = pos
		house.setup(
			size.y, HOUSE_TEXTURES[d["roof"]], HOUSE_TEXTURES_DAMAGED[d["roof"]],
			Palette.c(d["wall"]), Palette.c(d["wall"] + "Shadow"),
			Palette.c(d["roof"]), Palette.c(d["roof"] + "Shadow"),
			0.75 + _seeded(i * 9.1) * 0.6, i * 4.1 + 3.0, _wind, entities, d["tier"],
			_structure_start_ruined(id),
		)
		_wire_structure_ruin(house, id, 1, TOTAL_LEVEL_1_STRUCTURES)
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
	return _resolve_positions_mutually(positions, sizes)

## The actual mutual-overlap resolution, pulled out of
## _resolve_house_positions() so _compute_town_lots() can re-run it a 2nd
## time on positions that already moved once (after being pushed clear of
## the street grid) — the exact same "nudge any two overlapping rects
## apart horizontally" logic either way, just no longer tied to deriving
## its starting positions from defs/gx/gy specifically.
func _resolve_positions_mutually(positions: Array, sizes: Array) -> Array:
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
const WINDMILL_HOUSE_MARGIN := 6.0
const WINDMILL_MAX_PUSH_MUL := 3.0

func _add_windmill(gx: Callable, gy: Callable, u: float, house_rects: Array) -> Rect2:
	var h_mill: float = u * 0.40
	var w_mill: float = h_mill * (float(WINDMILL_TEXTURE.get_width()) / float(WINDMILL_TEXTURE.get_height()))
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var pos := Vector2(gx.call(0.82), gy.call(0.64))
	pos = _clear_windmill_of_houses(pos, w_mill / 2.0, h_mill, house_rects, screen_x0, screen_x1)

	var mill := HouseSprite.new()
	mill.position = pos
	mill.setup(
		h_mill, WINDMILL_TEXTURE, WINDMILL_TEXTURE_DAMAGED,
		Palette.c("stone"), Palette.c("stoneDark"),
		Palette.c("roofBlue"), Palette.c("roofBlueShadow"),
		0.75 + _seeded(5 * 9.1) * 0.6, 5 * 4.1 + 3.0, _wind, entities, 2,
		_structure_start_ruined("l1_windmill"),
	)
	_wire_structure_ruin(mill, "l1_windmill", 1, TOTAL_LEVEL_1_STRUCTURES)
	entities.add_child(mill)

	return Rect2(pos.x - w_mill / 2.0, pos.y - h_mill, w_mill, h_mill)

## Same interval-merge escape as _clear_of_rects (below, for trees) — merge
## every blocking house's grown horizontal span at once and escape past the
## outer edge of whichever merged span currently contains the windmill —
## but not a straight reuse of that function. _clear_of_rects tests the
## mover's own anchor point against each rect's vertical span grown by
## `radius` in *both* directions, which only reads correctly when the
## mover's reach above its own base is roughly the same order of magnitude
## as its radius — true for a tree canopy, false here: the windmill is
## several times taller than it is wide, so that test would either miss
## houses its actual silhouette does reach (radius far smaller than height)
## or flag houses it could never reach at all — tried first, and confirmed
## exactly that: houses more than a screen-width away still came back
## "blocking". This does the real check instead: the mover's own vertical
## extent, from `height` above `pos.y` down to `pos.y` itself, against
## each house rect's vertical extent, both grown by WINDMILL_HOUSE_MARGIN
## only (no radius folded in vertically). WINDMILL_MAX_PUSH_MUL and the
## final on-screen clamp mirror
## TREE_MAX_PUSH_MUL's own reasoning: this village is dense enough that a
## few narrow aspect ratios have no fully clear spot for a structure this
## size at all, so a bounded best-effort beats an unbounded chase.
func _clear_windmill_of_houses(pos: Vector2, half_w: float, height: float, house_rects: Array, screen_x0: float, screen_x1: float) -> Vector2:
	var p: Vector2 = pos
	var max_push: float = half_w * WINDMILL_MAX_PUSH_MUL
	for _iter in range(8):
		var intervals: Array = []
		for rect in house_rects:
			var r: Rect2 = rect
			var gy0: float = r.position.y - WINDMILL_HOUSE_MARGIN
			var gy1: float = r.position.y + r.size.y + WINDMILL_HOUSE_MARGIN
			if gy0 <= p.y and p.y - height <= gy1:
				var gx0: float = r.position.x - half_w - WINDMILL_HOUSE_MARGIN
				var gx1: float = r.position.x + r.size.x + half_w + WINDMILL_HOUSE_MARGIN
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
	p.x = clamp(p.x, screen_x0 - half_w * 0.7, screen_x1 + half_w * 0.7)
	return p

## Same HouseSprite reuse as the windmill (see its own header for why that
## class has nothing house-specific baked in) and, per direct request, the
## same full behaviour too — not just the real texture: this well can
## crack under wind stress and eventually collapse for good, exactly like
## a house, rather than staying an indestructible decoration. The two
## reference images (assets/well/) uploaded directly are an intact/
## damaged pair in exactly the same shape as a house's own two textures —
## confirmed before writing any code (visually compared: one has a lit
## lantern, flowers, an upright barrel and a clean stone ring; the other
## has none of that plus a visible crack through the stone), not assumed
## from the filenames, which were meaningless upload artifacts (renamed
## here to well.png/well_damaged.png).
##
## size_tier 0 (small): a well is smaller than even the smallest house, so
## it gets that tier's quicker, roof-only partial collapse rather than the
## bigger houses'/windmill's staggered multi-piece one. "wall"/"roof"
## colours reuse existing Palette entries rather than inventing well-
## specific ones — Palette.c("stone")/("stoneDark") already tint the
## windmill's own stone base, and Palette.c("roofRed")/("roofRedShadow")
## is what the old procedural well already used for its own roof, so both
## choices continue what this project already picked for this exact
## structure rather than picking arbitrarily.
##
## Height (u*0.20) and home position (fx=0.59, fy=0.46) are a fresh
## search, not the old procedural well's own tiny fx=0.565/fy=0.30 spot —
## checked directly (same static-search approach as the windmill/trees)
## that the OLD spot, at this real structure's actual size, overlaps a
## house at every resolution in this file's usual test battery; fx=0.59/
## fy=0.46 was the first found with zero overlap at every one of those
## resolutions AND clear of the lamp post/bushes' own fx by a margin,
## rather than the first spot that merely happens to survive the push.
## _clear_windmill_of_houses reused as-is for the push itself (already
## generic rect-vs-rect despite the name — see its own header) as a
## defence-in-depth measure now that the search found a home spot needing
## none, the same reasoning that already applies to every other structure
## in this file.
func _add_well(gx: Callable, gy: Callable, u: float, house_rects: Array) -> Rect2:
	var h_well: float = u * 0.20
	var w_well: float = h_well * (float(WELL_TEXTURE.get_width()) / float(WELL_TEXTURE.get_height()))
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var pos := Vector2(gx.call(0.59), gy.call(0.46))
	pos = _clear_windmill_of_houses(pos, w_well / 2.0, h_well, house_rects, screen_x0, screen_x1)

	var well := HouseSprite.new()
	well.position = pos
	well.setup(
		h_well, WELL_TEXTURE, WELL_TEXTURE_DAMAGED,
		Palette.c("stone"), Palette.c("stoneDark"),
		Palette.c("roofRed"), Palette.c("roofRedShadow"),
		0.75 + _seeded(6 * 9.1) * 0.6, 6 * 4.1 + 3.0, _wind, entities, 0,
		_structure_start_ruined("l1_well"),
	)
	_wire_structure_ruin(well, "l1_well", 1, TOTAL_LEVEL_1_STRUCTURES)
	entities.add_child(well)

	return Rect2(pos.x - w_well / 2.0, pos.y - h_well, w_well, h_well)

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
##
## The first pass at this (all 4 within a narrow 0.32-0.45 band) reads
## as fine individually but visibly bunched together as a group once
## resolved — reported directly. Spread further apart (0.24-0.50) for
## real depth variety instead: re-checked the same way, and this spread
## happens to leave every one of the 7 ordinary aspect ratios already
## tested fully clear with no push needed at all, not just bounded —
## tighter clustering was never required for collision safety, only an
## artefact of how the previous values were picked one at a time instead
## of considered together.
func _add_trees(gx: Callable, gy: Callable, u: float, house_rects: Array) -> void:
	var defs := [
		{"fx": 0.145, "fy": 0.30, "type": "round", "width": u * 0.11, "height": u * 0.30, "flex": 1.1},
		{"fx": 0.30, "fy": 0.24, "type": "round", "width": u * 0.09, "height": u * 0.24, "flex": 1.2},
		{"fx": 0.70, "fy": 0.38, "type": "round", "width": u * 0.105, "height": u * 0.28, "flex": 1.0},
		{"fx": 0.865, "fy": 0.50, "type": "round", "width": u * 0.095, "height": u * 0.25, "flex": 1.15},
		{"fx": 0.015, "fy": 0.44, "type": "round", "width": u * 0.135, "height": u * 0.35, "flex": 0.9},
	]
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var placed: Array = []
	for i in range(defs.size()):
		var d = defs[i]
		var canopy_r: float = float(d["width"]) * TREE_CANOPY_R_MUL
		var pos: Vector2 = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		# Alternated, and always finished on a rects pass, rather than run
		# once each: clearing the placed-tree circles has no notion of the
		# fixed rects and can push a tree straight back into one that
		# _clear_of_rects had just resolved it out of — confirmed directly
		# (reported: a tree still grazing the windmill at a couple of dense
		# aspect ratios), and confirmed to be a genuine back-and-forth, not
		# slow convergence: at the exact reported spot, rects sends the
		# tree to one point, circles sends it right back past the other,
		# forever, so more alternating passes alone never settle it — only
		# rects running LAST, unconditionally, does, and it's the right
		# tiebreaker: ending up a bit close to another tree's canopy (soft,
		# barely visible) beats ending up inside a building (hard, obvious).
		# Simulated this exact loop in Python across this file's usual
		# battery before writing it here, not just against the one reported
		# case — every tree that could reach a spot clear of every fixed
		# rect within TREE_MAX_PUSH_MUL now does, same as _clear_of_rects
		# was already documented to guarantee on its own. The only
		# still-imperfect cases the same check turned up are pre-existing
		# and unrelated to this fix: a couple of narrow-portrait ratios
		# already documented above (class header, TREE_MAX_PUSH_MUL) as
		# having no fully clear spot for a given tree AT ALL — there,
		# _clear_of_rects itself already settles short of fully clear
		# once its own push cap is hit, with or without this loop; letting
		# rects win here just stops that from being silently overridden
		# by circles into a position that happened to look clear of rects
		# purely by chance, at those exact same already-imperfect ratios,
		# rather than actually being any more clear.
		for _pass in range(3):
			pos = _clear_of_rects(pos, canopy_r, house_rects, screen_x0, screen_x1)
			var before_circles: Vector2 = pos
			pos = _clear_of_circles(pos, canopy_r, placed)
			if pos.is_equal_approx(before_circles):
				break
		pos = _clear_of_rects(pos, canopy_r, house_rects, screen_x0, screen_x1)

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

## 8 reserved building LOTS — fx/fy/scale only now (no roof/wall/tier: see
## _compute_town_lots()'s own header for why nothing is actually built on
## these anymore). TOWN_LOT_ASPECT (below) replaces each lot's old per-
## texture aspect ratio with one generic ratio for all 8 — a future real
## building can be whatever shape it needs; these numbers only exist so
## trees/streets/decor have a real footprint to avoid in the meantime, and
## picking one representative aspect for all of them is honest about that
## rather than implying a shape future buildings must match.
##
## Row 1 (fy=0.07) sits clear of cross_top/the plaza the same way
## _add_houses()'s own row already sits clear of the village's roofline —
## even its tallest member's grown rect never reaches down as far as
## cross_top's own band.
##
## Rows 2 and 3 (fy=0.55/0.97) are NOT the first draft (fy=0.46/0.80, near
## the original placeholder houses' own scale). That draft "looked" clear
## of cross_top/cross_bottom by the same "doesn't overlap in this file's
## own curated numbers" reasoning this comment used to lean on here — but a
## Python port of this exact placement (the same resolution battery used
## everywhere else in this file) caught it flatly overlapping BOTH cross
## streets, at every single resolution tested, not just a narrow few.
## cross_top/cross_bottom are full-width rects (see _add_town_streets()),
## so a lot whose grown rect reaches into one can never actually be pushed
## clear by _clear_windmill_of_houses()'s horizontal-only escape — there is
## no direction to push a mover out of a span that already covers the
## entire screen width. The push still ran every time and still reported
## success by its own bookkeeping, but had nowhere to send these lots
## except toward its own max-push cap — which for several of them meant
## landing most of the way off-screen (confirmed directly: one lot's rect
## at x0=-56 on a 300px-wide screen). That is a real, universal bug, not
## the kind of narrow-aspect-ratio imperfection TREE_MAX_PUSH_MUL/
## WINDMILL_MAX_PUSH_MUL already accept elsewhere in this file. This is
## exactly the trap the tertiary street spurs in _add_town_streets() are
## kept short and centered specifically to avoid reintroducing.
##
## Fixed by sizing to the actual gap instead of assuming one: row 2 sits at
## fy=0.55 (within the ~0.29*u-tall strip between cross_top and
## cross_bottom) with scale cut to ~0.55 so its worst-case height leaves
## real margin on both sides; row 3 sits at fy=0.97 (base near the bottom
## of the ground band, past cross_bottom) with scale cut to ~0.65 for the
## same reason — both re-verified clear of both cross streets across the
## same battery. A few thin-edge slivers remain at narrow portrait aspect
## ratios (a lot corner grazing the well/windmill by a handful of px) —
## that is the same bounded, narrow-viewport trade already accepted
## throughout this file, never the all-resolutions off-screen failure this
## replaces.
const TOWN_LOT_ASPECT := 0.85
const TOWN_LOT_DEFS := [
	{"fx": 0.18, "fy": 0.07, "scale": 0.85},
	{"fx": 0.32, "fy": 0.07, "scale": 0.80},
	{"fx": 0.68, "fy": 0.07, "scale": 0.82},
	{"fx": 0.82, "fy": 0.07, "scale": 0.88},
	{"fx": 0.14, "fy": 0.55, "scale": 0.58},
	{"fx": 0.86, "fy": 0.55, "scale": 0.52},
	{"fx": 0.28, "fy": 0.97, "scale": 0.65},
	{"fx": 0.72, "fy": 0.97, "scale": 0.62},
]

## Returns each lot's resolved footprint rect — same resolution order this
## used when it still built real HouseSprite instances (lots vs each other
## first via _resolve_house_positions, already generic; then each lot
## pushed clear of every street rect via _clear_windmill_of_houses, a
## rect-vs-rect base-anchored push, the right shape for "a lot must never
## straddle a street", already generic despite the name — see its own
## header; then lots vs each other ONCE MORE since the street push can
## reintroduce an overlap the first pass already resolved) but instantiates
## NOTHING into `entities` anymore — no HouseSprite, no id, no ruin-
## tracking. Real level-2 buildings are being provided and integrated
## separately later (explicit request); this file's job for now is only to
## keep these 8 spots clear, cohered with the streets around them, and
## ready for whatever gets placed there next — not to guess what that will
## look like.
func _compute_town_lots(gx: Callable, gy: Callable, u: float, streets: Array) -> Array:
	var defs := TOWN_LOT_DEFS
	var sizes: Array = []
	for d in defs:
		var h_lot: float = u * 0.30 * d["scale"]
		sizes.append(Vector2(h_lot * TOWN_LOT_ASPECT, h_lot))

	var positions: Array = _resolve_house_positions(defs, sizes, gx, gy)
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	for i in range(positions.size()):
		positions[i] = _clear_windmill_of_houses(positions[i], sizes[i].x / 2.0, sizes[i].y, streets, screen_x0, screen_x1)
	positions = _resolve_positions_mutually(positions, sizes)

	var lot_rects: Array = []
	for i in range(defs.size()):
		var size: Vector2 = sizes[i]
		var pos: Vector2 = positions[i]
		lot_rects.append(Rect2(pos.x - size.x / 2.0, pos.y - size.y, size.x, size.y))
	return lot_rects

## Same windmill reference art and same reuse rationale as level 1's own
## _add_windmill() (see that function's header) — a small town on this
## project's own established medieval-fantasy logic still plausibly has
## one, kept at the outskirts rather than duplicated per-district.
## Pushed clear of building lots only (not streets — its own footprint is
## picked to sit past the town's own street grid already, at the edge of
## the screen, the same "curated home position, pushed only as a safety
## net" approach every structure in this file uses).
func _add_town_windmill(gx: Callable, gy: Callable, u: float, lot_rects: Array) -> Rect2:
	var h_mill: float = u * 0.42
	var w_mill: float = h_mill * (float(WINDMILL_TEXTURE.get_width()) / float(WINDMILL_TEXTURE.get_height()))
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var pos := Vector2(gx.call(0.94), gy.call(0.90))
	pos = _clear_windmill_of_houses(pos, w_mill / 2.0, h_mill, lot_rects, screen_x0, screen_x1)

	var mill := HouseSprite.new()
	mill.position = pos
	mill.setup(
		h_mill, WINDMILL_TEXTURE, WINDMILL_TEXTURE_DAMAGED,
		Palette.c("stone"), Palette.c("stoneDark"),
		Palette.c("roofBlue"), Palette.c("roofBlueShadow"),
		0.75 + _seeded(8 * 9.1 + 500.0) * 0.6, 8 * 4.1 + 200.0, _wind, entities, 2,
		_structure_start_ruined("l2_windmill"),
	)
	_wire_structure_ruin(mill, "l2_windmill", 2, TOTAL_LEVEL_2_STRUCTURES)
	entities.add_child(mill)
	return Rect2(pos.x - w_mill / 2.0, pos.y - h_mill, w_mill, h_mill)

## The well moves to the plaza — the one placement choice here that isn't
## just "level 1's spot, pushed": a town's own well belongs at its public
## square on this project's own established medieval-fantasy logic, not
## tucked beside a building the way the village's single well was.
func _add_town_well(gx: Callable, gy: Callable, u: float, lot_rects: Array) -> Rect2:
	var h_well: float = u * 0.18
	var w_well: float = h_well * (float(WELL_TEXTURE.get_width()) / float(WELL_TEXTURE.get_height()))
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var pos := Vector2(gx.call(0.5), gy.call(0.24))
	pos = _clear_windmill_of_houses(pos, w_well / 2.0, h_well, lot_rects, screen_x0, screen_x1)

	var well := HouseSprite.new()
	well.position = pos
	well.setup(
		h_well, WELL_TEXTURE, WELL_TEXTURE_DAMAGED,
		Palette.c("stone"), Palette.c("stoneDark"),
		Palette.c("roofRed"), Palette.c("roofRedShadow"),
		0.75 + _seeded(9 * 9.1 + 500.0) * 0.6, 9 * 4.1 + 200.0, _wind, entities, 0,
		_structure_start_ruined("l2_well"),
	)
	_wire_structure_ruin(well, "l2_well", 2, TOTAL_LEVEL_2_STRUCTURES)
	entities.add_child(well)
	return Rect2(pos.x - w_well / 2.0, pos.y - h_well, w_well, h_well)

## Fewer, sparser trees than the village — explicit ask ("une ville, pas
## tout recouvrir de pierre") without contradicting "plus dense/urbanisée"
## elsewhere: 3 trees at the town's own periphery/plaza edge rather than
## the village's 5 spread through it. Same avoidance helpers as
## _add_trees(), unchanged — obstacles here already include streets
## (Rect2s, same as road_rect always was) alongside buildings/windmill/
## well, so a town tree can no more spawn in a street than a village one
## can in the road.
func _add_town_trees(gx: Callable, gy: Callable, u: float, obstacles: Array) -> void:
	var defs := [
		{"fx": 0.03, "fy": 0.30, "type": "round", "width": u * 0.10, "height": u * 0.27, "flex": 1.0},
		{"fx": 0.97, "fy": 0.30, "type": "round", "width": u * 0.10, "height": u * 0.27, "flex": 1.1},
		{"fx": 0.50, "fy": 0.24, "type": "round", "width": u * 0.075, "height": u * 0.20, "flex": 1.15},
	]
	var screen_x0: float = gx.call(0.0)
	var screen_x1: float = gx.call(1.0)
	var placed: Array = []
	for i in range(defs.size()):
		var d = defs[i]
		var canopy_r: float = float(d["width"]) * TREE_CANOPY_R_MUL
		var pos: Vector2 = Vector2(gx.call(d["fx"]), gy.call(d["fy"]))
		for _pass in range(3):
			pos = _clear_of_rects(pos, canopy_r, obstacles, screen_x0, screen_x1)
			var before_circles: Vector2 = pos
			pos = _clear_of_circles(pos, canopy_r, placed)
			if pos.is_equal_approx(before_circles):
				break
		pos = _clear_of_rects(pos, canopy_r, obstacles, screen_x0, screen_x1)

		var tree := TreeSprite.new()
		tree.position = pos
		tree.setup(d["type"], d["width"], d["height"], d["flex"], i * 3.7 + 300.0, _wind, entities)
		entities.add_child(tree)
		placed.append({"pos": pos, "r": canopy_r})

## Denser street furniture than the village's own decor pass — more lamp
## posts (one per street-facing corner near the plaza, matching "davantage
## de lanternes"), fences at the town's edge and flanking the two side lot
## clusters (echoing the village's own edge fence, same reasoning: a
## boundary marker — here doubling as the "clôtures séparant les
## quartiers" asked for around the reserved building lots), and a handful
## of TownPropSprite barrels/crates/benches/a sign around the plaza plus a
## cart and a woodpile staged near the bottom-row lots — materials waiting
## for whichever real buildings land there next, not decoration for its
## own sake. See TownPropSprite's own header for why these are procedural
## rather than real reference art.
func _add_town_decor(gx: Callable, gy: Callable, ground_h: float, u: float, streets: Array) -> void:
	var fence := FenceSprite.new()
	fence.position = Vector2(gx.call(0.02), gy.call(0.88))
	fence.setup(u * 0.22, _wind)
	entities.add_child(fence)

	var lot_fence_defs := [{"fx": 0.24, "fy": 0.55}, {"fx": 0.76, "fy": 0.55}]
	for lf in lot_fence_defs:
		var lot_fence := FenceSprite.new()
		lot_fence.position = Vector2(gx.call(lf["fx"]), gy.call(lf["fy"]))
		lot_fence.setup(u * 0.10, _wind)
		entities.add_child(lot_fence)

	var lamp_defs := [
		{"fx": 0.38, "fy": 0.24}, {"fx": 0.62, "fy": 0.24},
		{"fx": 0.40, "fy": 0.66}, {"fx": 0.60, "fy": 0.66},
	]
	for l in lamp_defs:
		var lamp := LampPostSprite.new()
		lamp.position = Vector2(gx.call(l["fx"]), gy.call(l["fy"]))
		lamp.setup(ground_h * 0.30)
		entities.add_child(lamp)

	var bush_defs := [{"fx": 0.06, "fy": 0.46}, {"fx": 0.94, "fy": 0.46}]
	for b in bush_defs:
		var bush := BushSprite.new()
		bush.position = Vector2(gx.call(b["fx"]), gy.call(b["fy"]))
		bush.setup(ground_h * 0.032, _wind)
		entities.add_child(bush)

	var flower_defs := [{"fx": 0.44, "fy": 0.30}, {"fx": 0.56, "fy": 0.18}]
	for i in range(flower_defs.size()):
		var f = flower_defs[i]
		var flower := FlowerPatchSprite.new()
		flower.position = Vector2(gx.call(f["fx"]), gy.call(f["fy"]))
		flower.setup(i * 7.0 + 300.0)
		entities.add_child(flower)

	var prop_defs := [
		{"kind": "barrel", "fx": 0.435, "fy": 0.28, "w": u * 0.045, "h": u * 0.07},
		{"kind": "crate", "fx": 0.565, "fy": 0.29, "w": u * 0.05, "h": u * 0.05},
		{"kind": "bench", "fx": 0.46, "fy": 0.20, "w": u * 0.09, "h": u * 0.03},
		{"kind": "sign", "fx": 0.30, "fy": 0.62, "w": u * 0.05, "h": u * 0.10},
		{"kind": "cart", "fx": 0.20, "fy": 0.90, "w": u * 0.09, "h": u * 0.06},
		{"kind": "woodpile", "fx": 0.80, "fy": 0.90, "w": u * 0.07, "h": u * 0.05},
	]
	for p in prop_defs:
		var prop := TownPropSprite.new()
		prop.position = Vector2(gx.call(p["fx"]), gy.call(p["fy"]))
		prop.setup(p["kind"], p["w"], p["h"])
		entities.add_child(prop)

## Same formula as PixelDrawer.seeded() — duplicated rather than shared
## because WorldScene extends Node2D, not PixelDrawer (it does no
## drawing of its own), and this is the one place outside a sprite that
## needs it (per-house resilience).
func _seeded(n: float) -> float:
	var x: float = sin(n * 12.9898) * 43758.5453
	return x - floor(x)
