class_name LevelSelectMenu
extends Control
## Full-screen level-select overlay, opened from a HUD button: one
## LevelCard per GameData.LEVELS entry, read fresh on every open() —
## never cached, since GameState.is_level_unlocked() can change while the
## game runs. Picking any unlocked level, even one already outgrown, is
## real navigation via GameState.view_level(), not a "seen it" indicator.

signal closed

var _row: HBoxContainer

func _ready() -> void:
	visible = false
	UiUtil.fill_parent(self)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UiUtil.fill_parent(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UiUtil.fill_parent(center)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Sélection du niveau"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Populated fresh by _rebuild_cards() on every open() — never built
	# once here and left stale (see class header).
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	box.add_child(_row)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(close)
	box.add_child(close_btn)

func open() -> void:
	_rebuild_cards()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _rebuild_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	for lvl in GameData.LEVELS:
		var kind := _kind_for_level(lvl["id"])
		var unlocked: bool = GameState.is_level_unlocked(lvl["id"])
		var card := LevelCard.new()
		card.setup(lvl["id"], lvl["name"], lvl["implemented"], unlocked, kind)
		card.activated.connect(_on_card_activated)
		_row.add_child(card)

## Which icon LevelCard should draw for a given level id — a purely
## cosmetic detail of this menu, deliberately kept as a tiny local lookup
## here rather than a "kind" field baked into GameData's own data table,
## since GameData.LEVELS is simulation data and this is presentation only.
func _kind_for_level(level_id: int) -> String:
	match level_id:
		1:
			return "village"
		2:
			return "town"
		_:
			return ""

func _on_card_activated(level_id: int) -> void:
	if GameState.view_level(level_id):
		close()
