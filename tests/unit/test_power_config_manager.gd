extends TestBase

# Unit tests for PowerConfigManager
# Tests configuration loading, saving, and runtime parameter adjustment

var config_manager: PowerConfigManager
var test_config_path: String = "user://test_power_config.json"

func _init():
	test_name = "PowerConfigManager Tests"

func setup():
	"""Setup test environment"""
	config_manager = PowerConfigManager.new()
	
	# Clean up any existing test config
	if FileAccess.file_exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)

func teardown():
	"""Clean up test environment"""
	# Clean up test config file
	if FileAccess.file_exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)
	
	config_manager = null

func test_default_configuration_loading():
	"""Test that default configuration loads correctly"""
	assert_true(config_manager != null, "Config manager should be created")
	assert_true(config_manager.is_system_enabled(), "System should be enabled by default")
	assert_false(config_manager.is_debug_mode(), "Debug mode should be disabled by default")
	
	var invincibility_config = config_manager.get_power_config("invincibility")
	assert_true(invincibility_config.size() > 0, "Invincibility config should exist")
	assert_eq(invincibility_config.get("duration", 0.0), 10.0, "Default duration should be 10.0")
	assert_eq(invincibility_config.get("spawn_chance", 0.0), 0.15, "Default spawn chance should be 0.15")

func test_power_configuration_access():
	"""Test power configuration access methods"""
	# Test duration access
	var duration = config_manager.get_power_duration("invincibility")
	assert_eq(duration, 10.0, "Should get correct default duration")
	
	# Test spawn chance access
	var spawn_chance = config_manager.get_spawn_chance("invincibility")
	assert_eq(spawn_chance, 0.15, "Should get correct default spawn chance")
	
	# Test enemy spawn rate access
	var enemy_rate = config_manager.get_enemy_spawn_rate("invincibility", "EnemyBase")
	assert_eq(enemy_rate, 0.15, "Should get correct enemy spawn rate")
	
	# Test non-existent enemy type (should return base spawn chance)
	var unknown_rate = config_manager.get_enemy_spawn_rate("invincibility", "UnknownEnemy")
	assert_eq(unknown_rate, 0.15, "Should return base spawn chance for unknown enemy")

func test_runtime_parameter_adjustment():
	"""Test runtime parameter adjustment"""
	# Test duration adjustment
	config_manager.set_power_duration("invincibility", 15.0)
	var new_duration = config_manager.get_power_duration("invincibility")
	assert_eq(new_duration, 15.0, "Duration should be updated")
	
	# Test spawn chance adjustment
	config_manager.set_spawn_chance("invincibility", 0.25)
	var new_spawn_chance = config_manager.get_spawn_chance("invincibility")
	assert_eq(new_spawn_chance, 0.25, "Spawn chance should be updated")
	
	# Test enemy spawn rate adjustment
	config_manager.set_enemy_spawn_rate("invincibility", "EnemyHunter", 0.35)
	var new_enemy_rate = config_manager.get_enemy_spawn_rate("invincibility", "EnemyHunter")
	assert_eq(new_enemy_rate, 0.35, "Enemy spawn rate should be updated")

func test_system_enable_disable():
	"""Test system enable/disable functionality"""
	# Test disabling system
	config_manager.set_system_enabled(false)
	assert_false(config_manager.is_system_enabled(), "System should be disabled")
	
	# Test re-enabling system
	config_manager.set_system_enabled(true)
	assert_true(config_manager.is_system_enabled(), "System should be enabled")

func test_debug_mode_toggle():
	"""Test debug mode toggle functionality"""
	# Test enabling debug mode
	config_manager.set_debug_mode(true)
	assert_true(config_manager.is_debug_mode(), "Debug mode should be enabled")
	
	# Test disabling debug mode
	config_manager.set_debug_mode(false)
	assert_false(config_manager.is_debug_mode(), "Debug mode should be disabled")

func test_debug_settings_access():
	"""Test debug settings access"""
	var log_events = config_manager.get_debug_setting("log_power_events", false)
	assert_true(log_events is bool, "Should return boolean for log_power_events")
	
	var force_spawn_rate = config_manager.get_debug_setting("force_spawn_rate", -1.0)
	assert_eq(force_spawn_rate, -1.0, "Should return default force spawn rate")
	
	var unknown_setting = config_manager.get_debug_setting("unknown_setting", "default")
	assert_eq(unknown_setting, "default", "Should return default value for unknown setting")

func test_power_enabled_check():
	"""Test power enabled/disabled checking"""
	var is_enabled = config_manager.is_power_enabled("invincibility")
	assert_true(is_enabled, "Invincibility should be enabled by default")
	
	var unknown_enabled = config_manager.is_power_enabled("unknown_power")
	assert_false(unknown_enabled, "Unknown power should be disabled")

func test_configuration_validation():
	"""Test configuration validation"""
	var issues = config_manager.validate_configuration()
	assert_true(issues is Array, "Validation should return array")
	
	# Default configuration should have no issues
	assert_eq(issues.size(), 0, "Default configuration should be valid")

func test_debug_info():
	"""Test debug information retrieval"""
	var debug_info = config_manager.get_debug_info()
	assert_true(debug_info is Dictionary, "Debug info should be dictionary")
	assert_true(debug_info.has("config_loaded"), "Should have config_loaded field")
	assert_true(debug_info.has("system_enabled"), "Should have system_enabled field")
	assert_true(debug_info.has("debug_mode"), "Should have debug_mode field")

func test_configuration_export_import():
	"""Test configuration export and import"""
	# Modify some settings
	config_manager.set_power_duration("invincibility", 12.0)
	config_manager.set_spawn_chance("invincibility", 0.20)
	
	# Export configuration
	var exported_config = config_manager.export_configuration()
	assert_true(exported_config is String, "Export should return string")
	assert_true(exported_config.length() > 0, "Exported config should not be empty")
	
	# Reset to defaults
	config_manager.load_configuration()
	assert_eq(config_manager.get_power_duration("invincibility"), 10.0, "Should reset to default duration")
	
	# Import the exported configuration
	var import_success = config_manager.import_configuration(exported_config)
	assert_true(import_success, "Import should succeed")
	assert_eq(config_manager.get_power_duration("invincibility"), 12.0, "Should restore modified duration")
	assert_eq(config_manager.get_spawn_chance("invincibility"), 0.20, "Should restore modified spawn chance")

func test_invalid_configuration_handling():
	"""Test handling of invalid configuration data"""
	# Test invalid JSON import
	var invalid_json = "{ invalid json }"
	var import_success = config_manager.import_configuration(invalid_json)
	assert_false(import_success, "Invalid JSON import should fail")
	
	# Test setting invalid values (should be clamped)
	config_manager.set_spawn_chance("invincibility", 2.0)  # > 1.0
	var clamped_chance = config_manager.get_spawn_chance("invincibility")
	assert_true(clamped_chance <= 1.0, "Spawn chance should be clamped to 1.0")
	
	config_manager.set_spawn_chance("invincibility", -0.5)  # < 0.0
	var clamped_negative = config_manager.get_spawn_chance("invincibility")
	assert_true(clamped_negative >= 0.0, "Spawn chance should be clamped to 0.0")

func test_runtime_overrides():
	"""Test runtime override tracking"""
	# Make some runtime changes
	config_manager.set_power_duration("invincibility", 8.0)
	config_manager.set_spawn_chance("invincibility", 0.30)
	
	# Check that overrides are tracked
	var debug_info = config_manager.get_debug_info()
	var overrides = debug_info.get("runtime_overrides", {})
	assert_true(overrides.size() > 0, "Should have runtime overrides")
	
	# Reset overrides
	config_manager.reset_runtime_overrides()
	
	# Check that values are reset
	assert_eq(config_manager.get_power_duration("invincibility"), 10.0, "Duration should reset after override reset")
	assert_eq(config_manager.get_spawn_chance("invincibility"), 0.15, "Spawn chance should reset after override reset")

func run_all_tests():
	"""Run all configuration manager tests"""
	print("\n=== PowerConfigManager Tests ===")
	
	var tests = [
		"test_default_configuration_loading",
		"test_power_configuration_access",
		"test_runtime_parameter_adjustment",
		"test_system_enable_disable",
		"test_debug_mode_toggle",
		"test_debug_settings_access",
		"test_power_enabled_check",
		"test_configuration_validation",
		"test_debug_info",
		"test_configuration_export_import",
		"test_invalid_configuration_handling",
		"test_runtime_overrides"
	]
	
	for test_method in tests:
		setup()
		call(test_method)
		teardown()
	
	print_results()