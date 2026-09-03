class_name WindEngine
extends RefCounted
## Direct translation of the wind-gust engine from render.js: a fixed
## direction chosen once and frozen for the whole session (never
## reassigned after construction — every wind-reactive consumer reads
## this same sign, so nothing can ever switch sides mid-session), and a
## continuous, memoryless force curve — three unsigned sine lobes at
## incommensurate speeds/phases, summed and weighted — rather than a
## calm/rise/peak/fall state machine that could get mis-sequenced.
## Owned by WorldScene, updated once per frame, read by every
## wind-reactive sprite (trees, bushes, fence, clouds, wind streaks).
##
## Also carries `elapsed` (one shared session clock, so every
## wind-reactive sprite animates off the same timeline) and
## `last_tree_fall_at` — the original staggers tree falls with a single
## shared cooldown (`let lastTreeFallAt` at module scope) so several
## trees under the same gust don't all come down on the same frame;
## this is as reasonable a shared home for that as any, since it's
## exactly the same kind of session-wide wind-runtime state.

const MAX_FORCE := [0.0, 0.42, 0.8, 1.2]
const FLOOR_FRACTION := 0.45

var direction: float
var force: float = 0.0
var elapsed: float = 0.0
var last_tree_fall_at: float = -999.0

func _init() -> void:
	direction = 1.0 if randf() < 0.5 else -1.0

func update(delta: float, wind_level: int) -> void:
	elapsed += delta
	var max_force: float = MAX_FORCE[wind_level] if wind_level < MAX_FORCE.size() else 0.0
	var target_force: float = 0.0
	if wind_level > 0:
		var floor_v: float = max_force * FLOOR_FRACTION
		target_force = floor_v + _wind_wave(elapsed) * (max_force - floor_v)
	# A single exponential glide toward that target — this only smooths
	# the moment wind switches on/off or changes tier, since the target
	# itself is already smooth and continuous.
	force += (target_force - force) * min(1.0, delta * 3.0)

func _wind_wave(t: float) -> float:
	var lobe_a: float = 0.5 + 0.5 * sin(t * 0.23)
	var lobe_b: float = 0.5 + 0.5 * sin(t * 0.53 + 2.4)
	var lobe_c: float = 0.5 + 0.5 * sin(t * 0.11 + 5.1)
	return lobe_a * 0.5 + lobe_b * 0.3 + lobe_c * 0.2
