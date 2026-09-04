class_name ChaosTreeOverlay
extends Control
## Full-screen Chaos Tree overlay: radial node layout (mirrors
## getNodeCanvasPosition() from script.js — same TREE_RADIUS_STEP/
## TREE_CANVAS_SIZE constants), connector lines, pan (drag) + zoom
## (wheel, clamped 0.35–1.8, same as the original), and an inspector
## panel for the selected node.
##
## Visual pass added once a reference screenshot was actually provided
## (chaos-tree-reference.png, repo root) — dark carved-stone panels/
## nodes, a gold title, a violet glow on the always-owned core node, a
## rounded currency pill, small diamond joints on the connector lines.
## No new image-generation tool exists in this environment any more
## than it did for the world layer's own decor pass (see world_scene.gd/
## background_layer.gd's own headers), so this is the same kind of
## approximation: StyleBoxFlat panels standing in for painted stone
## texture, emoji glyphs standing in for custom node icons — the actual
## per-node icons already assigned in GameData.UPGRADE_TREE happen to
## line up with the reference's own iconography closely enough (droplet/
## cloud on the rain arm, spark/lightning on storm, rock/brick on flood,
## leaf/gust/tornado on wind) that keeping them was better than
## replacing a working, readable glyph with a shape this engine has no
## way to paint. The layout itself needed no change at all: BRANCH_ANGLES
## (0/-90/90/180 for wind/rain/storm/flood) already put the tree on
## exactly the cross the reference shows, entirely by coincidence of
## values chosen for the original web version — confirmed by reading
## the reference's per-arm icons against UPGRADE_TREE's before touching
## anything, not assumed.
##
## One deliberate, disclosed deviation: the reference's 3rd header
## button reads as a padlock, but this overlay has no lock-view feature
## to attach that icon to (and no source to confirm what it actually
## does in the original) — repurposing a padlock glyph for the existing
## "recentrer" action would misrepresent what pressing it does, so that
## button keeps a recenter-shaped glyph instead. Everything else in the
## header (title, currency pill, close) matches.
##
## That first pass reported back, screenshot attached, as reading like
## nothing had changed at all — every colour/label/layout change from it
## WAS live (visible in the screenshot itself: the gold title, the
## "N KO disponibles" pill, the violet-bordered core node, the diamond
## line joints), but flat StyleBoxFlat colour with a thin uniform border
## next to the reference's carved-stone bevel and real padlock icon
## reads as "unchanged placeholder" rather than "different art budget".
## Two fixes from that: every button here is now a TreeNodeButton (see
## that class) instead of a plain Button, adding a drawn highlight/
## shadow bevel and, on locked nodes, a drawn padlock shape instead of
## the 🔒 emoji; and this overlay's backdrop is now fully opaque (was
## 0.985) — the previous near-opaque value let a sliver of the bright
## world scene behind bleed through at full-screen scale, which likely
## read as part of the "doesn't look different" impression too.
##
## Explicitly asked for next: not an approximation "inspired by" the
## reference, but the reference's own pixels used directly, the same way
## the houses use their provided PNGs rather than a procedural drawing —
## confirmed first (small crop tests) that this environment's image tools
## (PIL, already used earlier this project for the windmill texture) can
## actually cut clean pieces out of chaos-tree-reference.png, then asked
## which of two paths to take: crop reusable pieces out of the single
## reference screenshot already provided, or wait for separately exported
## per-element files the way the houses eventually got one PNG each.
## Answered: crop it now, ask instead of guessing if that turns out not
## to be possible. It was possible. assets/chaos_tree/ holds what came out
## of chaos-tree-reference.png: node_locked.png/node_frame.png/
## node_core.png (one representative node tile per state — every locked
## node in the reference already shows the same generic padlock baked in,
## so that tile is directly reusable everywhere locked; node_frame.png is
## one representative unlocked tile reused for every non-core, non-locked
## node regardless of its own baked-in icon, since the reference has no
## spare unlocked node whose art is actually meant to be generic), plus
## background.png (a clean stone-wall swatch, tiled), title_icon.png (the
## header's spiral mark) and corner_sparkle.png (one accent reused at all
## 4 corners, the reference only shows this decoration once per corner
## anyway). These are StyleBoxTexture fills now, not StyleBoxFlat colour —
## see _tile_style(). Per-node emoji glyphs are still drawn on top of
## node_frame.png for everything except core/locked (those two states'
## textures already have their one-and-only icon baked in, so their emoji
## is cleared instead of doubling up) — the emoji were never the
## complaint, only the flat frame around them was, and this engine still
## has no way to paint 20-odd distinct custom icons from nothing. Header
## buttons and the inspector's buy button keep the drawn-bevel
## TreeNodeButton treatment from the previous pass rather than reusing
## node_frame.png too — that tile's own baked-in pebble icon fighting
## with a −/+/⌖/✕ glyph in the same small square read worse in a quick
## check than the plain bevel already did, and nothing about those
## buttons was reported as a problem.

const TREE_RADIUS_STEP := 150.0
const TREE_CANVAS_SIZE := 2000.0
const TREE_CENTER := 1000.0

# ---------------------------------------------------------------------------
# Real crops from chaos-tree-reference.png (see class header) — not
# procedural. TEX_MARGIN is this project's own judgement call, not measured
# from the source: roughly the bevel width visible in the crops, kept as a
# fixed corner/edge so StyleBoxTexture 9-patches instead of stretching the
# whole tile (and its baked-in icon) out of shape at button sizes other
# than the ~64-93px the crops themselves are.
# ---------------------------------------------------------------------------
const NODE_LOCKED_TEX := preload("res://assets/chaos_tree/node_locked.png")
const NODE_FRAME_TEX := preload("res://assets/chaos_tree/node_frame.png")
const NODE_CORE_TEX := preload("res://assets/chaos_tree/node_core.png")
const BACKGROUND_TEX := preload("res://assets/chaos_tree/background.png")
const TITLE_ICON_TEX := preload("res://assets/chaos_tree/title_icon.png")
const CORNER_SPARKLE_TEX := preload("res://assets/chaos_tree/corner_sparkle.png")
const TEX_MARGIN := 10

# ---------------------------------------------------------------------------
# Stone/violet palette for this overlay only — the rest of the HUD is still
# on Godot's default theme (see README: a full HUD fidelity pass is its own
# later, separately-scoped task, not part of this one).
# ---------------------------------------------------------------------------
const COL_STONE := Color(0.145, 0.125, 0.107, 1.0)
const COL_STONE_LIGHT := Color(0.205, 0.178, 0.148, 1.0)
const COL_BORDER := Color(0.34, 0.30, 0.25, 1.0)
const COL_GOLD := Color(0.87, 0.71, 0.33, 1.0)
const COL_GOLD_DIM := Color(0.56, 0.46, 0.28, 1.0)
const COL_PURPLE := Color(0.58, 0.38, 0.93, 1.0)
const COL_TEXT := Color(0.88, 0.83, 0.73, 1.0)
const COL_TEXT_DIM := Color(0.56, 0.53, 0.47, 1.0)

var _tree_viewport: Control
var _tree_canvas: Control
var _lines_layer: TreeLinesLayer
var _node_buttons: Dictionary = {}

var _inspector_panel: PanelContainer
var _label_inspector_icon: Label
var _label_inspector_name: Label
var _label_inspector_desc: Label
var _label_inspector_state: Label
var _button_inspector_buy: Button
var _selected_id: String = ""

var _label_ko_badge: Label

var _view_x := 0.0
var _view_y := 0.0
var _view_scale := 0.72
var _pending_center := false

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_view := Vector2.ZERO

func _ready() -> void:
	visible = false
	UiUtil.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := TextureRect.new()
	dim.texture = BACKGROUND_TEX
	dim.stretch_mode = TextureRect.STRETCH_TILE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.fill_parent(dim)
	add_child(dim)

	var root_margin := MarginContainer.new()
	UiUtil.fill_parent(root_margin)
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	root_margin.add_child(root_vbox)

	_build_header(root_vbox)
	_build_viewport(root_vbox)
	_build_inspector(root_vbox)

	_build_nodes()
	_build_corner_sparkles()

## The reference's own corner decoration (corner_sparkle.png, one crop
## reused at all 4 corners — see class header), purely decorative,
## anchored directly to `self` rather than the margined content column so
## it sits at the true screen corners.
func _build_corner_sparkles() -> void:
	var box_size := 32.0
	var inset := 8.0
	# Each entry pins a box_size x box_size square to one corner via a zero-size anchor
	# point (anchor_left==anchor_right, anchor_top==anchor_bottom) plus all
	# four offsets set explicitly — same reasoning as UiUtil.fill_parent's
	# own header: a Control's unset offsets don't reliably default to
	# "zero size at this point", so left to imply the box from a single
	# offset each corner would size (and sign) itself differently, and
	# left/right corners silently ended up with negative width until this
	# was written out in full instead.
	var corners := [
		{"ax": 0.0, "ay": 0.0, "l": inset, "t": inset},
		{"ax": 1.0, "ay": 0.0, "l": -inset - box_size, "t": inset},
		{"ax": 0.0, "ay": 1.0, "l": inset, "t": -inset - box_size},
		{"ax": 1.0, "ay": 1.0, "l": -inset - box_size, "t": -inset - box_size},
	]
	for c in corners:
		var spark := TextureRect.new()
		spark.texture = CORNER_SPARKLE_TEX
		spark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.anchor_left = c["ax"]
		spark.anchor_right = c["ax"]
		spark.anchor_top = c["ay"]
		spark.anchor_bottom = c["ay"]
		spark.offset_left = c["l"]
		spark.offset_right = c["l"] + box_size
		spark.offset_top = c["t"]
		spark.offset_bottom = c["t"] + box_size
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)

## Flat StyleBoxFlat standing in for a carved-stone panel — see class
## header for why this is a colour/border approximation rather than an
## actual stone texture. `glow` adds a soft coloured shadow (the closest
## StyleBoxFlat gets to a glow) for the core node's always-owned state.
func _stone_style(bg: Color, border: Color, border_w: int, radius: int, glow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	if glow:
		sb.shadow_color = Color(border.r, border.g, border.b, 0.55)
		sb.shadow_size = 7
	return sb

## One real crop (see class header) used as a StyleBoxTexture fill, 9-patched
## by TEX_MARGIN so it doesn't stretch out of shape at a button size other
## than the crop's own. `modulate` tints the same tile for state feedback
## (gold for purchased, dimmed for unaffordable/locked) instead of needing a
## separately-painted tile per state this environment has no way to produce.
func _tile_style(tex: Texture2D, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = TEX_MARGIN
	sb.texture_margin_top = TEX_MARGIN
	sb.texture_margin_right = TEX_MARGIN
	sb.texture_margin_bottom = TEX_MARGIN
	sb.modulate_color = modulate
	return sb

func _apply_button_style(btn: Button, sb: StyleBox, font_color: Color, font_size: int) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)
	btn.add_theme_font_size_override("font_size", font_size)

func _build_header(parent: Node) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	parent.add_child(header)

	var title_box := HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	header.add_child(title_box)

	var title_icon := TextureRect.new()
	title_icon.texture = TITLE_ICON_TEX
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.custom_minimum_size = Vector2(28, 28)
	title_box.add_child(title_icon)

	var title := Label.new()
	title.text = "ARBRE DU CHAOS"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(title)

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", _stone_style(COL_STONE, COL_GOLD_DIM, 2, 10))
	header.add_child(badge_panel)

	var badge_margin := MarginContainer.new()
	badge_margin.add_theme_constant_override("margin_left", 12)
	badge_margin.add_theme_constant_override("margin_right", 12)
	badge_margin.add_theme_constant_override("margin_top", 4)
	badge_margin.add_theme_constant_override("margin_bottom", 4)
	badge_panel.add_child(badge_margin)

	_label_ko_badge = Label.new()
	_label_ko_badge.add_theme_color_override("font_color", COL_GOLD)
	badge_margin.add_child(_label_ko_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var zoom_out_btn := TreeNodeButton.new()
	zoom_out_btn.bevel = true
	zoom_out_btn.text = "−"
	zoom_out_btn.custom_minimum_size = Vector2(36, 36)
	zoom_out_btn.pressed.connect(func(): _zoom_by(1.0 / 1.25, _viewport_center()))
	_apply_button_style(zoom_out_btn, _stone_style(COL_STONE, COL_BORDER, 2, 6), COL_TEXT, 18)
	header.add_child(zoom_out_btn)

	var zoom_in_btn := TreeNodeButton.new()
	zoom_in_btn.bevel = true
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(36, 36)
	zoom_in_btn.pressed.connect(func(): _zoom_by(1.25, _viewport_center()))
	_apply_button_style(zoom_in_btn, _stone_style(COL_STONE, COL_BORDER, 2, 6), COL_TEXT, 18)
	header.add_child(zoom_in_btn)

	# Recentre — kept as its own working feature rather than mapped to
	# the reference's padlock icon; see class header.
	var recenter_btn := TreeNodeButton.new()
	recenter_btn.bevel = true
	recenter_btn.text = "⌖"
	recenter_btn.custom_minimum_size = Vector2(36, 36)
	recenter_btn.pressed.connect(_center_view)
	_apply_button_style(recenter_btn, _stone_style(COL_STONE, COL_BORDER, 2, 6), COL_TEXT, 18)
	header.add_child(recenter_btn)

	var close_btn := TreeNodeButton.new()
	close_btn.bevel = true
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(close)
	_apply_button_style(close_btn, _stone_style(COL_STONE, COL_BORDER, 2, 6), COL_TEXT, 18)
	header.add_child(close_btn)

func _build_viewport(parent: Node) -> void:
	_tree_viewport = Control.new()
	_tree_viewport.clip_contents = true
	_tree_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_tree_viewport.gui_input.connect(_on_viewport_gui_input)
	parent.add_child(_tree_viewport)

	_tree_canvas = Control.new()
	_tree_canvas.size = Vector2(TREE_CANVAS_SIZE, TREE_CANVAS_SIZE)
	_tree_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_viewport.add_child(_tree_canvas)

	_lines_layer = TreeLinesLayer.new()
	_lines_layer.size = Vector2(TREE_CANVAS_SIZE, TREE_CANVAS_SIZE)
	_lines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_canvas.add_child(_lines_layer)

func _build_inspector(parent: Node) -> void:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.add_theme_stylebox_override("panel", _stone_style(COL_STONE, COL_BORDER, 2, 8))
	parent.add_child(_inspector_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_inspector_panel.add_child(margin)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_label_inspector_icon = Label.new()
	_label_inspector_icon.add_theme_font_size_override("font_size", 32)
	box.add_child(_label_inspector_icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_box)

	_label_inspector_name = Label.new()
	_label_inspector_name.add_theme_color_override("font_color", COL_GOLD)
	text_box.add_child(_label_inspector_name)

	_label_inspector_desc = Label.new()
	_label_inspector_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label_inspector_desc.add_theme_color_override("font_color", COL_TEXT)
	text_box.add_child(_label_inspector_desc)

	_label_inspector_state = Label.new()
	_label_inspector_state.add_theme_color_override("font_color", COL_TEXT_DIM)
	text_box.add_child(_label_inspector_state)

	_button_inspector_buy = TreeNodeButton.new()
	_button_inspector_buy.bevel = true
	_button_inspector_buy.pressed.connect(_on_inspector_buy_pressed)
	_apply_button_style(_button_inspector_buy, _stone_style(COL_STONE_LIGHT, COL_GOLD, 2, 6), COL_GOLD, 16)
	box.add_child(_button_inspector_buy)

	_inspector_panel.visible = false

func _build_nodes() -> void:
	var positions: Dictionary = {}
	for id in GameData.UPGRADE_TREE:
		positions[id] = _node_canvas_position(GameData.UPGRADE_TREE[id])
	_lines_layer.node_positions = positions

	for id in GameData.UPGRADE_TREE:
		var pos: Vector2 = positions[id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size = Vector2(64, 64)
		btn.position = pos - Vector2(32, 32)
		btn.pressed.connect(_make_node_press_handler(id))
		_apply_button_style(btn, _tile_style(NODE_FRAME_TEX), COL_TEXT, 26)
		_tree_canvas.add_child(btn)
		_node_buttons[id] = btn

func _node_canvas_position(node_data: Dictionary) -> Vector2:
	if node_data["depth"] == 0:
		return Vector2(TREE_CENTER, TREE_CENTER)
	var angle_deg: float = GameData.BRANCH_ANGLES.get(node_data["branch"], 0)
	var angle_rad := deg_to_rad(angle_deg)
	var r: float = node_data["depth"] * TREE_RADIUS_STEP
	return Vector2(TREE_CENTER + cos(angle_rad) * r, TREE_CENTER + sin(angle_rad) * r)

# ---------------------------------------------------------------------------
# Open / close
# ---------------------------------------------------------------------------
func open() -> void:
	visible = true
	# _tree_viewport.size comes from a Container's SIZE_EXPAND_FILL, which
	# only resolves after Godot runs a layout pass — it can still read as
	# near-zero right here, the same frame visibility flips on. Rather than
	# guess how many frames that pass takes, keep retrying from _process()
	# until the size looks real, then center exactly once.
	_pending_center = true

func close() -> void:
	visible = false
	_selected_id = ""
	_inspector_panel.visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()

# ---------------------------------------------------------------------------
# Per-frame refresh
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not visible:
		return
	if _pending_center and _tree_viewport.size.x > 10.0:
		_center_view()
		_pending_center = false
	_label_ko_badge.text = "◆ %d KO disponibles" % GameState.get_available_ko()
	_refresh_nodes()
	if _selected_id != "":
		_refresh_inspector()

## core/locked nodes use a texture that already has its one-and-only icon
## (the spiral glow, the padlock) baked in from the reference, so their
## emoji is cleared instead of doubling up on top of it — every other node
## keeps its own emoji over the shared node_frame.png tile (see class
## header for why that tile isn't also icon-free). State feedback (locked
## vs available vs affordable vs purchased) comes from which texture and
## modulate_color _tile_style() gets, not from a hand-picked border colour
## on a flat StyleBoxFlat any more.
func _refresh_nodes() -> void:
	for id in _node_buttons:
		var btn: Button = _node_buttons[id]
		var node_data: Dictionary = GameData.UPGRADE_TREE[id]
		var auto_owned: bool = node_data.get("auto_owned", false)
		var node_state: String = "purchased" if auto_owned else GameState.get_tree_node_state(id)
		var locked: bool = node_state == "coming-soon"

		var tex: Texture2D = NODE_FRAME_TEX
		var modulate := Color.WHITE
		var font_color: Color = COL_TEXT
		var icon_text: String = node_data.get("icon", "")

		if auto_owned:
			tex = NODE_CORE_TEX
			icon_text = ""
			font_color = COL_PURPLE
		elif locked:
			tex = NODE_LOCKED_TEX
			icon_text = ""
			font_color = COL_TEXT_DIM
		else:
			match node_state:
				"purchased":
					modulate = Color(1.0, 0.88, 0.55, 1.0)
					font_color = COL_GOLD
				"available":
					var affordable: bool = GameState.get_available_ko() >= node_data.get("cost", 0)
					if affordable:
						font_color = COL_TEXT
					else:
						modulate = Color(0.55, 0.55, 0.55, 1.0)
						font_color = COL_TEXT_DIM
				_:
					modulate = Color(0.7, 0.7, 0.7, 1.0)
					font_color = COL_TEXT_DIM

		btn.text = icon_text
		_apply_button_style(btn, _tile_style(tex, modulate), font_color, 26)

# ---------------------------------------------------------------------------
# Node selection & inspector
# ---------------------------------------------------------------------------
func _make_node_press_handler(id: String) -> Callable:
	return func(): _select_node(id)

func _select_node(id: String) -> void:
	_selected_id = id
	_refresh_inspector()

func _refresh_inspector() -> void:
	_inspector_panel.visible = true
	var node_data: Dictionary = GameData.UPGRADE_TREE[_selected_id]
	var auto_owned: bool = node_data.get("auto_owned", false)
	var node_state: String = "purchased" if auto_owned else GameState.get_tree_node_state(_selected_id)

	_label_inspector_icon.text = "🔒" if node_state == "coming-soon" else node_data.get("icon", "")
	_label_inspector_name.text = node_data["name"]
	_label_inspector_desc.text = node_data["description"]
	_label_inspector_state.text = "✅ Toujours actif" if auto_owned else GameState.describe_tree_node_lock(_selected_id)

	var cost: int = node_data.get("cost", 0)
	var can_buy: bool = not auto_owned and node_state == "available" and GameState.get_available_ko() >= cost
	_button_inspector_buy.visible = not auto_owned and node_state != "purchased" and node_state != "coming-soon"
	_button_inspector_buy.disabled = not can_buy
	_button_inspector_buy.text = "Débloquer — %d KO" % cost if cost else "Débloquer"
	# Overriding every Button stylebox state (see _apply_button_style) also
	# overrides Godot's own default "disabled" dimming, so an unaffordable
	# buy button would otherwise look identical to a buyable one — restyled
	# here each refresh instead, same as _refresh_nodes() already does for
	# the tree nodes themselves.
	if can_buy:
		_apply_button_style(_button_inspector_buy, _stone_style(COL_STONE_LIGHT, COL_GOLD, 2, 6), COL_GOLD, 16)
	else:
		_apply_button_style(_button_inspector_buy, _stone_style(COL_STONE, COL_BORDER, 2, 6), COL_TEXT_DIM, 16)

func _on_inspector_buy_pressed() -> void:
	if _selected_id != "":
		GameState.purchase_tree_node(_selected_id)

# ---------------------------------------------------------------------------
# Pan & zoom (mirrors applyTreeTransform()/zoomTreeBy()/centerTreeView()
# from script.js — Control.position/scale compose the same way CSS
# translate()+scale() do with a top-left transform-origin)
# ---------------------------------------------------------------------------
func _viewport_center() -> Vector2:
	return _tree_viewport.size / 2.0

func _center_view() -> void:
	var vp_size: Vector2 = _tree_viewport.size
	_view_scale = 0.72
	_view_x = vp_size.x / 2.0 - TREE_CENTER * _view_scale
	_view_y = vp_size.y / 2.0 - TREE_CENTER * _view_scale
	_apply_transform()

func _zoom_by(factor: float, cursor_pos: Vector2) -> void:
	var world_x: float = (cursor_pos.x - _view_x) / _view_scale
	var world_y: float = (cursor_pos.y - _view_y) / _view_scale
	var new_scale: float = clamp(_view_scale * factor, 0.35, 1.8)
	_view_scale = new_scale
	_view_x = cursor_pos.x - world_x * new_scale
	_view_y = cursor_pos.y - world_y * new_scale
	_apply_transform()

func _apply_transform() -> void:
	_tree_canvas.position = Vector2(_view_x, _view_y)
	_tree_canvas.scale = Vector2(_view_scale, _view_scale)

func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_mouse = event.position
				_drag_start_view = Vector2(_view_x, _view_y)
			else:
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.12, event.position)
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _drag_start_mouse
		_view_x = _drag_start_view.x + delta.x
		_view_y = _drag_start_view.y + delta.y
		_apply_transform()
