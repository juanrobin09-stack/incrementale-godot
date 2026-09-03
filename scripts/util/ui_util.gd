class_name UiUtil
extends RefCounted
## Small, deliberately explicit UI helpers. `fill_parent()` exists
## because `Control.set_anchors_preset(PRESET_FULL_RECT)` takes an
## implicit `resize_mode` argument (defaults to resizing to the
## control's minimum size) that can silently collapse a freshly built,
## still-childless Control to zero size instead of actually filling its
## parent — exactly the kind of thing impossible to catch without a
## running editor. Setting all six properties directly leaves no room
## for a hidden default to interfere.

static func fill_parent(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
