class_name TreeLinesLayer
extends Control
## Draws the connector lines between Chaos Tree nodes (parent → child,
## per UPGRADE_TREE's `requires`), colored by purchase state. A plain
## `_draw()` layer rather than one Line2D per connector — simpler to
## keep in sync with state, since it just redraws from GameData +
## GameState each time `queue_redraw()` is called.
##
## Colours/joint markers match the stone-and-violet reference passed to
## ChaosTreeOverlay (see that script's header) — thin mortar-toned lines,
## gold once both ends are owned, a small diamond marker at each
## connector's midpoint standing in for the reference's own joint studs.

var node_positions: Dictionary = {}  # id (String) -> Vector2, set by the owner before first draw

const COL_LOCKED := Color(0.30, 0.27, 0.23, 0.55)
const COL_PARTIAL := Color(0.56, 0.47, 0.32, 0.7)
const COL_PURCHASED := Color(0.87, 0.71, 0.33, 1.0)
const JOINT_SIZE := 5.0

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
				color = COL_PURCHASED
			elif from_purchased:
				color = COL_PARTIAL
			else:
				color = COL_LOCKED
			draw_line(from_pos, to_pos, color, 2.0)
			_draw_joint((from_pos + to_pos) / 2.0, color)

func _draw_joint(center: Vector2, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -JOINT_SIZE), center + Vector2(JOINT_SIZE, 0.0),
		center + Vector2(0.0, JOINT_SIZE), center + Vector2(-JOINT_SIZE, 0.0),
	])
	draw_colored_polygon(pts, color)

func _is_purchased(id: String) -> bool:
	if GameData.UPGRADE_TREE[id].get("auto_owned", false):
		return true
	return GameState.state.tree[id]["purchased"]
