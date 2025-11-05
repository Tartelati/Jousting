extends TestBase

# Comprehensive integration test for the complete power system
# Tests the full flow: enemy defeat -> power egg spawn -> collection -> activation -> effects -> expiration

var power_manager: Node
var test_scene: Node

func _ready():
	print("Starting Comprehensive Power System Integration Test...")
	run_integration_tests()

func run_integration_tests():
	"""Run comprehensive integration tests for the power system"""
	
	# Get PowerManager
	power_manager = get_node("/root/PowerManager")
	if not power_manager:
		print("❌ CRITICAL: PowerManager autoload not found!")
		return
	
	print("✓ PowerManager autoload found")
	
	# Create test scene container
	test_scene = Node.new()
	add_child(test_scene)
	
	# Run comprehensive tests
	await test_complete_power_flow()
	await test_multi_player_power_scenarios()
	await test_power_system_performance()
	await test_error_recovery_scenarios()
	
	print("\n🎉 Comprehensive Power System Integration Tests Complete!")
	
	# Clean up
	if test_scene:
		test_scene.queue_free()

func test_complete_power_flow():
	"""Test the complete power system flow from enemy defeat to power expiration"""
	print("\n--- Testing Complete Power Flow ---")
	
	# Step 1: Test power egg spawning logic
	var spawn_success_count = 0
	var total_spawn_tests = 100
	
	for i in total_spawn_tests:
		if power_manager.should_spawn_power_egg("EnemyBase"):
			spawn_success_count += 1
	
	var spawn_rate = float(spawn_success_count) / float(total_spawn_tests)
	print("✓ Power egg spawn rate: %.1f%% (%d/%d)" % [spawn_rate * 100, spawn_success_count, total_spawn_tests])
	
	# Step 2: Test power egg instantiation and setup
	var power_egg_scene = power_manager.get_power_egg_scene()
	if power_egg_scene:
		var power_egg = power_egg_scene.instantiate()
		test_scene.add_child(power_egg)
		
		await get_tree().process_frame
		
		print("✓ Power egg instantiated successfully")
		print("  - Power type: %d" % power_egg.power_type)
		print("  - Collection points: %d" % power_egg.collection_points)
		print("  - Timeout duration: %.1fs" % power_egg.timeout_duration)
		
		# Step 3: Test power collection and activation
		var initial_score = ScoreManager.get_score(1) if ScoreManager else 0
		power_egg.collect(1)
		
		await get_tree().process_frame
		
		if power_manager.is_power_active(1):
			print("✓ Power activated successfully after collection")
			print("  - Active power type: %d" % power_manager.get_active_power_type(1))
			print("  - Remaining duration: %.1fs" % power_manager.get_remaining_duration(1))
		else:
			print("❌ Power activation failed after collection")
		
		if ScoreManager:
			var final_score = ScoreManager.get_score(1)
			if final_score > initial_score:
				print("✓ Score increased by %d points" % (final_score - initial_score))
			else:
				print("❌ Score did not increase after collection")
	else:
		print("❌ Power egg scene could not be loaded")

func test_multi_player_power_scenarios():
	"""Test complex multi-player power scenarios"""
	print("\n--- Testing Multi-Player Power Scenarios ---")
	
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Scenario 1: All players activate powers simultaneously
	print("\n🧪 Scenario 1: Simultaneous activation for all players")
	for player_index in range(1, 5):
		var result = power_manager.activate_power(player_index, power_type)
		if result:
			print("  ✓ Player %d power activated" % player_index)
		else:
			print("  ❌ Player %d power activation failed" % player_index)
	
	# Verify independence
	var all_independent = true
	for player_index in range(1, 5):
		if not power_manager.is_power_active(player_index):
			all_independent = false
			break
	
	if all_independent:
		print("✓ All players have independent active powers")
	else:
		print("❌ Power independence failed")
	
	# Scenario 2: Staggered power expiration
	print("\n🧪 Scenario 2: Staggered power expiration")
	
	# Set different expiration times
	for player_index in range(1, 5):
		var power_data = power_manager.active_powers[player_index]
		if power_data:
			# Player 1: 1 second remaining, Player 2: 2 seconds, etc.
			power_data.start_time = Time.get_time_dict_from_system().unix - (10.0 - player_index)
	
	# Update timers and check expiration
	for second in range(5):
		power_manager.update_power_timers(1.0)
		await get_tree().process_frame
		
		var active_count = 0
		for player_index in range(1, 5):
			if power_manager.is_power_active(player_index):
				active_count += 1
		
		print("  After %d seconds: %d players still have active powers" % [second + 1, active_count])
	
	# Scenario 3: Power replacement during active power
	print("\n🧪 Scenario 3: Power replacement")
	power_manager.activate_power(1, power_type)
	var initial_duration = power_manager.get_remaining_duration(1)
	
	await wait_frames(30)  # Wait half a second
	
	power_manager.activate_power(1, power_type)  # Reactivate
	var new_duration = power_manager.get_remaining_duration(1)
	
	if new_duration >= initial_duration:
		print("✓ Power replacement resets duration correctly")
	else:
		print("❌ Power replacement failed to reset duration")

func test_power_system_performance():
	"""Test power system performance under load"""
	print("\n--- Testing Power System Performance ---")
	
	var start_time = Time.get_time_dict_from_system().unix
	var power_type = power_manager.PowerType.INVINCIBILITY
	
	# Performance test 1: Rapid activation/deactivation
	print("\n🧪 Performance Test 1: Rapid activation/deactivation")
	for cycle in 100:
		for player_index in range(1, 5):
			power_manager.activate_power(player_index, power_type)
			power_manager.deactivate_power(player_index)
	
	var rapid_test_time = Time.get_time_dict_from_system().unix - start_time
	print("  Completed 400 activation/deactivation cycles in %.3fs" % rapid_test_time)
	
	# Performance test 2: Multiple simultaneous powers with updates
	print("\n🧪 Performance Test 2: Multiple simultaneous powers")
	start_time = Time.get_time_dict_from_system().unix
	
	# Activate all powers
	for player_index in range(1, 5):
		power_manager.activate_power(player_index, power_type)
	
	# Run many update cycles
	for frame in 300:  # 5 seconds at 60fps
		power_manager.update_power_timers(1.0/60.0)
		if frame % 60 == 0:  # Every second
			await get_tree().process_frame
	
	var update_test_time = Time.get_time_dict_from_system().unix - start_time
	print("  Completed 300 update cycles with 4 active powers in %.3fs" % update_test_time)
	
	# Performance test 3: Memory usage stability
	print("\n🧪 Performance Test 3: Memory usage stability")
	var initial_active_count = power_manager.active_powers.size()
	var initial_timer_count = power_manager.power_timers.size()
	
	# Create and destroy many powers
	for cycle in 50:
		for player_index in range(1, 5):
			power_manager.activate_power(player_index, power_type)
		power_manager.reset_all_powers()
	
	var final_active_count = power_manager.active_powers.size()
	var final_timer_count = power_manager.power_timers.size()
	
	if final_active_count == initial_active_count and final_timer_count == initial_timer_count:
		print("✓ Memory usage remains stable after 200 power cycles")
	else:
		print("❌ Memory leak detected: active=%d->%d, timers=%d->%d" % 
			[initial_active_count, final_active_count, initial_timer_count, final_timer_count])

func test_error_recovery_scenarios():
	"""Test error recovery and edge case handling"""
	print("\n--- Testing Error Recovery Scenarios ---")
	
	# Error scenario 1: Invalid player indices
	print("\n🧪 Error Scenario 1: Invalid player indices")
	var invalid_indices = [-1, 0, 5, 999]
	for invalid_index in invalid_indices:
		var result = power_manager.activate_power(invalid_index, power_manager.PowerType.INVINCIBILITY)
		if not result:
			print("  ✓ Invalid player index %d properly rejected" % invalid_index)
		else:
			print("  ❌ Invalid player index %d was accepted" % invalid_index)
	
	# Error scenario 2: Corrupted power data
	print("\n🧪 Error Scenario 2: Corrupted power data handling")
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	
	# Corrupt the power data
	power_manager.active_powers[1] = null
	power_manager.active_powers[2] = "invalid_string"
	
	# Update should handle corruption gracefully
	power_manager.update_power_timers(0.016)
	print("  ✓ System handled corrupted power data without crashing")
	
	# Error scenario 3: Missing configuration
	print("\n🧪 Error Scenario 3: Missing configuration handling")
	var original_config_manager = power_manager.config_manager
	power_manager.config_manager = null
	
	var result = power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	if not result:
		print("  ✓ System properly handles missing configuration")
	else:
		print("  ❌ System should reject activation when configuration is missing")
	
	# Restore configuration
	power_manager.config_manager = original_config_manager
	
	# Error scenario 4: Timer system failure
	print("\n🧪 Error Scenario 4: Timer system failure recovery")
	power_manager.activate_power(1, power_manager.PowerType.INVINCIBILITY)
	
	# Remove timer to simulate failure
	if power_manager.power_timers.has(1):
		power_manager.power_timers[1].queue_free()
		power_manager.power_timers.erase(1)
	
	# Force expiration should still work
	power_manager._force_power_expiration(1)
	
	if not power_manager.is_power_active(1):
		print("  ✓ Force expiration works even with timer failure")
	else:
		print("  ❌ Force expiration failed")
	
	print("\n✅ All error recovery scenarios tested")