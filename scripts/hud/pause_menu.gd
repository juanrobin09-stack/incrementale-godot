class_name PauseMenu
extends Control
## Real pause: opening this sets SceneTree.paused = true, which — because
## every other node in this project keeps Godot's default
## PROCESS_MODE_INHERIT — freezes the world, HUD, wind, economy tick and
## disaster production for free; only this control (and everything under
## it, since children inherit an ancestor's explicit mode) is marked
## PROCESS_MODE_ALWAYS so its own buttons/sliders keep working while
## everything else is frozen. Escape opening this menu is decided in
## main.gd (which also owns deferring to ChaosTreeOverlay first — see its
## own header); Escape CLOSING it is decided here instead, since once the
## tree is actually paused this is the only thing still listening.

const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.75)

var _main_panel: PanelContainer
var _options_menu: OptionsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	UiUtil.fill_parent(self)

	var dim := ColorRect.new()
	dim.color = BACKDROP_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UiUtil.fill_parent(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UiUtil.fill_parent(center)
	add_child(center)

	_main_panel = PanelContainer.new()
	center.add_child(_main_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_main_panel.add_child(box)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Reprendre la partie"
	resume_btn.pressed.connect(resume)
	box.add_child(resume_btn)

	var options_btn := Button.new()
	options_btn.text = "Options"
	options_btn.pressed.connect(_show_options)
	box.add_child(options_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quitter le jeu"
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)

	# Sits alongside _main_panel in the same CenterContainer (both always
	# present, only one ever visible) rather than being created on demand,
	# so _show_options()/_show_main() are a plain visibility swap with no
	# first-open special case.
	_options_menu = OptionsMenu.new()
	_options_menu.visible = false
	_options_menu.back_requested.connect(_show_main)
	center.add_child(_options_menu)

func is_open() -> bool:
	return visible

func open() -> void:
	_show_main()
	get_tree().paused = true
	visible = true

func resume() -> void:
	visible = false
	get_tree().paused = false

func _show_main() -> void:
	_main_panel.visible = true
	_options_menu.visible = false

func _show_options() -> void:
	_main_panel.visible = false
	_options_menu.visible = true

func _on_quit_pressed() -> void:
	if not GameState.save_game():
		push_error("Échec de la sauvegarde avant fermeture — le jeu se ferme quand même.")
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()
