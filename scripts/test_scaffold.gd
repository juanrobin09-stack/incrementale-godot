extends Node
# TEMP TEST HOOK — remove before final commit.
# Functional smoke-test for the GameState autoload (economy/state layer):
# purchases, costs, production, unlocks, objectives, save/load, offline
# progress, reset. Self-checking (OK/FAIL per assertion against exact
# expected values) rather than a raw dump, so a wrong number can't be
# missed by eyeballing the console.

var _pass_count := 0
var _fail_count := 0

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  OK   ", label)
	else:
		_fail_count += 1
		print("  FAIL ", label, "  ", detail)

func _ready() -> void:
	print("=== GameState smoke test ===")

	# --- Fresh state ----------------------------------------------------
	GameState.do_reset()
	_check("rain starts unlocked", GameState.state.disasters["rain"]["unlocked"])
	_check("wind starts locked", not GameState.state.disasters["wind"]["unlocked"])
	_check("core is auto-purchased", GameState.state.tree["core"]["purchased"])
	_check("wind_1 is not purchased", not GameState.state.tree["wind_1"]["purchased"])
	_check("first rain activation is free", GameState.get_disaster_cost("rain") == 0)

	# --- Purchase a disaster ---------------------------------------------
	var bought: bool = GameState.purchase_disaster("rain")
	_check("purchase_disaster(rain) succeeds", bought)
	_check("rain level is now 1", GameState.state.disasters["rain"]["level"] == 1)
	var rain_cost := GameState.get_disaster_cost("rain")
	_check("next rain cost is 10", rain_cost == 10, "got %s" % rain_cost)
	var rain_prod := GameState.get_disaster_production("rain")
	_check("rain production is 1.0", is_equal_approx(rain_prod, 1.0), "got %s" % rain_prod)

	var failed_buy: bool = GameState.purchase_disaster("wind")
	_check("purchase_disaster(wind) fails while locked", not failed_buy)

	# --- Deterministic tick: chaos accrues by exactly cps * dt -----------
	var chaos_before_tick: float = GameState.state.chaos
	var total_before_tick: float = GameState.state.total_chaos_earned
	var cps_before_tick := GameState.get_total_chaos_per_second()
	GameState.tick(1.0)
	_check("tick(1.0) adds cps to chaos", is_equal_approx(GameState.state.chaos, chaos_before_tick + cps_before_tick),
		"chaos=%s expected=%s" % [GameState.state.chaos, chaos_before_tick + cps_before_tick])
	_check("tick(1.0) adds cps to total_chaos_earned", is_equal_approx(GameState.state.total_chaos_earned, total_before_tick + cps_before_tick),
		"total=%s expected=%s" % [GameState.state.total_chaos_earned, total_before_tick + cps_before_tick])

	# --- Drive unlocks & objectives via simulated chaos -------------------
	GameState.state.chaos = 200.0
	GameState.state.total_chaos_earned = 200.0
	GameState.check_unlocks()
	GameState.update_objectives()
	_check("wind unlocks at 150+ total chaos", GameState.state.disasters["wind"]["unlocked"])
	_check("obj_unlock_wind completes", GameState.state.objectives["obj_unlock_wind"]["completed"])
	_check("obj_100_chaos completes", GameState.state.objectives["obj_100_chaos"]["completed"])
	_check("wind_1 becomes available", GameState.get_tree_node_state("wind_1") == "available", GameState.get_tree_node_state("wind_1"))

	# total KO = floor(200/200)=1 [chaos] + 2*3=6 [obj_100_chaos, obj_unlock_wind] + 2*5=10 [rain+wind unlocked] = 17
	var ko_before := GameState.get_available_ko()
	_check("available KO is exactly 17", ko_before == 17, "got %s" % ko_before)

	# --- Purchase a tree node ---------------------------------------------
	var node_bought: bool = GameState.purchase_tree_node("wind_1")
	_check("purchase_tree_node(wind_1) succeeds", node_bought)
	_check("wind_1 is now purchased", GameState.state.tree["wind_1"]["purchased"])
	var ko_after := GameState.get_available_ko()
	_check("available KO decreased by 5 (to 12)", ko_after == 12, "got %s" % ko_after)

	var double_buy: bool = GameState.purchase_tree_node("wind_1")
	_check("re-purchasing wind_1 fails", not double_buy)

	# --- Purchase the newly-unlocked disaster (free activation, then paid) -
	var wind_bought: bool = GameState.purchase_disaster("wind")
	_check("wind first activation is free", wind_bought and GameState.state.chaos == 200.0, "chaos=%s" % GameState.state.chaos)
	_check("wind level is now 1", GameState.state.disasters["wind"]["level"] == 1)
	var wind_cost := GameState.get_disaster_cost("wind")
	_check("wind cost at level 1 is 75", wind_cost == 75, "got %s" % wind_cost)

	var wind_bought_2: bool = GameState.purchase_disaster("wind")
	_check("second wind purchase succeeds and costs chaos", wind_bought_2 and GameState.state.chaos == 125.0, "chaos=%s" % GameState.state.chaos)
	_check("wind level is now 2", GameState.state.disasters["wind"]["level"] == 2)

	var wind_prod := GameState.get_disaster_production("wind")
	# base_production(2.5) * level(2) * (1 + 0.08 from wind_1) = 5.4
	_check("wind production reflects level + wind_1 bonus (5.4)", is_equal_approx(wind_prod, 5.4), "got %s" % wind_prod)
	_check("available KO unaffected by disaster purchases (still 12)", GameState.get_available_ko() == 12, "got %s" % GameState.get_available_ko())

	# --- Save / load round-trip --------------------------------------------
	GameState.save_game()
	var chaos_snapshot: float = GameState.state.chaos
	var total_snapshot: float = GameState.state.total_chaos_earned
	var rain_level_snapshot: int = GameState.state.disasters["rain"]["level"]
	var wind_level_snapshot: int = GameState.state.disasters["wind"]["level"]
	GameState.load_game()
	_check("chaos survives save/load", is_equal_approx(GameState.state.chaos, chaos_snapshot), "got %s" % GameState.state.chaos)
	_check("total_chaos_earned survives save/load", is_equal_approx(GameState.state.total_chaos_earned, total_snapshot), "got %s" % GameState.state.total_chaos_earned)
	_check("rain level survives save/load", GameState.state.disasters["rain"]["level"] == rain_level_snapshot)
	_check("wind level survives save/load", GameState.state.disasters["wind"]["level"] == wind_level_snapshot)
	_check("wind_1 purchase survives save/load", GameState.state.tree["wind_1"]["purchased"])
	_check("obj_unlock_wind completion survives save/load", GameState.state.objectives["obj_unlock_wind"]["completed"])

	# --- Offline progress ---------------------------------------------------
	var chaos_before_noop: float = GameState.state.chaos
	GameState.state.last_save_time = Time.get_unix_time_from_system()
	GameState.apply_offline_progress()
	_check("offline progress no-ops below the notify threshold", is_equal_approx(GameState.state.chaos, chaos_before_noop),
		"chaos changed to %s" % GameState.state.chaos)

	var chaos_before_offline: float = GameState.state.chaos
	var total_before_offline: float = GameState.state.total_chaos_earned
	var cps_offline := GameState.get_total_chaos_per_second()
	GameState.state.last_save_time = Time.get_unix_time_from_system() - 3600.0
	GameState.apply_offline_progress()
	var expected_gain: float = cps_offline * 3600.0 * GameData.OFFLINE_EFFICIENCY
	_check("1h offline gain matches cps * elapsed * efficiency", is_equal_approx(GameState.state.chaos, chaos_before_offline + expected_gain),
		"chaos=%s expected=%s" % [GameState.state.chaos, chaos_before_offline + expected_gain])
	_check("offline gain also adds to total_chaos_earned", is_equal_approx(GameState.state.total_chaos_earned, total_before_offline + expected_gain),
		"total=%s expected=%s" % [GameState.state.total_chaos_earned, total_before_offline + expected_gain])

	# --- Reset ----------------------------------------------------------
	GameState.do_reset()
	_check("reset clears rain level", GameState.state.disasters["rain"]["level"] == 0)
	_check("reset clears wind level", GameState.state.disasters["wind"]["level"] == 0)
	_check("reset clears wind unlocked flag", not GameState.state.disasters["wind"]["unlocked"])
	_check("reset clears wind_1 purchase", not GameState.state.tree["wind_1"]["purchased"])
	_check("reset keeps core auto-purchased", GameState.state.tree["core"]["purchased"])
	_check("reset clears chaos", GameState.state.chaos == 0.0)
	_check("reset clears objectives", not GameState.state.objectives["obj_100_chaos"]["completed"])
	_check("reset also clears the save file", not FileAccess.file_exists(GameState.SAVE_PATH))

	print("=== smoke test done: ", _pass_count, " OK, ", _fail_count, " FAIL ===")
	if _fail_count == 0:
		print("=== ALL GREEN — economy/state layer is good ===")
	else:
		print("=== FAILURES ABOVE — do not consider this layer verified ===")
