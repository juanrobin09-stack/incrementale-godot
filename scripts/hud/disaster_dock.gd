class_name DisasterDock
extends PanelContainer
## Bottom-left dock: one button per GameData.DOCK_DISASTER_IDS, showing the
## real logo texture, dimmed with a lock icon while the disaster is
## locked. Clicking toggles selection; the popover panel reacts to
## `disaster_selected` to show details for the clicked id.

signal disaster_selected(id: String)

var _buttons: Dictionary = {}

func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	for id in GameData.DOCK_DISASTER_IDS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.expand_icon = true
		btn.icon = load(GameData.DOCK_LOGOS[id])
		btn.pressed.connect(_make_press_handler(id))
		row.add_child(btn)
		_buttons[id] = btn

	_refresh()

func _make_press_handler(id: String) -> Callable:
	return func(): disaster_selected.emit(id)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	for id in _buttons:
		var st: Dictionary = GameState.state.disasters[id]
		var btn: Button = _buttons[id]
		if st["unlocked"]:
			btn.text = "Niv. %d" % st["level"]
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.text = "🔒"
			btn.modulate = Color(1, 1, 1, 0.5)
