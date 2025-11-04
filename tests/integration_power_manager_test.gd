extends TestBase

# Integration test for PowerManager functionality
# This test verifies the PowerManager works correctly in a real game context

var power_manager: Node

func _ready():
	print("Starting PowerManager Integration Test...")
	run_integration_tests()

func run_integration_tests():
	"""Run integration tests for PowerManager"""
	power_manager = get_node("/root/PowerManager")
	
	if not power_manager:
		print("❌ CRITICAL: PowerManager autoload not found!")
		return
	
	print("✓ PowerManager autoload found")
	
	# Test basic functionality
	test_basic_power_system()
	test_spawn_probability_system()
	test_multi_player_powers()
	test_configuration_system()
	
	print("\n🎉 PowerManager Integration Tests Complete!")

func test_basic_power_system():
	"""Test basic power activation and deactivation"""
	print("\n--- Testing Basic Power System ---")
	
	var player_index = 1
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Test initial state
	if not power_manager.is_power_active(player_index):
		print("✓ No power active initially")
	else:
		print("❌ Power should not be active initially")
	
	# Test activation
	var result = power_manager.activate_power(player_index, power_type)
	if result and power_manager.is_power_active(player_index):
		print("✓ Power activation successful")
	else:
		print("❌ Power activation failed")
	
	# Test duration tracking
	var remaining = power_manager.get_remaining_duration(player_index)
	if remaining > 0 and remaining <= 10.0:
		print("✓ Duration tracking working (%.1fs remaining)" % remaining)
	else:
		print("❌ Duration tracking failed")
	
	# Test deactivation
	power_manager.deactivate_power(player_index)
	if not power_manager.is_power_active(player_index):
		print("✓ Power deactivation successful")
	else:
		print("❌ Power deactivation failed")

func test_spawn_probability_system():
	"""Test power egg spawn probability logic"""
	print("\n--- Testing Spawn Probability System ---")
	
	# Test spawn logic for different enemy types
	var enemy_types = ["EnemyBase", "EnemyHunter", "ShadowLord", "UnknownEnemy"]
	
	for enemy_type in enemy_types:
		var spawn_count = 0
		var total_tests = 50
		
		for i in total_tests:
			if power_manager.should_spawn_power_egg(enemy_type):
				spawn_count += 1
		
		var spawn_rate = float(spawn_count) / float(total_tests) * 100.0
		print("✓ %s spawn rate: %.1f%% (%d/%d)" % [enemy_type, spawn_rate, spawn_count, total_tests])

func test_multi_player_powers():
	"""Test multi-player power independence"""
	print("\n--- Testing Multi-Player Powers ---")
	
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Activate powers for multiple players
	for player_index in range(1, 5):
		var result = power_manager.activate_power(player_index, power_type)
		if result:
			print("✓ Player %d power activated" % player_index)
		else:
			print("❌ Player %d power activation failed" % player_index)
	
	# Verify all players have independent powers
	var active_count = 0
	for player_index in range(1, 5):
		if power_manager.is_power_active(player_index):
			active_count += 1
	
	if active_count == 4:
		print("✓ All 4 players have independent active powers")
	else:
		print("❌ Expected 4 active powers, got %d" % active_count)
	
	# Test selective deactivation
	power_manager.deactivate_power(2)
	if not power_manager.is_power_active(2) and power_manager.is_power_active(1):
		print("✓ Selective power deactivation working")
	else:
		print("❌ Selective power deactivation failed")
	
	# Clean up
	power_manager.reset_all_powers()

func test_configuration_system():
	"""Test power configuration system"""
	print("\n--- Testing Configuration System ---")
	
	var power_type = power_manager.PowerType.INVINCIBILITY
	var config = power_manager.get_power_config(power_type)
	
	if config.has("duration") and config.has("spawn_chance"):
		print("✓ Power configuration accessible")
	else:
		print("❌ Power configuration missing required fields")
	
	# Test configuration modification
	var original_duration = config.duration
	power_manager.set_power_duration(power_type, 15.0)
	
	var updated_config = power_manager.get_power_config(power_type)
	if updated_config.duration == 15.0:
		print("✓ Configuration modification working")
	else:
		print("❌ Configuration modification failed")
	
	# Restore original
	power_manager.set_power_duration(power_type, original_duration)
	
	# Test debug info
	var debug_info = power_manager.get_debug_info()
	if debug_info.has("active_powers_count") and debug_info.has("power_configs"):
		print("✓ Debug information available")
	else:
		print("❌ Debug information incomplete")