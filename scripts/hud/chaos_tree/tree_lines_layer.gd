class_name TreeLinesLayer
extends Control
## Draws the connector lines between Chaos Tree nodes (parent → child,
## per UPGRADE_TREE's `requires`), colored by purchase state. A plain
## `_draw()` layer rather than one Line2D per connector — simpler to
## keep in sync with state, since it just redraws from GameData +
## GameState each time `queue_redraw()` is called.

var node_positions: Dictionary = {}  # id (String) -> Vector2, set by the owner before first draw

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	for id in GameData.UPGRADE_TREE:
		if not node_positions.has(id):
			continue
		var node_data: Dictionary = GameData.UPGRADE_TREE[id]
		var to_pos: Vector2 = node_positions[id]
		for req_id in node_data["requires"]:
			if not node_positions.has(req_id):
				continue
			var from_pos: Vector2 = node_positions[req_id]
			var from_purchased := _is_purchased(req_id)
			var to_purchased := _is_purchased(id)
			var color: Color
			if from_purchased and to_purchased:
				color = Color(1.0, 0.85, 0.35, 1.0)
			elif from_purchased:
				color = Color(0.7, 0.65, 0.5, 0.6)
			else:
				color = Color(0.4, 0.4, 0.4, 0.4)
			draw_line(from_pos, to_pos, color, 3.0)

func _is_purchased(id: String) -> bool:
	if GameData.UPGRADE_TREE[id].get("auto_owned", false):
		return true
	return GameState.state.tree[id]["purchased"]
