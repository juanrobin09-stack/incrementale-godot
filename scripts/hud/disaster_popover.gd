class_name DisasterPopover
extends PanelContainer
## Detail card for whichever dock item is selected: name, description,
## level/production when unlocked (with a buy/upgrade button), or the
## unlock requirement when still locked. Lives in the same VBoxContainer
## flow as the dock (hidden = zero layout space) rather than a manually
## positioned overlay, so its placement never depends on hand-derived
## anchor math.

signal purchase_requested(id: String)

var _current_id: String = ""
var _label_name: Label
var _label_desc: Label
var _label_stats: Label
var _button_buy: Button

func _ready() -> void:
	visible = false

	var box := VBoxContainer.new()
	add_child(box)

	_label_name = Label.new()
	box.add_child(_label_name)

	_label_desc = Label.new()
	_label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_label_desc)

	_label_stats = Label.new()
	box.add_child(_label_stats)

	_button_buy = Button.new()
	_button_buy.pressed.connect(_on_buy_pressed)
	box.add_child(_button_buy)

func show_for(id: String) -> void:
	_current_id = id
	visible = true
	_refresh()

func hide_popover() -> void:
	_current_id = ""
	visible = false

func _process(_delta: float) -> void:
	if visible and _current_id != "":
		_refresh()

func _refresh() -> void:
	var cfg: Dictionary = GameData.DISASTERS[_current_id]
	var st: Dictionary = GameState.state.disasters[_current_id]
	_label_name.text = "%s %s" % [cfg["icon"], cfg["name"]]
	_label_desc.text = cfg["description"]

	if not st["unlocked"]:
		_label_stats.text = _describe_unlock(cfg["unlock"])
		_button_buy.visible = false
		return

	_button_buy.visible = true
	var production := GameState.get_disaster_production(_current_id)
	var cost := GameState.get_disaster_cost(_current_id)
	_label_stats.text = "Niveau %d — +%.1f Chaos/s" % [st["level"], production]

	var can_afford: bool = GameState.state.chaos >= cost
	_button_buy.disabled = not can_afford
	var label: String = "Activer" if st["level"] == 0 else "Améliorer"
	var cost_label: String = "Gratuit" if cost == 0 else "%d Chaos" % cost
	_button_buy.text = "%s — %s" % [label, cost_label]

func _describe_unlock(cond: Variant) -> String:
	var parts: PackedStringArray = []
	if cond.has("chaos"):
		parts.append("%d Chaos" % cond["chaos"])
	if cond.has("disaster_level"):
		var req: Dictionary = cond["disaster_level"]
		parts.append("%s niveau %d" % [GameData.DISASTERS[req["id"]]["name"], req["level"]])
	return "Débloqué à " + " + ".join(parts)

func _on_buy_pressed() -> void:
	if _current_id != "":
		purchase_requested.emit(_current_id)
