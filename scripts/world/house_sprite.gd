class_name HouseSprite
extends PixelDrawer
## Intact house is a real sprite (assets/houses/house_*.png, reference art
## provided directly) instead of the procedural pxRect/pxTriangle drawing
## every other village element uses — the reference art's rounded shingle
## tiles, half-timbering and lived-in detail aren't realistically
## reproducible with this renderer's flat-shaded pixel primitives, and
## exact visual fidelity to the references was the explicit ask here.
##
## Roof damage tears real chunks out of the sprite instead of just playing
## debris on top of an untouched texture: `texture.get_image()` is copied
## once into `_display_image`/`_display_texture` (an ImageTexture Godot
## lets us mutate at runtime), and each roof_chunks[i] rectangle — hand-
## placed per reference image so it only ever covers roof pixels — is
## erased (Image.fill_rect to transparent) the moment stress crosses its
## tear threshold, at the same time a debris burst flies off from roughly
## that spot. Tearing is one-way: once a chunk is gone it stays gone even
## if stress later eases off, same as a real missing roof section
## wouldn't grow back — only the crack overlay (still just drawn on top,
## same as before) softens back down with stress. Walls stay a drawn
## overlay rather than punched sprite holes: cracking reads fine as lines
## over the intact wall texture, and unlike the roof there's no obvious
## "chunk" shape to cut free.
##
## The previous roofless_t stage (an intermediate "roof gone, attic
## exposed" look between cracks and rubble) is still dropped — the torn
## roof chunks are what carries that beat now — and rubble itself is
## still the old procedural pile; reference art for actual ruin debris is
## a later pass.
##
## resilience / no-respawn / no-recovery-from-collapse behaviour is
## unchanged from before — see tree_sprite.gd's own header for the
## "no respawn" product decision this follows.

## Stress level at which roof_chunks[i] tears free — index-matched, so
## roof_chunks and this must stay the same length.
const TEAR_THRESHOLDS := [0.50, 0.65, 0.80, 0.93]

var h: float
var texture: Texture2D
var roof_chunks: Array
var wall_color: Color
var wall_shadow_color: Color
var roof_color: Color
var roof_shadow_color: Color
var resilience: float
var wind: WindEngine
var entities_parent: Node2D

var _w: float
var _house_seed: float
var _stress: float = 0.0
var _last_stress: float = 0.0
var _collapsed: bool = false
var _torn_count: int = 0
var _display_image: Image
var _display_texture: ImageTexture

func setup(p_h: float, p_texture: Texture2D, p_roof_chunks: Array, p_wall: Color, p_wall_shadow: Color, p_roof: Color, p_roof_shadow: Color,
		p_resilience: float, p_seed: float, p_wind: WindEngine, p_entities_parent: Node2D) -> void:
	h = p_h
	texture = p_texture
	roof_chunks = p_roof_chunks
	wall_color = p_wall
	wall_shadow_color = p_wall_shadow
	roof_color = p_roof
	roof_shadow_color = p_roof_shadow
	resilience = p_resilience
	_house_seed = p_seed
	wind = p_wind
	entities_parent = p_entities_parent
	var tex_h: float = float(texture.get_height())
	var tex_w: float = float(texture.get_width())
	_w = h * (tex_w / tex_h if tex_h > 0.0 else 1.0)
	_display_image = texture.get_image()
	_display_texture = ImageTexture.create_from_image(_display_image)
	queue_redraw()

func _process(delta: float) -> void:
	_update_stress(delta)
	queue_redraw()

func _update_stress(delta: float) -> void:
	if _collapsed:
		return
	var wind_level: int = GameState.compute_stage("wind")
	var extreme: bool = wind_level >= 3 and wind.force > 0.6
	if extreme:
		_stress += delta * 0.055 * (wind.force - 0.5) * resilience
	else:
		_stress -= delta * 0.03
	_stress = clamp(_stress, 0.0, 1.0)

	var dir: float = wind.direction if wind.direction != 0.0 else 1.0
	var wall_h: float = h * 0.42

	_tear_roof_chunks(dir)

	if _last_stress < 0.65 and _stress >= 0.65:
		DebrisSpawner.burst(entities_parent, position.x + _w * 0.25, position.y - wall_h,
			5, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], _w * 0.5, dir)
	if _last_stress < 0.90 and _stress >= 0.90:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4,
			10, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], _w * 0.9, 1.0)
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.4, 0, [], 0.0, -1.0)
	var jitter: float = (seeded(_house_seed + 12) - 0.5) * 0.02
	if _last_stress < 0.93 + jitter and _stress >= 0.93 + jitter:
		DebrisSpawner.burst(entities_parent, position.x + (seeded(_house_seed + 20) - 0.5) * _w * 0.6, position.y - wall_h * 0.65,
			3, [wall_color, wall_shadow_color, Palette.c("rubbleWood")], _w * 0.25, dir)
	if _last_stress < 0.985 + jitter and _stress >= 0.985 + jitter:
		DebrisSpawner.burst(entities_parent, position.x, position.y - wall_h * 0.35,
			9, [wall_color, wall_shadow_color, Palette.c("rubbleWood"), Palette.c("rubbleWoodDark")], _w * 0.8, dir)
		DebrisSpawner.dust(entities_parent, position.x, position.y + 2.0, 3.0, _w * 0.6, 1.1)
	if _stress >= 1.0:
		_collapsed = true
	_last_stress = _stress

func _tear_roof_chunks(dir: float) -> void:
	var changed: bool = false
	while _torn_count < roof_chunks.size() and _torn_count < TEAR_THRESHOLDS.size() and _stress >= TEAR_THRESHOLDS[_torn_count]:
		var rect: Rect2i = roof_chunks[_torn_count]
		_display_image.fill_rect(rect, Color(0.0, 0.0, 0.0, 0.0))
		changed = true
		var wpos: Vector2 = _chunk_world_pos(rect)
		DebrisSpawner.burst(entities_parent, wpos.x, wpos.y,
			4, [roof_color, roof_shadow_color, Palette.c("rubbleWood")], _w * 0.18, dir)
		_torn_count += 1
	if changed:
		_display_texture.update(_display_image)

## Texture-pixel-space chunk center -> world position, through the same
## mapping _draw() uses to place the sprite (top-left at
## (-_w/2, -h), full h/_w size) — keeps torn debris starting from
## roughly where the hole actually appears regardless of house scale.
func _chunk_world_pos(rect: Rect2i) -> Vector2:
	var cx: float = rect.position.x + rect.size.x / 2.0
	var cy: float = rect.position.y + rect.size.y / 2.0
	var tex_w: float = float(texture.get_width())
	var tex_h: float = float(texture.get_height())
	var local_x: float = -_w / 2.0 + (cx / tex_w) * _w
	var local_y: float = -h + (cy / tex_h) * h
	return position + Vector2(local_x, local_y)

func _draw() -> void:
	var crack_t: float = clamp((_stress - 0.40) / 0.25, 0.0, 1.0)
	var cut_point: float = 0.985 + (seeded(_house_seed + 12) - 0.5) * 0.02
	if _stress >= cut_point:
		_draw_rubble()
		return
	draw_texture_rect(_display_texture, Rect2(-_w / 2.0, -h, _w, h), false)
	if crack_t > 0.01:
		_draw_cracks(crack_t)

func _draw_cracks(crack_t: float) -> void:
	var crack_color := Color(35.0 / 255.0, 25.0 / 255.0, 20.0 / 255.0, 0.7 * crack_t)
	_draw_crack_line(-_w * 0.05, -h * 0.55, _house_seed, h * 0.35, _w * 0.12, crack_color)
	if crack_t > 0.5:
		_draw_crack_line(_w * 0.15, -h * 0.45, _house_seed + 4.0, h * 0.30, _w * 0.10, crack_color)
	if crack_t > 0.8:
		_draw_crack_line(-_w * 0.28, -h * 0.35, _house_seed + 8.0, h * 0.22, _w * 0.08, crack_color)

func _draw_crack_line(x: float, y: float, seed: float, length: float, wobble: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(x, y))
	var steps: int = 4
	for i in range(1, steps + 1):
		var yy: float = y + (length * i) / steps
		var xx: float = x + (seeded(seed + i) - 0.5) * wobble
		points.append(Vector2(xx, yy))
	draw_polyline(points, color, 1.0)

func _draw_rubble() -> void:
	var wall_h: float = h * 0.42
	px_rect(-_w / 2.0, -3, _w, 3, Palette.c("rubbleWoodDark"))
	var chunks := [
		{"dx": -0.32, "dw": 0.22, "dh": 0.5, "c": wall_shadow_color},
		{"dx": -0.05, "dw": 0.26, "dh": 0.7, "c": wall_color},
		{"dx": 0.28, "dw": 0.2, "dh": 0.42, "c": roof_shadow_color},
		{"dx": 0.1, "dw": 0.16, "dh": 0.3, "c": roof_color},
		{"dx": -0.2, "dw": 0.14, "dh": 0.24, "c": Palette.c("rubbleWood")},
	]
	for c in chunks:
		var cw: float = _w * c["dw"]
		var ch: float = h * c["dh"] * 0.4
		px_rect(_w * c["dx"] - cw / 2.0, -ch, cw, ch, c["c"])
	var rubble_dark: Color = Palette.c("rubbleWoodDark")
	px_rect(-_w * 0.12, -wall_h * 0.55, 2, wall_h * 0.55, rubble_dark)
	px_rect(_w * 0.05, -wall_h * 0.4, 2, wall_h * 0.4, rubble_dark)
