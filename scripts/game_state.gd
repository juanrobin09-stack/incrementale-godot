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

const SAVE_PATH := "user://incrementable_save_v1.json"

var state: Dictionary = {}

var _tick_accumulator := 0.0
var _autosave_accumulator := 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	load_game()
	apply_offline_progress()

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
		"settings": {"sound_enabled": false},
		"last_save_time": Time.get_unix_time_from_system(),
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

	state = merged

func save_game() -> void:
	state.last_save_time = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))
		f.close()

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

func get_current_tier_id() -> String:
	var best_id := "village"
	var best_order := -1
	for id in GameData.DISASTERS:
		if not state.disasters[id]["unlocked"]:
			continue
		var tier_id: String = GameData.DISASTERS[id]["tier"]
		var order: int = GameData.TIERS[tier_id]["order"] if GameData.TIERS.has(tier_id) else 0
		if order >= best_order:
			best_order = order
			best_id = tier_id
	return best_id

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
