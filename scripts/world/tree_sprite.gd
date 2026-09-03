class_name TreeSprite
extends PixelDrawer
## Tree with wind sway plus a fall state machine — direct translation of
## drawTreeStructure()/drawTreeStanding()/drawTreeFallen()/updateTree()
## from render.js, EXCEPT: the original's `regrowing` state (a fallen
## tree standing back up after a calm-wind cooldown) is deliberately not
## ported — explicit product decision: fallen trees stay down for good.
##
## Falling/fallen no longer need the original's manual
## ctx.translate/rotate/translate-back dance around the tree's own base
## — that's just this node's own `rotation`, which Godot already applies
## around its local origin (== the tree's ground-contact point, since
## `position` is set to (x, groundY) externally). _draw() only ever
## draws the unrotated structure; the engine rotates the result.
##
## Pine foliage bend fix (deviates from the original's own drawTreeStructure
## formula, not just a straight port): the original's bendAtY() clamps to a
## flat tipBend the moment a tier's row falls at or below the trunk's own
## tip, but the trunk itself keeps following its pow(t,1.6) curve well
## below that point too — nearly straight for most of its height, only
## really hooking over near the very top. The bottom pine tier overlaps
## down onto that upper-trunk region, so the clamp made it shear by the
## FULL tip bend while the trunk right behind it was barely bent —
## foliage visibly detached from the trunk.
##
## _bend_at_y() now mirrors the trunk's own curve for any row still within
## the trunk's height (so foliage overlapping the trunk always matches
## what the trunk is doing right there), then carries that exact same tip
## bend straight up through the rest of the canopy, unchanged. The
## original amplifies the higher/wider tiers further (a tier gets wider
## as you go up, so the same absolute nudge reads as less lean against its
## own wider silhouette) — but at this renderer's low logical resolution
## that still isn't enough: the wide tiers read as barely leaning at all
## next to the trunk's own sharp hook. Shifting the whole canopy by the
## same amount the trunk tip itself moved is what actually reads as one
## connected mass swaying together, rather than a few extra amplified
## pixels on an already-wide shape.

var tree_type: String
var width: float
var height: float
var flex: float
var seed_val: float
var wind: WindEngine
var entities_parent: Node2D

# "standing" | "falling" | "fallen" — see header re: no "regrowing".
var _state: String = "standing"
var _strain: float = 0.0
var _fall_progress: float = 0.0
var _fall_angle: float = 0.0
var _fall_dir: float = 1.0

func setup(p_type: String, p_width: float, p_height: float, p_flex: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	tree_type = p_type
	width = p_width
	height = p_height
	flex = p_flex
	seed_val = p_seed
	wind = p_wind
	entities_parent = p_entities_parent
	queue_redraw()

func _process(delta: float) -> void:
	_update_fall_state(delta)
	rotation = _fall_angle
	queue_redraw()

func _update_fall_state(delta: float) -> void:
	if _state == "standing":
		var wind_level: int = GameState.compute_stage("wind")
		if wind_level >= 3 and wind.force > 0.82:
			var flex_div: float = flex if flex != 0.0 else 1.0
			_strain += delta * (wind.force - 0.8) * 0.5 / flex_div
		else:
			_strain -= delta * 0.15
		_strain = clamp(_strain, 0.0, 1.3)
		if _strain >= 1.0 and wind.elapsed - wind.last_tree_fall_at > 7.0:
			_state = "falling"
			_fall_progress = 0.0
			_fall_dir = wind.direction
			wind.last_tree_fall_at = wind.elapsed
	elif _state == "falling":
		_fall_progress = min(1.0, _fall_progress + delta / 1.1)
		var eased: float = 1.0 - pow(1.0 - _fall_progress, 2.0)
		_fall_angle = eased * (1.35 + seeded(seed_val) * 0.3) * _fall_dir
		if _fall_progress >= 1.0:
			_state = "fallen"
			_strain = 0.0
			DebrisSpawner.burst(
				entities_parent,
				position.x + sin(_fall_angle) * height * 0.5, position.y,
				7, [Palette.c("leafMid"), Palette.c("leafDark"), Palette.c("trunkDark")],
				width * 0.6, _fall_dir,
			)
	# "fallen": permanent — nothing to update, no regrow.

func _draw() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var origin_x: float = 0.0
	var eff_force: float
	var eff_dir: float
	var eff_t: float
	match _state:
		"falling":
			eff_force = 0.3
			eff_dir = _fall_dir
			eff_t = t
		"fallen":
			eff_force = 0.0
			eff_dir = 1.0
			eff_t = 0.0
		_:
			eff_force = wind.force
			eff_dir = wind.direction
			eff_t = t
			var strain_t: float = clamp((_strain - 0.55) / 0.45, 0.0, 1.0) if _strain > 0.0 else 0.0
			if strain_t > 0.0:
				origin_x = (seeded(t * 47.0 + seed_val * 3.0) - 0.5) * strain_t * 3.0
	_draw_structure(origin_x, eff_force, eff_dir, eff_t)

func _draw_structure(origin_x: float, force: float, direction: float, t: float) -> void:
	var bend_max: float = height * (0.22 if tree_type == "pine" else 0.30) * flex
	var bend: float = direction * force * bend_max
	var trunk_h: float = height * (0.32 if tree_type == "pine" else 0.42)
	var base_w: float = max(2.0, width * 0.16)
	var tip_w: float = max(1.0, base_w * 0.4)

	px_ellipse(origin_x, 0, width * 0.32, width * 0.09, Color(30.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.25))
	var tip: Vector2 = px_tapered_bend(origin_x, 0, trunk_h, base_w, tip_w, bend, Palette.c("trunk"), Palette.c("trunkDark"))

	var branch_defs: Array
	if tree_type == "pine":
		branch_defs = [
			{"hf": 0.35, "ang": -0.55, "len": 0.6},
			{"hf": 0.6, "ang": 0.5, "len": 0.55},
			{"hf": 0.85, "ang": -0.4, "len": 0.4},
		]
	else:
		branch_defs = [
			{"hf": 0.15, "ang": -0.7, "len": 0.85},
			{"hf": 0.55, "ang": 0.55, "len": 0.8},
			{"hf": 0.85, "ang": 0.15, "len": 0.55},
		]

	var trunk_dark: Color = Palette.c("trunkDark")
	var line_width: float = max(1.0, base_w * 0.32)
	var tips: Array[Vector2] = []
	for i in range(branch_defs.size()):
		var b = branch_defs[i]
		var base_y: float = -trunk_h * b["hf"]
		var base_bend: float = bend * pow(b["hf"], 1.6)
		var base_x: float = origin_x + base_bend
		var flutter: float = 0.5 + 0.5 * sin(t * (3.2 + i * 0.7) + seed_val * 6.0 + i)
		var secondary: float = flutter * force * direction * flex * 0.35
		var angle: float = b["ang"] + secondary + bend * 0.01
		var len_: float = width * b["len"]
		var tx: float = base_x + sin(angle) * len_
		var ty: float = base_y - cos(angle) * len_
		draw_line(Vector2(base_x, base_y), Vector2(tx, ty), trunk_dark, line_width)
		tips.append(Vector2(tx, ty))

	if tree_type == "pine":
		var pine_light: Color = Palette.c("pineLight")
		var pine_dark: Color = Palette.c("pineDark")
		var trunk_tip_y: float = -trunk_h
		for i in range(3):
			var tier_h: float = height * 0.34
			var tier_top: float = -trunk_h - height * 0.62 + i * (height * 0.26)
			var hw: float = (width / 2.0) * (1.0 - i * 0.24)
			var bend_at_bottom: float = _bend_at_y(tier_top + tier_h, trunk_h, bend, trunk_tip_y)
			var bend_at_top: float = _bend_at_y(tier_top, trunk_h, bend, trunk_tip_y)
			px_triangle_up_sheared(origin_x, tier_top, tier_h, hw, bend_at_bottom, bend_at_top, pine_light, pine_dark)
		for tp in tips:
			px_circle(tp.x, tp.y, width * 0.12, pine_light, pine_dark)
	else:
		var leaf_light: Color = Palette.c("leafLight")
		var leaf_mid: Color = Palette.c("leafMid")
		px_circle(tip.x, tip.y - width * 0.18, width * 0.42, leaf_light, leaf_mid)
		for i in range(tips.size()):
			var tp: Vector2 = tips[i]
			var puff_flutter: float = 0.5 + 0.5 * sin(t * 6.0 + seed_val * 9.0 + i)
			var j: float = puff_flutter * force * direction * 1.2
			px_circle(tp.x + j, tp.y + j * 0.4, width * 0.27, leaf_light, leaf_mid)

func _bend_at_y(y: float, trunk_h: float, bend: float, trunk_tip_y: float) -> float:
	if y >= trunk_tip_y:
		var t: float = clamp(-y / trunk_h, 0.0, 1.0)
		return bend * pow(t, 1.6)
	return bend
