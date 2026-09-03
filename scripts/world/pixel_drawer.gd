class_name PixelDrawer
extends Node2D
## Base class for every world sprite: direct translations of render.js's
## pixel-perfect primitives (pxRect/pxTriangleUp/pxCircle/pxEllipse/
## pxTaperedBend/pxRotatedRect) — hard-edged scanline fills, no
## anti-aliasing, which is what reads as pixel art rather than shapes
## with a filter. Every px_* method draws relative to `self`, i.e. to
## this node's own local origin — Godot only allows draw_*() calls from
## within a CanvasItem's own draw pass, so subclasses must call these
## from their own _draw() override, not from an unrelated node.
##
## Coordinates are floats throughout and only rounded at the final
## draw_rect() call, exactly like the original rounding inside pxRect()
## itself rather than at every call site.

func px_rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	if w <= 0 or h <= 0:
		return
	draw_rect(Rect2(round(x), round(y), round(w), round(h)), color)

## Upward-pointing triangle (roof), flat-shaded left/right.
func px_triangle_up(cx: float, top_y: float, height: float, half_width: float, color_l: Color, color_r: Color) -> void:
	var rows: int = max(1, int(round(height)))
	for i in range(rows):
		var t: float = float(i + 1) / rows
		var hw: float = max(1.0, round(half_width * t))
		var y: float = round(top_y + i)
		px_rect(cx - hw, y, hw, 1, color_l)
		px_rect(cx, y, hw, 1, color_r)

## Same triangle, but each row's own center leans between a base and tip
## offset — the shape itself bends, not just translates as a rigid block.
func px_triangle_up_sheared(cx: float, top_y: float, height: float, half_width: float, bend_base: float, bend_tip: float, color_l: Color, color_r: Color) -> void:
	var rows: int = max(1, int(round(height)))
	for i in range(rows):
		var t: float = float(i + 1) / rows
		var hw: float = max(1.0, round(half_width * t))
		var y: float = round(top_y + i)
		var row_cx: float = cx + bend_tip + (bend_base - bend_tip) * t
		px_rect(row_cx - hw, y, hw, 1, color_l)
		px_rect(row_cx, y, hw, 1, color_r)

func px_circle(cx: float, cy: float, r: float, color_l: Color, color_r: Color) -> void:
	var rr: int = int(round(r))
	for y in range(-rr, rr + 1):
		var hw: int = int(round(sqrt(max(0.0, float(rr * rr - y * y)))))
		if hw <= 0:
			continue
		px_rect(cx - hw, cy + y, hw, 1, color_l)
		px_rect(cx, cy + y, hw, 1, color_r)

func px_ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var ry_i: int = int(round(ry))
	var denom: float = float(ry_i) if ry_i != 0 else 1.0
	for y in range(-ry_i, ry_i + 1):
		var t: float = float(y) / denom
		var hw: int = int(round(rx * sqrt(max(0.0, 1.0 - t * t))))
		if hw <= 0:
			continue
		px_rect(cx - hw, cy + y, hw * 2, 1, color)

## A tapered vertical trunk/branch segment, bent by offsetting each
## horizontal slice progressively more from base to tip. Returns the tip
## anchor point (for foliage/branches to attach to).
func px_tapered_bend(base_x: float, base_y: float, height: float, base_w: float, tip_w: float, bend_x: float, color_l: Color, color_r: Color) -> Vector2:
	var rows: int = max(2, int(round(height)))
	for i in range(rows):
		var t: float = float(i) / (rows - 1)
		var w: float = max(1.0, base_w + (tip_w - base_w) * t)
		var bend: float = bend_x * pow(t, 1.6)
		var cx: float = base_x + bend
		var y: float = round(base_y - i)
		px_rect(cx - w / 2.0, y, w / 2.0, 1, color_l)
		px_rect(cx, y, max(1.0, w / 2.0), 1, color_r)
	return Vector2(base_x + bend_x, base_y - rows)

func px_rotated_rect(x: float, y: float, w: float, h: float, rot: float, color: Color) -> void:
	var hw := w / 2.0
	var hh := h / 2.0
	var corners := [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
	var pts := PackedVector2Array()
	for corner in corners:
		pts.append(Vector2(x, y) + corner.rotated(rot))
	draw_colored_polygon(pts, color)

func seeded(n: float) -> float:
	var x: float = sin(n * 12.9898) * 43758.5453
	return x - floor(x)
