class_name PowerConfigManager
extends RefCounted

# Configuration file path
const CONFIG_FILE_PATH = "res://power_system_config.json"
const USER_CONFIG_PATH = "user://power_system_config.json"

# Configuration data
var config_data: Dictionary = {}
var is_loaded: bool = false

# Debug and runtime settings
var debug_mode: bool = false
var system_enabled: bool = true
var runtime_overrides: Dictionary = {}

# Signals for configuration changes
signal config_changed(section: String, key: String, value)
signal debug_mode_changed(enabled: bool)
signal system_enabled_changed(enabled: bool)

func _init():
	load_configuration()

func load_configuration() -> bool:
	"""Load configuration from file with fallback to defaults"""
	var config_file: FileAccess
	
	# Try to load user config first, then default config
	if FileAccess.file_exists(USER_CONFIG_PATH):
		config_file = FileAccess.open(USER_CONFIG_PATH, FileAccess.READ)
		print("[PowerConfigManager] Loading user configuration from: %s" % USER_CONFIG_PATH)
	elif FileAccess.file_exists(CONFIG_FILE_PATH):
		config_file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
		print("[PowerConfigManager] Loading default configuration from: %s" % CONFIG_FILE_PATH)
	else:
		print("[PowerConfigManager] No configuration file found, using defaults")
		_load_default_configuration()
		return false
	
	if not config_file:
		push_error("[PowerConfigManager] Failed to open configuration file")
		_load_default_configuration()
		return false
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[PowerConfigManager] Failed to parse configuration JSON: %s" % json.get_error_message())
		_load_default_configuration()
		return false
	
	config_data = json.data
	_validate_and_apply_configuration()
	is_loaded = true
	
	print("[PowerConfigManager] Configuration loaded successfully")
	return true

func save_configuration() -> bool:
	"""Save current configuration to user config file"""
	var config_file = FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	if not config_file:
		push_error("[PowerConfigManager] Failed to create user configuration file")
		return false
	
	var json_string = JSON.stringify(config_data, "\t")
	config_file.store_string(json_string)
	config_file.close()
	
	print("[PowerConfigManager] Configuration saved to: %s" % USER_CONFIG_PATH)
	return true

func _load_default_configuration():
	"""Load hardcoded default configuration"""
	config_data = {
		"power_system": {
			"enabled": true,
			"debug_mode": false,
			"global_settings": {
				"max_simultaneous_powers": 4,
				"power_egg_timeout": 15.0,
				"warning_threshold": 3.0,
				"collection_points": 200
			},
			"powers": {
				"invincibility": {
					"enabled": true,
					"duration": 10.0,
					"spawn_chance": 0.15,
					"enemy_spawn_rates": {
						"EnemyBase": 0.15,
						"EnemyHunter": 0.20,
						"ShadowLord": 0.25
					},
					"effects": {
						"player_glow": true,
						"screen_tint": {
							"r": 0.8,
							"g": 0.8,
							"b": 1.0,
							"a": 0.3
						},
						"particle_effect": "invincibility_sparkles",
						"overlay_animation": "invincibility_overlay"
					},
					"audio": {
						"collection": "power_collect_invincibility",
						"activation": "invincibility_start",
						"ambient": "invincibility_loop",
						"warning": "power_expire_warning",
						"expiration": "power_expire",
						"volume_levels": {
							"spawn": -5.0,
							"activation": 0.0,
							"ambient": -15.0,
							"warning": -3.0,
							"expiration": -8.0
						},
						"pitch_scales": {
							"activation": 1.5,
							"ambient": 0.8,
							"warning": 2.0,
							"expiration": 0.7
						}
					},
					"gameplay": {
						"invulnerable": true,
						"defeat_on_contact": true,
						"bonus_score_multiplier": 1.5,
						"movement_speed_multiplier": 1.0
					}
				}
			},
			"debug": {
				"show_spawn_visualization": false,
				"log_power_events": true,
				"show_power_timers": false,
				"force_spawn_rate": -1.0,
				"test_mode_duration": -1.0,
				"enable_dev_tools": false
			}
		}
	}
	_validate_and_apply_configuration()

func _validate_and_apply_configuration():
	"""Validate configuration and apply settings"""
	if not config_data.has("power_system"):
		push_error("[PowerConfigManager] Invalid configuration: missing power_system section")
		return
	
	var power_system = config_data.power_system
	
	# Apply global settings
	system_enabled = power_system.get("enabled", true)
	debug_mode = power_system.get("debug_mode", false)
	
	# Validate power configurations
	if power_system.has("powers"):
		for power_name in power_system.powers.keys():
			_validate_power_config(power_name, power_system.powers[power_name])
	
	print("[PowerConfigManager] Configuration validated and applied")

func _validate_power_config(power_name: String, power_config: Dictionary):
	"""Validate individual power configuration"""
	var required_fields = ["enabled", "duration", "spawn_chance"]
	
	for field in required_fields:
		if not power_config.has(field):
			push_warning("[PowerConfigManager] Power '%s' missing required field: %s" % [power_name, field])
	
	# Clamp values to valid ranges
	if power_config.has("duration"):
		power_config.duration = max(0.1, power_config.duration)
	
	if power_config.has("spawn_chance"):
		power_config.spawn_chance = clamp(power_config.spawn_chance, 0.0, 1.0)
	
	if power_config.has("enemy_spawn_rates"):
		for enemy_type in power_config.enemy_spawn_rates.keys():
			power_config.enemy_spawn_rates[enemy_type] = clamp(power_config.enemy_spawn_rates[enemy_type], 0.0, 1.0)

# Configuration Access Methods

func is_system_enabled() -> bool:
	"""Check if power system is enabled"""
	return system_enabled and config_data.get("power_system", {}).get("enabled", true)

func is_debug_mode() -> bool:
	"""Check if debug mode is enabled"""
	return debug_mode or config_data.get("power_system", {}).get("debug_mode", false)

func get_global_setting(key: String, default_value = null):
	"""Get global power system setting"""
	var global_settings = config_data.get("power_system", {}).get("global_settings", {})
	return global_settings.get(key, default_value)

func get_power_config(power_name: String) -> Dictionary:
	"""Get configuration for specific power"""
	var powers = config_data.get("power_system", {}).get("powers", {})
	return powers.get(power_name, {})

func get_debug_setting(key: String, default_value = null):
	"""Get debug configuration setting"""
	var debug_settings = config_data.get("power_system", {}).get("debug", {})
	return debug_settings.get(key, default_value)

func is_power_enabled(power_name: String) -> bool:
	"""Check if specific power is enabled"""
	var power_config = get_power_config(power_name)
	return power_config.get("enabled", false)

func get_power_duration(power_name: String) -> float:
	"""Get power duration"""
	var power_config = get_power_config(power_name)
	return power_config.get("duration", 10.0)

func get_spawn_chance(power_name: String) -> float:
	"""Get power spawn chance"""
	var power_config = get_power_config(power_name)
	return power_config.get("spawn_chance", 0.15)

func get_enemy_spawn_rate(power_name: String, enemy_type: String) -> float:
	"""Get spawn rate for specific enemy type"""
	var power_config = get_power_config(power_name)
	var enemy_rates = power_config.get("enemy_spawn_rates", {})
	return enemy_rates.get(enemy_type, get_spawn_chance(power_name))

func get_audio_config(power_name: String) -> Dictionary:
	"""Get audio configuration for power"""
	var power_config = get_power_config(power_name)
	return power_config.get("audio", {})

func get_effects_config(power_name: String) -> Dictionary:
	"""Get effects configuration for power"""
	var power_config = get_power_config(power_name)
	return power_config.get("effects", {})

func get_gameplay_config(power_name: String) -> Dictionary:
	"""Get gameplay configuration for power"""
	var power_config = get_power_config(power_name)
	return power_config.get("gameplay", {})

# Runtime Configuration Methods

func set_system_enabled(enabled: bool):
	"""Enable/disable power system at runtime"""
	system_enabled = enabled
	if config_data.has("power_system"):
		config_data.power_system.enabled = enabled
	emit_signal("system_enabled_changed", enabled)
	print("[PowerConfigManager] Power system %s" % ("enabled" if enabled else "disabled"))

func set_debug_mode(enabled: bool):
	"""Enable/disable debug mode at runtime"""
	debug_mode = enabled
	if config_data.has("power_system"):
		config_data.power_system.debug_mode = enabled
	emit_signal("debug_mode_changed", enabled)
	print("[PowerConfigManager] Debug mode %s" % ("enabled" if enabled else "disabled"))

func set_power_duration(power_name: String, duration: float):
	"""Set power duration at runtime"""
	var power_config = get_power_config(power_name)
	if power_config.size() > 0:
		power_config.duration = max(0.1, duration)
		runtime_overrides[power_name + "_duration"] = duration
		emit_signal("config_changed", "powers." + power_name, "duration", duration)
		print("[PowerConfigManager] Set %s duration to %.1fs" % [power_name, duration])

func set_spawn_chance(power_name: String, chance: float):
	"""Set spawn chance at runtime"""
	var power_config = get_power_config(power_name)
	if power_config.size() > 0:
		power_config.spawn_chance = clamp(chance, 0.0, 1.0)
		runtime_overrides[power_name + "_spawn_chance"] = chance
		emit_signal("config_changed", "powers." + power_name, "spawn_chance", chance)
		print("[PowerConfigManager] Set %s spawn chance to %.1f%%" % [power_name, chance * 100])

func set_enemy_spawn_rate(power_name: String, enemy_type: String, rate: float):
	"""Set enemy-specific spawn rate at runtime"""
	var power_config = get_power_config(power_name)
	if power_config.size() > 0:
		if not power_config.has("enemy_spawn_rates"):
			power_config.enemy_spawn_rates = {}
		power_config.enemy_spawn_rates[enemy_type] = clamp(rate, 0.0, 1.0)
		runtime_overrides[power_name + "_" + enemy_type + "_rate"] = rate
		emit_signal("config_changed", "powers." + power_name + ".enemy_spawn_rates", enemy_type, rate)
		print("[PowerConfigManager] Set %s spawn rate for %s to %.1f%%" % [power_name, enemy_type, rate * 100])

func reset_runtime_overrides():
	"""Reset all runtime configuration overrides"""
	runtime_overrides.clear()
	load_configuration()  # Reload from file
	print("[PowerConfigManager] Runtime overrides reset")

# Debug and Testing Methods

func get_debug_info() -> Dictionary:
	"""Get debug information about configuration"""
	return {
		"config_loaded": is_loaded,
		"system_enabled": is_system_enabled(),
		"debug_mode": is_debug_mode(),
		"runtime_overrides": runtime_overrides,
		"config_file_exists": FileAccess.file_exists(CONFIG_FILE_PATH),
		"user_config_exists": FileAccess.file_exists(USER_CONFIG_PATH),
		"power_count": config_data.get("power_system", {}).get("powers", {}).size()
	}

func validate_configuration() -> Array[String]:
	"""Validate configuration and return list of issues"""
	var issues: Array[String] = []
	
	if not config_data.has("power_system"):
		issues.append("Missing power_system section")
		return issues
	
	var power_system = config_data.power_system
	
	# Check required sections
	if not power_system.has("powers"):
		issues.append("Missing powers section")
	
	if not power_system.has("global_settings"):
		issues.append("Missing global_settings section")
	
	# Validate individual powers
	if power_system.has("powers"):
		for power_name in power_system.powers.keys():
			var power_config = power_system.powers[power_name]
			
			if not power_config.has("duration"):
				issues.append("Power '%s' missing duration" % power_name)
			elif power_config.duration <= 0:
				issues.append("Power '%s' has invalid duration: %.1f" % [power_name, power_config.duration])
			
			if not power_config.has("spawn_chance"):
				issues.append("Power '%s' missing spawn_chance" % power_name)
			elif power_config.spawn_chance < 0 or power_config.spawn_chance > 1:
				issues.append("Power '%s' has invalid spawn_chance: %.2f" % [power_name, power_config.spawn_chance])
	
	return issues

func export_configuration() -> String:
	"""Export current configuration as JSON string"""
	return JSON.stringify(config_data, "\t")

func import_configuration(json_string: String) -> bool:
	"""Import configuration from JSON string"""
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[PowerConfigManager] Failed to parse imported JSON: %s" % json.get_error_message())
		return false
	
	config_data = json.data
	_validate_and_apply_configuration()
	
	print("[PowerConfigManager] Configuration imported successfully")
	return true