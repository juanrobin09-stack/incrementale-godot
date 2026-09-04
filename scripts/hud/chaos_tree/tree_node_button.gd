class_name TreeNodeButton
extends Button
## Button subclass for every button in ChaosTreeOverlay (tree nodes,
## header, inspector) — adds a hand-drawn bevel and, for locked nodes, a
## custom padlock icon, layered on top of Button's own normal StyleBoxFlat/
## text rendering via `_draw()` rather than replacing it.
##
## Reported directly against a screenshot of the flat-StyleBoxFlat-only
## first pass: next to chaos-tree-reference.png's carved-stone look, flat
## colour with a thin uniform border read as unchanged/still-placeholder,
## even though every colour/layout/label change from that pass was
## actually live. StyleBoxFlat has no per-edge border colour to fake a
## bevel with (only per-edge *width*), so the bevel is drawn here instead:
## a translucent light line along the top+left inner edge and a
## translucent dark line along the bottom+right, the same highlight/
## shadow-strip technique already used on painted metal in
## lamp_post_sprite.gd, just in overlay-alpha form so it reads correctly
## over any of this overlay's per-state background colours without this
## class needing to know what they are.
##
## The lock icon is a genuine reason to stop using the 🔒 emoji rather
## than a purely cosmetic one: emoji glyphs render however the host
## platform's colour-emoji font draws them, entirely outside this
## project's control and visibly inconsistent with the reference's own
## flat single-tone padlock — drawn here instead (arc + rect + a small
## darker keyhole dot) so it's a real, on-purpose shape in the same
## line-art language as the bevel around it.

var bevel: bool = false
var draw_lock: bool = false
var lock_color: Color = Color.WHITE

func _draw() -> void:
	if bevel:
		_draw_bevel()
	if draw_lock:
		_draw_lock_icon()

func _draw_bevel() -> void:
	var s: Vector2 = size
	if s.x < 6.0 or s.y < 6.0:
		return
	var light := Color(1.0, 1.0, 1.0, 0.20)
	var dark := Color(0.0, 0.0, 0.0, 0.32)
	var inset := 2.0
	draw_line(Vector2(inset, s.y - inset), Vector2(inset, inset), light, 2.0)
	draw_line(Vector2(inset, inset), Vector2(s.x - inset, inset), light, 2.0)
	draw_line(Vector2(s.x - inset, inset), Vector2(s.x - inset, s.y - inset), dark, 2.0)
	draw_line(Vector2(inset, s.y - inset), Vector2(s.x - inset, s.y - inset), dark, 2.0)

func _draw_lock_icon() -> void:
	var c: Vector2 = size / 2.0
	var unit: float = min(size.x, size.y) * 0.34
	var body_w := unit * 1.3
	var body_h := unit * 1.05
	var body_top: float = c.y - unit * 0.1
	var body_rect := Rect2(c.x - body_w / 2.0, body_top, body_w, body_h)
	var shackle_r: float = unit * 0.62
	var shackle_center := Vector2(c.x, body_top)
	draw_arc(shackle_center, shackle_r, PI, TAU, 16, lock_color, unit * 0.22, true)
	draw_rect(body_rect, lock_color, true)
	var keyhole_c := Vector2(c.x, body_top + body_h * 0.5)
	draw_circle(keyhole_c, unit * 0.13, Color(lock_color.r * 0.35, lock_color.g * 0.35, lock_color.b * 0.35, lock_color.a))
