class_name DebrisSpawner
extends RefCounted
## Direct translation of spawnDebrisBurst()/spawnFragment()/spawnDust()
## from render.js. Spawns DebrisFragment/DustPuff nodes as children of
## `parent` (the Y-sorted entities container) at absolute
## (entities-local) positions — a static helper rather than a shared
## particle pool, since Godot nodes are cheap to spawn/free individually
## and this sidesteps needing to sort them manually against everything
## else (see DebrisFragment's own header for why that's safe).

static func burst(parent: Node2D, x: float, ground_y: float, count: int, palette: Array, spread_x: float, dir: float) -> void:
	for i in range(count):
		var ang: float = (-0.4 - randf() * 1.4) * dir
		var speed: float = 30.0 + randf() * 55.0
		var frag := DebrisFragment.new()
		frag.position = Vector2(x + (randf() - 0.5) * spread_x, ground_y - randf() * 8.0)
		var color: Color = palette[randi_range(0, palette.size() - 1)]
		frag.setup(
			cos(ang) * speed * dir + (randf() - 0.5) * 20.0,
			-abs(sin(ang)) * speed - 20.0,
			(randf() - 0.5) * 6.0,
			2.0 + randf() * 3.0, 2.0 + randf() * 3.0,
			color, ground_y, 2.5 + randf(),
		)
		parent.add_child(frag)

	dust(parent, x, ground_y - 4.0, 2.0, 18.0 + spread_x * 0.4, 1.1)
	dust(parent, x + spread_x * 0.3, ground_y - 2.0, 2.0, 14.0, 0.9)

static func dust(parent: Node2D, x: float, y: float, r: float, max_r: float, max_life: float) -> void:
	var puff := DustPuff.new()
	puff.position = Vector2(x, y)
	puff.setup(0.0, r, max_r, max_life)
	parent.add_child(puff)
