class_name ChaosTreeOverlay
extends Control
## Full-screen Chaos Tree overlay: radial node layout (mirrors
## getNodeCanvasPosition() from script.js — same TREE_RADIUS_STEP/
## TREE_CANVAS_SIZE constants), connector lines, pan (drag) + zoom
## (wheel, clamped 0.35–1.8, same as the original), and an inspector
## panel for the selected node. Functional pass — default theme, no
## custom art yet.

const TREE_RADIUS_STEP := 150.0
const TREE_CANVAS_SIZE := 2000.0
const TREE_CENTER := 1000.0

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

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_view := Vector2.ZERO

func _ready() -> void:
	visible = false
	UiUtil.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.92)
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

func _build_header(parent: Node) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	parent.add_child(header)

	var title := Label.new()
	title.text = "🌀 Arbre du Chaos"
	header.add_child(title)

	_label_ko_badge = Label.new()
	header.add_child(_label_ko_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.pressed.connect(func(): _zoom_by(1.0 / 1.25, _viewport_center()))
	header.add_child(zoom_out_btn)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.pressed.connect(func(): _zoom_by(1.25, _viewport_center()))
	header.add_child(zoom_in_btn)

	var recenter_btn := Button.new()
	recenter_btn.text = "Recentrer"
	recenter_btn.pressed.connect(_center_view)
	header.add_child(recenter_btn)

	var close_btn := Button.new()
	close_btn.text = "Fermer ✕"
	close_btn.pressed.connect(close)
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
	parent.add_child(_inspector_panel)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_inspector_panel.add_child(box)

	_label_inspector_icon = Label.new()
	_label_inspector_icon.add_theme_font_size_override("font_size", 32)
	box.add_child(_label_inspector_icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_box)

	_label_inspector_name = Label.new()
	text_box.add_child(_label_inspector_name)

	_label_inspector_desc = Label.new()
	_label_inspector_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_box.add_child(_label_inspector_desc)

	_label_inspector_state = Label.new()
	text_box.add_child(_label_inspector_state)

	_button_inspector_buy = Button.new()
	_button_inspector_buy.pressed.connect(_on_inspector_buy_pressed)
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
	_center_view()

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
	_label_ko_badge.text = "%d KO" % GameState.get_available_ko()
	_refresh_nodes()
	if _selected_id != "":
		_refresh_inspector()

func _refresh_nodes() -> void:
	for id in _node_buttons:
		var btn: Button = _node_buttons[id]
		var node_data: Dictionary = GameData.UPGRADE_TREE[id]
		var auto_owned: bool = node_data.get("auto_owned", false)
		var node_state: String = "purchased" if auto_owned else GameState.get_tree_node_state(id)
		btn.text = "🔒" if node_state == "coming-soon" else node_data.get("icon", "")
		match node_state:
			"purchased":
				btn.modulate = Color(0.6, 1.0, 0.6, 1.0)
			"available":
				var affordable: bool = GameState.get_available_ko() >= node_data.get("cost", 0)
				btn.modulate = Color(1.0, 0.85, 0.35, 1.0) if affordable else Color(0.85, 0.85, 0.85, 1.0)
			"coming-soon":
				btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
			_:
				btn.modulate = Color(0.5, 0.5, 0.5, 0.8)

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
