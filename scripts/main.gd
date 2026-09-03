extends Control
## Root scene: composes the HUD pieces into the actual playable game.
## Everything is built in code rather than hand-authored .tscn node
## trees — there is no local Godot editor in this environment to lay
## things out visually and verify, so code-constructed UI (reviewable as
## plain text, and far less likely to hide a subtle structural mistake)
## is the lower-risk choice for now. This is a functional pass: correct
## wiring and layout via Containers, default theme. Matching the
## original's specific art style (wood/parchment/gold, stone dock) is a
## later, screenshot-driven pass.
##
## World/village rendering (the equivalent of render.js) is not built
## yet — the background is a plain placeholder color for now.

var _top_bar: TopBar
var _dock: DisasterDock
var _popover: DisasterPopover
var _reset_modal: ResetModal
var _offline_modal: OfflineModal
var _chaos_tree: ChaosTreeOverlay
var _caption_label: Label
var _open_dock_id: String = ""

func _ready() -> void:
	UiUtil.fill_parent(self)

	var background := ColorRect.new()
	background.color = Color(0.16, 0.22, 0.14)
	UiUtil.fill_parent(background)
	add_child(background)

	var margin := MarginContainer.new()
	UiUtil.fill_parent(margin)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_top_bar = TopBar.new()
	_top_bar.reset_requested.connect(func(): _reset_modal.open())
	_top_bar.open_tree_requested.connect(func(): _chaos_tree.open())
	vbox.add_child(_top_bar)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_caption_label = Label.new()
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_caption_label)

	_popover = DisasterPopover.new()
	_popover.purchase_requested.connect(_on_purchase_requested)
	vbox.add_child(_popover)

	var bottom_row := HBoxContainer.new()
	vbox.add_child(bottom_row)

	_dock = DisasterDock.new()
	_dock.disaster_selected.connect(_on_disaster_selected)
	bottom_row.add_child(_dock)

	_reset_modal = ResetModal.new()
	_reset_modal.confirmed.connect(_on_reset_confirmed)
	_reset_modal.cancelled.connect(func(): _reset_modal.close())
	add_child(_reset_modal)

	_offline_modal = OfflineModal.new()
	add_child(_offline_modal)

	_chaos_tree = ChaosTreeOverlay.new()
	add_child(_chaos_tree)

	GameState.offline_progress_applied.connect(_on_offline_progress)
	GameState.apply_offline_progress()

func _process(_delta: float) -> void:
	_caption_label.text = GameState.get_scene_caption()

func _on_disaster_selected(id: String) -> void:
	if _open_dock_id == id:
		_open_dock_id = ""
		_popover.hide_popover()
	else:
		_open_dock_id = id
		_popover.show_for(id)

func _on_purchase_requested(id: String) -> void:
	GameState.purchase_disaster(id)

func _on_reset_confirmed() -> void:
	GameState.do_reset()
	_open_dock_id = ""
	_popover.hide_popover()
	_reset_modal.close()

func _on_offline_progress(elapsed_sec: float, gained: float) -> void:
	_offline_modal.show_progress(elapsed_sec, gained)
