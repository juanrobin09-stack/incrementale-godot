class_name LevelCard
extends Button
## One clickable card for a single level in LevelSelectMenu: a small
## procedural sky/ground scene (its shape picked by `kind`) when the level
## is unlocked, or a hand-drawn padlock over a darkened/blank card when
## it isn't. There is no padlock art asset and no image-generation tool in
## this project, so the locked look is painted with plain CanvasItem
## primitives in _draw() — the same constraint chaos_tree/tree_node_button.gd
## once solved the same way, before that overlay got real reference-art
## crops to replace its own drawn padlock.

signal activated(level_id: int)

const CARD_SIZE := Vector2(140, 110)
const CARD_MARGIN := 6.0
const LABEL_AREA_H := 20.0
const NAME_FONT_SIZE := 14

const PADLOCK_BODY_W := 22.0
const PADLOCK_BODY_H := 18.0
const PADLOCK_SHACKLE_RADIUS := 11.0
const PADLOCK_SHACKLE_WIDTH := 3.0

var _level_id: int = 0
var _level_name: String = ""
var _implemented: bool = false
var _unlocked: bool = false
var _kind: String = ""

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	text = ""
	pressed.connect(_on_pressed)

## Called fresh by LevelSelectMenu every time it rebuilds its card row —
## `unlocked` is never cached, always whatever GameState says right now.
func setup(level_id: int, level_name: String, implemented: bool, unlocked: bool, kind: String) -> void:
	_level_id = level_id
	_level_name = level_name
	_implemented = implemented
	_unlocked = unlocked
	_kind = kind
	# Real Button.disabled too, for correct focus/hover/click-eating
	# behaviour — but the actual locked *look* always comes from _draw()
	# below regardless of this flag, since disabled alone only dims via
	# modulate and draws neither a padlock nor a hidden scene.
	disabled = not (implemented and unlocked)
	queue_redraw()

func _on_pressed() -> void:
	if _implemented and _unlocked:
		activated.emit(_level_id)

# ---------------------------------------------------------------------------
# Drawing — layered on top of Button's own default background (an empty
# one here, since this class never sets `text`), same idiom as
# TreeNodeButton._draw() adding a bevel on top of the normal Button paint.
# ---------------------------------------------------------------------------
func _draw() -> void:
	if not _implemented:
		# Nothing built for this level yet — no scene to hint at, just the
		# lock and its name so the player at least knows what's coming.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.14, 0.9), true)
		_draw_padlock()
		_draw_name_label(Color(0.55, 0.55, 0.58))
		return

	_draw_icon()

	if not _unlocked:
		# Implemented but not yet earned: draw the real scene, then blot
		# it almost entirely out. 0.82 alpha is intentional — at most a
		# hint of the scene should survive underneath the padlock.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.82), true)
		_draw_padlock()
		return

	_draw_name_label()

func _icon_rect() -> Rect2:
	var w: float = max(0.0, size.x - CARD_MARGIN * 2.0)
	var h: float = max(0.0, size.y - CARD_MARGIN * 2.0 - LABEL_AREA_H)
	return Rect2(CARD_MARGIN, CARD_MARGIN, w, h)

func _draw_name_label(text_color: Color = Color.WHITE) -> void:
	var y: float = size.y - CARD_MARGIN - 4.0
	draw_string(ThemeDB.fallback_font, Vector2(0.0, y), _level_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, NAME_FONT_SIZE, text_color)

func _draw_icon() -> void:
	var r: Rect2 = _icon_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return

	var sky_h: float = r.size.y * 0.55
	draw_rect(Rect2(r.position, Vector2(r.size.x, sky_h)), Color(0.55, 0.75, 0.92), true)
	draw_rect(Rect2(r.position + Vector2(0.0, sky_h), Vector2(r.size.x, r.size.y - sky_h)), Color(0.42, 0.58, 0.28), true)

	match _kind:
		"village":
			_draw_village_scene(r)
		"town":
			_draw_town_scene(r)
		_:
			_draw_placeholder_scene(r)

func _draw_village_scene(r: Rect2) -> void:
	var ground_line: float = r.position.y + r.size.y * 0.86

	var house_w: float = r.size.x * 0.34
	var wall_h: float = r.size.y * 0.22
	var roof_h: float = r.size.y * 0.16
	var house_x: float = r.position.x + r.size.x * 0.14
	_draw_house(house_x, ground_line, house_w, wall_h, roof_h, Color(0.85, 0.78, 0.62), Color(0.55, 0.25, 0.2))

	var trunk_x: float = r.position.x + r.size.x * 0.74
	var trunk_w: float = r.size.x * 0.05
	var trunk_h: float = r.size.y * 0.16
	var canopy_r: float = r.size.x * 0.09
	_draw_tree(trunk_x, ground_line, trunk_w, trunk_h, canopy_r)

func _draw_town_scene(r: Rect2) -> void:
	var ground_line: float = r.position.y + r.size.y * 0.86

	# Paved street: a thin strip sitting in the gap between the two
	# houses below, spanning the full ground band front-to-back.
	var street_w: float = max(2.0, r.size.x * 0.06)
	var street_x: float = r.position.x + r.size.x * 0.5 - street_w * 0.5
	draw_rect(Rect2(street_x, r.position.y + r.size.y * 0.55, street_w, r.size.y * 0.45), Color(0.55, 0.55, 0.55), true)

	var house1_w: float = r.size.x * 0.26
	var wall1_h: float = r.size.y * 0.20
	var roof1_h: float = r.size.y * 0.14
	var house1_x: float = r.position.x + r.size.x * 0.08
	_draw_house(house1_x, ground_line, house1_w, wall1_h, roof1_h, Color(0.85, 0.78, 0.62), Color(0.55, 0.25, 0.2))

	var house2_w: float = r.size.x * 0.30
	var wall2_h: float = r.size.y * 0.24
	var roof2_h: float = r.size.y * 0.15
	var house2_x: float = r.position.x + r.size.x * 0.62
	_draw_house(house2_x, ground_line, house2_w, wall2_h, roof2_h, Color(0.80, 0.82, 0.85), Color(0.30, 0.42, 0.58))

func _draw_placeholder_scene(r: Rect2) -> void:
	var s: float = min(r.size.x, r.size.y) * 0.22
	var center: Vector2 = r.position + r.size * 0.5
	draw_rect(Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0.55, 0.55, 0.55), true)

## One house: a rectangular wall with a triangular roof (a 3-point
## polygon, slightly overhanging the wall for eaves) on top. base_x/
## base_y anchor the wall's bottom-left corner and ground line.
func _draw_house(base_x: float, base_y: float, w: float, wall_h: float, roof_h: float, wall_color: Color, roof_color: Color) -> void:
	draw_rect(Rect2(base_x, base_y - wall_h, w, wall_h), wall_color, true)
	var eave: float = w * 0.08
	var apex := Vector2(base_x + w * 0.5, base_y - wall_h - roof_h)
	var left := Vector2(base_x - eave, base_y - wall_h)
	var right := Vector2(base_x + w + eave, base_y - wall_h)
	draw_colored_polygon(PackedVector2Array([left, right, apex]), roof_color)

func _draw_tree(trunk_x: float, base_y: float, trunk_w: float, trunk_h: float, canopy_r: float) -> void:
	draw_rect(Rect2(trunk_x - trunk_w * 0.5, base_y - trunk_h, trunk_w, trunk_h), Color(0.40, 0.28, 0.16), true)
	draw_circle(Vector2(trunk_x, base_y - trunk_h - canopy_r * 0.6), canopy_r, Color(0.30, 0.55, 0.25))

## Hand-drawn padlock, always centered on the card's full `size` (not
## just the icon area) so it reads the same way whether the card behind
## it is a full scene or a flat "not implemented" rect. Shackle is a
## downward-opening half-circle arc; body is a dark rounded-look rect;
## keyhole is a small circle with a short slot beneath it.
func _draw_padlock() -> void:
	var center: Vector2 = size / 2.0
	var total_h: float = PADLOCK_SHACKLE_RADIUS + PADLOCK_BODY_H
	var top: float = center.y - total_h * 0.5
	var body_top: float = top + PADLOCK_SHACKLE_RADIUS
	var body_rect := Rect2(center.x - PADLOCK_BODY_W * 0.5, body_top, PADLOCK_BODY_W, PADLOCK_BODY_H)

	draw_arc(Vector2(center.x, body_top), PADLOCK_SHACKLE_RADIUS, PI, TAU, 16, Color(0.75, 0.75, 0.78), PADLOCK_SHACKLE_WIDTH)
	draw_rect(body_rect, Color(0.35, 0.32, 0.3), true)

	var keyhole_center := Vector2(center.x, body_top + PADLOCK_BODY_H * 0.4)
	draw_circle(keyhole_center, 2.6, Color(0.1, 0.1, 0.1))
	var slot_w := 2.2
	var slot_top: float = keyhole_center.y + 1.0
	var slot_bottom: float = body_rect.position.y + body_rect.size.y - 3.0
	draw_rect(Rect2(keyhole_center.x - slot_w * 0.5, slot_top, slot_w, max(2.0, slot_bottom - slot_top)), Color(0.1, 0.1, 0.1), true)
