class_name PowerDevTools
extends RefCounted

# Developer tools for power system testing and balancing
# This class provides utilities for runtime parameter adjustment and testing

var power_manager: Node
var config_manager

func _init(pm: Node = null):
	power_manager = pm
	if power_manager and power_manager.has_method("get_configuration_manager"):
		config_manager = power_manager.get_configuration_manager()

# Quick Configuration Presets

func apply_testing_preset():
	"""Apply configuration preset optimized for testing"""
	if not config_manager:
		return false
	
	print("[PowerDevTools] Applying testing preset...")
	
	# Faster testing parameters
	config_manager.set_power_duration("invincibility", 5.0)  # Shorter duration for quick testing
	config_manager.set_spawn_chance("invincibility", 0.5)    # Higher spawn rate for testing
	
	# Set debug settings
	var debug_config = config_manager.config_data.get("power_system", {}).get("debug", {})
	debug_config["force_spawn_rate"] = 0.5
	debug_config["test_mode_duration"] = 5.0
	debug_config["show_spawn_visualization"] = true
	debug_config["show_power_timers"] = true
	
	print("[PowerDevTools] Testing preset applied")
	return true

func apply_balanced_preset():
	"""Apply balanced configuration preset for normal gameplay"""
	if not config_manager:
		return false
	
	print("[PowerDevTools] Applying balanced preset...")
	
	# Balanced parameters
	config_manager.set_power_duration("invincibility", 10.0)
	config_manager.set_spawn_chance("invincibility", 0.15)
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyBase", 0.15)
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyHunter", 0.20)
	config_manager.set_enemy_spawn_rate("invincibility", "ShadowLord", 0.25)
	
	# Reset debug settings
	var debug_config = config_manager.config_data.get("power_system", {}).get("debug", {})
	debug_config["force_spawn_rate"] = -1.0
	debug_config["test_mode_duration"] = -1.0
	debug_config["show_spawn_visualization"] = false
	debug_config["show_power_timers"] = false
	
	print("[PowerDevTools] Balanced preset applied")
	return true

func apply_rare_preset():
	"""Apply configuration preset with rare power spawns"""
	if not config_manager:
		return false
	
	print("[PowerDevTools] Applying rare preset...")
	
	# Rare spawn parameters
	config_manager.set_power_duration("invincibility", 15.0)  # Longer duration since rare
	config_manager.set_spawn_chance("invincibility", 0.05)    # Very rare spawns
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyBase", 0.05)
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyHunter", 0.08)
	config_manager.set_enemy_spawn_rate("invincibility", "ShadowLord", 0.12)
	
	print("[PowerDevTools] Rare preset applied")
	return true

func apply_frequent_preset():
	"""Apply configuration preset with frequent power spawns"""
	if not config_manager:
		return false
	
	print("[PowerDevTools] Applying frequent preset...")
	
	# Frequent spawn parameters
	config_manager.set_power_duration("invincibility", 8.0)   # Shorter duration since frequent
	config_manager.set_spawn_chance("invincibility", 0.30)    # Frequent spawns
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyBase", 0.30)
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyHunter", 0.35)
	config_manager.set_enemy_spawn_rate("invincibility", "ShadowLord", 0.40)
	
	print("[PowerDevTools] Frequent preset applied")
	return true

# Testing Utilities

func run_spawn_rate_test(iterations: int = 1000) -> Dictionary:
	"""Run spawn rate test to verify configuration accuracy"""
	if not power_manager:
		return {}
	
	print("[PowerDevTools] Running spawn rate test with %d iterations..." % iterations)
	
	var results = {
		"total_attempts": iterations,
		"successful_spawns": 0,
		"enemy_results": {}
	}
	
	var enemy_types = ["EnemyBase", "EnemyHunter", "ShadowLord"]
	
	for enemy_type in enemy_types:
		results.enemy_results[enemy_type] = {
			"attempts": 0,
			"spawns": 0,
			"rate": 0.0
		}
	
	# Run test iterations
	for i in iterations:
		var enemy_type = enemy_types[i % enemy_types.size()]
		results.enemy_results[enemy_type].attempts += 1
		
		if power_manager.should_spawn_power_egg(enemy_type):
			results.successful_spawns += 1
			results.enemy_results[enemy_type].spawns += 1
	
	# Calculate rates
	results["overall_rate"] = float(results.successful_spawns) / float(iterations)
	
	for enemy_type in enemy_types:
		var enemy_data = results.enemy_results[enemy_type]
		if enemy_data.attempts > 0:
			enemy_data.rate = float(enemy_data.spawns) / float(enemy_data.attempts)
	
	print("[PowerDevTools] Spawn rate test completed:")
	print("  Overall rate: %.2f%%" % (results.overall_rate * 100))
	for enemy_type in enemy_types:
		var rate = results.enemy_results[enemy_type].rate * 100
		print("  %s rate: %.2f%%" % [enemy_type, rate])
	
	return results

func test_power_duration_accuracy(player_index: int = 1) -> Dictionary:
	"""Test power duration accuracy"""
	if not power_manager:
		return {}
	
	print("[PowerDevTools] Testing power duration accuracy for player %d..." % player_index)
	
	var start_time = Time.get_time_dict_from_system().unix
	var expected_duration = config_manager.get_power_duration("invincibility") if config_manager else 10.0
	
	# Activate power
	var success = power_manager.activate_power(player_index, 0)  # INVINCIBILITY = 0
	if not success:
		return {"error": "Failed to activate power"}
	
	# Wait for power to expire (this would need to be called periodically)
	var result = {
		"expected_duration": expected_duration,
		"start_time": start_time,
		"player_index": player_index,
		"activated": true
	}
	
	print("[PowerDevTools] Power duration test started (expected: %.1fs)" % expected_duration)
	return result

func force_spawn_power_eggs(count: int = 5, spread_radius: float = 200.0):
	"""Force spawn multiple power eggs for testing"""
	if not power_manager:
		return
	
	print("[PowerDevTools] Force spawning %d power eggs..." % count)
	
	var power_egg_scene = power_manager.get_power_egg_scene()
	if not power_egg_scene:
		print("[PowerDevTools] Failed to get power egg scene")
		return
	
	var current_scene = power_manager.get_tree().current_scene
	if not current_scene:
		print("[PowerDevTools] No current scene available")
		return
	
	var center_position = Vector2(400, 300)  # Default center position
	
	for i in count:
		var power_egg = power_egg_scene.instantiate()
		
		# Position eggs in a circle around center
		var angle = (float(i) / float(count)) * 2.0 * PI
		var offset = Vector2(cos(angle), sin(angle)) * spread_radius
		power_egg.global_position = center_position + offset
		
		current_scene.add_child(power_egg)
	
	print("[PowerDevTools] Spawned %d power eggs" % count)

func activate_power_for_all_players(power_type: int = 0):
	"""Activate specified power for all players"""
	if not power_manager:
		return
	
	print("[PowerDevTools] Activating power %d for all players..." % power_type)
	
	var activated_count = 0
	for player_index in range(1, 5):  # Players 1-4
		if power_manager.activate_power(player_index, power_type):
			activated_count += 1
	
	print("[PowerDevTools] Activated power for %d players" % activated_count)

func deactivate_all_powers():
	"""Deactivate all active powers"""
	if not power_manager:
		return
	
	print("[PowerDevTools] Deactivating all powers...")
	power_manager.reset_all_powers()

# Configuration Analysis

func analyze_balance() -> Dictionary:
	"""Analyze current configuration balance"""
	if not config_manager:
		return {}
	
	var analysis = {
		"balance_score": 0.0,
		"recommendations": [],
		"warnings": [],
		"power_analysis": {}
	}
	
	# Analyze invincibility power
	var invincibility_config = config_manager.get_power_config("invincibility")
	if invincibility_config.size() > 0:
		var power_analysis = {
			"duration": invincibility_config.get("duration", 10.0),
			"spawn_chance": invincibility_config.get("spawn_chance", 0.15),
			"balance_rating": "unknown"
		}
		
		var duration = power_analysis.duration
		var spawn_chance = power_analysis.spawn_chance
		
		# Analyze balance
		if duration > 15.0 and spawn_chance > 0.2:
			power_analysis.balance_rating = "overpowered"
			analysis.warnings.append("Invincibility may be overpowered (long duration + high spawn rate)")
		elif duration < 5.0 and spawn_chance < 0.1:
			power_analysis.balance_rating = "underpowered"
			analysis.warnings.append("Invincibility may be underpowered (short duration + low spawn rate)")
		else:
			power_analysis.balance_rating = "balanced"
		
		# Generate recommendations
		if duration > 20.0:
			analysis.recommendations.append("Consider reducing invincibility duration (currently %.1fs)" % duration)
		elif duration < 3.0:
			analysis.recommendations.append("Consider increasing invincibility duration (currently %.1fs)" % duration)
		
		if spawn_chance > 0.4:
			analysis.recommendations.append("Consider reducing spawn chance (currently %.1f%%)" % (spawn_chance * 100))
		elif spawn_chance < 0.05:
			analysis.recommendations.append("Consider increasing spawn chance (currently %.1f%%)" % (spawn_chance * 100))
		
		analysis.power_analysis["invincibility"] = power_analysis
	
	# Calculate overall balance score (0-100)
	var balance_factors = []
	if analysis.power_analysis.has("invincibility"):
		var inv_analysis = analysis.power_analysis.invincibility
		match inv_analysis.balance_rating:
			"balanced":
				balance_factors.append(80.0)
			"overpowered", "underpowered":
				balance_factors.append(40.0)
			_:
				balance_factors.append(60.0)
	
	if balance_factors.size() > 0:
		analysis.balance_score = balance_factors.reduce(func(a, b): return a + b) / balance_factors.size()
	
	return analysis

func export_configuration_report() -> String:
	"""Export detailed configuration report"""
	if not config_manager:
		return "Configuration manager not available"
	
	var report = "# Power System Configuration Report\n\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	
	# System status
	report += "## System Status\n"
	report += "- System Enabled: %s\n" % config_manager.is_system_enabled()
	report += "- Debug Mode: %s\n" % config_manager.is_debug_mode()
	report += "\n"
	
	# Power configurations
	report += "## Power Configurations\n\n"
	
	var invincibility_config = config_manager.get_power_config("invincibility")
	if invincibility_config.size() > 0:
		report += "### Invincibility Power\n"
		report += "- Enabled: %s\n" % invincibility_config.get("enabled", false)
		report += "- Duration: %.1f seconds\n" % invincibility_config.get("duration", 10.0)
		report += "- Spawn Chance: %.1f%%\n" % (invincibility_config.get("spawn_chance", 0.15) * 100)
		
		var enemy_rates = invincibility_config.get("enemy_spawn_rates", {})
		if enemy_rates.size() > 0:
			report += "- Enemy Spawn Rates:\n"
			for enemy_type in enemy_rates.keys():
				report += "  - %s: %.1f%%\n" % [enemy_type, enemy_rates[enemy_type] * 100]
		report += "\n"
	
	# Balance analysis
	var balance_analysis = analyze_balance()
	if balance_analysis.size() > 0:
		report += "## Balance Analysis\n"
		report += "- Balance Score: %.1f/100\n" % balance_analysis.get("balance_score", 0.0)
		
		var warnings = balance_analysis.get("warnings", [])
		if warnings.size() > 0:
			report += "- Warnings:\n"
			for warning in warnings:
				report += "  - %s\n" % warning
		
		var recommendations = balance_analysis.get("recommendations", [])
		if recommendations.size() > 0:
			report += "- Recommendations:\n"
			for recommendation in recommendations:
				report += "  - %s\n" % recommendation
		report += "\n"
	
	# Debug settings
	report += "## Debug Settings\n"
	var debug_settings = ["show_spawn_visualization", "log_power_events", "show_power_timers", "force_spawn_rate", "test_mode_duration"]
	for setting in debug_settings:
		var value = config_manager.get_debug_setting(setting, "not set")
		report += "- %s: %s\n" % [setting, str(value)]
	
	return report

# Utility Methods

func get_available_presets() -> Array[String]:
	"""Get list of available configuration presets"""
	return ["testing", "balanced", "rare", "frequent"]

func get_dev_tools_info() -> Dictionary:
	"""Get information about available dev tools"""
	return {
		"presets": get_available_presets(),
		"test_methods": ["spawn_rate_test", "duration_accuracy_test"],
		"spawn_methods": ["force_spawn_power_eggs", "activate_power_for_all_players"],
		"analysis_methods": ["analyze_balance", "export_configuration_report"],
		"power_manager_available": power_manager != null,
		"config_manager_available": config_manager != null
	}