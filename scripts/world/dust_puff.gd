class_name DustPuff
extends PixelDrawer
## A single expanding, fading dust puff — direct translation of
## spawnDust()/updateFragments()'s dust half/drawDustPuff() from
## render.js. Self-owned lifetime, same pattern as DebrisFragment.

var vx: float
var r: float
var max_r: float
var life: float = 0.0
var max_life: float

func setup(p_vx: float, p_r: float, p_max_r: float, p_max_life: float) -> void:
	vx = p_vx
	r = p_r
	max_r = p_max_r
	max_life = p_max_life

func _process(delta: float) -> void:
	life += delta
	position.x += vx * delta
	if life >= max_life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = life / max_life
	var radius: float = r + (max_r - r) * t
	# PAL.dust is 'rgba(196,182,158,0.55)'; the original also multiplies
	# by a fading ctx.globalAlpha of (1-t)*0.6 — both factors combined
	# here since draw_circle() has no ambient-alpha equivalent.
	var alpha: float = (1.0 - t) * 0.6 * 0.55
	draw_circle(Vector2.ZERO, radius, Color(196.0 / 255.0, 182.0 / 255.0, 158.0 / 255.0, alpha))
