class_name OptionsMenu
extends PanelContainer
## Settings page swapped into PauseMenu's dimmed backdrop (sized to its
## own content, not full-screen). No sounds exist in the game yet, but
## these sliders already have a real effect — they drive actual
## AudioServer bus volumes via GameSettings, ready for when sound lands.

signal back_requested

var _resolutions: Array = []
var _slider_sfx: HSlider
var _slider_music: HSlider
var _label_sfx_pct: Label
var _label_music_pct: Label
var _option_resolution: OptionButton

func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	var title := Label.new()
	title.text = "Options"
	box.add_child(title)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	box.add_child(sfx_row)

	var sfx_label := Label.new()
	sfx_label.text = "Effets sonores"
	sfx_row.add_child(sfx_label)

	_slider_sfx = HSlider.new()
	_slider_sfx.min_value = 0.0
	_slider_sfx.max_value = 1.0
	_slider_sfx.step = 0.01
	_slider_sfx.custom_minimum_size.x = 220
	_slider_sfx.value = GameSettings.get_sfx_volume()
	sfx_row.add_child(_slider_sfx)

	_label_sfx_pct = Label.new()
	_label_sfx_pct.text = "%d%%" % int(round(_slider_sfx.value * 100))
	sfx_row.add_child(_label_sfx_pct)

	_slider_sfx.value_changed.connect(_on_sfx_changed)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	box.add_child(music_row)

	var music_label := Label.new()
	music_label.text = "Musique"
	music_row.add_child(music_label)

	_slider_music = HSlider.new()
	_slider_music.min_value = 0.0
	_slider_music.max_value = 1.0
	_slider_music.step = 0.01
	_slider_music.custom_minimum_size.x = 220
	_slider_music.value = GameSettings.get_music_volume()
	music_row.add_child(_slider_music)

	_label_music_pct = Label.new()
	_label_music_pct.text = "%d%%" % int(round(_slider_music.value * 100))
	music_row.add_child(_label_music_pct)

	_slider_music.value_changed.connect(_on_music_changed)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	box.add_child(res_row)

	var res_label := Label.new()
	res_label.text = "Résolution"
	res_row.add_child(res_label)

	_option_resolution = OptionButton.new()
	_resolutions = GameSettings.get_available_resolutions()
	var current_res := GameSettings.get_current_resolution()
	var selected_index := -1
	for i in _resolutions.size():
		var res_size: Vector2i = _resolutions[i]
		_option_resolution.add_item("%d x %d" % [res_size.x, res_size.y])
		if res_size == current_res:
			selected_index = i
	if selected_index >= 0:
		_option_resolution.select(selected_index)
	_option_resolution.item_selected.connect(_on_resolution_selected)
	res_row.add_child(_option_resolution)

	var back_button := Button.new()
	back_button.text = "Retour"
	back_button.pressed.connect(func(): back_requested.emit())
	box.add_child(back_button)

func _on_sfx_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value)
	_label_sfx_pct.text = "%d%%" % int(round(value * 100))

func _on_music_changed(value: float) -> void:
	GameSettings.set_music_volume(value)
	_label_music_pct.text = "%d%%" % int(round(value * 100))

func _on_resolution_selected(index: int) -> void:
	GameSettings.set_resolution(_resolutions[index])
