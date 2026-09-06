extends Node
## Incrementable — economy/state logic: purchases, costs, unlocks,
## objectives, save/load, offline progress. Mutates the single source of
## truth (`state`), seeded from the pure tables in GameData. Faithful
## translation of the state/economy functions in script.js from the
## original vanilla-JS project. Autoloaded as `GameState`, after
## `GameData` in the autoload order.
##
## Self-driving: once autoloaded, ticks the economy and autosaves on its
## own (mirrors the original's `setInterval(tick, TICK_MS)` /
## `setInterval(saveGame, AUTOSAVE_MS)`), so any scene added later just
## works without extra wiring.
##
## Deliberately out of scope here (belongs to future layers): DOM/Control
## rendering, notifications/sound, and the lightning-timer runtime state
## (a render-layer concern in the original, not economy).

signal state_changed
signal disaster_unlocked(id: String)
signal tree_node_purchased(id: String)
signal offline_progress_applied(elapsed_sec: float, gained: float)
signal game_reset
signal level_changed(new_level: int)

const SAVE_PATH := "user://incrementable_save_v1.json"

var state: Dictionary = {}

var _tick_accumulator := 0.0
var _autosave_accumulator := 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	load_game()
	# Deliberately NOT calling apply_offline_progress() here: this autoload's
	# _ready() runs before the main scene exists, so nothing would be
	# listening to offline_progress_applied yet on a cold start. The main
	# scene calls it explicitly once it has connected the signal.

func _process(delta: float) -> void:
	var tick_step: float = GameData.TICK_MS / 1000.0
	_tick_accumulator += delta
	while _tick_accumulator >= tick_step:
		tick(tick_step)
		_tick_accumulator -= tick_step

	var autosave_step: float = GameData.AUTOSAVE_MS / 1000.0
	_autosave_accumulator += delta
	if _autosave_accumulator >= autosave_step:
		_autosave_accumulator = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

# ---------------------------------------------------------------------------
# Default state & persistence
# ---------------------------------------------------------------------------
func create_default_state() -> Dictionary:
	var disasters := {}
	for id in GameData.DISASTERS:
		disasters[id] = {"level": 0, "unlocked": GameData.DISASTERS[id]["unlock"] == null}
	var tree := {}
	for id in GameData.UPGRADE_TREE:
		tree[id] = {"purchased": GameData.UPGRADE_TREE[id].get("auto_owned", false)}
	var objectives := {}
	for obj in GameData.OBJECTIVES:
		objectives[obj["id"]] = {"completed": false}
	return {
		"chaos": 0.0,
		"total_chaos_earned": 0.0,
		"disasters": disasters,
		"tree": tree,
		"objectives": objectives,
		# sfx_volume/music_volume/resolution_w/resolution_h are read once by
		# GameSettings on startup (see its own header) and written back
		# through it whenever the player moves a slider/picks a resolution
		# in OptionsMenu — nothing here applies them, this dict only ever
		# holds the persisted values. resolution_w/h of 0 means "no explicit
		# choice made yet, leave the engine's own default window size alone".
		"settings": {
			"sound_enabled": false,
			"sfx_volume": 1.0,
			"music_volume": 1.0,
			"resolution_w": 0,
			"resolution_h": 0,
		},
		"last_save_time": Time.get_unix_time_from_system(),
		# Which world level is currently active (see world_scene.gd's
		# _build_level_1()/_build_level_2()) — 1 (village) until the
		# village's own structures are all ruined (see
		# notify_structure_ruined()). ruined_structures is a permanent,
		# one-way record of which individual structures (by the stable id
		# world_scene.gd assigns each one) have reached HouseSprite's
		# "ruined" state at least once — needed because that state itself
		# lives only on the live HouseSprite node and is NOT otherwise
		# persisted, so without this a village fully destroyed one session
		# would quietly rebuild intact next time build() reruns (a resize,
		# a reload) — the opposite of the "never rebuilds once truly
		# collapsed" guarantee this project already makes for houses.
		"level": 1,
		"ruined_structures": {},
		# `level` above is progression: it only ever advances (it's what
		# get_dock_disaster_ids()/disaster unlocks/objectives read, so
		# reaching level 2 keeps quake/blight available for good) and never
		# decreases. `viewed_level` is a separate, purely-cosmetic concern —
		# which WorldScene layout is actually on screen. It starts equal to
		# `level` and auto-follows every advance (see
		# notify_structure_ruined()), but LevelSelectMenu can also point it
		# at any already-unlocked level on its own (view_level()), so
		# revisiting an earlier level never touches progression-gated
		# systems. get_current_tier_id()/get_scene_caption()/world_scene.gd's
		# build() all read this one, never `level` directly.
		"viewed_level": 1,
		# Which levels the player may jump to from LevelSelectMenu, keyed by
		# level id as a STRING — JSON object keys are always strings, and
		# save_game()/load_game() round-trip through JSON, so using String
		# keys from the start avoids an int/String mismatch after a save/
		# reload (the same reason ruined_structures' own ids are always
		# strings). Level 1 is always unlocked; every other id starts absent
		# (== locked) until unlock_level() adds it.
		"unlocked_levels": {"1": true},
	}

func load_game() -> void:
	var fresh := create_default_state()
	var saved = null
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var text := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				saved = parsed
	if saved == null:
		state = fresh
		return

	# Explicit per-field merge with casts, rather than a generic copy —
	# JSON round-trips every number as float, so a saved disaster level
	# must be cast back to int or later strictly-typed int arithmetic
	# (e.g. `-> int` returns) would fail at runtime. Being explicit about
	# which keys are trusted from disk also protects against stray keys
	# from an older/future save format leaking into live state.
	var merged: Dictionary = fresh.duplicate(true)
	if saved.has("chaos"):
		merged.chaos = float(saved.chaos)
	if saved.has("total_chaos_earned"):
		merged.total_chaos_earned = float(saved.total_chaos_earned)
	if saved.has("last_save_time"):
		merged.last_save_time = float(saved.last_save_time)

	merged.disasters = {}
	for id in fresh.disasters:
		var entry: Dictionary = fresh.disasters[id].duplicate()
		var saved_disasters = saved.get("disasters", {})
		if saved_disasters.has(id):
			var saved_entry: Dictionary = saved_disasters[id]
			if saved_entry.has("level"):
				entry.level = int(saved_entry.level)
			if saved_entry.has("unlocked"):
				entry.unlocked = bool(saved_entry.unlocked)
		merged.disasters[id] = entry

	merged.tree = {}
	for id in fresh.tree:
		var entry: Dictionary = fresh.tree[id].duplicate()
		var saved_tree = saved.get("tree", {})
		if saved_tree.has(id) and saved_tree[id].has("purchased"):
			entry.purchased = bool(saved_tree[id].purchased)
		if GameData.UPGRADE_TREE[id].get("auto_owned", false):
			entry.purchased = true
		merged.tree[id] = entry

	merged.objectives = {}
	for id in fresh.objectives:
		var entry: Dictionary = fresh.objectives[id].duplicate()
		var saved_objectives = saved.get("objectives", {})
		if saved_objectives.has(id) and saved_objectives[id].has("completed"):
			entry.completed = bool(saved_objectives[id].completed)
		merged.objectives[id] = entry

	merged.settings = fresh.settings.duplicate()
	var saved_settings = saved.get("settings", {})
	if saved_settings.has("sound_enabled"):
		merged.settings.sound_enabled = bool(saved_settings.sound_enabled)
	if saved_settings.has("sfx_volume"):
		merged.settings.sfx_volume = float(saved_settings.sfx_volume)
	if saved_settings.has("music_volume"):
		merged.settings.music_volume = float(saved_settings.music_volume)
	if saved_settings.has("resolution_w"):
		merged.settings.resolution_w = int(saved_settings.resolution_w)
	if saved_settings.has("resolution_h"):
		merged.settings.resolution_h = int(saved_settings.resolution_h)

	if saved.has("level"):
		merged.level = int(saved.level)
	merged.ruined_structures = {}
	var saved_ruined = saved.get("ruined_structures", {})
	if typeof(saved_ruined) == TYPE_DICTIONARY:
		for id in saved_ruined:
			merged.ruined_structures[id] = true

	# Defaults to the level actually reached (not fresh's hardcoded 1) so a
	# save from before this field existed resumes looking at the same world
	# it last showed, rather than snapping back to the village.
	merged.viewed_level = merged.level
	if saved.has("viewed_level"):
		merged.viewed_level = int(saved.viewed_level)

	merged.unlocked_levels = fresh.unlocked_levels.duplicate()
	var saved_unlocked = saved.get("unlocked_levels", {})
	if typeof(saved_unlocked) == TYPE_DICTIONARY:
		for id in saved_unlocked:
			if bool(saved_unlocked[id]):
				merged.unlocked_levels[str(id)] = true
	# A save from before unlocked_levels existed still has its own `level`
	# reached — treat every level up to and including it as unlocked rather
	# than sending a returning player who already destroyed the village
	# back to a locked level 2.
	for lvl in GameData.LEVELS:
		if lvl["id"] <= merged.level:
			merged.unlocked_levels[str(lvl["id"])] = true

	state = merged

## Returns whether the write actually succeeded — read by PauseMenu's
## "Quitter le jeu" so a failed save (disk full, permissions) is logged
## rather than silently assumed to have worked right before closing.
func save_game() -> bool:
	state.last_save_time = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	return true

func do_reset() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	state = create_default_state()
	game_reset.emit()
	state_changed.emit()

# ---------------------------------------------------------------------------
# Economy — disasters (costs & production)
# ---------------------------------------------------------------------------
func meets_unlock_condition(cond) -> bool:
	if cond == null:
		return true
	if cond.has("level") and state.level < cond["level"]:
		return false
	if cond.has("chaos") and state.total_chaos_earned < cond["chaos"]:
		return false
	if cond.has("disaster_level"):
		var req: Dictionary = cond["disaster_level"]
		var lvl: int = 0
		if state.disasters.has(req["id"]):
			lvl = state.disasters[req["id"]]["level"]
		if lvl < req["level"]:
			return false
	return true

func get_disaster_cost(id: String) -> int:
	var cfg: Dictionary = GameData.DISASTERS[id]
	var level: int = state.disasters[id]["level"]
	if level == 0:
		return 0
	return int(ceil(cfg["base_cost"] * pow(cfg["cost_growth"], level - 1)))

func get_disaster_production(id: String) -> float:
	var cfg: Dictionary = GameData.DISASTERS[id]
	var st: Dictionary = state.disasters[id]
	if not st["unlocked"] or st["level"] <= 0:
		return 0.0

	var base: float = cfg["base_production"] * st["level"]
	var bonus: float = 0.0

	for node_id in GameData.UPGRADE_TREE:
		if not state.tree[node_id]["purchased"]:
			continue
		var eff = GameData.UPGRADE_TREE[node_id].get("effect", null)
		if eff == null:
			continue
		if eff["type"] == "disaster_production_mult" and eff["target"] == id:
			bonus += eff["value"]
		if eff["type"] == "tag_production_mult" and cfg["tags"].has(eff["tag"]):
			bonus += eff["value"]

	for syn in GameData.SYNERGIES:
		if syn["target"] != id:
			continue
		var src: Dictionary = state.disasters[syn["source"]]
		if src["unlocked"] and src["level"] > 0:
			bonus += syn["per_level"] * src["level"]

	return base * (1.0 + bonus)

func get_total_chaos_per_second() -> float:
	var total := 0.0
	for id in GameData.DISASTERS:
		total += get_disaster_production(id)
	return total

func get_synergy_text(id: String) -> String:
	var bits: PackedStringArray = []
	for syn in GameData.SYNERGIES:
		if syn["target"] != id:
			continue
		var src: Dictionary = state.disasters[syn["source"]]
		if src["unlocked"] and src["level"] > 0:
			var pct := int(round(syn["per_level"] * src["level"] * 100))
			bits.append("%s %s (+%d%%)" % [GameData.DISASTERS[syn["source"]]["icon"], syn["description"], pct])
	return " · ".join(bits)

func get_global_power() -> int:
	var sum := 0
	for id in state.disasters:
		sum += state.disasters[id]["level"]
	return sum

func count_unlocked_disasters() -> int:
	var count := 0
	for id in state.disasters:
		if state.disasters[id]["unlocked"]:
			count += 1
	return count

## Level-driven, not inferred from unlocked disasters — before levels
## existed, "which tier name to show" had no explicit source of truth of
## its own, so it borrowed the highest-order tier among already-unlocked
## disasters as a stand-in. That heuristic said nothing about *world
## layout* (which is what a tier/level actually changes now — see
## world_scene.gd's _build_level_1()/_build_level_2()), and could in
## principle drift from it. GameData.LEVELS is the direct, single source of
## truth instead — and this reads `viewed_level`, not `level`: the tier
## name shown in the HUD should always match the world actually on screen,
## including while the player is using LevelSelectMenu to look at an
## earlier level than the one they've progressed to.
func get_current_tier_id() -> String:
	return GameData.get_level_def(state.viewed_level).get("tier_id", "village")

func get_current_tier_name() -> String:
	var tier_id := get_current_tier_id()
	if GameData.TIERS.has(tier_id):
		var t: Dictionary = GameData.TIERS[tier_id]
		return "%s %s" % [t["icon"], t["name"]]
	return "Village"

func has_lightning_boost() -> bool:
	for id in GameData.UPGRADE_TREE:
		if GameData.UPGRADE_TREE[id].get("lightning_boost", false) and state.tree[id]["purchased"]:
			return true
	return false

# ---------------------------------------------------------------------------
# Levels & structure destruction
# ---------------------------------------------------------------------------
## Whether `id` (a stable id world_scene.gd assigns each destructible
## structure — see its own header) has permanently reached HouseSprite's
## "ruined" state at least once. Read by world_scene.gd when (re)building a
## level, to instantiate an already-ruined structure straight into that
## state (see HouseSprite.setup()'s start_ruined param) instead of
## replaying a fresh collapse it already went through in an earlier
## session.
func is_structure_ruined(id: String) -> bool:
	return state.ruined_structures.get(id, false)

## Whether the player may select `id` from LevelSelectMenu right now.
func is_level_unlocked(id: int) -> bool:
	return state.unlocked_levels.get(str(id), false)

## Marks `id` selectable from LevelSelectMenu from now on, permanently
## (persisted immediately). Idempotent — safe to call on an already-
## unlocked id. Deliberately never touches `viewed_level`: unlocking a
## level and jumping the camera to it are two different actions (see
## notify_structure_ruined(), which does both together on purpose, versus
## a hypothetical future unlock path that shouldn't yank the player's view
## away from where they are).
func unlock_level(id: int) -> void:
	if is_level_unlocked(id):
		return
	state.unlocked_levels[str(id)] = true
	state_changed.emit()
	save_game()

## Points world_scene.gd's build() at a different already-unlocked level
## without touching progression (`level`, disaster unlocks, objectives) —
## the mechanism behind LevelSelectMenu letting the player revisit any
## level they've already earned, including one they've since moved past.
## Returns false (no-op) for a locked or nonexistent id.
func view_level(id: int) -> bool:
	if not is_level_unlocked(id):
		return false
	if state.viewed_level == id:
		return true
	state.viewed_level = id
	level_changed.emit(state.viewed_level)
	state_changed.emit()
	save_game()
	return true

## Called once by world_scene.gd the instant a structure's HouseSprite
## fires its own `ruined` signal for the first time. `level` is which
## level that structure belongs to and `total_structures` is how many
## destructible structures that level has in total (world_scene.gd's own
## count — see TOTAL_LEVEL_1_STRUCTURES/TOTAL_LEVEL_2_STRUCTURES there;
## deliberately not duplicated as a second source of truth here).
##
## Auto-advances state.level to level+1 (and unlocks it, and points
## viewed_level at it — see unlock_level()/view_level()'s own headers for
## why those are usually two separate actions, joined here on purpose) the
## moment every one of that level's structures has been ruined at some
## point (not necessarily all in the same session — ruined_structures
## accumulates permanently across saves) — but only while `level` is still
## the CURRENT level and a next one actually exists
## (GameData.max_implemented_level()): level 2's own structures already
## call this exactly the same way level 1's do (see world_scene.gd), so the
## mechanism is exercised end-to-end today, but fully ruining level 2 is
## inert until a level 3 layout ships and gets marked implemented — not a
## half-built feature, a deliberately future one.
func notify_structure_ruined(id: String, level: int, total_structures: int) -> void:
	if state.ruined_structures.get(id, false):
		return
	state.ruined_structures[id] = true

	if state.level == level and level < GameData.max_implemented_level():
		var ruined_here := 0
		for ruined_id in state.ruined_structures:
			if str(ruined_id).begins_with("l%d_" % level):
				ruined_here += 1
		if ruined_here >= total_structures:
			state.level = level + 1
			state.viewed_level = state.level
			state.unlocked_levels[str(state.level)] = true
			level_changed.emit(state.viewed_level)
			check_unlocks()

	state_changed.emit()
	save_game()

# ---------------------------------------------------------------------------
# Village scene — visual stage per disaster (the actual drawing belongs
# to a future render layer; this only computes which stage each disaster
# is in, mirroring computeStage()/updateSceneCaption() from script.js)
# ---------------------------------------------------------------------------
func compute_stage(id: String) -> int:
	var cfg: Dictionary = GameData.DISASTERS[id]
	var st: Dictionary = state.disasters[id]
	if not st["unlocked"] or st["level"] <= 0:
		return 0
	return min(cfg["max_visual_stage"], int(ceil(float(st["level"]) / cfg["levels_per_stage"])))

func get_scene_stages() -> Dictionary:
	return {
		"rain": compute_stage("rain"),
		"wind": compute_stage("wind"),
		"storm": compute_stage("storm"),
		"flood": compute_stage("flood"),
	}

## Level 1's own captions are untouched (same conditions, same strings,
## checked before anything level-specific) — this only adds a level 2
## branch on top, read first so a town in the middle of a quake/blight
## isn't described as if it were still the calm village. "ville"
## replaces "village" throughout for the same reason get_current_tier_name
## now says "Petite ville" once viewed_level reaches 2: the caption is the
## other place a player reads the world's own name back.
func get_scene_caption() -> String:
	var stages := get_scene_stages()
	if state.viewed_level >= 2:
		var quake_stage := compute_stage("quake")
		var blight_stage := compute_stage("blight")
		if blight_stage > 0:
			return "Une lueur violette ronge les pierres de la ville..."
		if quake_stage > 1:
			return "Le sol tremble et lézarde les rues de la ville."
		if quake_stage >= 1:
			return "De légères secousses courent sous la ville."
		if stages["storm"] > 0:
			return "Un orage gronde au-dessus de la ville !"
		if stages["wind"] > 1:
			return "Le vent forcit et agite toute la ville."
		if stages["rain"] >= 3:
			return "Une pluie battante s'abat sur la ville."
		if stages["rain"] >= 1:
			return "Une pluie légère tombe sur la ville."
		return "Bienvenue dans la petite ville — le village n'est plus qu'un souvenir."

	if stages["storm"] > 0:
		return "Un orage gronde au-dessus du village !"
	if stages["flood"] > 0:
		return "La rivière déborde légèrement sur la berge..."
	if stages["wind"] > 1:
		return "Le vent forcit et agite tout le village."
	if stages["rain"] >= 3:
		return "Une pluie battante s'abat sur le village."
	if stages["rain"] >= 1:
		return "Une pluie légère tombe sur le village."
	if stages["wind"] >= 1:
		return "Une brise agréable souffle sur le village."
	return "Un village paisible... pour l'instant."

# ---------------------------------------------------------------------------
# Economy — KO & the Chaos Tree
# ---------------------------------------------------------------------------
func get_total_ko() -> int:
	var from_chaos := int(floor(state.total_chaos_earned / GameData.KO_FROM_CHAOS_DIVISOR))
	var completed_objectives := 0
	for id in state.objectives:
		if state.objectives[id]["completed"]:
			completed_objectives += 1
	var from_objectives := completed_objectives * GameData.KO_PER_OBJECTIVE
	var from_unlocks := count_unlocked_disasters() * GameData.KO_PER_UNLOCK
	return from_chaos + from_objectives + from_unlocks

func get_spent_ko() -> int:
	var spent := 0
	for id in GameData.UPGRADE_TREE:
		var node: Dictionary = GameData.UPGRADE_TREE[id]
		if not node.get("auto_owned", false) and state.tree[id]["purchased"]:
			spent += node["cost"]
	return spent

func get_available_ko() -> int:
	return get_total_ko() - get_spent_ko()

## 'purchased' | 'available' | 'locked-requires' | 'locked-disaster' | 'coming-soon'
func get_tree_node_state(id: String) -> String:
	var node: Dictionary = GameData.UPGRADE_TREE[id]
	var st: Dictionary = state.tree[id]
	if st["purchased"]:
		return "purchased"
	if node.get("coming_soon", false):
		return "coming-soon"
	for req_id in node["requires"]:
		if not state.tree[req_id]["purchased"]:
			return "locked-requires"
	var req_disaster: String = node.get("requires_disaster", "")
	if req_disaster != "" and not state.disasters[req_disaster]["unlocked"]:
		return "locked-disaster"
	return "available"

func describe_tree_node_lock(id: String) -> String:
	var node: Dictionary = GameData.UPGRADE_TREE[id]
	var node_state := get_tree_node_state(id)
	if node_state == "purchased":
		return "✅ Acquis"
	if node_state == "coming-soon":
		return "🔒 Bientôt disponible (future mise à jour)"
	if node_state == "locked-requires":
		var missing: PackedStringArray = []
		for req_id in node["requires"]:
			if not state.tree[req_id]["purchased"]:
				missing.append(GameData.UPGRADE_TREE[req_id]["name"])
		return "🔒 Débloque d'abord : %s" % ", ".join(missing)
	if node_state == "locked-disaster":
		var req: Dictionary = GameData.DISASTERS[node["requires_disaster"]]
		return "🔒 Débloque d'abord la catastrophe %s %s" % [req["icon"], req["name"]]
	var available := get_available_ko()
	if available >= node["cost"]:
		return "Disponible — %d KO" % node["cost"]
	return "Il te manque %d KO" % (node["cost"] - available)

func purchase_tree_node(id: String) -> bool:
	if not GameData.UPGRADE_TREE.has(id):
		return false
	var node: Dictionary = GameData.UPGRADE_TREE[id]
	if node.get("auto_owned", false):
		return false
	if get_tree_node_state(id) != "available":
		return false
	if get_available_ko() < node["cost"]:
		return false

	state.tree[id]["purchased"] = true
	tree_node_purchased.emit(id)
	state_changed.emit()
	save_game()
	return true

# ---------------------------------------------------------------------------
# Purchases — disasters
# ---------------------------------------------------------------------------
func purchase_disaster(id: String) -> bool:
	if not state.disasters.has(id):
		return false
	var st: Dictionary = state.disasters[id]
	if not st["unlocked"]:
		return false
	if st["level"] >= GameData.MAX_DISASTER_LEVEL:
		return false
	var cost := get_disaster_cost(id)
	if state.chaos < cost:
		return false
	state.chaos -= cost
	st["level"] += 1
	update_objectives()
	state_changed.emit()
	save_game()
	return true

# ---------------------------------------------------------------------------
# Unlocks & objectives
# ---------------------------------------------------------------------------
func check_unlocks() -> bool:
	var changed := false
	for id in GameData.DISASTERS:
		var st: Dictionary = state.disasters[id]
		if st["unlocked"]:
			continue
		if meets_unlock_condition(GameData.DISASTERS[id]["unlock"]):
			st["unlocked"] = true
			changed = true
			disaster_unlocked.emit(id)
	if changed:
		state_changed.emit()
		save_game()
	return changed

func evaluate_objective_condition(cond: Dictionary) -> bool:
	match cond["kind"]:
		"total_chaos_earned_gte":
			return state.total_chaos_earned >= cond["value"]
		"disaster_level_gte":
			return state.disasters[cond["disaster"]]["level"] >= cond["value"]
		"disaster_unlocked":
			return state.disasters[cond["disaster"]]["unlocked"]
		"level_gte":
			return state.level >= cond["value"]
		_:
			return false

# Objectives have no UI of their own (removed from the original's HUD
# too), but completion is still tracked silently — it remains one of the
# inputs to the KO total.
func update_objectives() -> bool:
	var changed := false
	for obj in GameData.OBJECTIVES:
		var st: Dictionary = state.objectives[obj["id"]]
		if not st["completed"] and evaluate_objective_condition(obj["condition"]):
			st["completed"] = true
			changed = true
	if changed:
		state_changed.emit()
		save_game()
	return changed

# ---------------------------------------------------------------------------
# Game loop & offline progress
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	var cps := get_total_chaos_per_second()
	var gained := cps * dt
	state.chaos += gained
	state.total_chaos_earned += gained

	check_unlocks()
	update_objectives()
	state_changed.emit()

func apply_offline_progress() -> void:
	var now := Time.get_unix_time_from_system()
	var last: float = state.last_save_time if state.last_save_time > 0 else now
	var elapsed_sec: float = now - last
	if elapsed_sec < GameData.MIN_OFFLINE_SECONDS_TO_NOTIFY:
		return

	elapsed_sec = min(elapsed_sec, float(GameData.MAX_OFFLINE_SECONDS))
	var cps := get_total_chaos_per_second()
	var gained: float = cps * elapsed_sec * GameData.OFFLINE_EFFICIENCY
	if gained < 1.0:
		return

	state.chaos += gained
	state.total_chaos_earned += gained
	offline_progress_applied.emit(elapsed_sec, gained)
	state_changed.emit()
