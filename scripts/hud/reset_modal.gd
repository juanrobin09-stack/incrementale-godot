class_name ResetModal
extends Control
## Full-screen confirmation overlay for the reset button. Uses the
## standard Godot "dim background + CenterContainer" modal idiom so
## centering never depends on hand-derived anchor math.

signal confirmed
signal cancelled

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var label := Label.new()
	label.text = "Réinitialiser toute la partie ? Cette action est irréversible."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(280, 0)
	box.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(func(): cancelled.emit())
	row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Réinitialiser"
	confirm_btn.pressed.connect(func(): confirmed.emit())
	row.add_child(confirm_btn)

func open() -> void:
	visible = true

func close() -> void:
	visible = false
