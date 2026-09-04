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
##
## Per-level tuning widened (reported: the jump between levels wasn't
## visible enough) on three independent axes, not just a bigger number:
## MAX_FORCE's per-level spread is wider (old top/bottom levels were
## closer together, and adjacent levels' [floor,max] ranges overlapped —
## e.g. old level 2's peak (0.8) sat inside old level 3's floor..max
## range, so a strong level-2 gust and a weak level-3 one could look
## alike); FLOOR_FRACTION dropped so force dips further between gusts
## within a single level too (a gust that comes and goes reads as more
## "gusty" than one that hovers at a steady medium value); and — new —
## FREQ_MUL speeds up the gust cycle itself at higher levels, not just
## its amplitude, since "rafales plus rapides" is a distinct ask from
## "rafales plus fortes". force's own glide rate scales with FREQ_MUL
## too, or the exponential smoothing below (tuned for the old, slower
## cycle) would low-pass-filter away exactly the faster oscillation
## FREQ_MUL is adding.
const MAX_FORCE := [0.0, 0.30, 0.72, 1.35]
const FREQ_MUL := [1.0, 1.0, 1.3, 1.75]
const FLOOR_FRACTION := 0.32

var direction: float
var force: float = 0.0
var elapsed: float = 0.0
var last_tree_fall_at: float = -999.0

func _init() -> void:
	direction = 1.0 if randf() < 0.5 else -1.0

func update(delta: float, wind_level: int) -> void:
	elapsed += delta
	var max_force: float = MAX_FORCE[wind_level] if wind_level < MAX_FORCE.size() else 0.0
	var freq_mul: float = FREQ_MUL[wind_level] if wind_level < FREQ_MUL.size() else 1.0
	var target_force: float = 0.0
	if wind_level > 0:
		var floor_v: float = max_force * FLOOR_FRACTION
		target_force = floor_v + _wind_wave(elapsed * freq_mul) * (max_force - floor_v)
	# A single exponential glide toward that target — this only smooths
	# the moment wind switches on/off or changes tier, since the target
	# itself is already smooth and continuous. Scaled by freq_mul so a
	# faster-cycling target at high levels doesn't get smoothed into a
	# slower-looking average than intended.
	force += (target_force - force) * min(1.0, delta * 3.0 * freq_mul)

func _wind_wave(t: float) -> float:
	var lobe_a: float = 0.5 + 0.5 * sin(t * 0.23)
	var lobe_b: float = 0.5 + 0.5 * sin(t * 0.53 + 2.4)
	var lobe_c: float = 0.5 + 0.5 * sin(t * 0.11 + 5.1)
	return lobe_a * 0.5 + lobe_b * 0.3 + lobe_c * 0.2
