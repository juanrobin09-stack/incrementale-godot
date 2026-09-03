class_name TopBar
extends PanelContainer
## Top bar HUD: current tier, chaos, chaos/s, available KO, plus reset and
## sound-toggle buttons. Functional pass — default theme, no custom art
## yet. Visual styling to match the original (wood/parchment/gold panels)
## is a later, screenshot-driven pass; there is no way to see Godot's
## rendered output from this environment.

signal reset_requested
signal open_tree_requested

var _label_tier: Label
var _label_chaos: Label
var _label_cps: Label
var _label_ko: Label
var _button_tree: Button
var _button_sound: Button

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	_label_tier = _make_stat_label(row)
	_label_chaos = _make_stat_label(row)
	_label_cps = _make_stat_label(row)
	_label_ko = _make_stat_label(row)

	_button_tree = Button.new()
	_button_tree.pressed.connect(func(): open_tree_requested.emit())
	row.add_child(_button_tree)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_button_sound = Button.new()
	_button_sound.pressed.connect(_on_sound_pressed)
	row.add_child(_button_sound)

	var button_reset := Button.new()
	button_reset.text = "Réinitialiser"
	button_reset.pressed.connect(func(): reset_requested.emit())
	row.add_child(button_reset)

	_refresh()

func _make_stat_label(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	_label_tier.text = GameState.get_current_tier_name()
	_label_chaos.text = "Chaos : %d" % int(floor(GameState.state.chaos))
	_label_cps.text = "%.1f Chaos/s" % GameState.get_total_chaos_per_second()
	_label_ko.text = "KO : %d" % GameState.get_available_ko()
	_button_tree.text = "🌀 Arbre du Chaos"
	_button_sound.text = "🔊" if GameState.state.settings.sound_enabled else "🔇"

func _on_sound_pressed() -> void:
	GameState.state.settings.sound_enabled = not GameState.state.settings.sound_enabled
	GameState.save_game()
