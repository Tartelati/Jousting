extends TestBase

# Integration test for power configuration system
# Tests the complete configuration and balancing system integration

var power_manager: Node
var config_manager
var original_config: Dictionary

func _init():
	test_name = "Power Configuration Integration Tests"

func setup():
	"""Setup test environment"""
	# Find or create PowerManager
	power_manager = get_node_or_null("/root/PowerManager")
	if not power_manager:
		# Create a minimal PowerManager for testing
		power_manager = Node.new()
		power_manager.name = "PowerManager"
		get_tree().root.add_child(power_manager)
		
		# Add the PowerManager script
		var PowerManagerScript = preload("res://scripts/managers/power_manager.gd")
		power_manager.set_script(PowerManagerScript)
		power_manager._ready()
	
	# Get config manager
	if power_manager.has_method("get_configuration_manager"):
		config_manager = power_manager.get_configuration_manager()
	
	# Store original configuration
	if config_manager:
		original_config = config_manager.config_data.duplicate(true)

func teardown():
	"""Clean up test environment"""
	# Restore original configuration
	if config_manager and original_config.size() > 0:
		config_manager.config_data = original_config.duplicate(true)
		config_manager._validate_and_apply_configuration()

func test_configuration_manager_integration():
	"""Test that PowerManager properly integrates with configuration manager"""
	assert_true(power_manager != null, "PowerManager should exist")
	assert_true(config_manager != null, "Configuration manager should be available")
	assert_true(config_manager.is_loaded, "Configuration should be loaded")

func test_system_enable_disable_integration():
	"""Test system enable/disable affects PowerManager behavior"""
	# Test system enabled
	config_manager.set_system_enabled(true)
	assert_true(config_manager.is_system_enabled(), "System should be enabled")
	
	# Test spawn behavior when enabled
	var should_spawn = power_manager.should_spawn_power_egg("EnemyBase")
	assert_true(should_spawn is bool, "Should return boolean when system enabled")
	
	# Test system disabled
	config_manager.set_system_enabled(false)
	assert_false(config_manager.is_system_enabled(), "System should be disabled")
	
	# Test spawn behavior when disabled
	var should_not_spawn = power_manager.should_spawn_power_egg("EnemyBase")
	assert_false(should_not_spawn, "Should not spawn when system disabled")
	
	# Re-enable for other tests
	config_manager.set_system_enabled(true)

func test_runtime_parameter_changes():
	"""Test that runtime parameter changes affect PowerManager behavior"""
	# Change duration
	var original_duration = config_manager.get_power_duration("invincibility")
	config_manager.set_power_duration("invincibility", 15.0)
	
	# Verify change is reflected
	var new_duration = config_manager.get_power_duration("invincibility")
	assert_eq(new_duration, 15.0, "Duration should be updated")
	
	# Change spawn chance
	var original_spawn_chance = config_manager.get_spawn_chance("invincibility")
	config_manager.set_spawn_chance("invincibility", 0.5)
	
	# Verify change is reflected
	var new_spawn_chance = config_manager.get_spawn_chance("invincibility")
	assert_eq(new_spawn_chance, 0.5, "Spawn chance should be updated")
	
	# Test that PowerManager uses new values
	var enemy_rate = config_manager.get_enemy_spawn_rate("invincibility", "EnemyBase")
	assert_eq(enemy_rate, 0.5, "Enemy spawn rate should use new base spawn chance")

func test_debug_mode_integration():
	"""Test debug mode integration"""
	# Enable debug mode
	config_manager.set_debug_mode(true)
	assert_true(config_manager.is_debug_mode(), "Debug mode should be enabled")
	
	# Test force spawn rate
	var debug_config = config_manager.config_data.get("power_system", {}).get("debug", {})
	debug_config["force_spawn_rate"] = 1.0  # Always spawn
	
	# Test that PowerManager respects force spawn rate
	var should_always_spawn = power_manager.should_spawn_power_egg("EnemyBase")
	assert_true(should_always_spawn, "Should always spawn with force rate 1.0")
	
	# Reset force spawn rate
	debug_config["force_spawn_rate"] = -1.0
	
	# Disable debug mode
	config_manager.set_debug_mode(false)
	assert_false(config_manager.is_debug_mode(), "Debug mode should be disabled")

func test_power_activation_with_config():
	"""Test power activation uses configuration values"""
	# Set a specific duration
	config_manager.set_power_duration("invincibility", 8.0)
	
	# Activate power for player 1
	var success = power_manager.activate_power(1, 0)  # INVINCIBILITY = 0
	assert_true(success, "Power activation should succeed")
	
	# Check that power is active
	assert_true(power_manager.is_power_active(1), "Power should be active for player 1")
	
	# Check remaining duration is approximately correct
	var remaining = power_manager.get_remaining_duration(1)
	assert_true(remaining > 7.0 and remaining <= 8.0, "Remaining duration should be close to configured value")
	
	# Clean up
	power_manager.deactivate_power(1)

func test_configuration_persistence():
	"""Test configuration save and load"""
	# Make some changes
	config_manager.set_power_duration("invincibility", 12.0)
	config_manager.set_spawn_chance("invincibility", 0.25)
	config_manager.set_system_enabled(false)
	
	# Save configuration
	var save_success = config_manager.save_configuration()
	assert_true(save_success, "Configuration save should succeed")
	
	# Reset to defaults
	config_manager.load_configuration()
	
	# Verify values were reset
	assert_eq(config_manager.get_power_duration("invincibility"), 10.0, "Should reset to default duration")
	assert_eq(config_manager.get_spawn_chance("invincibility"), 0.15, "Should reset to default spawn chance")
	assert_true(config_manager.is_system_enabled(), "Should reset to enabled")
	
	# Load saved configuration
	var load_success = config_manager.load_configuration()
	assert_true(load_success, "Configuration load should succeed")
	
	# Check if user config exists and has our changes
	if FileAccess.file_exists("user://power_system_config.json"):
		# If user config exists, it should have our saved values
		# Note: This test may vary depending on whether user config was actually saved
		print("[PowerConfigTest] User configuration file exists")

func test_spawn_rate_accuracy():
	"""Test spawn rate accuracy over multiple attempts"""
	# Set a known spawn rate
	config_manager.set_spawn_chance("invincibility", 0.3)  # 30%
	
	var spawn_count = 0
	var total_attempts = 100
	
	# Run multiple spawn checks
	for i in total_attempts:
		if power_manager.should_spawn_power_egg("EnemyBase"):
			spawn_count += 1
	
	var actual_rate = float(spawn_count) / float(total_attempts)
	
	# Allow for some variance (±10% of expected rate)
	var expected_rate = 0.3
	var tolerance = 0.1
	
	assert_true(actual_rate >= expected_rate - tolerance and actual_rate <= expected_rate + tolerance,
		"Spawn rate should be approximately 30% (got %.1f%%)" % (actual_rate * 100))

func test_configuration_validation():
	"""Test configuration validation"""
	var issues = config_manager.validate_configuration()
	assert_true(issues is Array, "Validation should return array")
	
	# Default configuration should be valid
	assert_eq(issues.size(), 0, "Default configuration should have no validation issues")
	
	# Test with invalid configuration
	var original_duration = config_manager.get_power_duration("invincibility")
	config_manager.set_power_duration("invincibility", -5.0)  # Invalid negative duration
	
	# The config manager should clamp this to a valid value
	var clamped_duration = config_manager.get_power_duration("invincibility")
	assert_true(clamped_duration > 0, "Duration should be clamped to positive value")

func test_debug_tools_integration():
	"""Test debug tools integration"""
	# Enable debug mode
	config_manager.set_debug_mode(true)
	
	# Test that debug UI methods exist
	if power_manager.has_method("toggle_debug_ui"):
		# This should not crash
		power_manager.toggle_debug_ui()
		print("[PowerConfigTest] Debug UI toggle method available")
	
	# Test configuration methods
	if power_manager.has_method("reload_configuration"):
		power_manager.reload_configuration()
		print("[PowerConfigTest] Configuration reload method available")
	
	if power_manager.has_method("save_configuration"):
		power_manager.save_configuration()
		print("[PowerConfigTest] Configuration save method available")

func run_all_tests():
	"""Run all configuration integration tests"""
	print("\n=== Power Configuration Integration Tests ===")
	
	var tests = [
		"test_configuration_manager_integration",
		"test_system_enable_disable_integration",
		"test_runtime_parameter_changes",
		"test_debug_mode_integration",
		"test_power_activation_with_config",
		"test_configuration_persistence",
		"test_spawn_rate_accuracy",
		"test_configuration_validation",
		"test_debug_tools_integration"
	]
	
	for test_method in tests:
		setup()
		call(test_method)
		teardown()
	
	print_results()