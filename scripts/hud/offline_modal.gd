class_name OfflineModal
extends Control
## Full-screen "you were away" overlay, shown once at startup when
## GameState reports offline progress. Same dim + CenterContainer idiom
## as ResetModal.

var _label: Label

func _ready() -> void:
	visible = false
	UiUtil.fill_parent(self)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	UiUtil.fill_parent(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UiUtil.fill_parent(center)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.custom_minimum_size = Vector2(280, 0)
	box.add_child(_label)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func(): visible = false)
	box.add_child(close_btn)

func show_progress(elapsed_sec: float, gained: float) -> void:
	_label.text = "Tu étais absent pendant %s. + %d Chaos !" % [_format_duration(elapsed_sec), int(gained)]
	visible = true

func _format_duration(total_seconds: float) -> String:
	var s := int(floor(total_seconds))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d heure%s %d minute%s" % [h, "s" if h > 1 else "", m, "s" if m > 1 else ""]
	if m > 0:
		return "%d minute%s" % [m, "s" if m > 1 else ""]
	return "%d seconde%s" % [sec, "s" if sec > 1 else ""]
