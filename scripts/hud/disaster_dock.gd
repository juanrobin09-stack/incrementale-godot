class_name DisasterDock
extends PanelContainer
## Bottom-left dock: one button per GameData.get_dock_disaster_ids(level),
## showing the real logo texture, dimmed with a lock icon while the
## disaster is locked. Clicking toggles selection; the popover panel
## reacts to `disaster_selected` to show details for the clicked id.
##
## Rebuilds its buttons whenever the level's own roster changes (see
## _current_ids/_rebuild()) rather than only once in _ready() — level 2
## adds two more disasters to the dock on top of the village's three
## (nothing is ever removed — see GameData.DOCK_DISASTER_IDS_LEVEL_2's
## own header), and that can happen mid-session, right when
## notify_structure_ruined() flips state.level, with this dock already on
## screen.

signal disaster_selected(id: String)

var _row: HBoxContainer
var _buttons: Dictionary = {}
var _current_ids: Array = []

func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	_rebuild()

func _make_press_handler(id: String) -> Callable:
	return func(): disaster_selected.emit(id)

func _process(_delta: float) -> void:
	if GameData.get_dock_disaster_ids(GameState.state.level) != _current_ids:
		_rebuild()
	_refresh()

func _rebuild() -> void:
	for child in _row.get_children():
		child.queue_free()
	_buttons.clear()
	_current_ids = GameData.get_dock_disaster_ids(GameState.state.level)

	for id in _current_ids:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.expand_icon = true
		# Not every disaster has real reference art for its dock logo yet
		# (quake/blight don't — see GameData.DOCK_LOGOS's own header) —
		# fall back to the disaster's own emoji as plain button text
		# rather than load()ing a path that isn't there.
		if GameData.DOCK_LOGOS.has(id):
			btn.icon = load(GameData.DOCK_LOGOS[id])
		btn.pressed.connect(_make_press_handler(id))
		_row.add_child(btn)
		_buttons[id] = btn

	_refresh()

func _refresh() -> void:
	for id in _buttons:
		var st: Dictionary = GameState.state.disasters[id]
		var btn: Button = _buttons[id]
		var has_logo: bool = GameData.DOCK_LOGOS.has(id)
		if st["unlocked"]:
			var label: String = "Niv. %d" % st["level"]
			btn.text = label if has_logo else "%s %s" % [GameData.DISASTERS[id]["icon"], label]
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.text = "🔒" if has_logo else "%s 🔒" % GameData.DISASTERS[id]["icon"]
			btn.modulate = Color(1, 1, 1, 0.5)
