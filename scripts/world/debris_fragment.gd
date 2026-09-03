class_name DebrisFragment
extends PixelDrawer
## A single flying debris chunk — direct translation of spawnFragment()/
## updateFragments()/drawFragment() from render.js: velocity + gravity +
## drag + spin, nothing more. Self-owned lifetime: spawned as a child of
## the Y-sorted entities container at an absolute (entities-local)
## position, it moves itself via `position` each frame and frees itself
## once its life expires — Godot's y_sort_enabled re-evaluates draw
## order from live `position` automatically, so this never needs to be
## sorted manually against houses/trees.

var vx: float
var vy: float
var vrot: float
var rot: float = 0.0
var w: float
var h: float
var color: Color
var ground_y: float
var life: float = 0.0
var max_life: float
var settled: bool = false

func setup(p_vx: float, p_vy: float, p_vrot: float, p_w: float, p_h: float, p_color: Color, p_ground_y: float, p_max_life: float) -> void:
	vx = p_vx
	vy = p_vy
	vrot = p_vrot
	w = p_w
	h = p_h
	color = p_color
	ground_y = p_ground_y
	max_life = p_max_life

func _process(delta: float) -> void:
	life += delta
	if not settled:
		vy += 220.0 * delta
		vx *= (1.0 - min(1.0, delta * 0.6))
		position.x += vx * delta
		position.y += vy * delta
		rot += vrot * delta
		if position.y >= ground_y:
			position.y = ground_y
			settled = true
			vx = 0.0
			vy = 0.0
			vrot = 0.0
	if life >= max_life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0
	if life > max_life - 0.6:
		alpha = max(0.0, (max_life - life) / 0.6)
	px_rotated_rect(0, 0, w, h, rot, Color(color.r, color.g, color.b, alpha))
